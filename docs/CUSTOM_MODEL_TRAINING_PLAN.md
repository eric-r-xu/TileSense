# Custom architecture and encoder training plan

Planning snapshot: 2026-11-08. Scope: two independently trained model lines,
sanma and four-player riichi for Nagomi, using a shared training framework.
Implementation has started in `model_training/`; its README records the current
scope and runnable checks. Production continues to use the existing models.
The initial visible-state encoder, bounded real-data overfit and local ONNX/mjai
adapter are implemented; full training and strength evaluation remain pending.
Outcome-aware labels and two-epoch pilots on 128 training/32 validation games
per ruleset are also complete. `model_training/STATUS.md` records results,
resume checks and the calling-policy weakness that needs the next experiment.
User preferences: include architecture and encoder design; train locally on an
Apple Silicon Mac.
Current priority: migrate the existing Nagomi weights to an independently
implemented compatible library first. No reference-code ports are allowed for
that replacement. The original library is a test oracle only; see
`nagomi_compat/README.md` for exact coverage and remaining gates. Independent
hand analysis, legal masks and 959 observation rows (0–888 and 891–960) now
match the oracle across 96 validation games. The remaining 53 probability/EV
rows, the win guard and complete chained policy reactions remain before
production integration. Independent hand scoring now matches 841 recorded win
settlements across those games; future score assumptions and search behavior
remain unresolved. See `nagomi_compat/SCORING.md`. Custom-model pilots below
remain experiments and are not faithful Nagomi replacements.

## Recommendation

Build a versioned custom model pipeline in TileSense's `model_training/` package,
reusing the sibling `Mortal` repository's rules engine through a pinned adapter.
Keep the existing models as frozen
baselines and optional teachers. Train separate weights for sanma and Nagomi;
share code and conventions first. Joint training can be a later experiment.

A new architecture and observation representation generally cannot resume the
existing weights. Distillation can transfer behavior between different networks
without loading the teacher's parameters into the student. Include an independent
training run without a teacher so we can measure whether distillation helps.
If independent initialization and learning are part of the goal, that run can
be the primary model instead.

There are two distinct meanings of encoder here:

- **Observation encoder:** converts seat-visible game state and history to input
  tensors. Mortal currently implements this in Rust.
- **Neural encoder:** learns features from those tensors. Mortal currently uses
  a residual convolutional network in `Brain`.

The plan supports replacing both. Changing only `Brain.encoder` would leave the
existing observation representation in place.

## Verified starting point

| Item | Sanma | Nagomi / four-player |
| --- | --- | --- |
| Production manifest | `mortal_sidecar/model_sanma.json` | `mortal_sidecar/model_nagomi.json` |
| Production export | `mortal_sanma.onnx` | `mortal_nagomi.onnx` |
| Current observation version | 5 | 4 |
| Input shape, excluding batch | `(777, 34)` | `(1012, 34)` |
| Action slots | 47, including kita | 46 |
| Current network | 192 channels, 40 residual blocks | Same architecture in local fine-tuning checkpoints |
| Local training games | 31,888 | 23,033 |
| Local validation games | 1,670 | 3,362 |
| Existing test directory | None found beside train/val | 3,073 games; usage history still needs auditing |

Local sources:

- Training code: `../Mortal/mortal/`; current checkout is branch `sanma`.
- Observation encoding: `../Mortal/libriichi/src/state/obs_repr.rs`.
- Training samples: `../Mortal/libriichi/src/dataset/gameplay.rs`.
- Serving observations and action selection:
  `../Mortal/libriichi/src/agent/mortal.rs`.
- Data: `~/Documents/mortal-sanma-data/` and
  `~/Documents/mortal-4p-data/`.
- Sanma checkpoint: `mortal_sidecar/mortal_sanma.pth`; inspected metadata
  confirms 104,000 optimizer steps, version 5, MPS training.
- Nagomi candidates: `~/Documents/mortal-4p-data/ft/run1/g*.pth`, including
  `g23033.pth`. These contain weights, configuration and tags, but lack the
  optimizer/scheduler state required for an exact training resume.
- Base four-player release: `mortal_sidecar/model.json` identifies 298k.
  Do not confuse its checkpoint label with Nagomi's later fine-tuning count.

