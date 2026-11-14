# Replacement training status — 2026-11-13

## Current priority: independent compatible-library migration

The user chose exact Nagomi compatibility before further custom-model training,
with independently implemented replacement code only. No reference engine code
is being vendored or translated. The frozen library is used as an oracle by
separate test tooling. This is an independent implementation effort, not a
formal clean-room process or a newly trained independent set of weights.

Implemented [nagomi_compat](../nagomi_compat/README.md): a pinned ONNX runtime,
visible-state bookkeeping, independent hand analysis and legal masks, action
serialization and 959 observation rows (0–888 and 891–960).
The structural efficiency group independently enumerates improving draws and
minimum-shanten discard candidates, with live tile counts and turn-order
horizons. The new runtime executes with all reference imports blocked. It has no `libriichi` runtime dependency and does not
import the training package. The [feature contract](../nagomi_compat/FEATURES.md)
records exact offsets and cached-field behavior.

Across 96 validation games and all four seats, there were zero differences in
60,933 decision masks, 647 kan-selection masks, 391,124 comparisons each of
stored shanten/waits/furiten and 59,055,220 implemented feature-row comparisons.
The replay covered 399,824 event-seat updates. Reports:
[32 development games](reports/nagomi_compat_scoring_rules_development_v1.json) and
[32 additional games](reports/nagomi_compat_scoring_rules_additional_v1.json) and
[32 further validation games](reports/nagomi_compat_scoring_rules_fresh_v1.json).
The first 64 validation games were used for iteration; the further 32 were
checked after implementation. The final test split was not read.

Across 427 sampled fixtures from two disjoint sets of 16 validation games
within those 96 games, all 959 implemented rows and all masks also matched:
409,493 row/case comparisons. Runtime action selection on oracle full inputs
matched all 427 cases. Serialization given oracle argmax matched all 407 normal
reactions semantically; 20 standalone kan-selection frames are excluded.
Reports: [development components](reports/nagomi_compat_efficiency_development_v1.json)
and [additional components](reports/nagomi_compat_efficiency_additional_v1.json).

**The library migration is not complete.** The 53 remaining rows (889–890 and
961–1011), the independent win guard and full chained-policy reaction parity remain.
Independent han/fu/basic hand payments are now implemented separately; future
EV assumptions and liability settlement are not. Every independent
observation remains incomplete. Unknown rows contain NaN and cannot be scored;
there is no approximation or native fallback. `migration_ready` remains false.
Production continues to use its existing library. Row coverage and sampled
parity do not establish end-to-end behavior or playing strength.

Validation includes 56 independent-library tests, an actual graph run with
reference imports blocked, both oracle corpora and all three 32-game replays. The
training regressions pass in separate processes: 32 sanma tests and 31 Nagomi
tests with one sanma-only skip. Compileall, tabnanny and whitespace checks pass.
Only oracle tooling imports the reference implementation. No dependencies were
added. New input/state/legality tracking warrants security-audit before merging.

A one-shanten analytical probability diagnostic covers 3,196 horizon comparisons
across 100 fixture cases, with maximum absolute difference `4.32e-7` and no
differences over `1e-6`. This exceeds the `1e-7` feature tolerance on some cases;
float32 operation order and multi-stage hand/score calculations remain open.
The diagnostic does not implement probability rows. Reports:
[development probability](reports/nagomi_compat_probability_development_v1.json)
and [additional probability](reports/nagomi_compat_probability_additional_v1.json).

The [independent scorer](../nagomi_compat/SCORING.md) now matches all **841 win
settlements** from the 96 validation games: 332 tsumo, 509 ron, 340 riichi wins,
69 ippatsu wins, five double-riichi wins, one yakuman win and five multiple-ron
follow-ups. The diagnostic applies the recorded convention that honba goes to
the first winner only. All four settlement deltas match. Revealed ura is used
only as outcome information, never model input. Reports:
[development outcomes](reports/nagomi_compat_scoring_outcomes_development_v1.json),
[additional outcomes](reports/nagomi_compat_scoring_outcomes_additional_v1.json)
and [further outcomes](reports/nagomi_compat_scoring_outcomes_fresh_v1.json).

All 48 synthetic completed-hand probes and all 30 frozen completed self-draw
frames also match the native clipped scoring scalars. This includes initial
self-draw, special waits, red tiles, live ippatsu and stacked yakuman. See
[scoring reference comparisons](reports/nagomi_compat_scoring_reference_v2.json).
The basic scorer excludes liability settlement and does not set future
riichi/ippatsu/ura assumptions.

A broader pure tenpai-maximization search hypothesis is rejected: 190 of 704
candidate vectors exceed `1e-6` difference, with maximum absolute probability
error `0.11948`. That experiment is not a runtime approximation or feature
implementation. Reports: [development search](reports/nagomi_compat_probability_search_development_v1.json)
and [additional search](reports/nagomi_compat_probability_search_additional_v1.json).
The correct search objective/transition assumptions remain to be characterized.

