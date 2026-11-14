import gzip
import json
from pathlib import Path
import tempfile
import unittest

import torch

from model_training.audit import audit_dataset, game_identity
from model_training.checkpoint import load_checkpoint, save_checkpoint
from model_training.model import ModelConfig, build_model, synthetic_batch


class DataAuditTests(unittest.TestCase):
    def write_game(self, path, name='a', players=3):
        path.parent.mkdir(parents=True, exist_ok=True)
        events = [{'type': 'start_game', 'names': [name] * players},
                  {'type': 'start_kyoku', 'scores': [35000] * players, 'tehais': [[]] * players},
                  {'type': 'end_game'}]
        with gzip.open(path, 'wt') as output:
            for event in events:
                output.write(json.dumps(event) + '\n')

    def test_cross_split_duplicate_found_even_after_rename(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.write_game(root / 'train/one.json.gz')
            self.write_game(root / 'val/renamed.json.gz', name='different')
            result = audit_dataset(root, 3, root / 'manifest.jsonl')
            self.assertFalse(result['passed'])
            self.assertEqual(result['issues'][0]['kind'], 'gameplay')
            self.assertTrue(result['issues'][0]['cross_split'])

    def test_incompatible_ruleset_seat_count_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'game.json.gz'
            self.write_game(path)
            with self.assertRaisesRegex(ValueError, 'seats'):
                game_identity(path, 4)

    def test_empty_dataset_cannot_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            result = audit_dataset(root, 3, root / 'manifest.jsonl')
            self.assertFalse(result['passed'])
            self.assertEqual({i['split'] for i in result['issues']}, {'train', 'val'})


class ModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        torch.set_num_threads(1)

    def test_padding_does_not_change_outputs(self):
        config = ModelConfig('sanma', width=32, layers=1, history_length=8)
        model = build_model(config).eval()
        inputs = synthetic_batch(config, 2)
        inputs[3][:, 3:] = False
        altered = list(inputs)
        altered[2] = inputs[2].clone()
        altered[2][:, 3:] = 0
        with torch.no_grad():
            before = model(*inputs)
            after = model(*altered)
        for expected, actual in zip(before, after):
            torch.testing.assert_close(actual, expected)

    def test_empty_history_and_single_legal_action_have_finite_gradients(self):
        for ruleset in ('sanma', 'nagomi'):
            config = ModelConfig(ruleset, width=32, layers=1, history_length=8)
            model = build_model(config)
            inputs = synthetic_batch(config, 2)
            inputs[3][:] = False
            inputs[4][:] = False
            inputs[4][:, 0] = True
            q, rank = model(*inputs)
            self.assertTrue(torch.isfinite(q[:, 0]).all())
            self.assertTrue(torch.isneginf(q[:, 1:]).all())
            self.assertTrue(torch.isfinite(rank).all())
            (q[:, 0].square().mean() + rank.square().mean()).backward()
            self.assertTrue(all(torch.isfinite(p.grad).all() for p in model.parameters() if p.grad is not None))

    def test_checkpoint_rejects_another_ruleset_and_never_overwrites(self):
        model = build_model(ModelConfig('sanma', width=32, layers=1, history_length=8))
        optimizer = torch.optim.AdamW(model.parameters())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'checkpoint.pth'
            save_checkpoint(path, model, optimizer, 0, {'purpose': 'test'})
            other = build_model(ModelConfig('nagomi', width=32, layers=1, history_length=8))
            with self.assertRaisesRegex(ValueError, 'contract mismatch'):
                load_checkpoint(path, other)
            with self.assertRaises(FileExistsError):
                save_checkpoint(path, model, optimizer, 1, {})

    def test_checkpoint_restores_rng_streams(self):
        import random
        import numpy as np

        model = build_model(ModelConfig('sanma', width=32, layers=1, history_length=8))
        optimizer = torch.optim.AdamW(model.parameters())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'checkpoint.pth'
            save_checkpoint(path, model, optimizer, 0, {})
            expected = (random.random(), np.random.random(), torch.rand(3))
            load_checkpoint(path, model, optimizer, restore_rng=True)
            self.assertEqual(random.random(), expected[0])
            self.assertEqual(np.random.random(), expected[1])
            torch.testing.assert_close(torch.rand(3), expected[2], rtol=0, atol=0)


if __name__ == '__main__':
    unittest.main()
