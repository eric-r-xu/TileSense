using Gee;
using Engine;

/*
 * Tile-efficiency calculations ported from Riichi-Trainer's
 * ShantenCalculator.js, UkeireCalculator.js, and Evaluations.js (GPL-3.0).
 * https://github.com/FluffyStuff/riichi-trainer
 *
 * The 38-slot representation is intentionally retained so the results match
 * Riichi-Trainer: 1-9m, 11-19p, 21-29s, and 31-37z.
 */
public class TileEfficiencyResult : Object
{
    public TileEfficiencyResult(int tile_index, int shanten, int ukeire, ArrayList<int> improving_tiles)
    {
        this.tile_index = tile_index;
        this.shanten = shanten;
        this.ukeire = ukeire;
        this.improving_tiles = improving_tiles;
    }

    public int tile_index { get; private set; }
    public int shanten { get; private set; }
    public int ukeire { get; private set; }
    public ArrayList<int> improving_tiles { get; private set; }
    // Probability-weighted points over the remaining live-wall horizon.  This
    // is populated by EfficiencyLogging, which has access to round/yaku state.
    public double expected_value { get; set; default = 0; }
    public string value_plan { get; set; default = "PROJECTED"; }
    public bool yaku_met { get; set; default = false; }
    public bool recommend_riichi { get; set; default = false; }
}

internal class UkeireResult : Object
{
    public UkeireResult()
    {
        tiles = new ArrayList<int>();
    }

    public int value { get; set; default = 0; }
    public ArrayList<int> tiles { get; private set; }
}

public class TileEfficiencyCalculator : Object
{
    private int[] work_hand = new int[38];
    private int complete_sets;
    private int pair;
    private int partial_sets;
    private int best_shanten;
    private int minimum_shanten;
    private bool has_given_minimum;

    public ArrayList<TileEfficiencyResult> calculate(int[] concealed_hand, int[] remaining_tiles)
    {
        int[] hand = copy_counts(concealed_hand);
        bool open_hand = count_tiles(hand) < 14;

        // Riichi-Trainer pads each open meld with a completed honor triplet.
        int shanten_offset = ((14 - count_tiles(hand)) / 3) * 2;
        for (int i = 0; i < shanten_offset; i += 2)
            hand[31] += 3;

        int base_shanten = shanten(hand, open_hand);
        ArrayList<TileEfficiencyResult> results = new ArrayList<TileEfficiencyResult>();

        for (int discard = 1; discard < hand.length; discard++)
        {
            if (discard % 10 == 0 || concealed_hand[discard] == 0)
                continue;

            hand[discard]--;
            int resulting_shanten = shanten(hand, open_hand);
            UkeireResult ukeire = calculate_ukeire(hand, remaining_tiles, open_hand, base_shanten);
            hand[discard]++;

            results.add(new TileEfficiencyResult(discard, resulting_shanten, ukeire.value, ukeire.tiles));
        }

        return results;
    }

    // Evaluate a hand between draws (13, 10, 7, or 4 concealed tiles).  The
    // missing groups are completed open melds, matching the padding strategy
    // used by calculate() for a post-call discard decision.
    public int calculate_waiting_shanten(int[] concealed_hand)
    {
        int[] hand = copy_counts(concealed_hand);
        int melds = int.max(0, (13 - count_tiles(hand)) / 3);
        for (int i = 0; i < melds; i++)
            hand[31] += 3;
        return shanten(hand, melds > 0);
    }

    private UkeireResult calculate_ukeire(int[] hand, int[] remaining_tiles, bool open_hand, int base_shanten)
    {
        UkeireResult result = new UkeireResult();

        for (int added = 1; added < hand.length; added++)
        {
            if (added % 10 == 0 || remaining_tiles[added] == 0)
                continue;

            hand[added]++;
            if (shanten(hand, open_hand, base_shanten - 1) < base_shanten)
            {
                result.value += remaining_tiles[added];
                result.tiles.add(added);
            }
            hand[added]--;
        }

        return result;
    }

    private int shanten(int[] hand, bool open_hand, int known_minimum = -2)
    {
        if (open_hand)
            return standard_shanten(hand, known_minimum);

        int chiitoitsu = chiitoitsu_shanten(hand);
        if (chiitoitsu < 0)
            return chiitoitsu;

        int kokushi = kokushi_shanten(hand);
        if (kokushi < 3)
            return kokushi;

        return int.min(standard_shanten(hand, known_minimum), int.min(chiitoitsu, kokushi));
    }

    private int chiitoitsu_shanten(int[] hand)
    {
        int pairs = 0;
        int unique = 0;
        for (int i = 1; i < hand.length; i++)
        {
            if (hand[i] == 0)
                continue;
            unique++;
            if (hand[i] >= 2)
                pairs++;
        }

        int result = 6 - pairs;
        if (unique < 7)
            result += 7 - unique;
        return result;
    }

    private int kokushi_shanten(int[] hand)
    {
        int unique = 0;
        int has_pair = 0;
        for (int i = 1; i < hand.length; i++)
        {
            if (i % 10 != 1 && i % 10 != 9 && i <= 30)
                continue;
            if (hand[i] == 0)
                continue;
            unique++;
            if (hand[i] >= 2)
                has_pair = 1;
        }
        return 13 - unique - has_pair;
    }

    private int standard_shanten(int[] hand, int known_minimum = -2)
    {
        work_hand = copy_counts(hand);
        complete_sets = 0;
        pair = 0;
        partial_sets = 0;
        best_shanten = 8;
        has_given_minimum = known_minimum != -2;
        minimum_shanten = has_given_minimum ? known_minimum : -1;

        for (int i = 1; i < work_hand.length; i++)
        {
            if (work_hand[i] < 2)
                continue;
            pair++;
            work_hand[i] -= 2;
            remove_completed_sets(1);
            work_hand[i] += 2;
            pair--;
        }

        remove_completed_sets(1);
        return best_shanten;
    }

