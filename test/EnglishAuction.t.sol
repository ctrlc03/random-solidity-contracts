// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/englishAuction.sol";
import "../contracts/mocks/mockERC721.sol";
import "../contracts/mocks/mockERC20.sol";
import "../contracts/mocks/mockWETH.sol";


contract EnglishAuctionTest is Test {
    address public user1;
    address public user2;

    EnglishAuction auctionContract;

    MockERC721 nft1;
    MockERC721 nft2;

    MockERC20 token1;
    MockERC20 token2;

    MockWETH mockWETH;

    uint256 user1PrivateKey = 5678;
    uint256 user2PrivateKey = 9876;

    uint256 nextNft = 2;

    function setUp() public {
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        auctionContract = new EnglishAuction();
        vm.startPrank(user1);
        nft1 = new MockERC721('Mock1', 'MCK1');
        nft2 = new MockERC721('Mock2', 'MCK2');
        token1 = new MockERC20('ERC201', 'ERC201');
        token2 = new MockERC20('ERC202', 'ERC202');
        vm.stopPrank();
    }

    function testCreateOrder() public {
        vm.startPrank(user1);

        uint256 nftId = 1;

        nft1.approve(address(auctionContract), nftId);

        uint256 auctionId = auctionContract.createAuction(address(nft1), uint128(nftId));

        EnglishAuction.Auction memory auction = auctionContract.getAuction(auctionId);

        assertEq(auction.asset, address(nft1));
    }
}
