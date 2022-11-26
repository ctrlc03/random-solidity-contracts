// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20('MOCKERC20', 'MCK') {
    constructor () payable {
        _mint(msg.sender, 100_000_000_000e18);
    }
}