    private void remove_completed_sets(int start)
    {
        if (best_shanten <= minimum_shanten)
            return;

        int i = start;
        while (i < work_hand.length && work_hand[i] == 0)
            i++;

        if (i >= work_hand.length)
        {
            remove_potential_sets(1);
            return;
        }

        if (work_hand[i] >= 3)
        {
            complete_sets++;
            work_hand[i] -= 3;
            remove_completed_sets(i);
            work_hand[i] += 3;
            complete_sets--;
        }

        if (i < 30 && work_hand[i + 1] != 0 && work_hand[i + 2] != 0)
        {
            complete_sets++;
            work_hand[i]--;
            work_hand[i + 1]--;
            work_hand[i + 2]--;
            remove_completed_sets(i);
            work_hand[i]++;
            work_hand[i + 1]++;
            work_hand[i + 2]++;
            complete_sets--;
        }

        remove_completed_sets(i + 1);
    }

    private void remove_potential_sets(int start)
    {
        if (best_shanten <= minimum_shanten)
            return;
        if (has_given_minimum && complete_sets < 3 - minimum_shanten)
            return;

        int i = start;
        while (i < work_hand.length && work_hand[i] == 0)
            i++;

        if (i >= work_hand.length)
        {
            int current = 8 - complete_sets * 2 - partial_sets - pair;
            if (current < best_shanten)
                best_shanten = current;
            return;
        }

        if (complete_sets + partial_sets < 4)
        {
            if (work_hand[i] == 2)
            {
                partial_sets++;
                work_hand[i] -= 2;
                remove_potential_sets(i);
                work_hand[i] += 2;
                partial_sets--;
            }

            if (i < 30 && work_hand[i + 1] != 0)
            {
                partial_sets++;
                work_hand[i]--;
                work_hand[i + 1]--;
                remove_potential_sets(i);
                work_hand[i]++;
                work_hand[i + 1]++;
                partial_sets--;
            }

            if (i < 30 && i % 10 <= 8 && work_hand[i + 2] != 0)
            {
                partial_sets++;
                work_hand[i]--;
                work_hand[i + 2]--;
                remove_potential_sets(i);
                work_hand[i]++;
                work_hand[i + 2]++;
                partial_sets--;
            }
        }

        remove_potential_sets(i + 1);
    }

    private static int count_tiles(int[] hand)
    {
        int count = 0;
        foreach (int value in hand)
            count += value;
        return count;
    }

    private static int[] copy_counts(int[] source)
    {
        int[] copy = new int[source.length];
        for (int i = 0; i < source.length; i++)
            copy[i] = source[i];
        return copy;
    }
}

internal class ActionEfficiencyOption : Object
{
    public ActionEfficiencyOption(string name, string row, int rank,
        int shanten = 99, int ukeire = -1, double expected_value = 0,
        bool yaku_path = true)
    {
        this.name = name;
        this.row = row;
        this.rank = rank;
        this.shanten = shanten;
        this.ukeire = ukeire;
        this.expected_value = expected_value;
        this.yaku_path = yaku_path;
    }

    public string name { get; private set; }
    public string row { get; private set; }
    public int rank { get; private set; }
    public int shanten { get; private set; }
    public int ukeire { get; private set; }
    public double expected_value { get; private set; }
    public bool yaku_path { get; private set; }
    public int tile_1_ID { get; set; default = -1; }
    public int tile_2_ID { get; set; default = -1; }
}

internal class ExpectedValueAssessment : Object
{
    public double expected_value { get; set; default = 0; }
    public double average_points { get; set; default = 0; }
    public string plan { get; set; default = "PROJECTED"; }
    public bool yaku_met { get; set; default = false; }
    public bool recommend_riichi { get; set; default = false; }
}

internal class PostCallQuality : Object
{
    public int shanten { get; set; default = 99; }
    public int ukeire { get; set; default = 0; }
    public double expected_value { get; set; default = 0; }
    public bool yaku_path { get; set; default = false; }
    public string value_plan { get; set; default = "NO YAKU"; }
}

public class EfficiencyLogging : Object
{
    // A conventional riichi-strategy threshold: preserve damaten only when
    // every live ron wait is already worth at least 5200 (7700 as dealer).
    private const int DAMATEN_MIN_POINTS = 5200;
    private const int DEALER_DAMATEN_MIN_POINTS = 7700;
    // Representative mangan-sized downside used only to compare offense and
    // safety after an opponent has declared riichi.
    private const int DEFENSIVE_DEAL_IN_EXPOSURE = 8000;

    private static ArrayList<TileEfficiencyResult>? last_results;
    private static double[]? last_safety;
    private static double last_best_safety;
    private static string? last_action_recommendation;
    private static int last_action_tile_1_ID = -1;
    private static int last_action_tile_2_ID = -1;
    private static int last_riichi_discard_index = -1;

    public static bool enabled { get; set; default = false; }
    public static bool singleplayer_session { get; set; default = false; }

