"""Fit the Hong Kong guide's win-probability model to self-play outcomes.

Input: the CSV written by test/hong_kong/hk_calibration_data_test.dart - one
row per discard the guide made, describing the hand it left (shanten, drawn
acceptance, pung and chow acceptance, live tiles, turns left) and whether that
hand went on to win.

This reimplements `_winProbabilityFromShanten` and `_winChanceOverTurns` from
lib/logic/efficiency_engine.dart line for line, vectorised, and fits the
`WinModel` constants by minimising log loss. Two fits are made:

  draws-only  pungRate = chowRate = 0, as riichi counts width
  calls       pungRate and chowRate fitted too

and both are compared with the model the guide currently ships. Run:

  python3 tools/fit_hk_win_model.py train.csv [holdout.csv] [--survive 0.955]

--survive pins survivesTurn instead of fitting it. The free fit tends to push
it to its bound and trade it off against the step widths.

Requires numpy and scipy (dev-time only).
"""
import sys

import numpy as np
from scipy.optimize import minimize

# The model the Hong Kong guide shipped with: riichi's constants, narrow
# penalty halved, draws only.
SHIPPED = dict(
    sw=[8, 20, 28, 35, 40, 44, 48],
    survive=0.955,
    inherit=0.5,
    narrow=0.5,
    win_chances=1.0,
    pung=0.0,
    chow=0.0,
    typical=[5, 14, 25, 43, 63, 73, 80],  # riichi's measured drawn ukeire
)


def load(path):
    data = np.genfromtxt(path, delimiter=",", names=True)
    return {k: data[k].astype(float) for k in data.dtype.names}


def width(d, m):
    return d["ukeire"] + m["pung"] * d["pung"] + m["chow"] * d["chow"]


def predict(d, m):
    """Win probability for every row under model m."""
    s = d["shanten"].astype(int)
    w = width(d, m)
    unseen = d["unseen"]
    draws = d["draws"].astype(int)
    p = np.zeros(len(s))

    # Ready hands: _winChanceOverTurns on the live wait.
    r = s == 0
    if r.any():
        rate = np.minimum(1.0, d["ukeire"][r] / np.maximum(unseen[r], 1))
        per = 1 - (1 - rate) ** m["win_chances"]
        alive = np.ones(r.sum())
        won = np.zeros(r.sum())
        dr = draws[r]
        for turn in range(dr.max() if len(dr) else 0):
            act = turn < dr
            won += np.where(act, alive * per, 0)
            alive = np.where(act, alive * (1 - per) * m["survive"], alive)
        p[r] = np.clip(won, 0, 1)

    # Hands short of ready: _winProbabilityFromShanten.
    for sh in range(1, int(s.max()) + 1):
        g = s == sh
        if not g.any():
            continue
        typical = m["typical"][min(sh, 6)]
        scale = w[g] / typical
        u = unseen[g]
        dg = draws[g]
        n = g.sum()
        chance = []
        for to in range(sh + 1):
            expo = m["inherit"] + (1 - m["inherit"]) * (to / sh)
            expo = np.where(scale < 1, expo * m["narrow"], expo)
            mult = np.minimum(1.0, np.power(np.maximum(scale, 1e-9), expo))
            stepw = m["sw"][min(to, 6)] * mult
            rate = np.minimum(1.0, stepw / np.maximum(u, 1))
            tries = m["win_chances"] if to == 0 else 1.0
            chance.append(1 - (1 - rate) ** tries)
        states = np.zeros((n, sh + 2))
        states[:, sh + 1] = 1
        won = np.zeros(n)
        for turn in range(dg.max()):
            act = (turn < dg)[:, None]
            nxt = np.zeros_like(states)
            for st in range(sh + 1, 0, -1):
                mass = states[:, st]
                pc = chance[st - 1]
                if st == 1:
                    won += np.where(act[:, 0], mass * pc, 0)
                else:
                    nxt[:, st - 1] += mass * pc
                nxt[:, st] += mass * (1 - pc)
            nxt *= m["survive"]
            states = np.where(act, nxt, states)
        p[g] = np.clip(won, 0, 1)
    # Rows whose width is zero cannot win in the model.
    p[(s >= 1) & (w <= 0)] = 0
    return p


