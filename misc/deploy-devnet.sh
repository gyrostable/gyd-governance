#!/bin/sh

set -e

NETWORK=devnet

brownie run --network $NETWORK scripts/deployment/deploy_governance_manager.py proxy_admin
brownie run --network $NETWORK scripts/deployment/deploy_governance_manager.py proxy

# only for development
brownie run --network $NETWORK scripts/deployment/deploy_erc20_ema_wrapper.py dummy_erc20
# end

# only for development and testing
brownie run --network $NETWORK scripts/deployment/deploy_vaults mock
# end

brownie run --network $NETWORK scripts/deployment/deploy_erc20_ema_wrapper.py
brownie run --network $NETWORK scripts/deployment/deploy_voting_power_aggregator.py
brownie run --network $NETWORK scripts/deployment/deploy_tier_strategy.py upgradeability
brownie run --network $NETWORK scripts/deployment/deploy_tier_strategy.py static_medium_impact
brownie run --network $NETWORK scripts/deployment/deploy_tierer.py
brownie run --network $NETWORK scripts/deployment/deploy_governance_manager.py
