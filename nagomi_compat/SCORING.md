# Independent hand scoring

`scoring.score_hand` independently calculates yaku, han, fu, limits and basic
four-player payments. It enumerates the hand decompositions from our own hand
mathematics and each possible placement of the winning tile. The highest-paying
reading wins. It does not import an original engine, a third-party scorer or
generated reference lookup tables.

`Meld` describes a sequence, triplet or kan. `WinContext` supplies winds and
explicit win conditions. Counts include the winning tile. `bonus_han` is an
explicit bonus count; bonus tiles cannot supply the required yaku. Invalid
tile counts, melds, flags and physical hand multiplicities are rejected.

`Score.payments` excludes honba, riichi deposits and liability settlement.
For a nondealer tsumo, payments are the two nondealer shares followed by the
dealer share. A dealer tsumo has three equal shares. Ron has one payment.
Scoring does not decide whether the player may legally claim the win: furiten
and action eligibility remain in `legality`, and the final policy win guard is
still unimplemented.

The implementation covers ordinary structural/situational yaku, seven pairs,
thirteen orphans, yakuman and additive yakuman combinations. It distinguishes
ron-completed triplets, wait fu, closed/open hands, concealed/open quads, pinfu
tsumo and the fixed seven-pairs fu. The pinned target uses no kiriage and a
counted-yakuman ceiling; its probed special waits use single yakuman values.
The scorer uses additive double-wind pair fu.

The [official WRC scoring rules](https://www.worldriichi.org/wrc-rules) provide
background for the scoring arithmetic. This target is a pinned engine contract;
it does not adopt every current WRC option, such as kiriage or double-wind pair
treatment. Target comparisons use black-box outputs and recorded outcomes.

## Visible-state adapter

`score_win` translates a current visible state into scoring inputs. It counts
visible dora and red tiles and preserves the actual winning tile. State now
tracks normal/double riichi and ippatsu. Ippatsu ends on the player's next
discard or any call/kan; double riichi survives the interruption.

Revealed ura indicators can be supplied explicitly for a finished result and
require accepted riichi. This adapter does not discover unrevealed ura, infer
hidden tiles or assign future-riichi/ippatsu assumptions. Revealed ura in the
outcome diagnostic is target information only, never an encoded observation.

## Validation

- All **841 recorded wins** across 96 validation games matched basic hand
  points and all four settlement deltas after the recorded settlement rules.
  Coverage includes 332 tsumo, 509 ron, 340 riichi wins, 69 ippatsu wins,
  five double-riichi wins, one yakuman win and five multiple-ron follow-ups.
- All **48 synthetic completed-hand probes** matched the pinned native
  encoder's clipped scalar values at `1e-7` absolute tolerance. These include
  dealer/nondealer, special waits, stacked yakuman and initial self-draw.
- All **30 completed self-draw frames** in the two frozen corpora matched the
  scalar values as well, including red bonuses and live ippatsu conditions.
- The 959 previously implemented observation rows, legal masks, stored hand
  fields and furiten still match the oracle across the same 96 full games.
- There are 56 compatibility tests, including scorer execution with reference
  imports blocked. Both training regression suites and basic Python lint pass.

The recorded Tenhou-derived multiple-ron outcomes award honba only to the
first recorded winner. The outcome tool applies that convention and uses the
recorded deposit award. Liability settlement is not implemented; the tool
reports vector differences instead of treating them as successful comparisons.
No liability exception was needed for these 841 outcomes. Synthetic prefixes
isolate scoring; they are not legal full-game replays. Clipped scalar values
cannot certify all exact payments beyond their saturation bounds. Sampled
agreement is not proof over every possible hand or rule variation.

Reports: [development outcomes](../model_training/reports/nagomi_compat_scoring_outcomes_development_v1.json),
[additional outcomes](../model_training/reports/nagomi_compat_scoring_outcomes_additional_v1.json),
[further outcomes](../model_training/reports/nagomi_compat_scoring_outcomes_fresh_v1.json)
and [synthetic/frozen scalar checks](../model_training/reports/nagomi_compat_scoring_reference_v2.json).

## Probability/EV integration gate

Scoring is a prerequisite for the remaining 53 observation rows. Those rows
remain unknown. The new scorer is not yet used to fill their values.

A separate search experiment tested the hypothesis that future discards
maximize tenpai probability independently of score. Across 704 candidate
vectors (11,968 horizon values), 190 vectors differed from the oracle by more
than `1e-6`; maximum absolute probability difference was `0.11948`.
That hypothesis does not reproduce the target. The experiment does not prove
which search objective, transition assumptions or score estimates the target
uses. It is diagnostic tooling, never a runtime fallback or approximation.

Reports: [development search diagnostic](../model_training/reports/nagomi_compat_probability_search_development_v1.json)
and [additional search diagnostic](../model_training/reports/nagomi_compat_probability_search_additional_v1.json).

Next, characterize score-aware future choices, bonus/ura and riichi assumptions,
then independently implement and validate all probability/EV horizons. The
existing NaN/incomplete-input guard remains active. Win-guard and full reaction
chain parity still follow complete independently generated observations.
