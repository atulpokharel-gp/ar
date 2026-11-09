# FieldGuide — iPhone spatial guidance prototype

Version 0.2 · November 8, 2026

Native SwiftUI iPhone source project with ARKit/SceneKit, PDFKit and spoken instructions. No third-party iOS dependencies. This is a development prototype, not an installed or signed app.

## What is implemented

- Five tabs: spatial guide, agent team, PDF manual reader, manual questions and connection settings.
- Authored assembly, education and creative practice scenarios with explicit user confirmation.
- Tap-to-place animated markers, two-tap directional arrows and freehand world-space drawing.
- Dynamic controls, bounded geometry, tracking-loss hiding/gates, clear/reposition and spoken instructions.
- Local PDF text extraction and search, clearly labeled as not AI.
- Optional authenticated HTTPS manual Q&A and separate planner/reviewer/presenter AI calls.
- Generated agent proposals are review-only; they cannot execute repair procedures.
- Shared semantic action definitions, headset roadmap and GitHub build/test workflow.

See [MULTI_AGENT_AR.md](MULTI_AGENT_AR.md) for architecture, interaction details and limits.

## Run on your iPhone

1. Unzip this folder on a Mac with Xcode 16 or newer and the iOS SDK installed.
2. Open `FieldGuide.xcodeproj`. No XcodeGen or package install is required.
3. Select the FieldGuide target → Signing & Capabilities. Choose your Apple development team and change `com.example.FieldGuide` to a unique bundle identifier.
4. Connect an ARKit-compatible iPhone running iOS 17 or newer. Enable Developer Mode if Xcode requests it.
5. Select that physical iPhone as the destination and Run. Grant camera permission when starting practice.
6. Select a demo scenario. For assembly, use an empty cardboard box; education and creative scenarios use a clear table. Scan slowly, then use Marker, Arrow or Draw. Arrows require two taps. Clear annotations or Stop to reset.

The simulator may show the non-AR interface; it cannot validate camera tracking. A Mac/Xcode signing workflow is required for installation. This archive is not an IPA or TestFlight release.

## Optional connected agent

The app works without a backend in local search mode. For actual AI responses:

```bash
export FIELDGUIDE_TOKEN='choose-a-long-random-secret'
export OPENAI_API_KEY='your-server-side-key'
export OPENAI_MODEL='your-enabled-chat-model-with-json-mode'
python3 backend/server.py
```

Keep provider keys on the server. Put the development gateway behind a trusted HTTPS reverse proxy before connecting the iPhone. The server binds only to loopback. Enter the HTTPS base URL (without `/ask`) and FIELDGUIDE_TOKEN in Connect, then explicitly allow sending text. Use the deployed server's token, not your OpenAI key. Import a PDF in Manual, then ask a question in Ask. The Agents tab sends a domain, goal and manual text to `/plan` for a three-role proposal. Requests can take longer because the roles run sequentially.

This uses `/v1/chat/completions` with JSON mode. Select a model supporting that API and format. Actual provider calls were not tested in the build environment. The development HTTP server needs a production ASGI replacement, rate limiting, per-user authentication and deployment hardening before multi-user/public use.

Manual text and questions reach your configured server. Only retrieved passages reach the model provider. The iPhone app does not upload camera images, use the microphone, or persist manuals, tokens, or history. Text-to-speech reads the practice steps; it is not two-way voice conversation. Provider retention follows your provider configuration.

## Important boundaries

- This build does not identify devices or parts, diagnose live camera images, read a manual into an approved repair procedure, or verify completed physical actions.
- All executable AR instructions are clearly labeled authored practice demos. Imported manuals do not change those instructions.
- A marker is anchored to the room after a user tap, not to a recognized moving component. Reposition it if the object moves. Estimated surfaces can have substantial error.
- AI answers appear only as advisory manual references. The model cannot execute actions or alter the practice workflow. Valid page references do not prove that every generated claim is supported; semantic checking and technician review remain future work.
- Scanned PDFs without text require future OCR. No manufacturer-approved repair content is bundled.
- No glasses client or headset deployment has been implemented. See HEADSET_ROADMAP.md.

## Validation completed here

Run the expanded Python suite for page validation, retrieval, evidence references, missing-provider behavior and multi-agent proposal validation. Provider responses in tests are mocked, not live accuracy measurements.

The project and plist were generated and structurally inspected. This environment is Linux and has no Swift compiler, Apple SDK, Xcode, simulator or physical iPhone. **Local Swift compilation, signing and device validation are unavailable here.** GitHub Actions includes an unsigned simulator build; inspect its result separately. Real-device checks below are still required.

## Validation on a Mac

```bash
xcodebuild -project FieldGuide.xcodeproj -scheme FieldGuide \
  -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
python3 -m unittest discover -s tests -v
```

On a real device check camera denial/regrant, first launch, cue placement, dim light/tracking loss, interruption/restart, every confirmation gate, back/finish/stop, switching tabs, backgrounding, PDF cancellation/locked/scanned/oversized files, local search, HTTPS authorization failure, provider outage and actual grounded replies. Ensure no cue is visible during tracking loss and no live repair is suggested by the practice flow.

## Next build milestones

1. Compile and run this app on the user's iPhone; fix SDK and device issues.
2. Choose one exact device model and obtain a technician-reviewed service manual and procedure.
3. Add model confirmation, reviewed action assets, source-page display per step, and reference-image alignment.
4. Add scene snapshot analysis with explicit camera-upload permission; measure part localization and completion false positives before allowing progression.
5. Add interruptible voice input and unify touch/voice/headset intents through a controller.
6. Implement one selected headset client and evaluate tracking/input support on its actual hardware.

## Source references

- Apple ARSCNView: https://developer.apple.com/documentation/arkit/arscnview
- Apple PDFKit: https://developer.apple.com/documentation/pdfkit
- Apple speech synthesis: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer
- OpenAI Chat Completions: https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create

This is newly authored source, not a fork of FixIt Lens. Prior repository research informed the architecture but no third-party repository source was copied.
