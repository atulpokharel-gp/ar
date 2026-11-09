import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

@MainActor final class ReferenceTargetStore: ObservableObject {
    @Published var reference: ARReferenceImage?
    @Published var preview: UIImage?
    @Published var widthCM = "15"
    @Published var name = "No reference image"
    @Published var status = "Import an image you can print at a known size."
    @Published var running = false
    @Published var validating = false
    @Published var tracked = false
    @Published var error: String?
    private var generation = UUID()

    func load(_ url: URL) {
        stop()
        reference = nil; preview = nil
        guard let cm = Double(widthCM), cm.isFinite, cm >= 2, cm <= 100 else {
            error = "Enter a printed width between 2 and 100 cm before importing."; return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 10_000_000 else { throw GuideError.message("Choose an image under 10 MB.") }
            let data = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1600
                  ] as CFDictionary), image.width >= 100, image.height >= 100 else {
                throw GuideError.message("Use a readable PNG or JPEG with at least 100 pixels on each side.")
            }
            let candidate = ARReferenceImage(image, orientation: .up, physicalWidth: CGFloat(cm / 100))
            candidate.name = url.lastPathComponent
            let requestID = UUID(); generation = requestID
            validating = true; status = "Checking reference-image quality…"
            candidate.validate { [weak self] failure in
                DispatchQueue.main.async {
                    guard let self, self.generation == requestID else { return }
                    self.validating = false
                    if let failure { self.status = "Reference rejected"; self.error = failure.localizedDescription; return }
                    self.reference = candidate
                    self.preview = UIImage(cgImage: image)
                    self.name = url.lastPathComponent
                    self.status = "Ready. Print this exact image at \(cm) cm wide."
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func stop() { running = false; tracked = false }
    func reset() {
        generation = UUID(); validating = false; stop()
        reference = nil; preview = nil; name = "No reference image"
        status = "Import an image at the new printed width."
    }
}

struct ReferenceTrackingView: View {
    @StateObject private var target = ReferenceTargetStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Let the image anchor the guide.").font(.title.bold())
                    Text("Import a detailed flat image, print it, and enter its actual width. The camera can recognize that image and attach an animated overlay to it.").foregroundStyle(.secondary)
                    HStack {
                        Text("Printed width (cm)")
                        TextField("15", text: $target.widthCM).keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                            .disabled(target.running || target.validating)
                    }
                    .onChange(of: target.widthCM) { _, _ in target.reset() }
                    Button("Import reference PNG / JPEG") { importing = true }
                        .disabled(target.running || target.validating)
                    if let image = target.preview {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 130)
                    }
                    Text(target.name).font(.caption).foregroundStyle(.secondary)
                    if target.validating { ProgressView("Validating image") }
                    if target.running {
                        ReferenceCamera(target: target).frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        Button("Stop tracking", role: .destructive) { target.stop() }
                    } else {
                        Button("Start image tracking") { target.running = true }
                            .buttonStyle(.borderedProminent).disabled(target.reference == nil || target.validating)
                    }
                    Label(target.status, systemImage: target.tracked ? "checkmark.viewfinder" : "viewfinder")
                        .foregroundStyle(target.tracked ? Color.mint : Color.secondary)
                    Text("This recognizes only the imported image. It does not recognize a device, confirm a repair, or measure part positions. Keep the printed target well lit and visible. Surface drawing remains in the main Guide view.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Images remain on this iPhone and are discarded when you close this view.").font(.caption)
                }.padding(24)
            }.navigationTitle("Image target")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { target.stop(); dismiss() } } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg]) { result in
                    switch result {
                    case .success(let url): target.load(url)
                    case .failure(let error): target.error = error.localizedDescription
                    }
                }
                .alert("Image target", isPresented: Binding(get: { target.error != nil }, set: { if !$0 { target.error = nil } })) {
                    Button("OK") { target.error = nil }
                } message: { Text(target.error ?? "") }
                .onChange(of: scenePhase) { _, phase in if phase != .active { target.stop() } }
                .onDisappear { target.stop() }
        }
    }
}

@MainActor struct ReferenceCamera: UIViewRepresentable {
    @ObservedObject var target: ReferenceTargetStore
    func makeCoordinator() -> Coordinator { Coordinator(target) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene(); view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.start()
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        coordinator.active = false
        uiView.session.pause(); uiView.delegate = nil; uiView.session.delegate = nil
    }
    @MainActor final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        let target: ReferenceTargetStore
        weak var view: ARSCNView?
        var active = false
        var cameraNormal = false
        var imageTracked = false
        var overlay: SCNNode?
        var anchorID: UUID?
        init(_ target: ReferenceTargetStore) { self.target = target }
        func start() {
            guard target.running, let reference = target.reference, let view else { return }
            guard ARImageTrackingConfiguration.isSupported else {
                target.status = "Image tracking needs a compatible physical iPhone."; return
            }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                let config = ARImageTrackingConfiguration()
                config.trackingImages = [reference]; config.maximumNumberOfTrackedImages = 1
                active = true
                view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                DispatchQueue.main.async { self.target.status = "Point at the printed reference image." }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { _ in DispatchQueue.main.async { self.start() } }
            default:
                DispatchQueue.main.async { self.target.status = "Allow Camera in iPhone Settings, then restart." }
            }
        }
        func refreshVisibility() {
            let visible = active && target.running && cameraNormal && imageTracked
            overlay?.isHidden = !visible; target.tracked = visible
            target.status = visible ? "Reference tracked · overlay follows the image" : "Target not tracked · keep the entire printed image visible"
        }
        nonisolated func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let image = anchor as? ARImageAnchor else { return }
            DispatchQueue.main.async {
                guard self.active, self.target.running else { return }
                self.overlay?.removeFromParentNode()
                let width = image.referenceImage.physicalSize.width
                let height = image.referenceImage.physicalSize.height
                let geometry = SCNPlane(width: width, height: height)
                geometry.firstMaterial?.diffuse.contents = UIColor.systemMint.withAlphaComponent(0.25)
                geometry.firstMaterial?.lightingModel = .constant
                geometry.firstMaterial?.isDoubleSided = true
                let plane = SCNNode(geometry: geometry)
                plane.eulerAngles.x = -.pi / 2; plane.position.y = 0.001
                // Parent to ARKit's image anchor node: its transform follows image updates.
                node.addChildNode(plane)
                plane.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.4, duration: 0.8), .fadeOpacity(to: 1, duration: 0.8)])))
                self.overlay = plane; self.anchorID = image.identifier
                self.imageTracked = image.isTracked; self.refreshVisibility()
            }
        }
        nonisolated func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let image = anchor as? ARImageAnchor else { return }
            DispatchQueue.main.async {
                guard self.active, self.anchorID == image.identifier else { return }
                self.imageTracked = image.isTracked; self.refreshVisibility()
            }
        }
        nonisolated func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            DispatchQueue.main.async {
                guard self.anchorID == anchor.identifier else { return }
                self.imageTracked = false; self.refreshVisibility()
            }
        }
        nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let normal: Bool
            if case .normal = camera.trackingState { normal = true } else { normal = false }
            DispatchQueue.main.async { self.cameraNormal = normal; self.refreshVisibility() }
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            DispatchQueue.main.async { self.cameraNormal = false; self.imageTracked = false; self.refreshVisibility() }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async {
                guard self.target.running else { return }
                self.overlay?.removeFromParentNode(); self.overlay = nil; self.anchorID = nil
                self.cameraNormal = false; self.imageTracked = false; self.start()
            }
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.active = false; self.refreshVisibility()
                self.target.status = "Tracking failed. Stop and restart the image session."
            }
        }
    }
}
