# Reference project audit and implementation decisions

Reviewed November 9, 2026. This is a source-level comparison, not a runtime benchmark. No upstream source or assets were copied into this update; native implementations were authored independently. External dependencies have not been installed into the app.

| Reference | Pinned revision | Source inspected | Relevant pattern | FieldGuide change |
| --- | --- | --- | --- | --- |
| [FixIt Lens](https://github.com/rakexhs/fixit-lens) | `6e5a06ca2b94849a3ea5d80d1d845f4be0493b7a` | `backend/app/rag/citation_validator.py`, `LICENSE` | Validate every step's references against retrieved source IDs | Retained fail-closed proposal validation; added exact source excerpt checks and visible quoted evidence for maintenance |
| [MindAR](https://github.com/hiukim/mind-ar-js) | `fb5db87b1e5076ba86fde82101955da70b629a1c` | `examples/image-tracking/three.html`, `LICENSE` | Prepare an image target and parent visual content to its anchor; explicit start/stop lifecycle | Native reference-image import, physical-width entry, validation and anchor-parented overlay |
| [AR Foundation samples](https://github.com/Unity-Technologies/arfoundation-samples) | `16489599d11baf15548b1d8b632bc455c65e07ca` | `Assets/Scenes/ImageTracking/BasicImageTracking/TrackedImageInfoManager.cs`, `LICENSE.md` | Handle tracked-image add/update events, physical size and visual visibility based on tracking | ARKit image-anchor callbacks, target-sized overlay, tracking-loss hiding |

## Why not merge all three repositories?

MindAR uses browser JavaScript/WebGL, Unity samples require Unity packages and a Unity project, while this iPhone project uses SwiftUI and ARKit. Adding their runtimes would introduce additional renderers and app architectures. Their image-target/anchor lifecycle patterns transfer cleanly; their source files do not drop into Swift.

FixIt Lens is closer on backend structure. Its inspected citation validator checks IDs and drops invalid steps. FieldGuide rejects an invalid entire proposed sequence to avoid silently skipping a prerequisite. The new excerpt validator additionally checks that maintenance quotations occur in the supplied retrieved passages. Neither method proves semantic entailment or operational safety.

## Licensing

FixIt Lens and MindAR expose MIT licenses at the pinned revisions. AR Foundation samples exposes its Unity-specific license in LICENSE.md. No Unity sample code/assets are vendored or translated here. Before directly copying code later, preserve its applicable notices and review dependency/asset terms separately. License availability is not proof of production suitability.

## Native API references

- https://developer.apple.com/documentation/arkit/arreferenceimage
- https://developer.apple.com/documentation/arkit/arimagetrackingconfiguration
- https://developer.apple.com/documentation/arkit/tracking-and-altering-images

ARKit needs the real printed image size to establish scale. The app validates input size, downsamples image decoding, normalizes image orientation through ImageIO, asks ARKit to validate the reference, and tracks one target at a time. Imported images and camera frames are not sent to the backend.

## Device acceptance checklist

1. Import a textured, high-contrast rectangular image at its actual printed width.
2. Reject blank/low-quality images, oversized files, invalid widths and unreadable formats without starting tracking.
3. Start on a physical supported iPhone; verify camera denial gives instructions rather than a blank success state.
4. Show the target; verify the pulsing plane matches its orientation and approximate dimensions.
5. Move the printed target slowly; verify overlay follows while tracked.
6. Hide the target; verify overlay hides and status does not claim recognition.
7. Background/close/reopen; verify camera session stops and no stale overlay remains.
8. Reimport with another width; verify previous reference is invalidated and revalidated.
9. Confirm surface drawing still works independently in Guide.

These are pending hardware tests, not achieved results. The earlier CI Mac job was cancelled and did not establish a successful Swift build. Follow the latest GitHub Actions build for compiler validation.
