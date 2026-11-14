# Replacement model training

This package starts TileSense's custom architecture and observation encoder
work. Production still uses the existing pinned models in `mortal_sidecar/`.
See [the replacement plan](../docs/CUSTOM_MODEL_TRAINING_PLAN.md).
Results and the next implementation milestone are in [STATUS.md](STATUS.md).
The current priority is the [independent compatible-library migration](../nagomi_compat/README.md),
which keeps the original Nagomi weights. Its partial encoder and runtime are
separate from the custom-model training experiments below.

Implemented here:

- Read-only hashes of the three baseline exports and a complete local game
  inventory, with split ID/content overlap detection and frozen JSONL manifests.
- Numerical comparison of Nagomi checkpoint candidates to its deployed export
  using the pinned model source and real held-out replay inputs.
- A roughly 530k-parameter hybrid model: tile and context branches, two
  128-wide attention layers, masked action values and auxiliary rank logits.
- Separate sanma/Nagomi configs, explicit checkpoint compatibility, RNG and
  optimizer restoration, synthetic learning checks and dynamic-batch ONNX parity.
- Shared visible-state encoding with hidden-tile sanitization, engine-owned
  legality, bounded history and persistent public summaries.
- A bounded real-data overfit command and local ONNX/mjai adapter, including
  separate riichi discard and kan-selection handling.
- Outcome-aware labels, with engine verification and explicit censoring of
  unobservable interrupted actions; immutable per-game pilot shards.
- A streaming imitation/final-rank pilot with validation by action kind,
  periodic checkpoints, explicit resume contracts and deterministic data cursors.

**Full-scale training, playing-strength evaluation and production integration
remain outstanding.** The tiny smoke command memorizes 64 decisions; the broader
pilot uses separate frozen training/validation games. Inspect [the input contract](ENCODER_SPEC.md)
and [action schema](action_spec.json) before extending the extractor or trainer.

Training tools live here so specifications, configurations and integration work
can be reviewed together in TileSense. The existing sibling engine checkout is
read-only during this milestone. Existing state getters provide the bridge;
binary hashes and expected source commits are recorded with each real run.

## Existing local environment

Run from the TileSense repository root. On this Mac, the already installed
`mortal_sidecar/.venv/bin/python` has PyTorch 2.15.0, NumPy 2.5.3, ONNX 1.23.2
and ONNX Runtime 1.30.0, with MPS available. No packages were added. The sibling
training environment is older and does not have the ONNX packages.

Use a fresh output path for every invocation; tools refuse to overwrite runs.
`model_training/runs/` is ignored. Checkpoints and logs remain local.

```sh
mortal_sidecar/.venv/bin/python -m model_training.audit \
  --out model_training/runs/baseline-audit

mortal_sidecar/.venv/bin/python -m model_training.verify_nagomi \
  --out model_training/runs/nagomi-provenance.json

mortal_sidecar/.venv/bin/python -m model_training.smoke \
  --config model_training/configs/sanma.json \
  --device mps --batch-size 64 --out model_training/runs/sanma-smoke

mortal_sidecar/.venv/bin/python -m model_training.smoke \
  --config model_training/configs/nagomi.json \
  --device mps --batch-size 64 --out model_training/runs/nagomi-smoke

mortal_sidecar/.venv/bin/python -m model_training.real_smoke \
  --ruleset sanma --out model_training/runs/sanma-real

mortal_sidecar/.venv/bin/python -m model_training.real_smoke \
  --ruleset nagomi --out model_training/runs/nagomi-real

mortal_sidecar/.venv/bin/python -m model_training.cache \
  --ruleset sanma --train-games 128 --val-games 32 \
  --out model_training/runs/sanma-pilot-cache

mortal_sidecar/.venv/bin/python -m model_training.pilot \
  --manifest model_training/runs/sanma-pilot-cache/manifest.json \
  --epochs 2 --max-steps 3000 --out model_training/runs/sanma-pilot

TILESENSE_TEST_RULESET=sanma mortal_sidecar/.venv/bin/python -m unittest discover -s model_training/tests -v
TILESENSE_TEST_RULESET=nagomi mortal_sidecar/.venv/bin/python -m unittest discover -s model_training/tests -v
mortal_sidecar/.venv/bin/python -m compileall -q model_training
mortal_sidecar/.venv/bin/python -m tabnanny model_training
```

