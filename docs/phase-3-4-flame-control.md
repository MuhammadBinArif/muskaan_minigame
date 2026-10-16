# Phase 3.4 face-controlled Flame gameplay

## Repository audit

Phase 3.3 already supplies real front-camera observations through a bounded
camera stream, ML Kit face contours, normalized upright coordinates, one front
camera mirror, stale-data handling, and Riverpod state. The game already has
tested spawning, collision, score, combo, lives, game-over, restart, and
idempotent persistence rules in `GameSessionNotifier`.

The repository did not previously contain Flame. Phase 3.4 adds Flame 1.38.2 as
a focused active-round presentation and input-update layer while retaining the
existing domain rules.

## Control contract

`FaceGameControlSample` is the only tracking input accepted by gameplay. It
contains normalized horizontal position, gameplay tracking status, and the
observation timestamp. It contains no ML Kit, camera frame, or camera controller
objects.

The Phase 3.3 coordinate is already mirrored for the front-camera preview, so
increasing X moves the target right. Calibration supplies the neutral X and a
horizontal range derived from calibrated face size. A movement of one range to
either side maps from the centered target to the playable edge.

## Stability and lifecycle

- Target centers are clamped to the playable bounds, including visual radius.
- Exponential smoothing uses elapsed seconds, so its response does not depend
  on display frame rate.
- Input older than 250 ms becomes temporarily lost. At 650 ms it becomes lost.
- Lost input freezes the target; it is never extrapolated or randomized.
- Recovery changes the target goal and lets smoothing move from the frozen
  position, avoiding a teleport.
- Pause clears the last observation. Resume waits for a new observation.
- Restart resets the control position and target to the center.
- Camera errors pause the round without changing score or lives.

The active game uses a Flame `GameWidget` for food and target drawing. Flutter
continues to own navigation, the premium HUD, pause overlay, and results UI.
Only small status/debug listenables rebuild on tracking frames.

## Runtime verification

Automated tests verify mapping, direction, clamping, sensitivity, smoothing,
staleness, loss/recovery, pause/resume, restart, collisions, scoring, and
idempotent persistence. A physical device is still required to tune sensitivity
and confirm perceived direction and latency with a real camera.
