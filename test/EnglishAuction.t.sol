// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/englishAuction.sol";
import "../contracts/mocks/mockERC721.sol";
import "../contracts/mocks/mockERC20.sol";
import "../contracts/mocks/mockWETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract EnglishAuctionTest is Test {
    address public user1;
    address public user2;
    address public user3;

    EnglishAuction auctionContract;

    MockERC721 nft1;
    MockERC721 nft2;

    MockERC20 token1;
    MockERC20 token2;

    MockWETH mockWETH;

    uint256 user1PrivateKey = 5678;
    uint256 user2PrivateKey = 9876;
    uint256 user3PrivateKey = 1234;

    uint256 nextNft = 2;

    function setUp() public {
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        user3 = vm.addr(user3PrivateKey);
        mockWETH = new MockWETH('Wrapped Ethereum', 'WETH');
        auctionContract = new EnglishAuction(address(mockWETH));
        vm.startPrank(user1);
        nft1 = new MockERC721('Mock1', 'MCK1');
        nft2 = new MockERC721('Mock2', 'MCK2');
        token1 = new MockERC20('ERC201', 'ERC201');
        token2 = new MockERC20('ERC202', 'ERC202');
        vm.stopPrank();
        vm.startPrank(user2);
        vm.stopPrank();
    }

    function testCreateOrder() public {
        vm.startPrank(user1);

        uint256 nftId = 1;

        nft1.approve(address(auctionContract), nftId);

        uint256 auctionId = auctionContract.createAuction(address(nft1), uint128(nftId));

        EnglishAuction.Auction memory auction = auctionContract.getAuction(auctionId);

        assertEq(auction.asset, address(nft1));
        vm.stopPrank();
    }

    function testBid() public {
        vm.startPrank(user1);

        uint256 nftId = 1;

        nft1.approve(address(auctionContract), nftId);
        uint256 auctionId = auctionContract.createAuction(address(nft1), uint128(nftId));
        vm.stopPrank();

        hoax(user2, 2 ether);

        auctionContract.bid{value: 1 ether}(auctionId);

        assertEq(address(auctionContract).balance, 1 ether);

        EnglishAuction.Bid memory _bid = auctionContract.getTopBid(auctionId);
        assertEq(_bid.creator, user2);
        assertEq(_bid.amount, 1 ether);
    }

    function testOutbid() public {
        vm.startPrank(user1);

        uint256 nftId = 1;

        nft1.approve(address(auctionContract), nftId);
        uint256 auctionId = auctionContract.createAuction(address(nft1), uint128(nftId));
        vm.stopPrank();

        hoax(user2, 2 ether);

        auctionContract.bid{value: 1 ether}(auctionId);

        assertEq(address(auctionContract).balance, 1 ether);

        EnglishAuction.Bid memory _bid = auctionContract.getTopBid(auctionId);
        assertEq(_bid.creator, user2);
        assertEq(_bid.amount, 1 ether);

        hoax(user3, 2 ether);

        auctionContract.bid{value: 1.5 ether}(auctionId);

        _bid = auctionContract.getTopBid(auctionId);
        assertEq(_bid.creator, user3);
        assertEq(_bid.amount, 1.5 ether);

        assertEq(user2.balance, 2 ether);
    }

    function testCancel() public {
        vm.startPrank(user1);

        uint256 nftId = 1;

        nft1.approve(address(auctionContract), nftId);
        uint256 auctionId = auctionContract.createAuction(address(nft1), uint128(nftId));

        auctionContract.cancelAuction(auctionId);

        EnglishAuction.Auction memory auction = auctionContract.getAuction(auctionId);
        assertEq(auction.creator, address(0));

        vm.stopPrank();
    }
}
