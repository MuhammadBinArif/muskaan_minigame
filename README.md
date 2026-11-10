# Muskaan Minigame

A Flutter Android game controlled by on-device face and mouth tracking. The game includes calibration, scoring, results, replay, local session records, and an optional Android AdMob integration.

Run `flutter pub get`, then `flutter analyze`, `flutter test`, and `flutter build apk --debug` with a configured Flutter/Android SDK. Debug builds use Google's official sample ad identifiers; do not test live ads. Camera behavior requires a physical Android device.

The app is **not yet ready for a production Play release**. See the [Phase 6 release-readiness handoff](docs/phase-6-release-readiness.md) for the signing and AdMob requirements, store checklist, outstanding defects, and controlled build procedure. No keystore or production ad IDs are included in this repository.

The [Phase 7 security report](docs/phase-7-security-report.md) records the threat model, fixes, test evidence, remaining device/release checks, and local security commands. Shared icons and falling golgappas use the supplied Dart CustomPainter; no external image assets are required.

Phase 4L implementation and verification limitations: [player identity and dynamic smile measurements](docs/phase-4l-identity-smile.md).

Phase 4L.6 progression rules, cosmetic catalog, persistence, and trust limits:
[player progression and cosmetics](docs/phase-4l6-player-progression-and-cosmetics.md).

Phase 4L.6A audio architecture, assets, event mapping, and verification limits:
[audio system](docs/phase-4l6a-audio-system.md).
