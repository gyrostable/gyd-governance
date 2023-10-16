from support.utils import scale


BOUNDED_ERC20_WITH_EMA_WINDOW_WIDTH = 7200 * 10**18  # 1 day in blocks (not seconds!)

COUNCILLOR_NFT_MAX_SUPPLY = 196


DAO_TREASURY = {}

GYD_TOKEN_ADDRESS = {
    1: "0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A",
    137: "0x37b8E1152fB90A867F3dccA6e8d537681B04705E",
}

GYFI_TOKEN_ADDRESS = {
    137: "0x815c288dD62a761025f69B7dac2C93143Da4c0a8",
}

BALANCER_POOLS = {
    137: {
        "MATIC_STMATIC": "0xf0ad209e2e969EAAA8C882aac71f02D8a047d5c2",
    }
}

STRATEGIES = {
    1: {
        "low": "0xFE41992176Ad0fA41C4A2Ed70F3c36273027c27C",
        "medium": "0x0B4237b829c34507EEdDB67006Db6061D3D60edF",
        "high": "0xc2dAEFf6fE82Ab18a32BC70c0098345a183492E6",
        "core": "0xeA8106503a136eAaD94BF9Fcf1DE485459fd538E",
        "high_treasury": "0xd955238D7815564365706e327108331f8A18fD49",
        "limit_upgradeability": "0xD837D6c421ec3d6E6361BffBccd0Ff8f218d1c6d",
    }
}


EMA_THRESHOLD = int(scale("0.5"))
ACTION_LEVEL_THRESHOLD = 30
MIN_BGYD_SUPPLY = int(scale(25_000_000))
