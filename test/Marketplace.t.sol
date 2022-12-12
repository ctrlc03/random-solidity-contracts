// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/escrow.sol";
import "../contracts/mocks/mockERC721.sol";
import "../contracts/mocks/mockERC20.sol";


contract MarketplaceTest is Test {
    address public owner;
    address public user1;
    address public user2;

    EscrowNFTSale marketplace;

    MockERC721 nft1;
    MockERC721 nft2;

    MockERC20 token1;
    MockERC20 token2;

    uint256 ownerPrivateKey = 1234;
    uint256 user1PrivateKey = 5678;
    uint256 user2PrivateKey = 9876;

    uint256 nextNft = 2;

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        vm.startPrank(owner);
        marketplace = new EscrowNFTSale();
        nft1 = new MockERC721('Mock1', 'MCK1');
        nft2 = new MockERC721('Mock2', 'MCK2');
        token1 = new MockERC20('ERC201', 'ERC201');
        token2 = new MockERC20('ERC202', 'ERC202');
        vm.stopPrank();
    }

    function testMintNFT() public {
        vm.startPrank(owner);
        uint256 _nextNFT = nextNft;
        nextNft++;
        nft1.mint(owner, _nextNFT);
        assertEq(nft1.ownerOf(2), owner);
    }

    function testBalances() public {
        uint256 balanceOwner = token1.balanceOf(owner);
        assertEq(balanceOwner, 100_000_000_000e18);
        assertEq(token2.balanceOf(owner), 100_000_000_000e18);
    }

    function testCreateOrder() public {
        uint256 _nextNft = nextNft;
        nextNft++;
        nft1.mint(user1, _nextNft);
        vm.startPrank(user1);

        nft1.approve(address(marketplace), _nextNft);

        marketplace.createOrder(
            address(nft1),
            _nextNft,
            2 days,
            1000,
            address(token1),
            address(0)
        );
        vm.stopPrank();

        uint256 orderId = marketplace.nextOrderId();
        assertEq(orderId, 1);
        EscrowNFTSale.Order memory order = marketplace.getOrder(orderId - 1);
        assertEq(order.seller, user1);
        assertEq(order.nftAddress, nft1);
    }
    
}
