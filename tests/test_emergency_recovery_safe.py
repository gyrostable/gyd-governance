import pytest
from brownie import (
    chain,
    reverts,
    NoSafeManagementByMultisig,
    SafeManagementModule,
    Contract,
)
from eip712.messages import EIP712Message
from eth_keys import keys
from eth_abi import encode
from eth_utils import function_signature_to_4byte_selector, keccak
from eth_account._utils.signing import sign_message_hash

ZERO_ADDR = "0x0000000000000000000000000000000000000000"
HEAD_ADDR = "0x0000000000000000000000000000000000000001"


@pytest.fixture()
def safe(admin, GnosisSafe, GnosisSafeProxy):
    singleton = admin.deploy(GnosisSafe)
    proxy = admin.deploy(GnosisSafeProxy, singleton)
    return Contract.from_abi("GnosisSafe", proxy.address, GnosisSafe.abi)


@pytest.fixture()
def signers(accounts):
    return [accounts.add() for i in range(3)]


def sign_and_execute_transaction(account, safe, address, value, data):
    nonce = safe.nonce()
    args = (
        safe.address,
        value,
        data,
        None,
        0,
        0,
        0,
        ZERO_ADDR,
        ZERO_ADDR,
    )
    message_hash = safe.getTransactionHash(
        *args,
        nonce,
        {"from": account.address},
    )
    pk = keys.PrivateKey(bytes.fromhex(account.private_key[2:]))
    (_, _, _, signature) = sign_message_hash(msg_hash=message_hash, key=pk)
    tx = safe.execTransaction(
        *args,
        signature,
        {"from": account.address},
    )
    return tx


@pytest.fixture()
def safe_without_guard(safe, local_account, signers):
    tx = safe.setup(
        [local_account.address, *[s.address for s in signers]],
        1,  # threshold
        ZERO_ADDR,  # optional
        b"",  # optional
        ZERO_ADDR,  # optional
        ZERO_ADDR,  # optional
        0,  # optional
        ZERO_ADDR,  # optional
        {"from": local_account},
    )

    module = local_account.deploy(
        SafeManagementModule, safe.address, local_account.address
    )

    enable_module_call = encode_call("enableModule", ["address"], [module.address])
    sign_and_execute_transaction(
        local_account, safe, safe.address, 0, enable_module_call
    )

    # Gnosis' API is... awkward... In order to allow constant time/gas updates of the safe
    # owners, the owners are modelled as a linked list. headOfOwners is the hardcoded
    # address to indicate the head of the list.
    headOfOwners = "0x0000000000000000000000000000000000000001"
    module.removeOwner(headOfOwners, local_account.address, 1)
    return safe, module


@pytest.fixture()
def configured_safe(safe_without_guard, signers):
    # The following encodes how to set up the Gnosis safe,
    # and will be useful as a guide for production.
    # The steps are:
    # - Configure the safe with the intended owners,
    # plus the address deploying the contract.
    # - Set the safe threshold to 1, to allow the deploying
    # address to set modules and guards.
    # - Deploy the module.
    # - Execute a safe transaction to enable the module, signing the
    # the payload with the private key of the deploying address
    # - Set the guard in the same way.
    # - From the module, call removeOwner to remove the deploying address
    # and set the threshold to the intended threshold. This will need to be executed
    # from the governance contract (i.e. via a governance proposal).
    safe, module = safe_without_guard
    guard = enable_guard(safe, module.address, signers[0])
    return safe, module, guard


def enable_guard(safe, module_address, signer):
    guard = signer.deploy(NoSafeManagementByMultisig, safe.address, module_address)

    set_guard_call = encode_call("setGuard", ["address"], [module_address])
    sign_and_execute_transaction(signer, safe, safe.address, 0, set_guard_call)
    return guard


def encode_call(function_name, types, values):
    typesStr = ",".join(types)
    fs = f"{function_name}({typesStr})"
    sel = function_signature_to_4byte_selector(fs)
    args = encode(types, values)
    return sel + args


def _test_guard(call, safe_without_guard, signers):
    safe, module = safe_without_guard

    # the call should succeed without the guard configured
    sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)

    enable_guard(safe, module.address, signers[0])

    # but should fail with the guard enabled
    with reverts():
        sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)


# NOTE: we can't use parametrization for the guard tests below since
# we need to generate the calldata based on some fixtures.


def test_guard_enableModule(safe_without_guard, signers):
    module_address = signers[0].address  # dummy address
    call = encode_call("enableModule", ["address"], [module_address])
    _test_guard(call, safe_without_guard, signers)


