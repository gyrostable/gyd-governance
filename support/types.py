from typing import NamedTuple


class LimitUpgradeabilityParams(NamedTuple):
    action_level_threshold: int
    ema_threshold: int
    min_bgyd_supply: int
    tier_strategy: str


class StrategyConfig(NamedTuple):
    contract: str
    sig: str
    strategy: str
