import SwiftUI
import AVFoundation
import PDFKit

@MainActor final class GuideStore: ObservableObject {
    @Published var index = 0
    @Published var confirmed = false
    @Published var completed = false
    @Published var running = false
    @Published var anchorPlaced = false
    @Published var trackingReady = false
    @Published var trackingMessage = "Camera is off"
    @Published var resetToken = UUID()
    @Published var pages: [ManualPage] = []
    @Published var manualName = "No manual imported"
    @Published var question = ""
    @Published var reply: AgentReply?
    @Published var busy = false
    @Published var error: String?
    @Published var selectedTab = 0
    @Published var endpoint = ""
    @Published var accessToken = ""
    @Published var consent = false
    private let speaker = AVSpeechSynthesizer()
    var step: GuideStep { practiceSteps[index] }
    var canAdvance: Bool { running && confirmed && (index == 0 || (anchorPlaced && trackingReady)) }
    var event: GuidanceEvent {
        .init(version: 1, stepID: step.id, action: SpatialAction(rawValue: step.action) ?? .inspect,
              anchorMode: "manual-world-anchor", requiresConfirmation: true)
    }
    func start() { index = 0; completed = false; confirmed = false; running = true; trackingReady = false; resetAnchor() }
    func resetAnchor() { anchorPlaced = false; resetToken = UUID() }
    func stop() { running = false; trackingReady = false; confirmed = false; resetAnchor(); speaker.stopSpeaking(at: .immediate) }
    func next() {
        guard canAdvance else { return }
        speaker.stopSpeaking(at: .immediate)
        if index == practiceSteps.count - 1 { completed = true; stop() }
        else { index += 1; confirmed = false }
    }
    func back() {
        guard index > 0 else { return }
        index -= 1; confirmed = false; speaker.stopSpeaking(at: .immediate)
    }
    func speak() {
        speaker.stopSpeaking(at: .immediate)
        let speech = AVSpeechUtterance(string: step.instruction)
        speech.rate = 0.46
        speaker.speak(speech)
    }
    func importManual(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20_000_000 else { throw GuideError.message("Choose a PDF under 20 MB.") }
            guard let pdf = PDFDocument(url: url), !pdf.isLocked else { throw GuideError.message("This PDF cannot be opened or is locked.") }
            guard pdf.pageCount <= 300 else { throw GuideError.message("Choose a manual with at most 300 pages.") }
            let extracted = (0..<pdf.pageCount).compactMap { i -> ManualPage? in
                let text = (pdf.page(at: i)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : ManualPage(page: i + 1, text: text)
            }
            guard !extracted.isEmpty else { throw GuideError.message("No readable text found. Scanned manuals need OCR, which this prototype does not include.") }
            guard extracted.reduce(0, { $0 + $1.text.utf8.count }) <= 800_000 else { throw GuideError.message("Extracted text exceeds the prototype limit. Import a shorter section.") }
            pages = extracted; manualName = url.lastPathComponent; reply = nil
        } catch { self.error = error.localizedDescription }
    }
    func ask() async {
        guard !busy else { return }
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !pages.isEmpty else { error = "Import a manual and enter a question first."; return }
        guard q.count <= 2000 else { error = "Keep your question under 2,000 characters."; return }
        reply = nil
        if endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let words = Set(q.lowercased().split { !$0.isLetter && !$0.isNumber }.filter { $0.count > 2 }.map(String.init))
            let matches = pages.map { page in
                (page, words.filter { page.text.lowercased().contains($0) }.count)
            }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(3)
            reply = AgentReply(answer: matches.isEmpty ? "No matching passage found. Try the manual's exact terminology." : matches.map { "Page \($0.0.page)\n\(String($0.0.text.prefix(1800)))" }.joined(separator: "\n\n"), pages: matches.map { $0.0.page }, mode: "Local keyword search · not AI")
            return
        }
        guard consent else { error = "Enable permission to send manual text to your configured server and its AI provider."; return }
        guard let base = URL(string: endpoint), base.scheme == "https", base.host != nil,
              base.user == nil, base.password == nil, base.query == nil, base.fragment == nil else {
            error = "Enter an HTTPS server URL without credentials or query parameters."; return
        }
        guard !accessToken.isEmpty else { error = "Enter your backend access token."; return }
        busy = true
        defer { busy = false }
        do {
            var request = URLRequest(url: base.appendingPathComponent("ask"))
            request.httpMethod = "POST"; request.timeoutInterval = 50
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(AskRequest(question: q, pages: pages))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw GuideError.message("Agent request failed. Check server configuration and access token. No simulated answer was substituted.")
            }
            reply = try JSONDecoder().decode(AgentReply.self, from: data)
        } catch { self.error = error.localizedDescription }
    }
}
struct AskRequest: Encodable { let question: String; let pages: [ManualPage] }
enum GuideError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