The initial implementation verified that `g23033.pth` numerically matches the
deployed Nagomi ONNX on 128 replay positions; other local candidates did not
meet the Q-value tolerance. See `model_training/STATUS.md` for evidence and
limits. Exact byte-level export provenance remains unverified.

## 1. Freeze baselines and establish provenance

Deliverables: a baseline inventory and reproducible evaluation commands.

- Record SHA-256 hashes, source commits, rules, action schemas, observation
  versions and checkpoint metadata for both deployed models and the base 298k.
- Confirm which Nagomi checkpoint produced the deployed export using artifact
  records or re-export and numerical comparison on a fixed replay suite.
- Preserve existing data and checkpoints. Use an isolated branch/worktree and
  fresh run directories for new work.
- Reproduce current validation metrics and a small set of local gameplay runs.
  Record the game engine commit, opponents, seeds, seat rotations and failures.

Acceptance: both production models can be loaded and evaluated reproducibly,
and every new experiment has an unambiguous baseline.

## 2. Define representation and model contracts

Deliverables: `encoder_spec.md`, `action_spec.json`, and a small fixture suite
in the training project.

- Preserve the current action IDs initially, including kan selection, pass,
  riichi and sanma kita. Keep legal-action generation in the rules engine.
- Define an explicit `ruleset_id`, `observation_schema_id`,
  `action_schema_id`, `architecture_id` and schema version. Model architecture
  must not be selected indirectly by the observation version.
- Define tile/red-five identity, relative seats, scores, round/game length,
  own hand, melds, dora indicators, discards and event history. Sanma needs its
  removed tiles, kita counts and three-seat perspective represented explicitly.
- Specify history ordering, truncation, padding, normalization and input dtypes.
- Construct inputs from only the acting seat's visible event prefix. Outcomes
  and future events may supply labels, never policy input features.
- Use the same observation encoder for training replay and live inference.
  If its public-state input is new, expose it from the existing Rust state
  engine instead of maintaining another mahjong rules implementation in Python.
- Add cases for red fives, calls, kan selection, riichi follow-up, kita,
  terminal hands and East-only versus hanchan games. Verify hidden draws/hands
  cannot change the acting player's inputs before they become public.

Initial architecture to design and benchmark:

- Tile branch: 34 tile-type records with own-hand counts, red-five flags,
  visible counts, dora and per-seat public discard/meld summaries. Start with
  learned tile embeddings and a small residual MLP over flattened features;
  define unavailable sanma tiles explicitly.
- History branch: the last 128 visible events, embedded at width 128, with
  event type, relative actor, tile/red identity and applicable flags. Start with
  two transformer encoder layers and four attention heads, then masked pooling.
  Represent hidden draws with unknown identity. Historical summary features
  must retain relevant information outside this window, including furiten,
  all public discards, melds, riichi and kita state.
- Context branch: a small MLP for normalized scores, seat/round winds, honba,
  riichi sticks, wall count and game length.
- Fuse the three branches into a 256-wide representation. Use a scalar value
  head plus per-action advantages to produce masked Q values, and a separate
  auxiliary rank head with three or four outputs according to the ruleset.
- Keep widths, history length and layer counts configurable. Benchmark the
  history branch against a smaller temporal convolution if MPS training or CPU
  inference is too slow. Verify attention export and padding behavior early.

These are starting hyperparameters, not established winners. Benchmark a small
sample before fixing capacity, and document the complete feature specification
before extracting the full dataset.

Acceptance: fixtures produce identical inputs and legal masks through training
and serving paths. A dummy custom network exports and runs before a long run.

## 3. Build a small, separate training package

Suggested layout within TileSense, separate from the existing trainer:

```text
model_training/
  configs/{sanma,nagomi}/
  encoding/              # versioned observation encoding and fixtures
  models/                # neural encoders and heads
  data/                  # replay extraction, splits, cache manifests
  train.py
  evaluate.py
  export.py
  tests/
```

- Keep the existing trainer runnable. Centralize custom model construction in
  one factory used by training, evaluation, export and checkpoint loading.
- Reuse state tracking and action decoding; introduce the custom observation
  path at both dataset extraction and agent inference. A Python wrapper around
  the old tensor cannot recover information omitted by the old encoder.
- First support offline training. Avoid introducing online/self-play services
  as a prerequisite for the first model.
