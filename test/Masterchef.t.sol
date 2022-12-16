// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/masterchef.sol";
import "../contracts/mocks/mockERC20.sol";

contract MasterChefTest is Test {
    address public owner;
    address public user1;
    address public user2;

    MasterChef public master;

    MockERC20 token1;
    MockERC20 token2;
    MockERC20 lp1;
    MockERC20 lp2;

    uint256 ownerPrivateKey = 1234;
    uint256 user1PrivateKey = 5678;
    uint256 user2PrivateKey = 9876;

    function setup() public {
        owner = vm.addr(ownerPrivateKey);
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        vm.startPrank(owner);
        token1 = new MockERC20('ERC201', 'ERC201');
        token2 = new MockERC20('ERC202', 'ERC202');
        lp1 = new MockERC20('LP1', 'LP1');
        lp2 = new MockERC20('LP2', 'LP2');
        master = new MasterChef(block.number + 10, address(token1));
    }

    function createPool() public {
        vm.startPrank(owner);

        uint256 _allocPoint = 10;
        master.add(
            _allocPoint,
            address(lp1),
            false 
        );
    }
}