def test_guard_disableModule(safe_without_guard, signers):
    safe, module = safe_without_guard
    call = encode_call("disableModule", ["address"], [module.address])
    _test_guard(call, safe_without_guard, signers)


def test_guard_addOwnerWithThreshold(safe_without_guard, signers, admin):
    safe, module = safe_without_guard
    call = encode_call(
        "addOwnerWithThreshold",
        ["address", "uint256"],
        [admin.address, 1],
    )
    _test_guard(call, safe_without_guard, signers)


def test_guard_removeOwner(safe_without_guard, signers, admin):
    safe, module = safe_without_guard
    call = encode_call(
        "removeOwner",
        ["address", "address", "uint256"],
        [signers[1].address, signers[2].address, 1],
    )
    _test_guard(call, safe_without_guard, signers)


def test_guard_swapOwner(safe_without_guard, signers, admin):
    safe, module = safe_without_guard
    call = encode_call(
        "swapOwner",
        ["address", "address", "address"],
        [signers[1].address, signers[2].address, admin.address],
    )
    _test_guard(call, safe_without_guard, signers)


def test_guard_changeThreshold(safe_without_guard, signers, admin):
    safe, module = safe_without_guard
    call = encode_call(
        "changeThreshold",
        ["uint256"],
        [1],
    )
    _test_guard(call, safe_without_guard, signers)


def test_guard_setGuard(safe_without_guard, signers):
    safe, module = safe_without_guard

    guard = signers[0].deploy(NoSafeManagementByMultisig, safe.address, module.address)

    # the call should succeed without the guard configured
    call = encode_call("setGuard", ["address"], [guard.address])
    sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)

    # no need to enable the guard here, since it's already enabled.

    # but should fail with the guard enabled
    with reverts():
        sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)


@pytest.mark.parametrize(
    "owners",
    [
        ("0xc1f36a69ef03Cb202D548B5058fF0a70299B1d03",),
        (
            "0xc1f36a69ef03Cb202D548B5058fF0a70299B1d03",
            "0x46ce96BDbaFdd56957663BF810B3AFD0Fc0D1b1d",
            "0xb6b5ad22CcB7410844E2654EC518185f04B87b44",
        ),
        (
            "0xc1f36a69ef03Cb202D548B5058fF0a70299B1d03",
            "0x46ce96BDbaFdd56957663BF810B3AFD0Fc0D1b1d",
            "0xb6b5ad22CcB7410844E2654EC518185f04B87b44",
            "0x06977d4124a3E19Ee863850245b4e58A92c0758f",
        ),
    ],
)
def test_module_setSigners(owners, configured_safe, local_account, signers):
    safe, module, guard = configured_safe
    module.setSigners(owners, 1)
    got_owners = safe.getOwners()

    # assert match without ordering, since addOwnerWithThreshold adds
    # to the head of the list
    assert len(owners) == len(got_owners)
    for o in owners:
        assert o in got_owners


def test_module_setGuard(signers, local_account, configured_safe):
    safe, module, guard = configured_safe

    call = encode_call(
        "changeThreshold",
        ["uint256"],
        [1],
    )
    with reverts():
        sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)

    # this disables the guard
    module.setGuard(ZERO_ADDR, {"from": local_account})

    sign_and_execute_transaction(signers[0], safe, safe.address, 0, call)


def test_module_enableModule(local_account, configured_safe):
    safe, module, guard = configured_safe
    new_module = local_account.deploy(
        SafeManagementModule, safe.address, local_account.address
    )
    tx = module.enableModule(new_module.address, {"from": local_account})
    assert "ExecutionFromModuleSuccess" in tx.events
    tx = new_module.setSigners([local_account], 1)
    assert "ExecutionFromModuleSuccess" in tx.events


def test_module_disableModule(local_account, configured_safe):
    safe, module, guard = configured_safe
    new_module = local_account.deploy(
        SafeManagementModule, safe.address, local_account.address
    )
    tx = module.enableModule(new_module.address)
    assert "ExecutionFromModuleSuccess" in tx.events
    tx = new_module.disableModule(
        new_module.address, module.address, {"from": local_account}
    )
    assert "ExecutionFromModuleSuccess" in tx.events

    # GS104 = Method can only be called from an enabled module
    with reverts("GS104"):
        module.setSigners([local_account], 1, {"from": local_account})


def test_module_changeThreshold(local_account, configured_safe):
    safe, module, guard = configured_safe
    module.changeThreshold(2, {"from": local_account})
    assert safe.getThreshold() == 2
