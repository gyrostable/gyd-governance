import pytest


@pytest.fixture(scope="session")
def admin(accounts):
    return accounts[0]


@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass
