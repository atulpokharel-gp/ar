import SwiftUI

@main struct FieldGuideApp: App {
    @StateObject private var store = GuideStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.dark).tint(.mint)
        }
    }
}
