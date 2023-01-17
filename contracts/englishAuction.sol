// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

/// @notice The contract allows to create new English Auctions
contract EnglishAuction {

    struct Auction {
        uint128 id;
        uint128 startTime;
        address asset;
        address creator;
    }

    struct Bid {
        address creator;
        uint256 amount;
    }

    uint256 constant auctionDuration = 7 days;

    IWETH immutable WETH;

    // auctionId => Auction
    mapping(uint256 => Auction) public auctions;
    // auctionId => Bid
    mapping(uint256 => Bid) public bids;
    uint256 public nextAuctionId;

    // Events
    event AuctionCreated(uint256 auctionId);
    event NewTopBid(uint256 auctionId, uint256 amount, address bidder);
    event AuctionClaimed(uint256 auctionId, address claimer);
    event AuctionCancelled(uint256 auctionId);

    // Errors
    error NotOwned();
    error NotTransferred();
    error InvalidId();
    error NotCreator();
    error HasBid();
    error Cancelled();
    error SelfBid();
    error AuctionExpired();
    error OngoingAuction();
    error BidTooSmall();
    error NotEnoughEther();
    error NotBidder();

    constructor(address _weth) payable {
        WETH = IWETH(_weth);
    }

    /**
     * @notice Creates a new auction
     * @param _asset <address> - the address of the ERC721 token
     * @param _id <uint128> - the id of the NFT
     * @return auctionId <uint256>
     */
    function createAuction(
        address _asset,
        uint128 _id
    ) external payable returns(uint256 auctionId) {
        // must own asset
        if (msg.sender != IERC721(_asset).ownerOf(_id)) revert NotOwned();
        
        auctionId = nextAuctionId;
        unchecked {
            nextAuctionId++;
        }

        // save auction 
        auctions[auctionId] = Auction(
            _id,
            uint128(block.timestamp),
            _asset,
            msg.sender
        );

        emit AuctionCreated(auctionId);

        // take asset and confirm it was received
        IERC721(_asset).transferFrom(msg.sender, address(this), _id);
        if (address(this) != IERC721(_asset).ownerOf(_id)) revert NotTransferred();
    }

    /**
     * @notice Allows the creator of an auction to cancel it
     * @param auctionId <uint256> - the id of the auction to cancel
     */
    function cancelAuction(uint256 auctionId) external payable {
        // check if valid
        _validAuction(auctionId);

        Auction storage _auction = auctions[auctionId];

        if (_auction.creator != msg.sender) revert NotCreator();

        Bid memory _bid = bids[auctionId];
        // cannot cancel if there is a bid (I decided that u.u)
        if (_bid.amount > 0) revert HasBid();

        // we can delete
        delete auctions[auctionId];

        emit AuctionCancelled(auctionId);
    }

    /**
     * @notice Allows users to bid onto an auction
     * @param auctionId <uint256> - the id of the auction to bid for
     */
    function bid(uint256 auctionId) external payable {
        _validAuction(auctionId);
        Auction storage auction = auctions[auctionId];

        if (auction.creator == address(0)) revert Cancelled();
        if (msg.sender == auction.creator) revert SelfBid();
        if (block.timestamp >= auction.startTime + auctionDuration) revert AuctionExpired();

        Bid storage _bid = bids[auctionId];

        if (msg.value <= _bid.amount) revert BidTooSmall();

        uint256 amountToRefund = _bid.amount;
        address previousTopBidder = _bid.creator;

        // change values to new bidder
        _bid.amount = msg.value;
        _bid.creator = msg.sender;

        // refund the previous
        _sendEth(previousTopBidder, amountToRefund);

        emit NewTopBid(auctionId, amountToRefund, msg.sender);
    }

    /**
     * @notice allows to finish an auction
     * @param auctionId <uint256> - the id of the auction to complete and claim 
     */
    function claim(uint256 auctionId) external payable {
        _validAuction(auctionId);

        Auction memory auction = auctions[auctionId];
        if (auction.startTime + auctionDuration <= block.timestamp) revert OngoingAuction();
        Bid memory _bid = bids[auctionId];
        if (_bid.creator != msg.sender) revert NotBidder();

        // we can remove
        delete auctions[auctionId];
        delete bids[auctionId];

        // send NFT to winner
        IERC721(auction.asset).transferFrom(address(this), _bid.creator, auction.id);
        // send ETH to creator
        _sendEth(auction.creator, _bid.amount);

        emit AuctionClaimed(auctionId, msg.sender);
    }

    /**
     * @notice Get an Auction details
     * @param auctionId <uint256> - the id of the auction
     * @return Auction 
     */
    function getAuction(uint256 auctionId) external view returns(Auction memory) {
        _validAuction(auctionId);

        return auctions[auctionId];
    }

    /**
     * @notice Get the top bid for an auction
     * @param auctionId <uint256> - the id of the auction
     * @return Bid 
     */
    function getTopBid(uint256 auctionId) external view returns(Bid memory) {
        _validAuction(auctionId);

        return bids[auctionId];
    }

    /**
     * @notice Checks that the auction Id is valid
     * @param auctionId <uint256> - the auction id to validate
     */
    function _validAuction(uint256 auctionId) private view {
        if (auctionId >= nextAuctionId) revert InvalidId();
    }

    /**
     * @notice Sends Ether safely
     * @param receiver <address> - Ether receiver
     * @param amountToRefund <uint256> - the amount of Ether to send
     */
    function _sendEth(
        address receiver,
        uint256 amountToRefund
    ) private {
        if (address(this).balance < amountToRefund) revert NotEnoughEther();
        uint256 gas = gasleft();
        (bool success, ) = receiver.call{value: amountToRefund, gas: gas}("");

        // if the refund fails then send as WETH
        if (!success) {
            WETH.deposit{value: amountToRefund}();
            WETH.transfer(receiver, amountToRefund);
        }
    }
}