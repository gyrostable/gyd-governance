// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Mintable is ERC721Enumerable {
    constructor() ERC721("MyNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) public virtual {
        _mint(to, tokenId);
    }
}
