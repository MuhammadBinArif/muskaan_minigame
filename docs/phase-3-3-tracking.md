# Phase 3.3 tracking contract

All camera frames and face data remain on-device. Raw images are neither stored
nor sent to analytics.

## Coordinates

ML Kit receives the frame dimensions and camera rotation through `InputImage`.
Its upright image-space coordinates are normalized to `[0, 1] × [0, 1]`, with
the origin at the preview's top-left. X is mirrored exactly once for the front
camera, so moving right moves the tracking value right. Raw image coordinates
remain inside the vision service. Preview indicators additionally apply the
same centered `BoxFit.cover` scale and crop as `CameraPreview`.

Face size is `sqrt(face bounding-box area / upright image area)`. ML Kit Face
Detection 0.14.0 does not expose a per-face confidence value, so the tracking
contract deliberately has no confidence field.

## Mouth signal

The detector enables the documented `upperLipBottom` and `lowerLipTop`
contours. The estimate is the median vertical aperture through the central
third of those contours divided by face height. This is an experimental
geometric estimate, not ML Kit mouth-open probability and not smile
probability. Missing contours produce no mouth measurement.

Calibration measures a stable closed baseline, an open sample window, and a
closed confirmation window. It also records the average neutral face center
and face size. No physical distance or medical measurement is inferred.

## Stability

- Position EMA alpha: `0.35`
- Face-size EMA alpha: `0.30`
- Mouth-aperture EMA alpha: `0.40`
- Missing detections: `temporarilyLost` while shorter than `650 ms`
- At `650 ms`: `lost`, coordinates are cleared
- Detection after a gap over `1000 ms`: filter re-primes from the new sample
- Mouth threshold evidence: `70 ms` plus open/closed hysteresis

Only `tracking` output is fresh and actionable. Retained coordinates during a
short dropout exist solely to prevent visual jumps.
