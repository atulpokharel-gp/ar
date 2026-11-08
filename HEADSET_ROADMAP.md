# Dynamic guidance on iPhone and AR/VR glasses

## Product direction

One procedure/controller contract, multiple spatial clients. The current deliverable implements the iPhone client only. The shared event is declared in Models.swift and contracts/guidance-event.schema.json. It is not yet a deployed network protocol.

## What dynamic means

The interface responds to the current procedure state, input, evidence and tracking health. It does not generate arbitrary interface code or invent physical actions.

| Situation | Response | v0.1 status |
| --- | --- | --- |
| Enter new step | Change title, instruction, animation, confirmation and primary button | Implemented |
| Tracking limited | Hide cue and block next-step progression | Implemented |
| User requests repetition | Read current instruction aloud | Implemented by button |
| User moves object | Require manual cue repositioning | Manual; movement not detected |
| User confirms | Advance only through controller gates | Implemented |
| User interrupts | Stop AR session and speech | Implemented by button/background/tab change |
| Wrong part or procedure mismatch | Stop, request another view, show evidence | Planned |
| User says next/back/stop | Convert speech into controller intents | Planned |
| Gaze/pinch or controller gesture | Convert platform input into same intents | Planned |
| Step completion inferred from video | Show evidence and confidence; require confirmation until validated | Planned |

## Platform clients to evaluate

- iPhone: current native SwiftUI + ARKit/SceneKit implementation; no LiDAR assumption.
- Apple Vision Pro: separate visionOS SwiftUI/RealityKit client, with gaze/pinch and spatial UI. Do not assume access to unrestricted passthrough camera frames; verify platform entitlements and distribution restrictions before designing scene recognition.
- Quest: separate Unity/OpenXR client and controller/hand input adapter; verify device-specific passthrough-camera access and store requirements.
- Optical see-through / camera glasses: select actual hardware and vendor SDK first. A glasses camera or audio connection alone does not imply world-anchored displays, hand input, or six-degree tracking.

These are design routes, not validated compatibility claims. All platform APIs and permissions must be checked against current official documentation at implementation time.

## Controller design for next iteration

Inputs: start, stop, confirm, back, repeat, reposition, tracking-lost, tracking-restored, observation, help.
State: procedure/version, exact device identity, current step, prerequisites, confirmation, world/object anchor identity, tracking quality, pending observation, evidence references.
Outputs: approved semantic action, instruction, visible controls, audio, evidence card, escalation.

Only a reviewed procedure can request an action. Model suggestions are proposals. A deterministic validator checks exact model, allowed action, prerequisites and evidence before the controller accepts them. A model cannot mark a task complete just by saying it is complete.

Each client reports capabilities. Unsupported actions degrade to text/reference images or stop; they must not imply a spatial cue is precise when an anchor cannot be established. For v1 add units, coordinate frame, asset version, orientation, device/procedure version and target part IDs to the semantic event. The current minimal event is enough only for manual-anchor practice.

## Acceptance metrics

Measure cue error at the target part, tracking recovery time, wrong-part rate, false completion rate, voice interruption latency, user completion rate, time vs PDF/chat, and authoring minutes per procedure. Establish tolerances for each physical task with a qualified reviewer. Do not use a single global accuracy threshold across devices.

## Hardware decision needed later

Continue iPhone development now. Before implementing a glasses client, choose the first actual headset and confirm access to hardware for testing. This decision does not block the shared controller or iPhone work.