def log_loss(p, y):
    p = np.clip(p, 1e-4, 1 - 1e-4)
    return float(-np.mean(y * np.log(p) + (1 - y) * np.log(1 - p)))


def with_typical(d, m):
    """Typical width per shanten measured from the data, in the model's units."""
    m = dict(m)
    w = width(d, m)
    s = d["shanten"].astype(int)
    typ = list(m["typical"])
    for sh in range(1, 7):
        g = s == sh
        if g.sum() >= 30:
            typ[sh] = float(w[g].mean())
    m["typical"] = typ
    return m


NAMES = ["sw0", "sw1", "sw2", "sw3", "sw4", "sw5", "sw6",
         "survive", "inherit", "narrow", "win_chances", "pung", "chow"]


def unpack(x, calls):
    m = dict(
        sw=list(x[0:7]), survive=x[7], inherit=x[8], narrow=x[9],
        win_chances=x[10], pung=x[11] if calls else 0.0,
        chow=x[12] if calls else 0.0, typical=SHIPPED["typical"])
    return m


def fit(d, calls, survive=None):
    y = d["won"]
    x0 = np.array(SHIPPED["sw"] + [SHIPPED["survive"], SHIPPED["inherit"],
                                   SHIPPED["narrow"], SHIPPED["win_chances"],
                                   0.5 if calls else 0.0,
                                   0.2 if calls else 0.0])
    if survive is not None:
        x0[7] = survive
    bounds = [(1, 200)] * 7 + [
        (survive, survive) if survive is not None else (0.85, 0.999),
        (0, 1), (0, 1.5), (0.3, 4),
                               (0, 3) if calls else (0, 0),
                               (0, 3) if calls else (0, 0)]

    def objective(x):
        m = with_typical(d, unpack(x, calls))
        return log_loss(predict(d, m), y)

    res = minimize(objective, x0, method="L-BFGS-B", bounds=bounds,
                   options=dict(maxiter=200))
    return with_typical(d, unpack(res.x, calls)), res.fun


def report(name, d, m):
    y = d["won"]
    p = predict(d, m)
    s = d["shanten"].astype(int)
    print(f"{name:12s} log loss {log_loss(p, y):.4f}   "
          f"brier {float(np.mean((p - y) ** 2)):.4f}")
    for sh in range(0, 6):
        g = s == sh
        if g.sum():
            print(f"    shanten {sh}: n={g.sum():6d}  actual {y[g].mean():.3f}"
                  f"  predicted {p[g].mean():.3f}")


def show(m):
    print("  stepWidth    ", [round(v, 2) for v in m["sw"]])
    print("  typicalWidth ", [round(v, 2) for v in m["typical"]])
    print(f"  survivesTurn {m['survive']:.4f}  waitInheritance "
          f"{m['inherit']:.3f}  narrowPenalty {m['narrow']:.3f}  "
          f"winChancesPerTurn {m['win_chances']:.3f}  pungRate "
          f"{m['pung']:.3f}  chowRate {m['chow']:.3f}")


def main():
    args = sys.argv[1:]
    survive = None
    if "--survive" in args:
        i = args.index("--survive")
        survive = float(args[i + 1])
        del args[i:i + 2]
    train = load(args[0])
    hold = load(args[1]) if len(args) > 1 else None
    print(f"train rows {len(train['won'])}, win rate {train['won'].mean():.3f}")
    draws_only, _ = fit(train, calls=False, survive=survive)
    calls, _ = fit(train, calls=True, survive=survive)
    for label, m in [("shipped", SHIPPED), ("draws-only", draws_only),
                     ("calls", calls)]:
        print(f"\n== {label}")
        show(m)
        report("train", train, m)
        if hold is not None:
            report("holdout", hold, m)


if __name__ == "__main__":
    main()