    public static string? log_call_decision(RoundState state, bool can_chii,
        bool can_pon, bool can_kan, bool can_ron)
    {
        last_action_recommendation = null;
        last_action_tile_1_ID = -1;
        last_action_tile_2_ID = -1;
        if (!enabled || !singleplayer_session || state.discard_tile == null)
            return null;

        Tile incoming = state.discard_tile;
        int incoming_index = to_trainer_index(incoming.tile_type);
        int[] hand = hand_counts(state.self.hand);
        int[] remaining = remaining_counts(state);
        TileEfficiencyCalculator calculator = new TileEfficiencyCalculator();
        int baseline = calculator.calculate_waiting_shanten(hand);
        ArrayList<ActionEfficiencyOption> options = new ArrayList<ActionEfficiencyOption>();

        // Passing is the reference choice.  In addition to flexibility it
        // preserves riichi, which guarantees the one-yaku minimum for a future
        // closed tenpai even when the current shape has no natural yaku.
        options.add(new ActionEfficiencyOption("PASS",
            "%s PASS -> Keep the hand closed; preserves riichi/yaku (S%d)".printf(
                format_tile_overlay(incoming_index), baseline), 1, baseline, -1));

        if (can_ron)
            options.add(new ActionEfficiencyOption("RON",
                "%s RON -> Win immediately; always take a legal ron".printf(
                    format_tile_overlay(incoming_index)), 3, -1, 0));

        if (can_pon)
        {
            int[] called_hand = copy_action_counts(hand);
            called_hand[incoming_index] -= 2;
            ArrayList<Tile> pon_tiles = matching_tiles(
                state.self.hand, incoming.tile_type, 2);
            ArrayList<RoundStateCall> pon_calls = calls_with(
                state.self.calls, RoundStateCall.CallType.PON,
                incoming, pon_tiles);
            PostCallQuality quality = best_post_call_quality(state, calculator,
                called_hand, remaining, pon_calls);
            int rank = quality.shanten < baseline && quality.yaku_path ? 2 : 0;
            options.add(new ActionEfficiencyOption("PON", "%s %s %s PON -> S%d / U%d / EV %.0f; %s; %s".printf(
                format_tile_overlay(incoming_index), format_tile_overlay(incoming_index),
                format_tile_overlay(incoming_index), quality.shanten, quality.ukeire,
                quality.expected_value,
                rank == 2 ? "advances the hand, but opens it" :
                    "does not justify losing the closed route",
                quality.value_plan),
                rank, quality.shanten, quality.ukeire,
                quality.expected_value, quality.yaku_path));
        }

        if (can_chii)
        {
            foreach (ArrayList<Tile> group in state.get_chii_groups(state.self))
            {
                int[] called_hand = copy_action_counts(hand);
                foreach (Tile tile in group)
                    called_hand[to_trainer_index(tile.tile_type)]--;
                ArrayList<RoundStateCall> chii_calls = calls_with(
                    state.self.calls, RoundStateCall.CallType.CHII,
                    incoming, group);
                PostCallQuality quality = best_post_call_quality(state, calculator,
                    called_hand, remaining, chii_calls);
                int rank = quality.shanten < baseline && quality.yaku_path ? 2 : 0;
                ActionEfficiencyOption option = new ActionEfficiencyOption("CHII",
                    "%s CHII -> S%d / U%d / EV %.0f; %s; %s".printf(
                        format_chii_tiles(incoming, group), quality.shanten,
                        quality.ukeire, quality.expected_value,
                        rank == 2 ? "advances the hand, but opens it" :
                            "no legal-yaku/value advantage over passing",
                        quality.value_plan),
                    rank, quality.shanten, quality.ukeire,
                    quality.expected_value, quality.yaku_path);
                option.tile_1_ID = group[0].ID;
                option.tile_2_ID = group[1].ID;
                options.add(option);
            }
        }

        if (can_kan)
        {
            ArrayList<Tile> kan_tiles = matching_tiles(
                state.self.hand, incoming.tile_type, 3);
            ArrayList<RoundStateCall> kan_calls = calls_with(
                state.self.calls, RoundStateCall.CallType.OPEN_KAN,
                incoming, kan_tiles);
            bool kan_yaku = has_open_yaku_path(state, state.self.hand, kan_calls);
            options.add(new ActionEfficiencyOption("KAN",
                "%s %s %s %s KAN -> Rinshan + dora; %s; commits the hand and raises risk".printf(
                    format_tile_overlay(incoming_index), format_tile_overlay(incoming_index),
                    format_tile_overlay(incoming_index), format_tile_overlay(incoming_index),
                    kan_yaku ? "YAKU PATH" : "NO CONFIRMED YAKU"),
                0, 99, -1, 0, kan_yaku));
        }

        ActionEfficiencyOption best = options[0];
        foreach (ActionEfficiencyOption option in options)
        {
            if (option.rank > best.rank ||
                (option.rank == best.rank && option.shanten < best.shanten) ||
                (option.rank == best.rank && option.shanten == best.shanten &&
                    option.expected_value > best.expected_value) ||
                (option.rank == best.rank && option.shanten == best.shanten &&
                    option.expected_value == best.expected_value &&
                    option.ukeire > best.ukeire))
                best = option;
        }

        last_action_recommendation = best.name;
        last_action_tile_1_ID = best.tile_1_ID;
        last_action_tile_2_ID = best.tile_2_ID;

        StringBuilder overlay = new StringBuilder();
        overlay.append("ACTION EFFICIENCY GUIDE\n");
        overlay.append_printf("Incoming: %s\n", format_tile_overlay(incoming_index));
        overlay.append_printf("Recommended: %s BEST\n\n", best.name);
        overlay.append("OPTIONS\n");
        foreach (ActionEfficiencyOption option in options)
        {
            overlay.append(option.row);
            if (option == best)
                overlay.append(" BEST");
            overlay.append("\n");
        }
        overlay.append("\nPrinciple: take legal wins first; protect the one-yaku minimum, riichi access, and expected points before shape alone.");
        Environment.log(LogType.GAME, "ActionEfficiency", overlay.str);
        return overlay.str;
    }