Next: characterize future scoring assumptions and discard choices, then
implement the remaining 53 probability/EV rows, the win guard and complete
reaction chains. Encoder coverage remains **959/1,012**; no probability/EV row
was promoted by these scoring and search diagnostics.

## Previous milestone: outcome labels and broader training pilots

Implemented outcome-aware extraction: pass decisions, dora/riichi-payment
announcements, all observed winners in multiple-ron outcomes, engine-permitted
abortive draws and explicit kan selection. Unobservable lower-priority calls
and choices interrupted by wins are censored, with reasons counted. Targets
come from future events only; encoded inputs remain seat-visible prefixes.

Selected 128 training and 32 validation games per ruleset from the frozen
audit using seed 7. All **166,818 retained labels and legal masks** across
320 games matched the pinned engine loader; there were zero reference-only
positions or disagreements. The test split was not read. Immutable game shards
use about 17 MiB compressed and are loaded one at a time.

Both pilots trained for two epochs on nonforced decisions, batch size 64,
AdamW learning rate 0.0003 and final-rank auxiliary weight 0.1:

| Model | Unique training decisions | Validation decisions | Updates | Initial → final agreement | Final action loss |
| --- | ---: | ---: | ---: | --- | ---: |
| Sanma | 42,535 | 11,684 | 1,452 | 14.40% → 56.90% | 1.3058 |
| Nagomi | 82,388 | 20,216 | 2,690 | 15.29% → 56.63% | 1.3089 |

Agreement is with logged human actions, not playing strength. A simple
pass-when-legal/otherwise-first-legal reference scored 24.05% and 27.00%.
Final-rank accuracy reached 54.04% for sanma and 40.10% for Nagomi. Decisions
within games are correlated; these numbers are diagnostics, not significance
tests. Validation was used for iteration and is not a final untouched test.

The pilot exposes a concrete weakness: Nagomi reproduced only 5 of 255 logged
chi decisions (1.96%); pon agreement was 25.61%. High pass recall (98.87%) and
overall agreement do not establish good calling behavior. Sanma pon agreement
was also limited (32.84%). Review class balance, call-versus-pass confusion and
teacher targets before expanding training or promoting a model.

Reports and exact cache manifests:

- [Sanma pilot](reports/sanma_pilot_v1.json), [data manifest](reports/sanma_pilot_v1_data.json).
- [Nagomi pilot](reports/nagomi_pilot_v1.json), [data manifest](reports/nagomi_pilot_v1_data.json).

Checkpoints save optimizer/RNG state and the next epoch/shard/row. Resuming
sanma from step 1,000 reproduced the final cursor and all 11,684 validation
action choices; maximum policy-probability difference was 0.00000161. Raw
weights differed by up to 0.00289, principally in unidentifiable value/key-bias
directions. MPS resume is not bit-exact; imitation does not identify shared Q
offsets. See [resume comparison](reports/sanma_pilot_v1_resume.json).

Both final checkpoints restored exactly when loaded, exported to ONNX, passed
synthetic/real parity and produced eight independently validated local mjai
reactions each. Real-position ONNX legal Q differences were below 0.000023,
with identical actions on the checked fixtures. Production remains unchanged.

Training-update time was about 54 seconds for sanma and 104 seconds for Nagomi;
these exclude cache construction, initial/final validation and export. Local
driver allocation at the end was about 1.5 GiB per pilot, not a peak measurement.
Full-data extraction/training needs its own budget and capacity check.

Validation: 32 tests passed in the sanma process; 31 passed and one sanma-only
test skipped in the Nagomi process. Compilation, tabnanny and whitespace checks
passed. No dependencies were installed. New local cache/input-handling code
should receive security-audit before merging.

For the custom-model route, the next experiment is call imbalance and comparison
with the frozen expert policies. The compatible-library route now takes priority.
Full games must be evaluated before deployment. Broader
ablation runs, final test provenance and sanma's fresh test set remain open.

## Previous milestone: visible encoder and real-data integration

Implemented `tilesense-visible-v1`: 20 tile features, 40 context features and
128 visible history events. Training replay and local ONNX inference use the
same encoder. Existing engine getters provide hand/waits/furiten state and
legal masks; public summaries count observable events. No engine source changes
or second legality/scoring implementation were needed.

The boundary strips hidden hands, hidden draws, names, metadata and other
unavailable fields before state tracking. Tests cover hidden-information
invariance, relative seats, malformed inputs, red tiles, game length, riichi
follow-ups, kan selection, kita and real replay/inference parity.

Both rulesets completed independent FP32/MPS runs on two training games and
one validation game, selecting 64 nonforced decisions per split. Each memorized
its training batch in 20 optimizer updates:

