// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor (string memory name, string memory symbol) ERC721(name, symbol) payable {
        _mint(msg.sender, 1);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}