- Implement explicit `resume`, `initialize_from`, and `teacher` options.
  Resume requires matching architecture, encoder, action schema and rules, plus
  optimizer, scheduler, scaler, RNG and progress state. Document any remaining
  limitations on exact data-order resume with worker prefetching.
- Save weights, resolved config, schema identifiers, code commit, dataset/split
  hashes, seeds, hardware and progress. Save complete resumable checkpoints
  separately from inference-only weights.
- Fail on incompatible checkpoints rather than silently dropping parameters.
  Current `train.py` auto-resumes when its state file exists; new runs must not
  accidentally inherit that behavior from an old run directory.

Acceptance: overfit a tiny sample, perform a short interrupted/resumed run,
and evaluate/export the resulting checkpoint through the same factory.

## 4. Prepare data and training objectives

- Inventory log origins, conversion code and rules compatibility. Validate logs
  with the engine, count decisions by action kind, and report rejected games.
- Deduplicate whole games before splitting; all seats and augmented variants
  of one game belong to one split. Audit the existing split assignment first.
- Preserve current validation for comparison, but establish an untouched final
  test set. Sanma needs new held-out games if all current data has already been
  used for training or selection. Audit four-player test usage before calling
  it untouched. Freeze split manifests and keep their hashes with runs.
- Extract both teacher inputs and custom inputs from the same decision prefix
  when using distillation. Cache keys include game/decision identity, encoder
  version, rules, augmentation and teacher checkpoint hash.
- Start with behavior cloning as a pipeline check, then compare the existing
  offline action-value objective against that objective plus teacher loss.
  Existing training combines return regression, a CQL penalty, and auxiliary
  next-rank prediction; preserve its reward semantics for the first comparison.
- If reusing GRP reward shaping, pin the appropriate three- or four-player GRP
  model and audit its training split. Include its cost and provenance in runs.
  Replacing GRP is a separate reward-design experiment.
- Distill sanma from 104k and Nagomi from the confirmed deployed fine-tuned
  checkpoint. Retain base 298k as an additional four-player evaluation baseline.
  Apply teacher losses only over legal actions, with consistent action IDs;
  avoid arithmetic on masked negative infinities. Teacher agreement is a
  diagnostic, not a strength objective or promotion criterion.
- Keep augmentation valid for each ruleset. Sanma cannot use arbitrary suit
  permutations because the available manzu tiles differ from pinzu/souzu.

Acceptance: reproducible data counts, disjoint splits, finite losses, legal
targets and no future-information leakage in custom features.

## 5. Run staged experiments

1. **Smoke run:** small sample; check loss, masking, resume, export and latency.
2. **Architecture experiment:** custom network with existing observations to
   isolate architecture effects. Benchmark on the available Mac first.
3. **Encoder experiment:** add the custom observations with the same network
   family and comparable capacity. Keep a no-teacher control.
4. **Distillation experiment:** same custom model and data, with teacher loss.
5. **Full runs:** train each ruleset separately using the best justified setup,
   with multiple seeds for finalists where practical.

Fix train/validation manifests, optimizer-update budgets and evaluation cadence
for comparisons. Also report wall time, examples processed, parameter count,
peak memory and CPU inference cost; equal steps alone do not establish equal
compute. Tune on validation and reserve the final test for frozen finalists.

Train on the user's Apple Silicon Mac using MPS. First inventory chip, unified
memory and available disk, then measure samples/second, peak memory and CPU
inference time. Start with FP32, batch size 64 or 128, a small replay buffer and
zero or one loader worker; increase only after measuring unified-memory use.
Use gradient accumulation if a larger effective batch is needed. Keep model
and reward precision choices explicit: the existing GRP runs on CPU because
its float64 operations are unsupported on MPS. Run teacher inference/cache
generation separately from student training to limit peak memory. Estimate
full-run duration from measured throughput and decision counts. Choose the
smaller history encoder if needed to keep iteration practical locally. Cloud
training is outside the current plan. No new dependencies are part of this
planning change; discuss any required additions before installing them.

## 6. Evaluate actual play before promotion

- Offline: action-value losses, next-rank loss, human/teacher agreement broken
  down by action kind, and rare-action fixtures. These cannot establish playing
  strength alone.