The audit expects existing data in `~/Documents/mortal-sanma-data/` and
`~/Documents/mortal-4p-data/`; override `--data-parent` as needed. Its structural
checks are not a full engine replay. It does not declare the existing test split
untouched: historical usage still needs verification, and sanma has no test split.

The Nagomi verifier uses the existing local `../Mortal` Git history and
`mortal_sidecar/libriichi.so`, selects one sorted validation game, and compares
up to 128 deterministic replay positions. Matching a fixture identifies a
numerically compatible candidate; it does not prove byte-level export lineage.
It performs no training or strength evaluation.

The smoke command checks a fixed synthetic batch, restores a complete checkpoint,
compares a subsequent optimizer update, and exports CPU FP32 ONNX. It verifies
legal Q values and rank logits at batch sizes 1 and 3, illegal masks and chosen
actions. The CPU export intentionally uses the same legacy exporter path as
the existing export tooling. No deployment manifests or live services change.

The real smoke command replays two training games and one validation game, then
samples 64 nonforced decisions per split using seed 7. It stops after the tiny
training batch is memorized or the update cap is reached. Reports record log,
source and engine hashes, validation metrics, checkpoint restoration, MPS memory
snapshots, ONNX parity and eight locally decoded/validated game reactions.
This is not a generalization or playing-strength test. The test split is unused.

`inference.react_local` accepts a visible mjai prefix and returns the same
reaction/riichi-discard fields as the existing sidecar, plus a network-decision
count. It has no HTTP endpoint or deployment integration. Its callback checks
training/inference legal-mask agreement and retains engine action decoding.

Checkpoint resume covers fixed-batch single-process experiments. Real-data runs
record dataset/source provenance; streaming cursors, worker state, schedulers
and AMP must be added when those features exist. Legacy checkpoints cannot resume
through this loader.

## Broader pilot and resume

Build separate caches and run separate processes for `sanma` and `nagomi`.
`cache` deterministically samples whole games using seed 7, verifies their
hashes against the frozen audit, checks split disjointness, compares every
retained label/mask with the engine, and writes checksummed per-game NPZ shards.
The default audit path is the initial local audit; override `--audit-dir` for
a new audit. The final test split is not read. Encoder/extractor/engine changes
invalidate the cache. Completed manifests are written only after successful
extraction; incomplete cache directories are not training inputs.

The pilot defaults to batch size 64, AdamW at 0.0003, rank-loss weight 0.1,
two epochs and a 3,000-update cap. It trains on nonforced decisions, shuffles
game order and rows deterministically, and holds only one shard at a time.
Checkpoints and validation run every 500 updates. Metrics include action loss,
agreement by action kind, final-rank prediction and a pass/first-legal reference.
Cached outcomes are targets only. The final checkpoint is exported and checked
against PyTorch and local mjai decoding, but is not promoted to production.

Resume into a fresh output directory using the same cache and training contract:

```sh
mortal_sidecar/.venv/bin/python -m model_training.pilot \
  --manifest model_training/runs/sanma-pilot-cache/manifest.json \
  --resume model_training/runs/sanma-pilot/step_001000.pth \
  --epochs 2 --max-steps 3000 --out model_training/runs/sanma-pilot-resumed

mortal_sidecar/.venv/bin/python -m model_training.compare_resume \
  --manifest model_training/runs/sanma-pilot-cache/manifest.json \
  --original model_training/runs/sanma-pilot/final.pth \
  --resumed model_training/runs/sanma-pilot-resumed/final.pth \
  --out model_training/runs/resume-comparison.json
```

Resume restores optimizer/RNG state and the next epoch/shard/row cursor. It
rejects mismatched code, data, engine, device or objective contracts. MPS updates
are not bit-exact: compare policy probabilities and action choices, not just
raw weights. Imitation leaves shared Q offsets unidentified. Resume cannot
continue after the specified epoch/update bounds have already been reached.

There is no Python lint configuration for this package yet. Compileall,
tabnanny and Git whitespace checks require no new packages. Raw log parsing is
new local input handling; run the security-audit skill before merging that work.
