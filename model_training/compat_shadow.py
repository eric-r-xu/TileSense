"""Measure independent components against frozen oracle frames, without fallback."""

import argparse
from collections import Counter
import json
from pathlib import Path

import numpy as np

from nagomi_compat.actions import decode
from nagomi_compat.observation import encode
from nagomi_compat.legality import legal_mask
from nagomi_compat.runtime import NagomiRuntime
from nagomi_compat.state import VisibleState
from .audit import ROOT, sha256


def canonical(reaction):
    if reaction is None:
        return None
    result = {key: value for key, value in reaction.items() if key != 'meta'}
    if 'consumed' in result:
        result['consumed'] = sorted(result['consumed'])
    return result


def run(corpus):
    manifest = json.loads((corpus / 'manifest.json').read_text())
    if (sha256(corpus / 'frames.npz') != manifest['frames_sha256']
            or sha256(corpus / 'cases.jsonl') != manifest['cases_sha256']):
        raise ValueError('reference fixture checksum mismatch')
    runtime = NagomiRuntime(ROOT / 'mortal_sidecar/mortal_nagomi.onnx')
    with np.load(corpus / 'frames.npz', allow_pickle=False) as source:
        obs, masks, reference_q = source['obs'], source['mask'], source['q']
    cases = [json.loads(line) for line in (corpus / 'cases.jsonl').read_text().splitlines()]
    if len(cases) != len(obs) or len(cases) != manifest['cases']:
        raise ValueError('fixture count mismatch')
    runtime_actions = runtime_equal = 0
    max_q_difference = 0.0
    for begin in range(0, len(obs), 32):
        q = runtime.score(obs[begin:begin + 32], masks[begin:begin + 32])
        expected = reference_q[begin:begin + 32]
        mask = masks[begin:begin + 32]
        runtime_equal += int(np.all(np.isclose(q, expected, rtol=1e-4, atol=1e-5) | ~mask, axis=1).sum())
        runtime_actions += int((q.argmax(-1) == expected.argmax(-1)).sum())
        max_q_difference = max(max_q_difference, float(np.abs(q[mask] - expected[mask]).max()))
    row_compared, row_mismatch = Counter(), Counter()
    decoder_counts, decoder_matches, failures = Counter(), Counter(), Counter()
    missing = Counter()
    complete = 0
    independent_masks = independent_mask_matches = 0
    max_feature_difference = 0.0
    for case, expected in zip(cases, obs):
        state = VisibleState(case['seat'])
        for event in case['prefix']:
            state.apply(event)
        observation = encode(state, at_kan_select=case['kan_select'])
        own_mask = legal_mask(state, case['kan_select'])
        independent_masks += 1
        independent_mask_matches += int(np.array_equal(own_mask, masks[case['case']]))
        known = observation.known_rows
        for row in np.flatnonzero(known):
            row_compared[int(row)] += 1
        differences = np.abs(observation.values - expected)
        bad = known & np.any(differences > 1e-7, axis=1)
        for row in np.flatnonzero(bad):
            row_mismatch[int(row)] += 1
        max_feature_difference = max(max_feature_difference, float(differences[known].max()))
        missing.update(observation.missing_groups)
        complete += int(known.all())
        if case['kan_select']:
            continue
        kind = case['kind']
        decoder_counts[kind] += 1
        try:
            reaction = decode(case['argmax'], state)
            decoder_matches[kind] += canonical(reaction) == canonical(case['reference']['reaction'])
        except ValueError as error:
            failures[str(error)] += 1
    return {'scope': 'component parity, not independent end-to-end policy parity',
            'model_sha256': manifest['model_sha256'], 'reference_cases': len(cases),
            'frames_sha256': manifest['frames_sha256'], 'cases_sha256': manifest['cases_sha256'],
            'implementation_sha256': {path.name: sha256(path) for path in sorted((ROOT / 'nagomi_compat').glob('*.py'))},
            'reference_games': len(manifest['games']), 'case_kinds': manifest['by_kind'],
            'runtime_with_oracle_inputs': {'same_action_fraction': runtime_actions / len(cases),
                                         'q_close_cases': runtime_equal, 'max_legal_q_difference': max_q_difference},
            'independent_features': {'implemented_rows': len(row_compared),
                                     'row_case_comparisons': sum(row_compared.values()),
                                     'row_case_mismatches': sum(row_mismatch.values()),
                                     'mismatches_by_row': dict(sorted(row_mismatch.items())),
                                     'max_abs_difference': max_feature_difference,
                                     'complete_observation_cases': complete,
                                     'missing_groups': dict(missing)},
            'independent_masks': {'compared': independent_masks, 'exact_matches': independent_mask_matches},
            'decoder_given_oracle_argmax': {kind: {'cases': n, 'semantic_matches': decoder_matches[kind]}
                                            for kind, n in sorted(decoder_counts.items())},
            'decoder_failures': dict(failures),
            'migration_ready': False,
            'remaining': ['probability/EV observation planes 889–890 and 961–1011',
                          'independent win guard', 'full reaction and riichi/kan-chain parity'],
            'limitations': ['runtime parity uses oracle observations/masks; not a migrated feature pipeline',
                            'decoder uses oracle argmax; win guard and chained reactions are not exercised',
                            'consumed tile order is normalized; tile identity/redness is retained',
                            'only Nagomi four-player hanchan fixtures captured; not sanma or East-only']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--corpus', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    report = run(args.corpus)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
