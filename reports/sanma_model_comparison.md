# Sanma Model vs TileSense guide — short paired comparison

12 paired East–South games (24 total), seeds 1000–1011. Both opponents use the Model in both arms. Starting dealer rotates across the three active seats. Seat 0 uses either Model or the TileSense EV guide with its default automatic dials (not a fixed points-only strategy). Starting points: 35,000. Tied placements use mid-ranks; the empty seat is excluded.

Model: local FP32 mortal_sanma.onnx, SHA-256 e9863274c2972d15742fd3f46718bd2dff8ccc82e7a676aff25b44cbb63658c1 (matches the deployed 104k model). Zero request failures and zero fallback moves.

| Engine | Mean placement | Mean final points | 1st / 2nd / 3rd |
|---|---:|---:|---|
| guide | 2.500 | 21,458 | 1 / 4 / 7 |
| model | 2.167 | 29,583 | 2 / 6 / 4 |

Model minus guide: +8,125 points/game and -0.333 placement (lower is better).

Same seeds do not force identical later positions: actions, dealer repeats and early endings can diverge. This small sample is descriptive, not a reliable estimate of playing-strength differences.

Raw results: sanma_model_comparison.csv. Harness: flutter_client/test/sanma_model_comparison_test.dart. Run from flutter_client with a sanma sidecar on local port 18891:

```sh
SANMA_COMPARE_GAMES=12 SANMA_COMPARE_OUT=../reports/sanma_model_comparison.csv flutter test --dart-define=MP_ENDPOINT=ws://127.0.0.1:9 test/sanma_model_comparison_test.dart
```

Validation: paired simulation passed; flutter analyze --no-fatal-infos passed with the existing telemetry.dart:81 style info.