    public static string? log_turn(RoundState state)
    {
        last_riichi_discard_index = -1;
        if (!enabled || !singleplayer_session || state.self.index != state.current_player.index)
            return null;

        int[] hand = new int[38];
        foreach (Tile tile in state.self.hand)
            hand[to_trainer_index(tile.tile_type)]++;

        int[] remaining = new int[38];
        for (int i = 1; i < remaining.length; i++)
            if (i % 10 != 0)
                remaining[i] = 4;

        foreach (Tile tile in state.get_tiles())
        {
            if (tile.tile_type == TileType.BLANK)
                continue;
            int index = to_trainer_index(tile.tile_type);
            remaining[index] = int.max(0, remaining[index] - 1);
        }

        TileEfficiencyCalculator calculator = new TileEfficiencyCalculator();
        last_results = calculator.calculate(hand, remaining);
        if (last_results.size == 0)
            return null;

        bool can_riichi = state.can_riichi();
        foreach (TileEfficiencyResult result in last_results)
        {
            ExpectedValueAssessment value = assess_discard_value(state,
                result, remaining, state.self.calls, can_riichi);
            result.expected_value = value.expected_value;
            result.value_plan = value.plan;
            result.yaku_met = value.yaku_met;
            result.recommend_riichi = value.recommend_riichi;
        }

        // The guide lists every discard candidate, ordered by expected value
        // (then by nearer/wider shape), so the strongest option is always the
        // first row.
        last_results.sort((a, b) => {
            if (a.expected_value != b.expected_value)
                return a.expected_value > b.expected_value ? -1 : 1;
            if (a.shanten != b.shanten)
                return a.shanten - b.shanten;
            return b.ukeire - a.ukeire;
        });

        // Efficiency and value are two independent rankings: the tile that
        // keeps the widest/nearest shape is often not the tile with the
        // highest probability-weighted points, so each is resolved on its own
        // criteria and a single winner is picked per column.
        TileEfficiencyResult best_efficiency = last_results[0];
        TileEfficiencyResult best_ev = last_results[0];
        foreach (TileEfficiencyResult result in last_results)
        {
            if (result.shanten < best_efficiency.shanten ||
                (result.shanten == best_efficiency.shanten &&
                    (result.ukeire > best_efficiency.ukeire ||
                        (result.ukeire == best_efficiency.ukeire &&
                            result.expected_value > best_efficiency.expected_value))))
                best_efficiency = result;
            if (result.expected_value > best_ev.expected_value ||
                (result.expected_value == best_ev.expected_value &&
                    (result.shanten < best_ev.shanten ||
                        (result.shanten == best_ev.shanten &&
                            result.ukeire > best_ev.ukeire))))
                best_ev = result;
        }

        if (best_ev.recommend_riichi)
            last_riichi_discard_index = best_ev.tile_index;

        StringBuilder defense_message = new StringBuilder();
        StringBuilder defense_overlay = new StringBuilder();
        append_defense_analysis(state, hand, remaining,
            defense_message, defense_overlay);

        // The tile autoplay would discard now, resolved with the same policy as
        // the automated discard (risk-adjusted once a riichi is out).
        Tile? autoplay_tile = recommended_discard(state.self.hand);
        int autoplay_index = autoplay_tile == null ? best_ev.tile_index :
            to_trainer_index(autoplay_tile.tile_type);

        StringBuilder message = new StringBuilder();
        StringBuilder overlay = new StringBuilder();
        message.append("Riichi-Trainer tile efficiency\n");
        message.append("Hand: ").append(format_counts(hand)).append("\n");
        // The hand strip is redundant with the on-table hand and only cost
        // vertical room in the overlay, so it is no longer shown there.
        overlay.append_printf("AUTOPLAY CHOICE: %s · %s\n",
            format_tile_overlay(autoplay_index),
            last_safety == null ? "best expected value" : "risk-adjusted EV + defense");
        overlay.append("EXPECTED VALUE / EFFICIENCY\n");
        overlay.append("DISCARD\tEFFICIENCY + EV\n");
        foreach (TileEfficiencyResult result in last_results)
        {
            // Mark the single resolved winner of each ranking by identity.
            // Comparing on values instead tagged every tile that merely tied
            // the best figure, which collapsed the two columns together.
            string markers = "";
            string overlay_markers = "";
            if (result == best_ev)
            {
                markers += " · BEST EV";
                overlay_markers += " [EV]";
            }
            if (result == best_efficiency)
            {
                markers += " · BEST EFFICIENCY";
                overlay_markers += " [EFF]";
            }
            string displayed_plan = result.value_plan == "RIICHI PATH" ? "" :
                " · " + result.value_plan;
            message.append_printf("Discard %-5s -> shanten %d, ukeire %d, EV %.0f, plan %s [%s]%s\n",
                format_tile(result.tile_index), result.shanten, result.ukeire,
                result.expected_value, result.value_plan,
                format_indexes(result.improving_tiles), markers);
            overlay.append_printf("%s\tS%d / U%d · %.0f pts%s%s\n",
                format_tile_overlay(result.tile_index), result.shanten,
                result.ukeire, result.expected_value, displayed_plan, overlay_markers);
        }
        message.append(defense_message.str);
        overlay.append(defense_overlay.str);
        // The acronym key sits at the very bottom of the panel, all one size.
        overlay.append("LEGEND\n");
        overlay.append("S = shanten · U = ukeire · EV = probability-weighted points\n");
        overlay.append("Damaten minimum: 5200 points (7700 as dealer) on every live ron wait\n");
        Environment.log(LogType.GAME, "TileEfficiency", message.str);
        return overlay.str;
    }

    public static void log_discard(TileType tile_type)
    {
        if (!enabled || !singleplayer_session || last_results == null)
            return;

        int index = to_trainer_index(tile_type);
        TileEfficiencyResult? best_result = null;
        TileEfficiencyResult? chosen = null;
        foreach (TileEfficiencyResult result in last_results)
        {
            if (best_result == null || result.shanten < best_result.shanten ||
                (result.shanten == best_result.shanten &&
                    result.expected_value > best_result.expected_value) ||
                (result.shanten == best_result.shanten &&
                    result.expected_value == best_result.expected_value &&
                    result.ukeire > best_result.ukeire))
                best_result = result;
            if (result.tile_index == index)
                chosen = result;
        }

        if (chosen != null && best_result != null)
        {
            string verdict = chosen.shanten == best_result.shanten &&
                chosen.expected_value == best_result.expected_value &&
                chosen.ukeire == best_result.ukeire ? "optimal" : "suboptimal";
            Environment.log(LogType.GAME, "TileEfficiency",
                "Chosen discard %s: %s (S%d/U%d, EV %.0f, %s; best S%d/U%d EV %.0f)".printf(
                    format_tile(index), verdict, chosen.shanten, chosen.ukeire,
                    chosen.expected_value, chosen.value_plan,
                    best_result.shanten, best_result.ukeire,
                    best_result.expected_value));
        }
        if (last_safety != null)
        {
            double rating = last_safety[index];
            string verdict = rating == last_best_safety ? "safest" : "not the safest";
            Environment.log(LogType.GAME, "DefensivePlay",
                "Chosen discard %s: %s (safety %.1f, best %.1f; %s)".printf(
                    format_tile(index), verdict, rating, last_best_safety,
                    safety_explanation((int)Math.floor(rating))));
        }
        last_results = null;
        last_safety = null;
    }

    public static string? recommended_action()
    {
        return last_action_recommendation;
    }

    public static int recommended_action_tile_1_ID()
    {
        return last_action_tile_1_ID;
    }

    public static int recommended_action_tile_2_ID()
    {
        return last_action_tile_2_ID;
    }

    public static bool recommends_riichi(Tile tile)
    {
        if (last_results != null)
            foreach (TileEfficiencyResult result in last_results)
                if (result.tile_index == to_trainer_index(tile.tile_type))
                    return result.recommend_riichi;
        return last_riichi_discard_index >= 0 &&
            to_trainer_index(tile.tile_type) == last_riichi_discard_index;
    }

