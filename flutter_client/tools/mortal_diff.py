#!/usr/bin/env python3
"""Builds a browsable page of where the TileSense guide disagrees with Mortal.

Reads the position log that test/guide_vs_mortal_sim_test.dart writes when
MORTAL_POS=PREFIX is set (PREFIX.SHARD.jsonl, one decision per line) and writes
one self-contained HTML file: no server, no dependencies.

  python3 tools/mortal_diff.py 'PREFIX.*.jsonl' -o mortal_diff.html

The page has two tabs. "Patterns" tabulates every logged decision (so it is not
sampled); "Examples" lets you filter and open individual positions: the board,
the guide's EV lines beside Mortal's q-values, and a plain-language read of how
they differ. Only a sample of positions is embedded (the biggest q-gaps plus a
random slice of the rest), so the file stays a few MB.

Mortal's q-values are in its own units and only mean something within one
position. A disagreement is not a mistake either way: this page shows what
differs, and the simulation's hybrid arms say which differences cost placement.
"""
import argparse
import glob
import json
import random
import sys
from collections import Counter, defaultdict


def bare(t):
    return t[:-1] if t and t.endswith("r") else t


def tile_class(t):
    t = bare(t or "")
    if not t:
        return None
    if t[0] in "ESWNPFC":
        return "honor"
    n = int(t[0])
    return "terminal" if n in (1, 9) else "2/8" if n in (2, 8) else "3-7"


def junme_bucket(j):
    return "1-3" if j <= 3 else "4-6" if j <= 6 else "7-9" if j <= 9 else "10+"


def shanten_bucket(s):
    return str(s) if s <= 3 else "4+"


def lines_by_tile(rec):
    trace = rec["guide"].get("trace") or {}
    return {bare(l["d"]): l for l in trace.get("lines", [])}


def mortal_tile(rec):
    m = rec["mortal"]
    return m["riichiPai"] if m["type"] == "reach" else m["pai"] if m["type"] == "dahai" else None


def guide_tile(rec):
    g = rec["guide"]
    return g["pai"] if g["type"] in ("dahai", "reach") else None


def annotate(rec):
    """Chips that say, in the guide's own terms, how the two choices differ."""
    chips = []
    if rec["kind"] != "turn" or rec["diff"] != "discard":
        return chips
    trace = rec["guide"].get("trace") or {}
    lines = lines_by_tile(rec)
    g, m = lines.get(bare(guide_tile(rec) or "")), lines.get(bare(mortal_tile(rec) or ""))
    cur = trace.get("shanten")
    if g and cur is not None and g["shanten"] > cur:
        chips.append("guide steps back")
        if m and m["shanten"] < g["shanten"]:
            chips.append("Mortal keeps shanten")
    if g and trace.get("lines"):
        ties = sum(1 for l in trace["lines"] if abs(l["ev"] - g["ev"]) < 0.05)
        if ties >= 3:
            chips.append("guide EV tie ×%d" % min(ties, 99))
    if g and m and g["ukeire"] > m["ukeire"] and g["shanten"] > m["shanten"]:
        chips.append("guide trades shanten for ukeire")
    if m and g and m["ev"] < g["ev"] - 1:
        chips.append("guide EV ranks Mortal's cut lower")
    gc, mc = tile_class(guide_tile(rec)), tile_class(mortal_tile(rec))
    if mc in ("honor", "terminal") and gc in ("2/8", "3-7"):
        chips.append("Mortal cuts %s, guide a %s tile" % (mc, gc))
    if rec["state"]["riichiAt"][0] < 0 and any(r >= 0 for r in rec["state"]["riichiAt"][1:]):
        chips.append("opponent in riichi")
    return chips


