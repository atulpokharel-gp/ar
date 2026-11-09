import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import simd

@MainActor struct SpatialView: UIViewRepresentable {
    @ObservedObject var store: GuideStore
    func makeCoordinator() -> Coordinator { Coordinator(store) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = true
        view.session.delegate = context.coordinator
        context.coordinator.view = view
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.place(_:))))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.draw(_:)))
        pan.maximumNumberOfTouches = 1
        context.coordinator.drawingGesture = pan
        view.addGestureRecognizer(pan)
        return view
    }
    func updateUIView(_ view: ARSCNView, context: Context) { context.coordinator.sync() }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        coordinator.active = false
        coordinator.clearAll()
        view.session.pause()
        view.session.delegate = nil
    }

    @MainActor final class Coordinator: NSObject, ARSessionDelegate {
        let store: GuideStore
        weak var view: ARSCNView?
        weak var drawingGesture: UIPanGestureRecognizer?
        var active = false
        var requesting = false
        var failed = false
        var marker: SCNNode?
        var drawings: [SCNNode] = []
        var arrows: [SCNNode] = []
        var pendingArrow: SIMD3<Float>?
        var pendingDot: SCNNode?
        var lastPoint: SIMD3<Float>?
        var token: UUID?
        var drawingToken: UUID?
        var selectedTool: OverlayTool?
        var action = ""
        // Bounded scene complexity: at most one marker, 600 drawing segments and 24 arrows.
        let maxSegments = 600
        let maxArrows = 24

        init(_ store: GuideStore) { self.store = store }
        func sync() {
            guard let view else { return }
            drawingGesture?.isEnabled = store.overlayTool == .draw
            if token != store.resetToken {
                clearAll()
                token = store.resetToken
                action = ""
                failed = false
            }
            if drawingToken != store.clearDrawingToken {
                clearAll()
                drawingToken = store.clearDrawingToken
                DispatchQueue.main.async { self.store.anchorPlaced = false }
            }
            if selectedTool != store.overlayTool {
                selectedTool = store.overlayTool
                cancelPendingInput()
            }
            if !store.running {
                active = false
                clearAll()
                view.session.pause()
                return
            }
            if !active && !requesting && !failed {
                guard ARWorldTrackingConfiguration.isSupported else {
                    failed = true
                    DispatchQueue.main.async { self.store.trackingMessage = "AR needs a compatible physical iPhone. Simulator is unsupported." }
                    return
                }
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    let config = ARWorldTrackingConfiguration()
                    config.planeDetection = [.horizontal, .vertical]
                    view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                    active = true
                case .notDetermined:
                    requesting = true
                    AVCaptureDevice.requestAccess(for: .video) { _ in
                        DispatchQueue.main.async { self.requesting = false; self.sync() }
                    }
                default:
                    failed = true
                    DispatchQueue.main.async { self.store.trackingMessage = "Allow Camera in iPhone Settings, then restart the session." }
                }
            }
            if action != store.step.action {
                action = store.step.action
                animate()
            }
        }

        func raycast(_ point: CGPoint) -> ARRaycastResult? {
            guard active, store.running, store.trackingReady, let view,
                  let query = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any) else { return nil }
            return view.session.raycast(query).first
        }
        func position(_ result: ARRaycastResult) -> SIMD3<Float> {
            let t = result.worldTransform.columns.3
            // Lift a tiny distance off the detected surface to reduce z-fighting.
            let normal = result.worldTransform.columns.1
            return SIMD3(t.x, t.y, t.z) + SIMD3(normal.x, normal.y, normal.z) * 0.004
        }
        func material(_ geometry: SCNGeometry, color: UIColor) {
            geometry.firstMaterial?.diffuse.contents = color
            geometry.firstMaterial?.lightingModel = .constant
        }
        func dot(at point: SIMD3<Float>, color: UIColor) -> SCNNode {
            let geometry = SCNSphere(radius: 0.006)
            material(geometry, color: color)
            let node = SCNNode(geometry: geometry)
            node.simdPosition = point
            return node
        }
        func segment(from start: SIMD3<Float>, to end: SIMD3<Float>, radius: CGFloat, color: UIColor) -> SCNNode? {
            let delta = end - start
            let length = simd_length(delta)
            guard length > 0.001, length.isFinite else { return nil }
            let geometry = SCNCylinder(radius: radius, height: CGFloat(length))
            material(geometry, color: color)
            let node = SCNNode(geometry: geometry)
            node.simdPosition = (start + end) / 2
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: delta / length)
            return node
        }

        @objc func place(_ gesture: UITapGestureRecognizer) {
            guard store.overlayTool != .draw, let view,
                  let hit = raycast(gesture.location(in: view)) else { return }
            if store.overlayTool == .arrow {
                placeArrowPoint(position(hit))
                return
            }
            marker?.removeFromParentNode()
            let root = SCNNode()
            root.simdTransform = hit.worldTransform
            // World-space annotation only: moving the physical object requires re-placement.
            let ringGeometry = SCNTorus(ringRadius: 0.035, pipeRadius: 0.003)
            material(ringGeometry, color: .systemMint)
            let ring = SCNNode(geometry: ringGeometry)
            ring.position.y = 0.004
            root.addChildNode(ring)
            let tipGeometry = SCNCone(topRadius: 0, bottomRadius: 0.012, height: 0.025)
            material(tipGeometry, color: .systemMint)
            let tip = SCNNode(geometry: tipGeometry)
            tip.position.y = 0.045
            root.addChildNode(tip)
            view.scene.rootNode.addChildNode(root)
            marker = root
            store.anchorPlaced = true
            animate()
        }

        func placeArrowPoint(_ end: SIMD3<Float>) {
            guard let view else { return }
            guard let start = pendingArrow else {
                pendingArrow = end
                let dot = dot(at: end, color: .systemOrange)
                pendingDot = dot
                view.scene.rootNode.addChildNode(dot)
                store.trackingMessage = "Arrow start placed · tap the destination"
                return
            }
            let distance = simd_distance(start, end)
            guard distance >= 0.025, distance <= 2 else {
                store.trackingMessage = "Choose an arrow destination 2.5 cm to 2 m from its start"
                return
            }
            let direction = (end - start) / distance
            let headLength = min(Float(0.04), distance * 0.35)
            let root = SCNNode()
            if let shaft = segment(from: start, to: end - direction * headLength, radius: 0.003, color: .systemOrange) {
                root.addChildNode(shaft)
            }
            let geometry = SCNCone(topRadius: 0, bottomRadius: CGFloat(headLength * 0.4), height: CGFloat(headLength))
            material(geometry, color: .systemOrange)
            let head = SCNNode(geometry: geometry)
            head.simdPosition = end - direction * headLength / 2
            head.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
            root.addChildNode(head)
            view.scene.rootNode.addChildNode(root)
            arrows.append(root)
            if arrows.count > maxArrows { arrows.removeFirst().removeFromParentNode() }
            cancelPendingInput()
            store.anchorPlaced = true
            store.trackingMessage = "Arrow placed · tap two points to add another"
        }

        @objc func draw(_ gesture: UIPanGestureRecognizer) {
            guard store.overlayTool == .draw else { return }
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                lastPoint = nil
                return
            }
            if gesture.state == .began { lastPoint = nil }
            guard let view, let hit = raycast(gesture.location(in: view)) else {
                // Break the stroke across missing surfaces, rather than bridging an unknown region.
                lastPoint = nil
                return
            }
            let point = position(hit)
            guard let previous = lastPoint else { lastPoint = point; return }
            let distance = simd_distance(previous, point)
            guard distance >= 0.006 else { return }
            // Large jumps usually indicate a surface change or unstable raycast.
            guard distance <= 0.15 else { lastPoint = point; return }
            guard let line = segment(from: previous, to: point, radius: 0.0025, color: .systemCyan) else { return }
            view.scene.rootNode.addChildNode(line)
            drawings.append(line)
            if drawings.count > maxSegments { drawings.removeFirst().removeFromParentNode() }
            lastPoint = point
            store.anchorPlaced = true
        }

        func cancelPendingInput() {
            pendingArrow = nil
            pendingDot?.removeFromParentNode()
            pendingDot = nil
            lastPoint = nil
        }
        func clearAll() {
            marker?.removeFromParentNode()
            marker = nil
            drawings.forEach { $0.removeFromParentNode() }
            drawings.removeAll()
            arrows.forEach { $0.removeFromParentNode() }
            arrows.removeAll()
            cancelPendingInput()
        }
        func setOverlaysHidden(_ hidden: Bool) {
            marker?.isHidden = hidden
            drawings.forEach { $0.isHidden = hidden }
            arrows.forEach { $0.isHidden = hidden }
            pendingDot?.isHidden = hidden
            if hidden { cancelPendingInput() }
        }
        func animate() {
            guard let ring = marker?.childNodes.first else { return }
            ring.removeAllActions()
            ring.position = SCNVector3(0, 0.004, 0)
            ring.scale = SCNVector3(1, 1, 1)
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
            case .normal: ready = true; message = "Tracking ready · choose a tool and annotate a surface"
            case .limited: ready = false; message = "Tracking limited · move slowly in a well-lit area"
            case .notAvailable: ready = false; message = "Tracking unavailable"
            }
            DispatchQueue.main.async {
                guard self.active, self.store.running else { return }
                self.store.trackingReady = ready
                self.store.trackingMessage = message
                self.setOverlaysHidden(!ready)
            }
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            DispatchQueue.main.async {
                self.store.trackingReady = false
                self.store.trackingMessage = "Session interrupted"
                self.setOverlaysHidden(true)
            }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async {
                guard self.store.running else { return }
                self.active = false
                self.store.trackingReady = false
                self.store.resetAnchor()
                self.sync()
            }
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.failed = true
                self.active = false
                self.store.trackingReady = false
                self.store.trackingMessage = "AR failed. Stop and restart the session."
                self.setOverlaysHidden(true)
            }
        }
    }
}
