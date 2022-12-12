// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor (string memory name, string memory symbol) ERC20(name, symbol) payable {
        _mint(msg.sender, 100_000_000_000e18);
    }
}