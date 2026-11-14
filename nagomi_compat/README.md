# Independent Nagomi compatibility migration

Status: **partial implementation; not a replacement serving backend yet**.
The target is the existing Nagomi fine-tuned ONNX graph, with identical weights
and behavior, implemented around an independent library. New replacement code
is independently written; it does not vendor or translate the reference engine.
This is not a formal clean-room claim. The weights retain their existing
provenance; this package does not create an independently trained model.

The package imports no `libriichi`, Mortal Python modules or training tools.
NumPy and ONNX Runtime were already installed; no dependencies were added.
Reference-only tools live separately under `model_training/compat_*.py`.
They may use the pinned original library to record expected behavior.

## Implemented

- `runtime.NagomiRuntime`: SHA-256-pinned CPU FP32 inference for complete
  `obs[batch,1012,34]` and boolean `mask[batch,46]` tensors. Input names, dtypes,
  dimensions, finite values, masks and outputs are checked. It performs no
  hidden game-state or feature generation.
- `state.VisibleState`: validated/redacted four-player mjai bookkeeping,
  own-hand/red identity, scores, riichi payments, calls, indicators, visible
  rivers and skipped-turn alignment. Hidden hands/draws never enter state.
  Tracks the cached hand-analysis and furiten lifecycle. A rejected
  update poisons the replay so it cannot silently continue from partial state.
  Normal/double riichi and ippatsu are tracked for current hand scoring.
- `hand`, `yaku` and `legality`: independently computed standard/seven-pairs/
  thirteen-orphans shanten and waits, yaku existence, legal masks, kuikae,
  riichi restrictions, closed/added/open kans and furiten. Yaku existence
  does not calculate han, fu, points or the policy's final win guard.
- `scoring.score_hand` and `score_win`: independent yaku/han/fu/limit and
  basic-payment calculation, including winning-tile placements, open/closed
  sets, red/visible dora and explicitly revealed ura. See
  [scoring coverage and limitations](SCORING.md). Liability settlement and
  future score assumptions remain separate work.
- `efficiency.analyze`: independent improving-tile enumeration, live tile
  counts, minimum-shanten discard candidates, the high-shanten fallback and
  the turn-order-dependent future-draw horizon. This does not estimate EV.
- `observation.encode`: independently reconstructed format rows 0–888 and 891–960,
  including relative scores/rank/winds, indicator packets, historical/recent
  rivers, call/kan metadata, physical visibility, hand analysis and action
  features, plus structural tile efficiency. See the
  [feature contract](FEATURES.md) for offsets, caching and tie-break behavior.
- `actions.decode`: action-ID representation for discard, reach, chi, pon,
  kan, agari, abortive draw and pass, preserving red identity. The caller must
  provide verified action selection, legality and guard decisions. Multiple
  kan options require an explicit selection.

## Exact coverage and migration gate

Two disjoint sets of 16 validation games produced 210 development fixtures and
217 additional fixtures. They include discard, pass, riichi, chi, pon, agari,
kan/kan-selection and abortive draw cases. The final test split was not read.

- All 959 implemented rows matched exactly on all 427 fixtures: 409,493
  row/case comparisons with zero mismatches.
- Independent legal masks matched all 427 fixtures, including kan selection.
- Independent runtime inference on **oracle-provided full inputs/masks** chose
  the same actions on all 427 fixtures; legal Q differences were below 0.000001.
- Independent action serialization given oracle argmax matched 407 normal
  reactions semantically. Consumed tile order is ignored; red identity is not.
  Standalone kan-selection frames are excluded from this serialization count.

Broader replay checks cover 96 validation games, all four seats, including the
fixture source games. The first 64 games were used for iteration; 32 more
validation games were checked after implementation. These are validation data,
not the final test split. Across 399,824 event-seat updates, there were zero
differences in:

- 60,933 decision masks and 647 kan-selection masks;
- 391,124 comparisons each of stored shanten, waits and furiten;
- 59,055,220 implemented feature-row comparisons, including kan phase frames.

Masks and hand-analysis fields use exact equality. Broad feature checks use
absolute tolerance `1e-7`; the 427-fixture feature comparisons have zero absolute
difference. Reports include implementation, oracle and source-game hashes.

These are **component checks, not end-to-end compatibility**. Row coverage is
not a percentage estimate of remaining engineering work. The additional set
checks generalization of the implemented format, not playing strength.

There are 53 unimplemented rows: EV scalars 889–890 and probability/EV
horizons 961–1011. The independent win guard, full riichi/kan-chain policy
behavior and broader edge-case coverage also remain. No fixture has a complete
independently encoded input. `migration_ready` remains false.

