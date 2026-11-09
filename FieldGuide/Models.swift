import Foundation

struct GuideStep: Identifiable, Codable {
    let id: String
    let title: String
    let instruction: String
    let action: String
    let confirmation: String
}
struct ManualPage: Codable, Identifiable {
    var id: Int { page }
    let page: Int
    let text: String
}
struct AgentReply: Codable {
    let answer: String
    let pages: [Int]
    let mode: String
}
// Platform-neutral semantic actions. Never execute arbitrary model-generated code.
// Headset clients map these actions to their own spatial rendering and input APIs.
enum SpatialAction: String, Codable { case highlight, lift, rotate, inspect }
struct GuidanceEvent: Codable {
    let version: Int
    let stepID: String
    let action: SpatialAction
    let anchorMode: String
    let requiresConfirmation: Bool
}
let practiceSteps: [GuideStep] = [
    .init(id: "prepare", title: "Set up your practice space", instruction: "Use an empty cardboard box on a table. This is a spatial interaction demo, not a device repair procedure. Keep the box still.", action: "inspect", confirmation: "My empty practice box is ready"),
    .init(id: "locate", title: "Mark the lid", instruction: "Move the phone slowly to scan the table. Tap near the box lid to place the marker. Positioning is manual; the app does not recognize the box.", action: "highlight", confirmation: "I placed the marker near the lid"),
    .init(id: "lift", title: "Follow the lift cue", instruction: "The marker demonstrates an upward motion. Lift the loose cardboard lid, then confirm below. The app cannot verify your action automatically.", action: "lift", confirmation: "I lifted the practice lid"),
    .init(id: "inspect", title: "Check and finish", instruction: "Inspect your empty box and replace the lid. This completes the practice session. Real repair procedures require model-specific reviewed content.", action: "inspect", confirmation: "Practice is complete")
]

enum OverlayTool: String, CaseIterable, Identifiable {
    case marker, arrow, draw
    var id: String { rawValue }
}
struct DemoScenario: Identifiable {
    let id: String
    let name: String
    let detail: String
    let steps: [GuideStep]
}
let demoScenarios: [DemoScenario] = [
    .init(id: "assembly", name: "Assembly practice", detail: "Demonstrate a sequence using an empty box.", steps: practiceSteps),
    .init(id: "education", name: "Spatial classroom", detail: "Explain a triangle on a tabletop.", steps: [
        .init(id: "setup", title: "Prepare a clear table", instruction: "Use an empty, stationary tabletop. This is a drawing exercise; no objects are recognized automatically.", action: "inspect", confirmation: "My table is clear"),
        .init(id: "trace", title: "Draw a triangle", instruction: "Choose Draw. Drag across the camera view to trace three sides on the detected table. Surface depth is estimated, not measured.", action: "highlight", confirmation: "I drew three sides"),
        .init(id: "point", title: "Explain a vertex", instruction: "Choose Arrow, tap a starting point, then tap a vertex to point it out. Explain how two edges meet here. The arrow is manually positioned.", action: "inspect", confirmation: "I demonstrated the vertex")]),
    .init(id: "creative", name: "Creative layout", detail: "Sketch and annotate a proposed arrangement.", steps: [
        .init(id: "setup", title: "Choose a blank surface", instruction: "Use a clear stationary surface for a conceptual sketch. These overlays are not dimensionally accurate design drawings.", action: "inspect", confirmation: "The surface is ready"),
        .init(id: "outline", title: "Sketch a layout", instruction: "Choose Draw and drag to outline where an object could go. No physical objects need to be moved.", action: "highlight", confirmation: "I drew the layout"),
        .init(id: "emphasis", title: "Mark the focal point", instruction: "Choose Marker and tap your sketch's focal point. Use Arrow to point toward it, then explain your idea.", action: "inspect", confirmation: "I explained the layout")])
]
struct AgentStage: Decodable, Identifiable {
    var id: String { role }
    let role: String
    let status: String
    let summary: String
}
struct SourceExcerpt: Decodable { let page: Int; let quote: String }
struct ProposedStep: Decodable, Identifiable {
    let id: String
    let title: String
    let instruction: String
    let action: String
    let confirmation: String
    let pages: [Int]
    let evidence: [SourceExcerpt]?
}
struct PlanReply: Decodable {
    let status: String
    let domain: String
    let goal: String
    let summary: String
    let steps: [ProposedStep]
    let agents: [AgentStage]
    let requiresHumanReview: Bool
    let executable: Bool
}
struct PlanRequest: Encodable { let domain: String; let goal: String; let pages: [ManualPage] }
