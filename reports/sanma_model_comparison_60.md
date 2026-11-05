# Sanma Model vs TileSense guide: 60-pair follow-up

Fixed sample: 60 fresh paired East–South games (120 games), seeds 100000–100059. The original 12 pilot pairs are excluded. Both opponents use Model; starting dealers are balanced across active seats 0, 1 and 3. The tested seat uses Model or the guide with default automatic dials (not a fixed points-only EV setting). Starting points: 35,000.

FP32 model SHA-256: `e9863274c2972d15742fd3f46718bd2dff8ccc82e7a676aff25b44cbb63658c1` (the deployed 104k model). Game code: f9dd6cb; harness: flutter_client/test/sanma_model_comparison_test.dart.

Valid pairs analyzed: 59. Excluded seed pairs: [100015].

| Engine | Mean placement ↓ | Mean final points | 1st / 2nd / 3rd |
|---|---:|---:|---|
| guide | 2.407 | 26,136 | 8 / 19 / 32 |
| model | 2.119 | 32,022 | 15 / 22 / 22 |

| Model minus guide | Mean difference | Paired 95% CI | Two-sided p | Holm-adjusted p |
|---|---:|---|---:|---:|
| place | -0.288 | [-0.526, -0.051] | 0.03531 | 0.07062 |
| points | +5,886 | [-1,012, +12,766] | 0.10163 | 0.10163 |

Outcomes significant at family-wise 5% after Holm correction: none.

Methods: paired label-swap permutation test (100,000 resamples, two-sided absolute mean statistic, plus-one correction). Holm correction controls the family-wise 5% threshold for the two outcomes. 95% percentile bootstrap intervals resample whole pairs within starting-dealer strata (20,000 resamples); intervals are marginal, not adjusted for multiple comparisons. Resampling RNG seed: 20261103.

Across all attempted games: 0 request failures, 2 fallback moves, 34,103 requests, 1,036 hands. Both arms of any affected pair are excluded; the pure-model analysis is conditional on completing without fallback. Exclusions may bias the comparison.

Limitations: inference assumes seed pairs represent the relevant game population; the permutation test assumes paired arm exchangeability under the null. These results describe play against two Model opponents using this specific model and guide configuration. Shared seeds do not force identical later positions, dealer repeats, or game lengths. A nonsignificant result does not establish equal strength.

Reproduction, from the repository root with the sanma sidecar on port 18891:

```sh
cd flutter_client
SANMA_COMPARE_GAMES=60 SANMA_COMPARE_SEED=100000 SANMA_COMPARE_ALLOW_FALLBACKS=1 SANMA_COMPARE_OUT=../reports/sanma_model_comparison_60.csv flutter test --dart-define=MP_ENDPOINT=ws://127.0.0.1:9 test/sanma_model_comparison_test.dart
cd ..
mortal_sidecar/.venv/bin/python reports/sanma_comparison_stats.py reports/sanma_model_comparison_60.csv 60
```