Unknown rows contain **NaN**, carry an explicit coverage mask, and cause
`Observation.require_complete()` to raise `IncompleteObservationError`.
`NagomiRuntime.score()` also rejects them. There is no zero-fill approximation,
native-library fallback, new HTTP endpoint or production switch.

Reports: [development components](../model_training/reports/nagomi_compat_efficiency_development_v1.json),
[additional components](../model_training/reports/nagomi_compat_efficiency_additional_v1.json),
[32 development games](../model_training/reports/nagomi_compat_scoring_rules_development_v1.json),
[32 additional games](../model_training/reports/nagomi_compat_scoring_rules_additional_v1.json)
and [32 further validation games](../model_training/reports/nagomi_compat_scoring_rules_fresh_v1.json).
Raw fixtures and their own-hand information remain in ignored local runs;
committed manifests contain source game hashes and aggregate coverage only.

## Reproduce

From the TileSense root, using the existing local environment and Nagomi model:

```sh
mortal_sidecar/.venv/bin/python -m unittest discover -s nagomi_compat/tests -v
mortal_sidecar/.venv/bin/python -m compileall -q nagomi_compat
mortal_sidecar/.venv/bin/python -m tabnanny nagomi_compat

mortal_sidecar/.venv/bin/python -m model_training.compat_reference \
  --out model_training/runs/compat-reference --games 16 --per-kind 32
mortal_sidecar/.venv/bin/python -m model_training.compat_shadow \
  --corpus model_training/runs/compat-reference \
  --out model_training/runs/compat-reference/shadow.json

mortal_sidecar/.venv/bin/python -m model_training.compat_reference \
  --out model_training/runs/compat-additional --games 16 --skip-games 32 --per-kind 32
mortal_sidecar/.venv/bin/python -m model_training.compat_shadow \
  --corpus model_training/runs/compat-additional \
  --out model_training/runs/compat-additional/shadow.json

mortal_sidecar/.venv/bin/python -m model_training.compat_rules_check \
  --games 32 --check-features --out model_training/runs/rules-development.json
mortal_sidecar/.venv/bin/python -m model_training.compat_rules_check \
  --games 32 --skip-games 32 --check-features \
  --out model_training/runs/rules-additional.json

mortal_sidecar/.venv/bin/python -m model_training.compat_rules_check \
  --games 32 --skip-games 64 --check-features \
  --out model_training/runs/rules-further-validation.json

mortal_sidecar/.venv/bin/python -m model_training.compat_probability_probe \
  --corpus model_training/runs/compat-reference \
  --out model_training/runs/probability-diagnostic.json

mortal_sidecar/.venv/bin/python -m model_training.compat_scoring_check \
  --games 32 --out model_training/runs/scoring-outcomes.json
mortal_sidecar/.venv/bin/python -m model_training.compat_scoring_reference \
  --corpus model_training/runs/compat-reference \
  --corpus model_training/runs/compat-additional \
  --out model_training/runs/scoring-reference.json
mortal_sidecar/.venv/bin/python -m model_training.compat_probability_search_probe \
  --corpus model_training/runs/compat-reference \
  --out model_training/runs/probability-search-diagnostic.json
```

Always use fresh output paths. The reference tool requires the existing native
library; the new runtime does not. An isolation test blocks all reference
imports while executing the actual model graph.

Validation also includes 56 independent-library tests and the training-package
regression suite in separate sanma and Nagomi processes. No dependencies were added.

Independent scoring matches all 841 recorded win settlements in the 96 games,
plus 48 synthetic and 30 frozen completed self-draw scalar checks. Revealed ura
is outcome information only. The scorer is tested independently of probability
features; those rows remain unknown.

The one-shanten analytical [probability diagnostic](../model_training/reports/nagomi_compat_probability_development_v1.json)
and [additional-game diagnostic](../model_training/reports/nagomi_compat_probability_additional_v1.json)
cover 3,196 horizon comparisons across 100 fixture cases. Maximum absolute
difference is `4.32e-7`; no case exceeds `1e-6`. This is a mathematical probe,
not probability-row parity: float32 behavior and multi-stage calculation remain
unresolved, and these rows stay unknown.

A broader pure tenpai-maximization search hypothesis is rejected by the frozen
frames: 190 of 704 candidate vectors differ by more than `1e-6`, with maximum
absolute probability difference `0.11948`. See the [search findings](SCORING.md#probabilityev-integration-gate).
It is diagnostic tooling and is never used by the encoder.

The next implementation stage is to characterize future scoring assumptions
and discard choices, then independently calculate the remaining 53
probability/EV rows with oracle probes, fixtures and parity gates. Then implement the
win guard and test complete chained policy reactions using independent inputs.
Only after full observation, mask and final-reaction parity should the server
be switched. New event/input handling warrants security-audit before merging.