    // Return a legal tenpai discard only when every live ron wait already
    // has a real yaku (dora alone does not qualify) and clears the conventional
    // damaten value threshold. This is independent of guide visibility so the
    // shared CPU uses the same riichi/damaten policy in every executable.
    public static Tile? qualifying_damaten_discard(RoundState state,
        ArrayList<Tile> tenpai_discards)
    {
        Tile? best_discard = null;
        int best_minimum = -1;
        int[] remaining = remaining_counts(state);
        int required_points = state.self.index == state.dealer ?
            DEALER_DAMATEN_MIN_POINTS : DAMATEN_MIN_POINTS;

        foreach (Tile discard in tenpai_discards)
        {
            ArrayList<Tile> concealed = new ArrayList<Tile>();
            concealed.add_all(state.self.hand);
            concealed.remove(discard);

            bool has_wait = false;
            bool every_wait_legal = true;
            int minimum_points = int.MAX;
            for (int type_value = (int)TileType.MAN1;
                type_value <= (int)TileType.CHUN; type_value++)
            {
                Tile wait = new Tile(-2000 - type_value,
                    (TileType)type_value, false);
                if (!TileRules.can_win_with(concealed, state.self.calls, wait))
                    continue;
                if (remaining[to_trainer_index(wait.tile_type)] <= 0)
                    continue;

                has_wait = true;
                int points = legal_points(state.advisory_score(concealed,
                    state.self.calls, wait, true, false));
                if (points == 0)
                {
                    every_wait_legal = false;
                    break;
                }
                minimum_points = int.min(minimum_points, points);
            }

            if (has_wait && every_wait_legal &&
                minimum_points >= required_points &&
                minimum_points > best_minimum)
            {
                best_discard = discard;
                best_minimum = minimum_points;
            }
        }
        return best_discard;
    }

    // Return an actual legal tile instance, not merely a tile type. Without a
    // threat, autoplay maximizes EV directly. Against riichi, the 0-15 safety
    // rating acts as a conservative survival proxy and discounts both winning
    // value and an estimated 8000-point deal-in exposure. Shape breaks ties.
    public static Tile? recommended_discard(ArrayList<Tile> legal_tiles)
    {
        Tile? best_tile = null;
        double best_utility = -double.MAX;
        int best_shanten = 99;
        int best_ukeire = -1;
        double best_expected_value = -1;
        bool defensive = last_safety != null;

        foreach (Tile tile in legal_tiles)
        {
            int index = to_trainer_index(tile.tile_type);
            double safety = defensive ? last_safety[index] : 0;
            int shanten = 99;
            int ukeire = -1;
            double expected_value = 0;
            if (last_results != null)
                foreach (TileEfficiencyResult result in last_results)
                    if (result.tile_index == index)
                    {
                        shanten = result.shanten;
                        ukeire = result.ukeire;
                        expected_value = result.expected_value;
                        break;
                    }

            double utility = expected_value;
            if (defensive)
            {
                double survival = double.max(0, double.min(1, safety / 15.0));
                utility = expected_value * survival -
                    (1 - survival) * DEFENSIVE_DEAL_IN_EXPOSURE;
            }
            bool better = best_tile == null || utility > best_utility ||
                (utility == best_utility &&
                    (expected_value > best_expected_value ||
                        (expected_value == best_expected_value &&
                            (shanten < best_shanten ||
                                (shanten == best_shanten &&
                                    ukeire > best_ukeire)))));

            if (better)
            {
                best_tile = tile;
                best_utility = utility;
                best_shanten = shanten;
                best_ukeire = ukeire;
                best_expected_value = expected_value;
            }
        }
        return best_tile;
    }

    private static void append_defense_analysis(RoundState state, int[] hand, int[] remaining,
        StringBuilder log_message, StringBuilder window_message)
    {
        int riichi_count = 0;
        double[] safety = new double[38];

        for (int player_index = 0; player_index < 4; player_index++)
        {
            RoundStatePlayer opponent = state.get_player(player_index);
            if (opponent.index == state.self.index || !opponent.in_riichi || opponent.riichi_tile == null)
                continue;

            riichi_count++;
            ArrayList<int> discards = tile_indexes(opponent.pond);
            ArrayList<int> passed_tiles = tile_indexes(opponent.post_riichi_discards);
            int riichi_tile = to_trainer_index(opponent.riichi_tile.tile_type);
            int[] opponent_safety = evaluate_safety(hand, discards, remaining, passed_tiles, riichi_tile);
            for (int i = 1; i < safety.length; i++)
                safety[i] += opponent_safety[i];
        }

        window_message.append("\nDEFENSIVE PLAY\n");
        if (riichi_count == 0)
        {
            window_message.append("No opponent has declared riichi.\n");
            last_safety = null;
            return;
        }

        for (int i = 1; i < safety.length; i++)
            safety[i] /= riichi_count;

        double best = 0;
        for (int i = 1; i < hand.length; i++)
            if (hand[i] > 0)
                best = double.max(best, safety[i]);

        string opponents = riichi_count == 1 ? "opponent" : "opponents";
        window_message.append_printf("Average safety vs %d riichi %s (15 = safest)\n", riichi_count, opponents);
        log_message.append_printf("Defensive safety vs %d riichi %s\n", riichi_count, opponents);
        // Tab-separated so the overlay renders the safety ranking as a gridded
        // two-column table, matching the efficiency guide above it.
        window_message.append("DISCARD\tSAFETY\n");

        // Safest first, so the tiles to reach for are at the top of the table.
        ArrayList<int> order = new ArrayList<int>();
        for (int i = 1; i < hand.length; i++)
            if (hand[i] > 0 && i % 10 != 0)
                order.add(i);
        order.sort((a, b) => {
            if (safety[a] != safety[b])
                return safety[a] > safety[b] ? -1 : 1;
            return a - b;
        });

        foreach (int i in order)
        {
            string best_marker = safety[i] == best ? " SAFEST" : "";
            string explanation = safety_explanation((int)Math.floor(safety[i]));
            // Whole-number score; tokens are kept short so the narrow SAFETY
            // column wraps them onto their own lines.
            window_message.append_printf("%s\t%.0f %s%s\n",
                format_tile_overlay(i), safety[i], explanation, best_marker);
            log_message.append_printf("Discard %-5s -> safety %.1f (%s)%s\n",
                format_tile(i), safety[i], explanation, best_marker);
        }

        last_safety = safety;
        last_best_safety = best;
    }

