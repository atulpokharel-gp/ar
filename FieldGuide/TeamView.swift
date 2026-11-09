import SwiftUI

struct TeamView: View {
    @EnvironmentObject var store: GuideStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("One goal. Three perspectives.").font(.title.bold())
                    Text("Planner proposes a demonstration. Reviewer checks it. Presenter explains it. Each role makes a separate AI call when your backend is configured.").foregroundStyle(.secondary)
                    Picker("Field", selection: $store.planningDomain) {
                        Text("Education").tag("education")
                        Text("Assembly").tag("assembly")
                        Text("Maintenance").tag("maintenance")
                        Text("Creative").tag("creative")
                    }.pickerStyle(.menu)
                    TextField("What would you like to demonstrate?", text: $store.planningGoal, axis: .vertical)
                        .lineLimit(3...6).padding().background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    if store.planningDomain == "maintenance" {
                        Text("Maintenance planning needs an imported manual and relevant source passages. Plans are not approved repair instructions.").font(.caption).foregroundStyle(.orange)
                    }
                    Button { Task { await store.requestPlan() } } label: {
                        HStack {
                            if store.planning { ProgressView() }
                            Text(store.planning ? "Agents are reviewing…" : "Create demonstration proposal")
                        }
                    }.buttonStyle(.borderedProminent).disabled(store.planning || store.planningGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("The server receives your goal and imported manual text. Configure connection and consent in Connect. No camera feed is shared. Progress is shown when the complete response arrives.").font(.caption).foregroundStyle(.secondary)
                    if let plan = store.planReply {
                        Label(plan.status.uppercased(), systemImage: "doc.text.magnifyingglass").foregroundStyle(.mint)
                        Text(plan.summary)
                        ForEach(plan.agents) { agent in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(agent.role.capitalized + " · " + agent.status).font(.headline)
                                Text(agent.summary).font(.subheadline).foregroundStyle(.secondary)
                            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        }
                        ForEach(plan.steps) { step in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(step.title).font(.headline)
                                Text(step.instruction)
                                Label("Suggested cue: " + step.action, systemImage: "pencil.tip.crop.circle")
                                    .font(.caption).foregroundStyle(.mint)
                                if !step.pages.isEmpty { Text("Source pages: " + step.pages.map(String.init).joined(separator: ", ")).font(.caption) }
                            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        }
                        Text("Review required. This proposal cannot start an AR procedure or confirm physical actions. Use the authored practice scenarios to test drawing and markers.").font(.caption).foregroundStyle(.orange)
                    }
                }.padding(24)
            }.navigationTitle("Agent team")
        }
    }
}
