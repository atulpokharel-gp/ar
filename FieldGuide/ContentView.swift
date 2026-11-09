import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: GuideStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $store.selectedTab) {
            PracticeView().tabItem { Label("Guide", systemImage: "viewfinder") }.tag(0)
            TeamView().tabItem { Label("Agents", systemImage: "person.3") }.tag(4)
            ManualView().tabItem { Label("Manual", systemImage: "doc.text") }.tag(1)
            AgentView().tabItem { Label("Ask", systemImage: "waveform") }.tag(2)
            SettingsView().tabItem { Label("Connect", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .onChange(of: store.selectedTab) { _, tab in if tab != 0 { store.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.stop() } }
        .alert("FieldGuide", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
struct PracticeView: View {
    @State private var imageTargetOpen = false
    @EnvironmentObject var store: GuideStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label("FIELDGUIDE", systemImage: "sparkle").font(.caption.bold()).tracking(3)
                        Spacer()
                        Text("SPATIAL LAB").font(.caption2.bold()).padding(8).background(.mint.opacity(0.15), in: Capsule())
                    }.foregroundStyle(.mint)
                    Text(store.completed ? "Practice complete." : "See it.\nUnderstand it.\nDo it.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("Demonstrate ideas in real space with markers, arrows and sketches.").foregroundStyle(.secondary)
                    if !store.running {
                        Button { store.stop(); imageTargetOpen = true } label: {
                            Label("Track a reference image", systemImage: "photo.on.rectangle.angled")
                        }.buttonStyle(.bordered)
                        Picker("Demo scenario", selection: Binding(get: { store.scenarioID }, set: { store.selectScenario($0) })) {
                            ForEach(demoScenarios) { scenario in Text(scenario.name).tag(scenario.id) }
                        }.pickerStyle(.menu)
                        VStack(alignment: .leading, spacing: 14) {
                            Label(store.scenario.name, systemImage: "shippingbox")
                                .font(.headline)
                            Text(store.scenario.detail + " These are authored practice scenarios, not AI-generated or verified field procedures.").foregroundStyle(.secondary)
                            Button(store.completed ? "Try again" : "Start AR practice") { store.start() }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                        }.padding(20).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                    } else {
                        ZStack(alignment: .topLeading) {
                            SpatialView(store: store).frame(height: 320)
                            Text(store.anchorPlaced ? "MANUAL ANCHOR" : "TAP TO PLACE A CUE")
                                .font(.caption.bold()).padding(10).background(.black.opacity(0.7), in: Capsule()).padding()
                        }.clipShape(RoundedRectangle(cornerRadius: 24))
                        Label(store.trackingMessage, systemImage: store.trackingReady ? "scope" : "exclamationmark.circle")
                            .font(.caption).foregroundStyle(store.trackingReady ? Color.mint : Color.orange)
                        Picker("Spatial tool", selection: $store.overlayTool) {
                            ForEach(OverlayTool.allCases) { tool in Text(tool.rawValue.capitalized).tag(tool) }
                        }.pickerStyle(.segmented)
                        Text(store.overlayTool == .draw ? "Drag on a detected surface to draw. Keep the camera steady." : store.overlayTool == .arrow ? "Tap a start point, then tap the destination to draw an arrow." : "Tap a detected surface to place a marker.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Clear annotations") { store.clearDrawing() }.font(.footnote)
                        ProgressView(value: Double(store.index), total: Double(store.steps.count))
                        VStack(alignment: .leading, spacing: 14) {
                            Text("STEP \(store.index + 1) OF \(store.steps.count)").font(.caption.bold()).foregroundStyle(.mint)
                            Text(store.step.title).font(.title2.bold())
                            Text(store.step.instruction).foregroundStyle(.secondary)
                            Button { store.speak() } label: { Label("Read this step", systemImage: "speaker.wave.2") }
                            Toggle(store.step.confirmation, isOn: $store.confirmed)
                            if store.index > 0 && !store.anchorPlaced { Text("Place a cue in the camera view before continuing.").font(.caption).foregroundStyle(.orange) }
                            HStack {
                                Button("Back") { store.back() }.disabled(store.index == 0)
                                Spacer()
                                Button(store.index == store.steps.count - 1 ? "Finish" : "Next step") { store.next() }
                                    .buttonStyle(.borderedProminent).disabled(!store.canAdvance)
                            }
                            HStack {
                                Button("Reposition cue") { store.resetAnchor() }
                                Spacer()
                                Button("Stop", role: .destructive) { store.stop() }
                            }.font(.footnote)
                        }.padding(20).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                        Text("Keep the surface still. Drawings and cues are anchored to the room, not tracked to moving objects. Completion is confirmed by you.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(24)
            }.sheet(isPresented: $imageTargetOpen) { ReferenceTrackingView() }.scrollDisabled(store.running && store.overlayTool == .draw).background(Color(red: 0.035, green: 0.055, blue: 0.07)).toolbar(.hidden, for: .navigationBar)
        }
    }
}
struct ManualView: View {
    @EnvironmentObject var store: GuideStore
    @State private var importing = false
    var body: some View {
        NavigationStack {
            List {
                Section("Your source material") {
                    Label(store.manualName, systemImage: "doc.text")
                    Button("Import PDF manual") { importing = true }
                    Text("PDF text stays in memory on this phone unless you explicitly enable the connected agent. Imports do not generate or approve repair procedures.").font(.caption).foregroundStyle(.secondary)
                    if !store.pages.isEmpty {
                        Button("Remove manual", role: .destructive) { store.pages = []; store.manualName = "No manual imported"; store.reply = nil }
                    }
                }
                ForEach(store.pages) { page in
                    Section("PDF page \(page.page)") { Text(page.text).textSelection(.enabled) }
                }
            }.navigationTitle("Manual")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
                    switch result {
                    case .success(let url): store.importManual(url)
                    case .failure(let error): store.error = error.localizedDescription
                    }
                }
        }
    }
}
struct AgentView: View {
    @EnvironmentObject var store: GuideStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label(store.endpoint.isEmpty ? "Local manual search" : "Connected AI · reference only", systemImage: "text.magnifyingglass")
                        .font(.headline).foregroundStyle(.mint)
                    Text("Ask about your imported manual. AI answers are reference material and cannot change the AR practice steps.").foregroundStyle(.secondary)
                    TextField("What does the manual say about…", text: $store.question, axis: .vertical)
                        .lineLimit(3...6).padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    Button { Task { await store.ask() } } label: {
                        HStack { if store.busy { ProgressView() }; Text(store.busy ? "Reading…" : "Ask the manual") }
                    }.buttonStyle(.borderedProminent).disabled(store.busy || store.pages.isEmpty || store.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if store.pages.isEmpty { Text("Import a PDF in the Manual tab to begin.").foregroundStyle(.orange) }
                    if let reply = store.reply {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(reply.mode.uppercased()).font(.caption.bold()).foregroundStyle(.mint)
                            Text(reply.answer).textSelection(.enabled)
                            if !reply.pages.isEmpty { Text("PDF pages: " + reply.pages.map(String.init).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                        }.padding(20).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    }
                }.padding(24)
            }.navigationTitle("Ask FieldGuide")
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: GuideStore
    var body: some View {
        NavigationStack {
            Form {
                Section("Optional AI backend") {
                    TextField("https://your-server.example", text: $store.endpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    SecureField("Backend access token", text: $store.accessToken)
                    Toggle("Allow sending manual text and questions", isOn: $store.consent)
                    Text("Your server receives the manual and question, and sends selected passages to its AI provider. Camera images are never uploaded by this build. Credentials are held in memory and cleared when the app exits.").font(.caption)
                }
                Section("Dynamic interaction") {
                    Label("Step-dependent animation and controls", systemImage: "arrow.triangle.branch")
                    Label("Tracking-aware pause", systemImage: "viewfinder")
                    Label("Spoken instructions", systemImage: "speaker.wave.2")
                    Text("Voice commands, gaze/pinch, hand tracking, live scene recognition, and headset clients are planned—not implemented in this build.").font(.caption)
                }
                Section("Prototype 0.3") {
                    Text("iPhone first. Multiple authored demo domains, spatial drawing, and optional planner/reviewer/presenter agents. Generated plans remain review-only. Headset clients and live scene understanding are not implemented.")
                }
            }.navigationTitle("Connect")
        }
    }
}