    private static int[] evaluate_safety(int[] hand, ArrayList<int> opponent_discards, int[] remaining,
        ArrayList<int> passed_tiles, int riichi_tile)
    {
        int[] ratings = new int[38];

        for (int i = 1; i < hand.length; i++)
        {
            if (hand[i] <= 0 || i % 10 == 0)
                continue;

            if (opponent_discards.contains(i) || passed_tiles.contains(i))
            {
                ratings[i] = 15;
                continue;
            }

            if (i < 30 && (i % 10 == 1 || i % 10 == 9))
            {
                ratings[i] = is_suji(i, opponent_discards, remaining, riichi_tile) ? 14 - remaining[i] : 5;
                continue;
            }

            if (i > 30)
            {
                switch (remaining[i])
                {
                case 0: ratings[i] = 14; break;
                case 1: ratings[i] = 13; break;
                case 2: ratings[i] = 10; break;
                default: ratings[i] = 6; break;
                }
                continue;
            }

            bool suji = is_suji(i, opponent_discards, remaining, riichi_tile);
            switch (i % 10)
            {
            case 4:
            case 5:
            case 6:
                ratings[i] = suji ? 9 : 1;
                break;
            case 2:
            case 8:
                ratings[i] = suji ? 8 : 3;
                break;
            default:
                ratings[i] = suji ? 7 : 2;
                break;
            }
        }

        return ratings;
    }

    private static bool is_suji(int tile, ArrayList<int> discards, int[] remaining, int riichi_tile)
    {
        int suit_start = (tile / 10) * 10;
        int lower = tile - 3;
        int upper = tile + 3;
        bool lower_passed = lower < suit_start + 1;
        bool upper_passed = upper > suit_start + 9;

        if (!lower_passed)
        {
            if (lower == riichi_tile)
                return false;
            lower_passed = discards.contains(lower) || remaining[lower + 1] == 0 || remaining[lower + 2] == 0;
        }

        if (!upper_passed)
        {
            if (upper == riichi_tile)
                return false;
            upper_passed = discards.contains(upper) || remaining[upper - 1] == 0 || remaining[upper - 2] == 0;
        }

        return lower_passed && upper_passed;
    }

    private static ArrayList<int> tile_indexes(ArrayList<Tile> tiles)
    {
        ArrayList<int> indexes = new ArrayList<int>();
        foreach (Tile tile in tiles)
            indexes.add(to_trainer_index(tile.tile_type));
        return indexes;
    }

    private static string safety_explanation(int rating)
    {
        switch (rating)
        {
        case 1: return "non-suji 4/5/6";
        case 2: return "non-suji 3/7";
        case 3: return "non-suji 2/8";
        case 4: return "one-chance";
        case 5: return "non-suji terminal";
        case 6: return "first honor";
        case 7: return "suji 3/7";
        case 8: return "suji 2/8";
        case 9: return "suji 4/5/6";
        case 10: return "second honor";
        case 11: return "first suji terminal";
        case 12: return "second suji terminal";
        case 13: return "third terminal / honor";
        case 14: return "fourth terminal / honor";
        case 15: return "genbutsu";
        default: return "unknown";
        }
    }

    private static int[] hand_counts(ArrayList<Tile> tiles)
    {
        int[] counts = new int[38];
        foreach (Tile tile in tiles)
            counts[to_trainer_index(tile.tile_type)]++;
        return counts;
    }

    private static int[] remaining_counts(RoundState state)
    {
        int[] remaining = new int[38];
        for (int i = 1; i < remaining.length; i++)
            if (i % 10 != 0)
                remaining[i] = 4;
        foreach (Tile tile in state.get_tiles())
        {
            if (tile.tile_type == TileType.BLANK)
                continue;
            int index = to_trainer_index(tile.tile_type);
            remaining[index] = int.max(0, remaining[index] - 1);
        }
        return remaining;
    }

    private static int[] copy_action_counts(int[] source)
    {
        int[] copy = new int[source.length];
        for (int i = 0; i < source.length; i++)
            copy[i] = source[i];
        return copy;
    }

    private static PostCallQuality best_post_call_quality(RoundState state,
        TileEfficiencyCalculator calculator, int[] called_hand, int[] remaining,
        ArrayList<RoundStateCall> calls)
    {
        PostCallQuality best = new PostCallQuality();
        ArrayList<TileEfficiencyResult> results = calculator.calculate(
            called_hand, remaining);
        foreach (TileEfficiencyResult result in results)
        {
            int[] after_discard = copy_action_counts(called_hand);
            after_discard[result.tile_index]--;
            ArrayList<Tile> concealed = counts_to_tiles(after_discard);
            ExpectedValueAssessment value = assess_shape_value(state, result,
                remaining, concealed, calls, false);
            // Once in tenpai, use exact wait scoring: a general shape heuristic
            // must not promote a call if any live wait still has no yaku.
            bool yaku_path = result.shanten == 0 ? value.yaku_met :
                has_open_yaku_path(state, concealed, calls);

            bool better = result.shanten < best.shanten ||
                (result.shanten == best.shanten &&
                    value.expected_value > best.expected_value) ||
                (result.shanten == best.shanten &&
                    value.expected_value == best.expected_value &&
                    result.ukeire > best.ukeire);
            if (better)
            {
                best.shanten = result.shanten;
                best.ukeire = result.ukeire;
                best.expected_value = value.expected_value;
                best.yaku_path = yaku_path;
                best.value_plan = yaku_path ? value.plan : "NO CONFIRMED YAKU";
            }
        }
        return best;
    }

    private static ExpectedValueAssessment assess_discard_value(RoundState state,
        TileEfficiencyResult result, int[] remaining,
        ArrayList<RoundStateCall> calls, bool can_riichi)
    {
        ArrayList<Tile> concealed = hand_without_index(
            state.self.hand, result.tile_index);
        return assess_shape_value(state, result, remaining, concealed, calls,
            can_riichi);
    }

