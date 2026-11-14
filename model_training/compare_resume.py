"""Check cursor and policy reproducibility after resuming an MPS pilot.

Imitation identifies relative action preferences, not the shared Q offset.
Compare normalized policy probabilities in addition to raw parameter differences.
"""

import argparse
import json
from pathlib import Path

import torch

from .audit import sha256
from .cache import iter_batches, load_manifest
from .model import ModelConfig, build_model


def compare(manifest_path, original, resumed):
    manifest = load_manifest(manifest_path)
    a = torch.load(original, weights_only=True, map_location='cpu')
    b = torch.load(resumed, weights_only=True, map_location='cpu')
    if (a['provenance'] != b['provenance'] or a['steps'] != b['steps']
            or a['trainer_state'] != b['trainer_state']
            or a['provenance']['manifest_sha256'] != sha256(manifest_path)):
        raise ValueError('resume data/progress/training contracts disagree')
    config = ModelConfig(**a['config'])
    left, right = build_model(config).eval(), build_model(config).eval()
    left.load_state_dict(a['model'])
    right.load_state_dict(b['model'])
    torch.set_num_threads(1)
    maximum_probability = maximum_centered_q = maximum_rank = 0.0
    count = same = 0
    with torch.no_grad():
        for arrays, _ in iter_batches(manifest_path.parent, manifest, 'val', 64):
            inputs = tuple(torch.from_numpy(value) for value in arrays[:5])
            q1, rank1 = left(*inputs)
            q2, rank2 = right(*inputs)
            mask = inputs[-1]
            center1 = q1.masked_fill(~mask, 0).sum(-1, keepdim=True) / mask.sum(-1, keepdim=True)
            center2 = q2.masked_fill(~mask, 0).sum(-1, keepdim=True) / mask.sum(-1, keepdim=True)
            maximum_probability = max(maximum_probability, float((q1.softmax(-1) - q2.softmax(-1)).abs().max()))
            maximum_centered_q = max(maximum_centered_q, float(((q1 - center1) - (q2 - center2))[mask].abs().max()))
            maximum_rank = max(maximum_rank, float((rank1 - rank2).abs().max()))
            count += len(q1)
            same += int((q1.argmax(-1) == q2.argmax(-1)).sum())
    maximum_weight = max(float((value - b['model'][name]).abs().max()) for name, value in a['model'].items())
    return {'steps': a['steps'], 'same_cursor_and_examples': True, 'same_provenance': True,
            'validation_decisions': count, 'same_action_fraction': same / count,
            'max_policy_probability_difference': maximum_probability,
            'max_centered_legal_q_difference': maximum_centered_q,
            'max_rank_logit_difference': maximum_rank, 'max_model_weight_difference': maximum_weight,
            'policy_probability_tolerance': 1e-4,
            'passed': same == count and maximum_probability < 1e-4,
            'limitation': 'MPS resume is not bit-exact. Imitation does not identify common Q offsets; '
                          'parameter equality is not the functional resume criterion.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--original', type=Path, required=True)
    parser.add_argument('--resumed', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    report = compare(args.manifest, args.original, args.resumed)
    with args.out.open('x') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
