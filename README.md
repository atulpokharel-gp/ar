# FieldGuide — iPhone spatial guidance prototype

Version 0.1 · November 8, 2026

Native SwiftUI iPhone source project with ARKit/SceneKit, PDFKit and spoken instructions. No third-party iOS dependencies. This is a development prototype, not an installed or signed app.

## What is implemented

- Four tabs: spatial practice, PDF manual reader, manual questions, connection settings.
- A four-step cardboard-box practice exercise with explicit user confirmation.
- Camera permission handling, plane raycasts, tap-to-place world-space cues, pulsing and lifting animations.
- Dynamic controls: next/finish, per-step confirmation, back, stop, reposition, read aloud.
- Tracking loss hides the cue and blocks advancement after preparation. Switching tabs or backgrounding stops the practice session.
- Local PDF text extraction and page display; limits on file size, page count, and extracted text size.
- Offline keyword search explicitly labeled as not AI.
- Optional authenticated HTTPS manual Q&A gateway using a configured OpenAI model; validated page IDs and no mock fallback.
- Shared semantic action types and JSON schema for future headset clients.

## Run on your iPhone

1. Unzip this folder on a Mac with Xcode 16 or newer and the iOS SDK installed.
2. Open `FieldGuide.xcodeproj`. No XcodeGen or package install is required.
3. Select the FieldGuide target → Signing & Capabilities. Choose your Apple development team and change `com.example.FieldGuide` to a unique bundle identifier.
4. Connect an ARKit-compatible iPhone running iOS 17 or newer. Enable Developer Mode if Xcode requests it.
5. Select that physical iPhone as the destination and Run. Grant camera permission when starting practice.
6. Place an empty cardboard box on a well-lit table. Start AR practice, scan the table slowly, tap to place the cue and follow the four steps.

The simulator may show the non-AR interface; it cannot validate camera tracking. A Mac/Xcode signing workflow is required for installation. This archive is not an IPA or TestFlight release.

## Optional connected agent

The app works without a backend in local search mode. For actual AI responses:

```bash
export FIELDGUIDE_TOKEN='choose-a-long-random-secret'
export OPENAI_API_KEY='your-server-side-key'
export OPENAI_MODEL='your-enabled-chat-model-with-json-mode'
python3 backend/server.py
```

Keep provider keys on the server. Put the development gateway behind a trusted HTTPS reverse proxy before connecting the iPhone. The server binds only to loopback. Enter the HTTPS base URL (without `/ask`) and FIELDGUIDE_TOKEN in Connect, then explicitly allow sending text. Use the deployed server's token, not your OpenAI key. Import a PDF in Manual, then ask a question in Ask.

This uses `/v1/chat/completions` with JSON mode. Select a model supporting that API and format. Actual provider calls were not tested in the build environment. The development HTTP server needs a production ASGI replacement, rate limiting, per-user authentication and deployment hardening before multi-user/public use.

Manual text and questions reach your configured server. Only retrieved passages reach the model provider. The iPhone app does not upload camera images, use the microphone, or persist manuals, tokens, or history. Text-to-speech reads the practice steps; it is not two-way voice conversation. Provider retention follows your provider configuration.

## Important boundaries

- This build does not identify devices or parts, diagnose live camera images, read a manual into an approved repair procedure, or verify completed physical actions.
- All AR instructions are a clearly labeled cardboard-box practice demo. Imported manuals do not change those instructions.
- A marker is anchored to the room after a user tap, not to a recognized moving component. Reposition it if the object moves. Estimated surfaces can have substantial error.
- AI answers appear only as advisory manual references. The model cannot execute actions or alter the practice workflow. Valid page references do not prove that every generated claim is supported; semantic checking and technician review remain future work.
- Scanned PDFs without text require future OCR. No manufacturer-approved repair content is bundled.
- No glasses client or headset deployment has been implemented. See HEADSET_ROADMAP.md.

## Validation completed here

Eight Python tests passed: invalid/duplicate page inputs, long-page retrieval, fabricated/missing citations, valid citation deduplication, no-evidence behavior, and explicit missing-provider failure.

The project and plist were generated and structurally inspected. This environment is Linux and has no Swift compiler, Apple SDK, Xcode, simulator or physical iPhone. **The Swift target has not been compiled, signed, run, or visually validated.** Build and device tests below are required before treating it as runnable or reliable.

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