    private static ExpectedValueAssessment assess_shape_value(RoundState state,
        TileEfficiencyResult result, int[] remaining,
        ArrayList<Tile> concealed, ArrayList<RoundStateCall> calls,
        bool can_riichi)
    {
        if (result.shanten == 0)
            return assess_tenpai_value(state, result.improving_tiles,
                remaining, concealed, calls, can_riichi);

        ExpectedValueAssessment value = new ExpectedValueAssessment();
        bool closed = is_closed_hand(calls);
        bool yaku_path = closed || has_open_yaku_path(state, concealed, calls);
        value.yaku_met = yaku_path;
        if (!yaku_path)
        {
            value.plan = "YAKU NEEDED";
            return value;
        }

        int unseen = count_remaining(remaining);
        int draws = int.max(1, (state.wall_tiles_remaining + 3) / 4);
        double improve_rate = unseen > 0 ?
            double.min(1, (double)result.ukeire / unseen) : 0;
        double improve_probability = 1 - Math.pow(1 - improve_rate, draws);
        double completion_probability = Math.pow(improve_probability,
            result.shanten + 1);
        double projected_points = closed ?
            (state.self.index == state.dealer ? 5800 : 3900) :
            (state.self.index == state.dealer ? 2900 : 2000);
        value.expected_value = completion_probability * projected_points;
        value.average_points = projected_points;
        value.plan = closed ? "RIICHI PATH" : "YAKU PATH";
        return value;
    }

    private static ExpectedValueAssessment assess_tenpai_value(RoundState state,
        ArrayList<int> waits, int[] remaining, ArrayList<Tile> concealed,
        ArrayList<RoundStateCall> calls, bool can_riichi)
    {
        ExpectedValueAssessment value = new ExpectedValueAssessment();
        int live_waits = 0;
        double dama_points = 0;
        double riichi_points = 0;
        bool every_dama_ron = true;
        bool any_dama_ron = false;
        bool any_dama_tsumo = false;
        int minimum_dama_ron = int.MAX;

        bool riichi_available = (can_riichi || state.self.in_riichi) &&
            is_closed_hand(calls);
        foreach (int wait in waits)
        {
            int copies = remaining[wait];
            if (copies <= 0)
                continue;

            Tile win_tile = new Tile(-1000 - wait, from_trainer_index(wait), false);
            Scoring dama_ron = state.advisory_score(
                concealed, calls, win_tile, true, false);
            Scoring dama_tsumo = state.advisory_score(
                concealed, calls, win_tile, false, false);
            int dama_ron_points = legal_points(dama_ron);
            int dama_tsumo_points = legal_points(dama_tsumo);
            if (dama_ron_points == 0)
                every_dama_ron = false;
            else
            {
                any_dama_ron = true;
                minimum_dama_ron = int.min(minimum_dama_ron,
                    dama_ron_points);
            }
            if (dama_tsumo_points > 0)
                any_dama_tsumo = true;
            dama_points += copies * (0.65 * dama_ron_points +
                0.35 * dama_tsumo_points);

            if (riichi_available)
            {
                Scoring riichi_ron = state.advisory_score(
                    concealed, calls, win_tile, true, true);
                Scoring riichi_tsumo = state.advisory_score(
                    concealed, calls, win_tile, false, true);
                riichi_points += copies * (0.65 * legal_points(riichi_ron) +
                    0.35 * legal_points(riichi_tsumo));
            }
            live_waits += copies;
        }

        if (live_waits == 0)
        {
            value.plan = "DEAD WAIT";
            return value;
        }

        dama_points /= live_waits;
        riichi_points /= live_waits;
        int dama_minimum = state.self.index == state.dealer ?
            DEALER_DAMATEN_MIN_POINTS : DAMATEN_MIN_POINTS;
        bool qualifying_damaten = every_dama_ron &&
            minimum_dama_ron >= dama_minimum;

        double selected_points;
        bool ron_available;
        if (state.self.in_riichi)
        {
            value.plan = "RIICHI";
            selected_points = riichi_points;
            ron_available = true;
            value.yaku_met = true;
        }
        else if (qualifying_damaten)
        {
            value.plan = "DAMATEN";
            selected_points = dama_points;
            ron_available = true;
            value.yaku_met = true;
        }
        else if (riichi_available)
        {
            value.plan = "RIICHI";
            selected_points = riichi_points;
            ron_available = true;
            value.yaku_met = true;
            value.recommend_riichi = true;
        }
        else if (every_dama_ron)
        {
            value.plan = is_closed_hand(calls) ? "DAMATEN" : "OPEN YAKU";
            selected_points = dama_points;
            ron_available = true;
            value.yaku_met = true;
        }
        else if (any_dama_ron)
        {
            // Some shapes only have yaku on a subset of waits. Preserve their
            // real point contribution in EV, but do not certify them as a safe
            // open-call route because another live wait is still yaku-less.
            value.plan = "PARTIAL YAKU";
            selected_points = dama_points;
            ron_available = true;
        }
        else if (any_dama_tsumo)
        {
            value.plan = "TSUMO ONLY";
            selected_points = dama_points;
            ron_available = false;
        }
        else
        {
            value.plan = "NO YAKU";
            return value;
        }

        int unseen = count_remaining(remaining);
        int draws = int.max(1, (state.wall_tiles_remaining + 3) / 4);
        double opportunities = draws * (ron_available ? 2.0 : 1.0);
        double hit_rate = unseen > 0 ?
            double.min(1, (double)live_waits / unseen) : 0;
        double win_probability = 1 - Math.pow(1 - hit_rate, opportunities);
        value.average_points = selected_points;
        value.expected_value = win_probability * selected_points;
        if (value.recommend_riichi)
            value.expected_value -= (1 - win_probability) * 1000;
        return value;
    }

    private static int legal_points(Scoring score)
    {
        if (!score.valid || !score.has_valid_yaku())
            return 0;
        return score.ron ? score.ron_points :
            score.tsumo_points_lower * 2 + score.tsumo_points_higher;
    }

    private static int count_remaining(int[] remaining)
    {
        int count = 0;
        for (int i = 1; i < remaining.length; i++)
            if (i % 10 != 0)
                count += remaining[i];
        return count;
    }

    private static bool is_closed_hand(ArrayList<RoundStateCall> calls)
    {
        foreach (RoundStateCall call in calls)
            if (call.call_type != RoundStateCall.CallType.CLOSED_KAN)
                return false;
        return true;
    }

