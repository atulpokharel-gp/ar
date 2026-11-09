# FieldGuide 0.2 — multi-domain spatial demonstrations

## What changed

FieldGuide now separates domain content, agent proposals, spatial tools and procedure state. The iPhone client can mark a surface, draw a two-point arrow, and sketch freehand lines onto raycast surface positions. Authored education, assembly and creative demos exercise those tools without pretending to understand the live scene.

The optional backend runs three sequential AI roles (separate requests, currently the same configured model): planner, reviewer and presenter. These are not independent sensor-aware agents and using several roles does not establish correctness. No live camera feed reaches them in this version.

## Roles and authority

| Component | Input | Output | May change live AR procedure? |
| --- | --- | --- | --- |
| Planner agent | Domain, goal, retrieved manual passages | Bounded proposed steps and cue types | No |
| Reviewer agent | Same evidence plus proposal | Review disposition and short explanation | No; can block proposal |
| Presenter agent | Validated proposal | User-facing summary | No; cannot rewrite actions |
| Deterministic validator | Model output | Accepted/rejected schema, evidence IDs, permitted actions | Rejects invalid proposals |
| iPhone controller | Authored scenario, user input, tracking health | Step state and allowed buttons | Yes, within authored sequence |
| Spatial renderer | User-selected tool, surface raycasts | Marker, arrow, freehand lines | Renders annotations, not physical actions |

Generated proposals are review-only in the Agents tab. There is intentionally no button to launch a generated repair sequence. Actual field procedures need source validation and a separate authoring/review process before becoming selectable scenarios. The authored demos run locally without AI keys.

## Dynamic interactions implemented

- Scenario selection changes the full instruction sequence and confirmation labels.
- Marker: tap a detected surface; a ring pulses or moves according to the current authored step.
- Arrow: first tap is the start; second tap is the destination. Invalid lengths are rejected.
- Draw: drag over a detected surface to sketch a line in world space. Lost raycasts break the stroke rather than bridging unknown space.
- Clear annotations: removes markers, arrows and drawings and invalidates placement confirmation.
- Tracking loss: hides annotations, breaks incomplete input and blocks next-step progression.
- Stop/background/tab changes: stops the session and clears annotations.
- Bounded geometry: one animated marker, 24 arrows and 600 drawing segments. Oldest elements are removed at the limit.

Positions are approximate world-space placements. No object recognition, automatic target placement, QR/image marker recognition, moving-part tracking, metric measurement, hand tracking or physical completion verification is included. "Marker" here means a user-placed AR annotation, not a fiducial detector.

## Extending to fields

A domain needs goals, source material, reviewed step templates, allowed actions, hazards/stopping conditions and evaluation tasks. Add domain content separately from the renderer. The current selectable backend domains are education, assembly, maintenance and creative; this is not validated coverage of all professional fields.

Maintenance proposals require relevant manual evidence. High-risk procedural requests are conservatively restricted by the backend. Keyword screening is only a coarse filter, not a safety certification or exhaustive hazard detector. Clinical, electrical-live-work, weapons, aviation and other critical procedures are not supported use cases.

## Next iteration

1. Compile the iPhone app and test gestures/tracking on physical hardware.
2. Add reviewed procedure-pack import with exact device/model identity and source-page citations.
3. Add approved scene-command proposals that users can place manually in a non-procedural educational sandbox.
4. Add camera observation with explicit image-sharing consent and calibrated uncertainty.
5. Implement one glasses platform with a platform-specific renderer and gesture adapter.
6. Test real-world demonstration outcomes, target error and false confirmations per domain.

## Validation

Backend tests exercise schemas, references, blocking behavior and separate role sequencing using mocked provider outputs. They do not demonstrate real model accuracy. GitHub Actions builds the unsigned iPhone simulator target and runs Python tests. A passing simulator compilation still does not validate AR on physical hardware.
