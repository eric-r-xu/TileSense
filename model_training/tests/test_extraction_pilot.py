import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

import numpy as np
import torch

from model_training.audit import sha256
from model_training.cache import iter_batches, load_shard
from model_training.checkpoint import load_checkpoint, save_checkpoint
from model_training.data import resolve_label
from model_training.model import INPUT_NAMES, ModelConfig, build_model


def cans(**updates):
    return SimpleNamespace(**{'can_pass': True, 'can_chi': False, 'can_pon': False,
                             'can_daiminkan': False, 'can_ryukyoku': False, **updates})


class OutcomeLabelTests(unittest.TestCase):
    def test_multiple_announcements_do_not_become_policy_inputs(self):
        events = [{'type': 'tsumo', 'actor': 0, 'pai': '1p'},
                  {'type': 'dora', 'dora_marker': '2p'},
                  {'type': 'reach_accepted', 'actor': 1}, {'type': 'reach', 'actor': 0}]
        self.assertEqual(resolve_label(events, 0, 0, cans()), (37, 3, 'self_action'))

    def test_multiple_ron_labels_all_observed_winners(self):
        events = [{'type': 'dahai', 'actor': 2}, {'type': 'hora', 'actor': 1},
                  {'type': 'hora', 'actor': 0}, {'type': 'end_kyoku'}]
        self.assertEqual(resolve_label(events, 0, 0, cans()), (43, 2, 'win'))
        self.assertEqual(resolve_label(events, 0, 1, cans()), (43, 1, 'win'))
        self.assertIsNone(resolve_label(events, 0, 3, cans())[0])

    def test_lost_chi_is_censored_instead_of_labeled_pass(self):
        events = [{'type': 'dahai', 'actor': 0},
                  {'type': 'pon', 'actor': 2, 'target': 0, 'pai': '1p', 'consumed': ['1p', '1p']}]
        self.assertEqual(resolve_label(events, 0, 1, cans(can_chi=True)),
                         (None, 1, 'censored_lower_priority_call'))

    def test_observed_chi_proves_higher_priority_call_was_declined(self):
        events = [{'type': 'dahai', 'actor': 0},
                  {'type': 'chi', 'actor': 1, 'target': 0, 'pai': '1p', 'consumed': ['2p', '3p']}]
        self.assertEqual(resolve_label(events, 0, 2, cans(can_pon=True)),
                         (45, 1, 'declined_higher_priority_call'))

    def test_quiet_continuation_is_pass_but_terminal_interruption_is_not(self):
        events = [{'type': 'dahai', 'actor': 0}, {'type': 'tsumo', 'actor': 1}]
        self.assertEqual(resolve_label(events, 0, 2, cans())[0], 45)
        events[1] = {'type': 'hora', 'actor': 1}
        self.assertIsNone(resolve_label(events, 0, 2, cans())[0])

    def test_abortive_draw_requires_the_engine_option(self):
        events = [{'type': 'tsumo', 'actor': 0}, {'type': 'ryukyoku'}]
        self.assertEqual(resolve_label(events, 0, 0, cans(can_ryukyoku=True))[0], 44)
        self.assertIsNone(resolve_label(events, 0, 0, cans())[0])


class StreamingTests(unittest.TestCase):
    def make_cache(self, root):
        shards = []
        for shard in range(3):
            count = 5
            tiles = np.zeros((count, 34, 20), dtype=np.float32)
            context = np.zeros((count, 40), dtype=np.float32)
            context[:, 0] = np.arange(shard * count, (shard + 1) * count)
            history = np.zeros((count, 128, 4), dtype=np.int64)
            history_mask = np.zeros((count, 128), dtype=np.bool_)
            mask = np.zeros((count, 46), dtype=np.bool_)
            mask[:, :2] = True
            path = root / f'{shard}.npz'
            np.savez_compressed(path, **dict(zip(INPUT_NAMES, (tiles, context, history, history_mask, mask))),
                                labels=np.arange(count, dtype=np.int64) % 2,
                                ranks=np.arange(count, dtype=np.int64) % 4)
            shards.append({'path': path.name, 'sha256': sha256(path), 'samples': count})
        return {'splits': {'train': {'shards': shards}}}

    def test_resume_cursor_preserves_exact_shuffled_order_across_epochs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = self.make_cache(root)
            full = list(iter_batches(root, manifest, 'train', 2, epochs=2))
            prefix = full[:4]
            remaining = list(iter_batches(root, manifest, 'train', 2,
                                           cursor=prefix[-1][1], epochs=2))
            expected = np.concatenate([arrays[1][:, 0] for arrays, _ in full])
            actual = np.concatenate([arrays[1][:, 0] for arrays, _ in prefix + remaining])
            np.testing.assert_array_equal(actual, expected)
            self.assertEqual(sorted(expected[:15].tolist()), list(range(15)))
            self.assertEqual(sorted(expected[15:].tolist()), list(range(15)))

    def test_tampered_shard_fails_before_numpy_load(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = self.make_cache(root)
            entry = manifest['splits']['train']['shards'][0]
            (root / entry['path']).write_bytes(b'not the frozen cache')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                load_shard(root, entry)

    def test_checkpoint_binds_cursor_and_optimizer_to_data_contract(self):
        config = ModelConfig('nagomi', width=32, layers=1, history_length=8)
        model = build_model(config)
        optimizer = torch.optim.AdamW(model.parameters())
        contract = {'data': 'frozen-cache-hash'}
        cursor = {'cursor': {'epoch': 1, 'shard': 2, 'row': 64}, 'examples': 500}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'resume.pth'
            save_checkpoint(path, model, optimizer, 10, contract, cursor)
            loaded = load_checkpoint(path, model, optimizer, expected_provenance=contract)
            self.assertEqual(loaded['trainer_state'], cursor)
            before = {name: value.clone() for name, value in model.state_dict().items()}
            with self.assertRaisesRegex(ValueError, 'training/data/source'):
                load_checkpoint(path, model, expected_provenance={'data': 'another-cache'})
            for name, value in model.state_dict().items():
                torch.testing.assert_close(value, before[name], rtol=0, atol=0)


if __name__ == '__main__':
    unittest.main()
