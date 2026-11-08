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