def patterns(recs):
    """Tables over every logged decision."""
    out = {}
    turns = [r for r in recs if r["kind"] == "turn" and r["guide"]["type"] == "dahai"]
    discards = [r for r in turns if mortal_tile(r)]

    def rate(group_fn, pred, rows):
        d = defaultdict(lambda: [0, 0])
        for r in rows:
            k = group_fn(r)
            if k is None:
                continue
            d[k][0] += 1
            d[k][1] += 1 if pred(r) else 0
        order = ["1-3", "4-6", "7-9", "10+"]
        return {k: d[k] for k in sorted(d, key=lambda k: order.index(k) if k in order else -1)
                if k in d} if set(d) <= set(order) else {k: v for k, v in sorted(d.items())}

    def cur(r):
        return (r["guide"].get("trace") or {}).get("shanten")

    out["disagree_by_shanten"] = rate(
        lambda r: shanten_bucket(cur(r)) if cur(r) is not None else None,
        lambda r: r["diff"] == "discard",
        discards,
    )
    out["disagree_by_junme"] = rate(
        lambda r: junme_bucket(r["state"]["junme"] + 1),
        lambda r: r["diff"] == "discard",
        discards,
    )

    def steps_back(who):
        def pred(r):
            tile = guide_tile(r) if who == "guide" else mortal_tile(r)
            l = lines_by_tile(r).get(bare(tile or ""))
            return bool(l and cur(r) is not None and l["shanten"] > cur(r))

        return pred

    for who in ("guide", "mortal"):
        out["steps_back_" + who] = rate(
            lambda r: shanten_bucket(cur(r)) if cur(r) is not None else None,
            steps_back(who),
            discards,
        )

    def tie(r):
        lines = (r["guide"].get("trace") or {}).get("lines", [])
        return len(lines) >= 2 and abs(lines[0]["ev"] - lines[1]["ev"]) < 0.05

    out["ev_tie_top_two"] = rate(
        lambda r: shanten_bucket(cur(r)) if cur(r) is not None else None, tie, discards
    )

    conf = Counter()
    for r in discards:
        if r["diff"] == "discard":
            conf[(tile_class(guide_tile(r)), tile_class(mortal_tile(r)))] += 1
    out["tile_class"] = {"%s|%s" % k: v for k, v in sorted(conf.items())}

    chips = Counter()
    for r in discards:
        if r["diff"] == "discard":
            for c in annotate(r):
                chips[c.split(" ×")[0]] += 1
    out["chips"] = dict(chips.most_common())

    gaps = [r["gap"] for r in discards if r.get("gap") is not None]
    out["gap"] = {
        "n": len(gaps),
        "mean": sum(gaps) / len(gaps) if gaps else 0,
        "calm": [r["gap"] for r in discards if r.get("gap") is not None
                 and not any(x >= 0 for x in r["state"]["riichiAt"][1:])],
    }
    out["gap"]["calm_mean"] = (
        sum(out["gap"]["calm"]) / len(out["gap"]["calm"]) if out["gap"]["calm"] else 0
    )
    del out["gap"]["calm"]

    out["kinds"] = {"%s|%s" % k: v for k, v in Counter((r["kind"], r["diff"]) for r in recs).items()}
    out["total"] = len(recs)
    return out


def pick_examples(recs, n, seed=1):
    rng = random.Random(seed)
    dis = [r for r in recs if r["diff"] != "none"]
    dis.sort(key=lambda r: -(r.get("gap") or 0))
    top = dis[: n // 2]
    rest = dis[n // 2:]
    rng.shuffle(rest)
    # Keep the rarer kinds visible even when the biggest gaps are all discards.
    rare = [r for r in rest if r["diff"] in ("riichi", "kan", "call")][: n // 4]
    seen = {id(r) for r in top} | {id(r) for r in rare}
    fill = [r for r in rest if id(r) not in seen][: n - len(top) - len(rare)]
    agree = [r for r in recs if r["diff"] == "none"]
    rng.shuffle(agree)
    return top + rare + fill + agree[: n // 10]


def slim(rec):
    r = json.loads(json.dumps(rec))
    for l in (r["guide"].get("trace") or {}).get("lines", []):
        if not l.get("why"):
            l.pop("why", None)
    r["chips"] = annotate(rec)
    return r


TEMPLATE = open(__file__.replace("mortal_diff.py", "mortal_diff.html"), encoding="utf-8").read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pattern", help="glob of PREFIX.SHARD.jsonl files")
    ap.add_argument("-o", "--out", default="mortal_diff.html")
    ap.add_argument("-n", "--examples", type=int, default=1500)
    args = ap.parse_args()

    recs = []
    for path in sorted(glob.glob(args.pattern)):
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    recs.append(json.loads(line))
                except ValueError:
                    pass  # the last line of a log still being written
    if not recs:
        sys.exit("no records match %r" % args.pattern)

    data = {
        "patterns": patterns(recs),
        "examples": [slim(r) for r in pick_examples(recs, args.examples)],
        "games": len({r["seed"] for r in recs}),
    }
    blob = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(TEMPLATE.replace("/*DATA*/null", blob))
    print("%d decisions from %d games; %d examples embedded -> %s"
          % (len(recs), data["games"], len(data["examples"]), args.out))


if __name__ == "__main__":
    main()
