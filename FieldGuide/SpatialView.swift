import SwiftUI
import ARKit
import SceneKit
import AVFoundation

@MainActor struct SpatialView: UIViewRepresentable {
    @ObservedObject var store: GuideStore
    func makeCoordinator() -> Coordinator { Coordinator(store) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene(); view.automaticallyUpdatesLighting = true
        view.session.delegate = context.coordinator
        context.coordinator.view = view
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.place(_:))))
        return view
    }
    func updateUIView(_ view: ARSCNView, context: Context) { context.coordinator.sync() }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        coordinator.active = false; view.session.pause(); view.session.delegate = nil
    }
    @MainActor final class Coordinator: NSObject, ARSessionDelegate {
        let store: GuideStore
        weak var view: ARSCNView?
        var active = false
        var requesting = false
        var marker: SCNNode?
        var token: UUID?
        var action = ""
        init(_ store: GuideStore) { self.store = store }
        func sync() {
            guard let view else { return }
            if token != store.resetToken {
                marker?.removeFromParentNode(); marker = nil; token = store.resetToken; action = ""
            }
            if !store.running { active = false; view.session.pause(); return }
            if !active && !requesting {
                guard ARWorldTrackingConfiguration.isSupported else {
                    DispatchQueue.main.async { self.store.trackingMessage = "AR needs a compatible physical iPhone. Simulator is unsupported." }
                    return
                }
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    let config = ARWorldTrackingConfiguration()
                    config.planeDetection = [.horizontal, .vertical]
                    view.session.run(config, options: [.resetTracking, .removeExistingAnchors]); active = true
                case .notDetermined:
                    requesting = true
                    AVCaptureDevice.requestAccess(for: .video) { _ in DispatchQueue.main.async {
                        self.requesting = false; self.sync()
                    } }
                default:
                    DispatchQueue.main.async { self.store.trackingMessage = "Allow Camera in iPhone Settings to use AR." }
                }
            }
            if action != store.step.action { action = store.step.action; animate() }
        }
        @objc func place(_ gesture: UITapGestureRecognizer) {
            guard store.running, store.trackingReady, let view,
                  let query = view.raycastQuery(from: gesture.location(in: view), allowing: .estimatedPlane, alignment: .any),
                  let result = view.session.raycast(query).first else { return }
            marker?.removeFromParentNode()
            let root = SCNNode(); root.simdTransform = result.worldTransform
            // A world-space cue, not object tracking. Moving the box requires repositioning.
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.035, pipeRadius: 0.003))
            ring.geometry?.firstMaterial?.diffuse.contents = UIColor.systemMint
            ring.geometry?.firstMaterial?.lightingModel = .constant
            root.addChildNode(ring)
            let tip = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.012, height: 0.025))
            tip.position.y = 0.045
            tip.geometry?.firstMaterial?.diffuse.contents = UIColor.systemMint
            tip.geometry?.firstMaterial?.lightingModel = .constant
            root.addChildNode(tip)
            view.scene.rootNode.addChildNode(root); marker = root; store.anchorPlaced = true; animate()
        }
        func animate() {
            guard let marker else { return }
            for child in marker.childNodes { child.removeAllActions() }
            guard let ring = marker.childNodes.first else { return }
            ring.position = SCNVector3Zero; ring.scale = SCNVector3(1, 1, 1)
            let animation: SCNAction
            switch store.step.action {
            case "lift": animation = .sequence([.moveBy(x: 0, y: 0.07, z: 0, duration: 0.9), .moveBy(x: 0, y: -0.07, z: 0, duration: 0.9)])
            case "rotate": animation = .rotateBy(x: 0, y: .pi * 2, z: 0, duration: 2)
            default: animation = .sequence([.scale(to: 1.2, duration: 0.7), .scale(to: 1, duration: 0.7)])
            }
            ring.runAction(.repeatForever(animation))
        }
        nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let ready: Bool
            let message: String
            switch camera.trackingState {
            case .normal: ready = true; message = "Tracking ready · tap a surface to place your cue"
            case .limited: ready = false; message = "Tracking limited · move slowly in a well-lit area"
            case .notAvailable: ready = false; message = "Tracking unavailable"
            }
            DispatchQueue.main.async {
                self.store.trackingReady = ready
                self.store.trackingMessage = message
                self.marker?.isHidden = !ready
            }
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            DispatchQueue.main.async {
                self.store.trackingReady = false; self.store.trackingMessage = "Session interrupted"
                self.marker?.isHidden = true
            }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async { self.active = false; self.store.resetAnchor(); self.sync() }
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.active = false; self.store.trackingReady = false
                self.store.trackingMessage = "AR failed. Stop and restart the practice session."
                self.marker?.isHidden = true
            }
        }
    }
}