    private static bool has_open_yaku_path(RoundState state,
        ArrayList<Tile> concealed, ArrayList<RoundStateCall> calls)
    {
        if (is_closed_hand(calls))
            return true;

        bool all_simples = true;
        bool terminals_and_honors = true;
        int suit = -1;
        bool one_suit = true;
        foreach (Tile tile in all_advisory_tiles(concealed, calls))
        {
            if (tile.is_honor_tile() || tile.is_terminal_tile())
                all_simples = false;
            else
                terminals_and_honors = false;
            if (!tile.is_honor_tile())
            {
                int tile_suit = ((int)tile.tile_type - 1) / 9;
                if (suit == -1)
                    suit = tile_suit;
                else if (suit != tile_suit)
                    one_suit = false;
            }
        }
        if (all_simples || terminals_and_honors || (one_suit && suit >= 0))
            return true;

        foreach (RoundStateCall call in calls)
        {
            if (call.call_type == RoundStateCall.CallType.CHII ||
                call.tiles.size < 3)
                continue;
            Tile tile = call.tiles[0];
            if (tile.is_dragon_tile() || tile.is_wind(state.self.wind) ||
                tile.is_wind(state.round_wind))
                return true;
        }
        return false;
    }

    private static ArrayList<Tile> all_advisory_tiles(ArrayList<Tile> concealed,
        ArrayList<RoundStateCall> calls)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add_all(concealed);
        foreach (RoundStateCall call in calls)
            tiles.add_all(call.tiles);
        return tiles;
    }

    private static ArrayList<Tile> hand_without_index(ArrayList<Tile> hand,
        int discard_index)
    {
        ArrayList<Tile> copy = new ArrayList<Tile>();
        bool removed = false;
        // Preserve red fives whenever a non-red copy of the same type exists.
        foreach (Tile tile in hand)
            if (!removed && !tile.dora &&
                to_trainer_index(tile.tile_type) == discard_index)
                removed = true;
            else
                copy.add(tile);
        if (!removed)
        {
            copy.clear();
            foreach (Tile tile in hand)
                if (!removed && to_trainer_index(tile.tile_type) == discard_index)
                    removed = true;
                else
                    copy.add(tile);
        }
        return copy;
    }

    private static ArrayList<Tile> counts_to_tiles(int[] counts)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        int id = -2000;
        for (int i = 1; i < counts.length; i++)
            if (i % 10 != 0)
                for (int count = 0; count < counts[i]; count++)
                    tiles.add(new Tile(id--, from_trainer_index(i), false));
        return tiles;
    }

    private static TileType from_trainer_index(int index)
    {
        if (index < 10)
            return (TileType)index;
        if (index < 20)
            return (TileType)(index - 1);
        if (index < 30)
            return (TileType)(index - 2);
        return (TileType)(index - 3);
    }

    private static ArrayList<Tile> matching_tiles(ArrayList<Tile> hand,
        TileType type, int count)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        foreach (Tile tile in hand)
            if (tile.tile_type == type && tiles.size < count)
                tiles.add(tile);
        return tiles;
    }

    private static ArrayList<RoundStateCall> calls_with(
        ArrayList<RoundStateCall> existing, RoundStateCall.CallType type,
        Tile incoming, ArrayList<Tile> from_hand)
    {
        ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();
        calls.add_all(existing);
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(incoming);
        tiles.add_all(from_hand);
        calls.add(new RoundStateCall(type, tiles, incoming, -1));
        return calls;
    }

    private static string format_chii_tiles(Tile incoming, ArrayList<Tile> group)
    {
        int[] indexes = {
            to_trainer_index(incoming.tile_type),
            to_trainer_index(group[0].tile_type),
            to_trainer_index(group[1].tile_type)
        };
        for (int i = 0; i < indexes.length; i++)
            for (int j = i + 1; j < indexes.length; j++)
                if (indexes[j] < indexes[i])
                {
                    int swap = indexes[i];
                    indexes[i] = indexes[j];
                    indexes[j] = swap;
                }
        return "%s %s %s".printf(format_tile_overlay(indexes[0]),
            format_tile_overlay(indexes[1]), format_tile_overlay(indexes[2]));
    }

    private static int to_trainer_index(TileType type)
    {
        int value = (int)type;
        if (value <= 9)
            return value;
        if (value <= 18)
            return value + 1;
        if (value <= 27)
            return value + 2;
        return value + 3;
    }

    private static string format_tile(int index)
    {
        if (index < 10)
            return "%dm".printf(index);
        if (index < 20)
            return "%dp".printf(index - 10);
        if (index < 30)
            return "%ds".printf(index - 20);
        return "%dz".printf(index - 30);
    }

    private static string format_tile_overlay(int index)
    {
        return tile_emoji(index);
    }

    private static string tile_emoji(int index)
    {
        string[] manzu = { "🀇", "🀈", "🀉", "🀊", "🀋", "🀌", "🀍", "🀎", "🀏" };
        string[] pinzu = { "🀙", "🀚", "🀛", "🀜", "🀝", "🀞", "🀟", "🀠", "🀡" };
        string[] souzu = { "🀐", "🀑", "🀒", "🀓", "🀔", "🀕", "🀖", "🀗", "🀘" };
        // MPSZ honor order: east, south, west, north, white, green, red.
        string[] honors = { "🀀", "🀁", "🀂", "🀃", "🀆", "🀅", "🀄" };

        if (index >= 1 && index <= 9)
            return manzu[index - 1];
        if (index >= 11 && index <= 19)
            return pinzu[index - 11];
        if (index >= 21 && index <= 29)
            return souzu[index - 21];
        if (index >= 31 && index <= 37)
            return honors[index - 31];
        return "?";
    }

    private static string format_indexes(ArrayList<int> indexes)
    {
        if (indexes.size == 0)
            return "none";
        StringBuilder text = new StringBuilder();
        foreach (int index in indexes)
        {
            if (text.len > 0)
                text.append(" ");
            text.append(format_tile(index));
        }
        return text.str;
    }

    private static string format_counts(int[] counts)
    {
        StringBuilder text = new StringBuilder();
        for (int suit = 0; suit < 4; suit++)
        {
            StringBuilder values = new StringBuilder();
            int start = suit < 3 ? suit * 10 + 1 : 31;
            int end = suit < 3 ? start + 9 : 38;
            for (int i = start; i < end; i++)
                for (int count = 0; count < counts[i]; count++)
                    values.append_printf("%d", i % 10);
            if (values.len > 0)
            {
                text.append(values.str);
                text.append(suit == 0 ? "m" : suit == 1 ? "p" : suit == 2 ? "s" : "z");
            }
        }
        return text.str;
    }
}
