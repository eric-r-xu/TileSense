"""Versioned multi-input networks for visible-state observations and fixtures."""

from dataclasses import asdict, dataclass

import torch
from torch import nn


@dataclass(frozen=True)
class ModelConfig:
    ruleset: str
    architecture_id: str = 'tilesense-hybrid-v0'
    observation_schema_id: str = 'tilesense-prototype-input-v0'
    action_schema_id: str = 'mjai-actions-v1'
    tile_features: int = 16
    context_features: int = 24
    history_length: int = 128
    width: int = 128
    layers: int = 2
    heads: int = 4

    def __post_init__(self):
        if self.ruleset not in ('sanma', 'nagomi'):
            raise ValueError('ruleset must be sanma or nagomi')
        if (self.architecture_id != 'tilesense-hybrid-v0'
                or self.observation_schema_id not in ('tilesense-prototype-input-v0', 'tilesense-visible-v1')
                or self.action_schema_id != 'mjai-actions-v1'):
            raise ValueError('unsupported model contract')
        if min(self.tile_features, self.context_features, self.history_length,
               self.width, self.layers, self.heads) <= 0 or self.width % self.heads:
            raise ValueError('dimensions must be positive and width divisible by heads')
        if self.observation_schema_id == 'tilesense-visible-v1' and (
                self.tile_features, self.context_features, self.history_length) != (20, 40, 128):
            raise ValueError('visible-v1 requires 20 tile features, 40 context features and 128 events')

    @classmethod
    def visible(cls, ruleset):
        return cls(ruleset, observation_schema_id='tilesense-visible-v1',
                   tile_features=20, context_features=40)

    @property
    def actions(self):
        return 47 if self.ruleset == 'sanma' else 46

    @property
    def players(self):
        return 3 if self.ruleset == 'sanma' else 4

    def to_dict(self):
        return asdict(self)


class AttentionBlock(nn.Module):
    """Explicit attention avoids dependence on platform-specific fused kernels."""

    def __init__(self, width, heads):
        super().__init__()
        self.heads = heads
        self.head_width = width // heads
        self.norm1 = nn.LayerNorm(width)
        self.qkv = nn.Linear(width, width * 3)
        self.projection = nn.Linear(width, width)
        self.norm2 = nn.LayerNorm(width)
        self.ff = nn.Sequential(nn.Linear(width, width * 2), nn.GELU(), nn.Linear(width * 2, width))

    def forward(self, x, valid):
        batch, length, width = x.shape
        qkv = self.qkv(self.norm1(x)).reshape(batch, length, 3, self.heads, self.head_width)
        q, k, v = qkv.permute(2, 0, 3, 1, 4).unbind(0)
        scores = (q @ k.transpose(-1, -2)) * self.head_width ** -0.5
        weights = scores.masked_fill(~valid[:, None, None, :], -1e4).softmax(-1)
        mixed = (weights @ v).transpose(1, 2).reshape(batch, length, width)
        x = x + self.projection(mixed)
        return x + self.ff(self.norm2(x))


class HybridModel(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.config = config
        width = config.width
        self.tile_identity = nn.Parameter(torch.empty(34, 8))
        nn.init.normal_(self.tile_identity, std=0.02)
        self.tiles = nn.Sequential(nn.Linear(34 * (config.tile_features + 8), width), nn.GELU())
        self.context = nn.Sequential(nn.Linear(config.context_features, width), nn.GELU())
        self.event_embeddings = nn.ModuleList(nn.Embedding(size, width) for size in (16, 5, 38, 8))
        self.positions = nn.Parameter(torch.empty(config.history_length, width))
        nn.init.normal_(self.positions, std=0.02)
        self.attention = nn.ModuleList(AttentionBlock(width, config.heads) for _ in range(config.layers))
        self.fusion = nn.Sequential(nn.Linear(width * 3, 256), nn.GELU(), nn.LayerNorm(256))
        self.value = nn.Linear(256, 1)
        self.advantage = nn.Linear(256, config.actions)
        self.rank = nn.Linear(256, config.players)

    def forward(self, tiles, context, history, history_mask, action_mask):
        identity = self.tile_identity.unsqueeze(0).expand(tiles.shape[0], -1, -1)
        tile_features = self.tiles(torch.cat((tiles, identity), dim=-1).flatten(1))
        sequence = self.positions.unsqueeze(0)
        for column, embedding in enumerate(self.event_embeddings):
            sequence = sequence + embedding(history[:, :, column])
        for block in self.attention:
            sequence = block(sequence, history_mask)
        valid = history_mask.unsqueeze(-1).to(sequence.dtype)
        pooled = (sequence * valid).sum(1) / valid.sum(1).clamp_min(1)
        phi = self.fusion(torch.cat((tile_features, self.context(context), pooled), dim=-1))
        advantage = self.advantage(phi)
        mean = (advantage * action_mask).sum(-1, keepdim=True) / action_mask.sum(-1, keepdim=True)
        q = (self.value(phi) + advantage - mean).masked_fill(~action_mask, -torch.inf)
        return q, self.rank(phi)


def build_model(config):
    return HybridModel(config)


INPUT_NAMES = ('tiles', 'context', 'history', 'history_mask', 'action_mask')


def synthetic_batch(config, batch_size, device='cpu'):
    """Synthetic contract fixture only; not a mahjong observation encoder."""
    tiles = torch.rand(batch_size, 34, config.tile_features, device=device)
    context = torch.rand(batch_size, config.context_features, device=device)
    columns = [torch.randint(0, size, (batch_size, config.history_length), device=device)
               for size in (16, config.players + 1, 38, 8)]
    history = torch.stack(columns, dim=-1)
    lengths = torch.randint(0, config.history_length + 1, (batch_size, 1), device=device)
    history_mask = torch.arange(config.history_length, device=device)[None] < lengths
    action_mask = torch.rand(batch_size, config.actions, device=device) > 0.5
    action_mask[:, 0] = True
    return tiles, context, history, history_mask, action_mask
