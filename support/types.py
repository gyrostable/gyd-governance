from typing import List, NamedTuple


class LimitUpgradeabilityParams(NamedTuple):
    action_level_threshold: int
    ema_threshold: int
    min_bgyd_supply: int
    tier_strategy: str


class StrategyConfig(NamedTuple):
    contract: str
    sig: str
    strategy: str


class VaultWeightConfiguration(NamedTuple):
    vault_address: str
    initial_weight: int
    target_weight: int


class VaultWeightSchedule(NamedTuple):
    vaults: List[VaultWeightConfiguration]
    starts_at: int
    ends_at: int
