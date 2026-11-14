# Visible observation contract v1

Schema ID: `tilesense-visible-v1`. Implemented in `encoding.py`, shared by log
replay and local ONNX inference. This supersedes the synthetic
`tilesense-prototype-input-v0` contract; those checkpoints are incompatible.
This is an experimental representation, not a production model release.

| Input | Shape | Dtype | Meaning |
| --- | --- | --- | --- |
| `tiles` | B × 34 × 20 | float32 | Normalized visible tile features |
| `context` | B × 40 | float32 | Relative seats, round, score and decision state |
| `history` | B × 128 × 4 | int64 | Event kind, relative actor, tile, flags |
| `history_mask` | B × 128 | bool | True for a real event |
| `action_mask` | B × 46 or 47 | bool | Legal actions from the rules engine |
| `q` (output) | B × 46 or 47 | float32 | Action values; illegal slots are −∞ |
| `rank` (output) | B × 4 or 3 | float32 | Auxiliary rank logits |

The batch axis is dynamic in ONNX. Both rulesets share the architecture factory
but have separate configurations, action counts, heads and checkpoints.

## Ownership and visibility

Rust `PlayerState` owns hand counts, red tiles in hand, waits, shanten, furiten,
action availability and masks. Only the legal mask is reused from `encode_obs`;
legacy observation planes are discarded. Existing getters provide this bridge
without changing or rebuilding engine source. Public summaries accumulate
observable fields; they do not implement legal-action or scoring rules.

`visible_event` allowlists fields, replaces opponents' initial hands and draws
with unknown identities, and removes names, seeds, metadata, ura markers and
other fields before either state tracking or feature accumulation. Own tiles
and public fields are validated. `snapshot` requires an active decision. Later
events, final scores and outcome labels never enter a snapshot.

Full-hand summaries reset at `start_kyoku` and survive history truncation.
Relative seat 0 is self, followed by compact engine seat order. Sanma's fourth
seat channels are zero. Tile order is 1m–9m, 1p–9p, 1s–9s, E/S/W/N/P/F/C.

## Tile channels

| Index | Meaning |
| --- | --- |
| 0 | Own hand count / 4 |
| 1 | Own red-five presence at its base tile type |
| 2 | Known physical count / 4: own hand, public discards/consumed tiles/kita, indicators |
| 3 | Revealed dora indicator count / 5 |
| 4 | Engine wait flag |
| 5 | Available tile type; 2m–8m are zero in sanma |
| 6–9 | All discards per relative seat / 4, including subsequently called tiles |
| 10–13 | Exposed meld counts per relative seat / 4, including concealed kans |
| 14 | Known red-five count: own hand, public tiles and indicators |
| 15 | Last self-draw base tile flag from the engine, if present |
| 16–19 | Discards since each relative seat declared riichi / 4, including the riichi discard |

Called tiles are already public discards: only newly consumed tiles increase
known counts. Kakan adds only the fourth tile. Kita increases visible North
counts and its separate context count. Discard summaries intentionally retain
called tiles as historical facts. Dora bonus identity is not supplied as a
handwritten feature; it can be learned from indicator and tile identities.

## Context channels

| Index | Meaning |
| --- | --- |
| 0–3 | Relative scores / 100,000, clipped to [−1, 1] |
| 4–7 | Relative dealer one-hot |
| 8–11 | Round wind E/S/W/N one-hot |
| 12 | Hand number / player count |
| 13 | Honba / 10, capped at 1 |
| 14 | Riichi sticks / 10, capped at 1 |
| 15 | Remaining draws / initial draw count (70 or 55), floored at zero |
| 16 | Scheduled game length / 8 (4/8 or 3/6) |
| 17 | Engine furiten flag |
| 18 | Engine shanten / 8 |
| 19 | Kan tile-selection phase, distinct from a normal decision |
| 20–23 | Kita count per relative seat / 4 |
| 24–27 | Riichi declared per relative seat |
| 28–31 | Riichi accepted per relative seat |
| 32–35 | Own seat wind one-hot |
| 36–39 | Active relative seat slots; three or four ones |

Scores start from each round's public scores and reflect accepted riichi
payments. Outcome events end decision availability; the next round resets
scores from its public start event. Outcome-score reconstruction is unnecessary.

## Event history

Chronological last 128 events of the current hand, left-aligned with zero
padding to the right. Each token contains event kind, relative actor, tile ID
and flags. Actor is 1 for self, 2–4 for opponents, or 0 when absent. Tile ID is
base tile index + 1; red 5m/5p/5s are 35/36/37; unknown/absent is 0. Flags use
only bit 0 (`tsumogiri`); the other bits are reserved and zero.

Event kinds: 0 padding; 1 start_kyoku; 2 tsumo; 3 dahai; 4 chi; 5 pon;
6 daiminkan; 7 ankan; 8 kakan; 9 nukidora; 10 dora; 11 reach;
12 reach_accepted; 13 hora; 14 ryukyoku; 15 end_kyoku.
Start/end game events are not tokens. Ankan uses its first consumed tile;
dora/start_kyoku use the indicator. Full meld composition remains in the tile
summaries even when not fully represented by one history token.

Inputs reject invalid shapes/dtypes, nonfinite values, out-of-range history
tokens, nonzero padding and empty legal masks. Empty history remains supported
by neural/ONNX tests. Local inference requires masks to agree with an independent
engine replay used for action decoding. Changing unavailable hands/draws cannot
change encoded inputs; rotating all absolute seats preserves relative features.

## Current extraction scope

`data.resolve_label` scans beyond dora/riichi-payment announcements to identify
the observed action. It labels discards, riichi, calls, explicit kan tile
selection, kita, all winners in a multiple-ron outcome and engine-permitted
abortive draws. A quiet next draw proves available calls were declined; an
observed lower-priority call proves higher-priority actions were declined.
Unobservable losing calls and actions interrupted by another player's win are
censored, rather than converted to pass. Normal terminal draws are not assumed
to be voluntary abortive draws. Every retained target must be legal.

Optional reference verification identifies positions by a digest of the legacy
observation, then compares retained action labels and masks with the pinned
engine's offline loader. These legacy arrays are used only for verification,
not custom model inputs. A disagreement aborts cache construction. All 166,818
retained labels/masks in the first 320-game pilot matched. Censoring reasons,
action counts and reference-only positions are recorded per split.

Final-placement targets come separately from the engine's GRP outcome parser,
which handles last-round deltas, deposits and seat-order tie rules. They never
enter policy observations. The broader pilot adds final-rank cross entropy;
the tiny overfit command still trains only imitation. Neither objective
calibrates Q values as expected returns. Logs are bounded by line size, total
decompressed size and event count.