- Gameplay: use paired seeds, balanced seats and a fixed opponent pool. Compare
  sanma against 104k and Nagomi against both deployed Nagomi and base 298k.
  Include TileSense guide opponents where useful to detect opponent-specific
  behavior. Predeclare the primary metric and practical regression tolerance.
- Report mean placement, rank points, deal-in/win rates and uncertainty. Choose
  final sample size from pilot variance and the desired detectable difference;
  a small pilot is not a promotion decision.
- Sanma: the current libriichi arena is four-player-only, and training does not
  automatically select a sanma `best.pth`. Adapt
  `flutter_client/test/sanma_model_comparison_test.dart` to candidate-versus-104k
  comparisons, including seat mapping between TileSense and compact sanma seats.
  A dedicated sanma arena is later work.
- Adapt Nagomi's current tests into paired full-game comparisons for the new
  candidate. Include the app's East-only behavior as a separate evaluation slice
  if the model will serve East-only games.
- Treat illegal actions, sidecar failures and fallback moves as operational
  failures. Report all attempts and investigate affected games; do not improve
  headline results by silently excluding failed pairs.

The existing sanma 60-pair report is a useful harness reference, but found no
family-wise significant improvement after adjustment. It cannot establish
strength for a new model or justify a small fixed promotion sample.

Acceptance: a frozen finalist passes a predeclared gameplay gate with adequate
uncertainty estimates and passes integration/correctness checks.

## 7. Export and integrate with TileSense

- Retain the external `/react` mjai request/reply contract. Build a versioned
  custom engine adapter inside the sidecar that receives the custom inputs and
  still uses the engine's legal masks and action decoding.
- Extend `mortal_sidecar/export_onnx.py` or add a focused custom exporter. Its
  current loader directly constructs `Brain` and `DQN`, so it cannot export an
  arbitrary architecture unchanged.
- Extend `mortal_sidecar/server.py` to dispatch explicitly by model/encoder
  metadata. It currently assumes one `obs` tensor, one `mask`, and the maximum
  libriichi observation version. Custom history/multi-input encodings require
  matching changes in both the Rust agent and sidecar.
- Check schema compatibility, input/output names, dtypes, dimensions, action
  counts, rules and pinned engine commit at startup. Preserve legacy support.
- Compare PyTorch and ONNX values and legal action choices on held-out replays
  and edge cases, including kan/riichi multi-stage actions. Investigate every
  action mismatch; document numerical tolerances and near-tie behavior.
- Benchmark FP32 on the actual CPU serving environment for latency, peak RSS
  and throughput. Start with FP32: existing INT8 reports show action changes.
- Package an immutable artifact manifest with architecture/encoder/action IDs,
  checksum, engine pin, training provenance and evaluation summary. Keep
  independent sanma and Nagomi releases with rollback to their current models.
- Run local sidecar integration and shadow comparisons before changing release
  manifests. Extend the existing deployment path only where the new artifact
  contract requires it.

Acceptance: a candidate can be served locally, evaluated end to end and rolled
back reproducibly. Publishing/deployment is a later explicit action.

## Suggested implementation batches

1. Baseline inventory, data/split audit and representation specification.
2. Custom model factory, checkpoint contract and a minimal training smoke run.
3. Shared custom observation extraction, fixtures and tiny-sample overfit.
4. Ruleset configs, optional teacher cache and ablation reports.
5. Candidate gameplay evaluation and statistical promotion gates.
6. ONNX export, sidecar adapter, release metadata and local integration checks.

Each batch should be reviewable without requiring the next batch to be complete.
Run the relevant Python tests in TileSense and Rust checks for engine changes;
run TileSense's affected Dart/Flutter analysis and tests for adapter/harness
changes. New raw-event parsing or input validation changes should be flagged
for a security-audit review before merging.

## Open design choices

- Whether the primary goal permits teacher-assisted training or requires fully
  independent learning. Keep either choice explicit in run provenance.
- Exact local Mac memory/disk capacity and acceptable run duration, established
  through inventory and a measured smoke run.
- Serving latency/memory targets and the acceptable gameplay regression margin.

Reference for the teacher/student method: [PyTorch knowledge distillation
tutorial](https://docs.pytorch.org/tutorials/beginner/knowledge_distillation_tutorial.html).
It demonstrates distinct student/teacher networks and combined training losses;
the mahjong-specific masking, replay alignment and evaluation gates above are
proposed adaptations for this project.