| Model | Initial/final training loss | Training accuracy | Tiny validation accuracy |
| --- | --- | ---: | ---: |
| Sanma | 2.4584 → 0.0647 | 100% | 26.56% |
| Nagomi | 2.5168 → 0.0400 | 100% | 26.56% |

These are deliberate overfit checks, not playing-strength results. The models
have 529,603 parameters. Checkpoints restored exactly. ONNX legal Q values on
eight real decisions matched within 0.0000024, with identical chosen actions.
Eight real validation prefixes per ruleset produced locally decoded reactions
that an independently replayed rules engine accepted. Dedicated ONNX fixtures
also verified riichi's follow-up discard and two-stage kan selection.

Reports: [sanma_real_v1.json](reports/sanma_real_v1.json) and
[nagomi_real_v1.json](reports/nagomi_real_v1.json). They record source/log/engine
hashes, masks/parity checks, objectives, timing and MPS allocation snapshots.
Memory snapshots are not peak measurements and timing excludes full-data I/O.
Checkpoints and ONNX files remain in ignored local run directories.

Validation: 23 unittest cases in the sanma process; 22 passed and one sanma-only
case skipped in the Nagomi process. Both real-data MPS runs and ONNX/local
integration checks passed. No dependencies or production changes were made.
New event parsing is input-handling work; run security-audit before merging.

Outcome-aware extraction, final-rank objectives and streaming pilots with
data-cursor resume are now implemented; see the current milestone above.
Full-game strength evaluation and production deployment remain outstanding.

## Initial milestone snapshot

The replacement pipeline has started. All results below are local, using an
Apple M4 Mac with 16 GiB unified memory. No dependencies were installed and no
production manifests or services changed.

## Baselines and data

All three local ONNX exports match their release manifest SHA-256 hashes.
The sanma training checkpoint is at 104,000 steps; its weights and metadata
are recorded in [checkpoints.json](baselines/checkpoints.json).

The read-only audit inspected **63,026 games**, checked JSON structure,
seat counts and completion, and found no duplicate IDs or normalized gameplay
content within or between splits:

| Dataset | Train | Validation | Test |
| --- | ---: | ---: | ---: |
| Sanma | 31,888 | 1,670 | None |
| Nagomi | 23,033 | 3,362 | 3,073 |

This is not rules-engine validation. Sanma still needs a final untouched test
set. Historical use of the four-player test split is unverified. Full split
manifests with per-file and gameplay hashes remain in
`model_training/runs/baseline-audit-20261108-v2/`; their hashes and audit results
are recorded in [inventory.json](baselines/inventory.json).

On 128 replay positions from one four-player validation game, `g23033.pth` was
the only local Nagomi candidate whose legal Q values met the numerical match
tolerance against the deployed ONNX. Action agreement was 100%, with maximum
legal Q difference 0.0000086. Some other candidates also chose the same actions
but had substantially different Q values. See
[nagomi_provenance.json](baselines/nagomi_provenance.json). This identifies a
numerically compatible baseline, not byte-level export provenance. That
checkpoint lacks optimizer/scheduler state and cannot exactly resume its
original fine-tuning run.

## Architecture and export smoke runs

Both rulesets used the 510,147-parameter hybrid prototype, FP32 on MPS, batch
size 64 for 12 synthetic training updates. They learned the fixed synthetic
fixture, restored weights and optimizer/RNG state, and matched the next update
within the documented MPS tolerance.

| Prototype | Initial/final synthetic loss | ONNX max legal Q difference |
| --- | --- | ---: |
| Sanma | 4.2654 → 0.1516 | 0.0000039 |
| Nagomi | 4.0509 → 0.2049 | 0.0000020 |

CPU FP32 ONNX inference matched legal values, auxiliary rank logits, legal masks
and chosen actions at batch sizes 1 and 3, including empty history. Reports:
[sanma_smoke.json](baselines/sanma_smoke.json) and
[nagomi_smoke.json](baselines/nagomi_smoke.json).

These are synthetic pipeline checks. They establish neither mahjong ability
nor real-data training throughput. They are not replacement model releases.

Validation completed: seven focused unittest cases, both MPS smoke runs, a CPU
config-file CLI smoke run, ONNX model validation and parity, Python compilation,
tabnanny, whitespace/JSON checks and verification of frozen manifest hashes.
There is no configured Python style linter; no new lint dependency was added.
The sibling engine checkout remained clean. Existing unrelated Flutter changes
were not modified or tested by this milestone.

## Initial milestone follow-up

The observation contract, engine getter bridge, leakage/parity fixtures and
tiny real-game overfit are now implemented; see the current milestone above.
The measured runs do not yet establish a budget for full-dataset extraction,
streaming training or gameplay evaluation.

Production deployment and gameplay evaluation remain later milestones. Baseline
inventory and prototype checks are complete; full baseline validation metrics
and paired gameplay reproduction remain outstanding.
