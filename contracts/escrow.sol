// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract EscrowNFTSale {
    // allow access to the SafeERC20 library
    using SafeERC20 for IERC20;
    
    struct Order {
        bool fulfilled; // was the order fulfilled or not
        address seller; // who is the seller
        address nftAddress; // the address of the NFT
        address buyer; // whoever bought the asset
        address paymentToken; // the token requested for the sale
        uint256 deadline; // when does the sale expire
        uint256 paymentAmount; // the amount requested
        uint256 tokenId; // the token Id of the NFT
    }

    struct Offer {
        bool fulfilled; // was the order fulfilled
        address proposer; // who is the offer proposer
        address offerToken; // which token did they offer
        uint256 amount; // how much did they offer
        uint256 deadline; // when does the offer expire
        uint256 orderId; // the order id 
    }

    // our events
    event OrderCreated(uint256 orderId);
    event OrderFulfilled(uint256 indexed orderId, address indexed buyer);
    event OrderCancelled(uint256 orderId);
    event OrderExpiredClaimed(uint256 orderId);
    event OfferCreated(uint256 offerId);
    event OfferFulfilled(uint256 indexed offerId, uint256 indexed orderId);
    event OfferCancelled(uint256 offerId);

    // minimum duration of a sale offer
    uint256 public constant MINDURATION = 1 days;

    // the counters for the order and offer id
    uint256 public nextOrderId;
    uint256 public nextOfferId;

    // storage for orders and offers
    // orderId => Order
    mapping(uint256 => Order) public orders;
    // offerId => Offer
    mapping(uint256 => Offer) public offers;

    constructor() payable {  
    }

    // check that the order is valid
    modifier validOrder(uint256 orderId) {
        require(orderId < nextOrderId, 'This order does not exist');
        _;
    }

    // check that the offer is valid
    modifier validOffer(uint256 offerId) {
        require(offerId < nextOfferId, 'This offer does not exist');
        _;
    }

    function createOrder(
        address nftAddress, 
        uint256 tokenId, 
        uint256 duration, 
        uint256 paymentAmount,
        address paymentTokenAddress,
        address buyer
    ) external {
        // the seller needs to own the NFT
        require(
            IERC721(nftAddress).ownerOf(tokenId) == msg.sender, 
            'You do not own this NFT'
        );

        // minimum duration is 1 days
        require(duration > MINDURATION, 'Minimum length is 1 day');

        // store and increase CEI pattern
        uint256 orderId = nextOrderId;
        unchecked {
            nextOrderId++;
        }
        
        // create an order object
        Order memory order = Order(
            false, // not fulfiiled
            msg.sender,
            nftAddress,
            buyer, 
            paymentTokenAddress,
            block.timestamp + duration, // deadline
            paymentAmount,
            tokenId
        );

        // store it 
        orders[orderId] = order;

        // transfer NFT 
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        require(
            IERC721(nftAddress).ownerOf(tokenId) == address(this), 
            'The NFT was not transferred'
        );

        emit OrderCreated(orderId);
    }

    function fulfillOrder(uint256 orderId) external payable {
        require(orderId < nextOrderId, 'This order does not exist');

        Order storage order = orders[orderId];
        
        // the order needs to be still on 
        require(block.timestamp < order.deadline, 'The order is expired');
        // when seller == address(0) it means that it has been cancelled
        require(order.seller != address(0), 'This order was cancelled');
        // cannot fulfill after already fulfilled
        require(!order.fulfilled, 'The order was already fulfilled');
        // the seller cannot buy from themselves
        require(order.seller != msg.sender, 'Cannot fulfill your own order');

        // if the seller asked for Ether then the buyer needs to send the correct amount
        if (order.paymentToken == address(0)) {
            require(msg.value == order.paymentAmount, 'Did not send the correct amount');
        }

        // if there was a designated buyer only them can buy
        if (order.buyer != address(0)) {
            require(order.buyer == msg.sender, 'You are not the designated buyer');
        }

        // set as fulfilled
        order.fulfilled = true;

        // transfer tokens
        if (order.paymentToken != address(0)) {
            uint256 balanceBefore = IERC20(order.paymentToken).balanceOf(order.seller);
            IERC20(order.paymentToken).safeTransferFrom(msg.sender, order.seller, order.paymentAmount);
            uint256 balanceAfter = IERC20(order.paymentToken).balanceOf(order.seller);
            
            require(balanceBefore + order.paymentAmount == balanceAfter, 'Fee token not allowed');
        } else {
            // can a seller DoS the buyer? 
            // don't think so as this would revert and msg.value sent back
            (bool result, bytes memory data) = order.seller.call{value: msg.value}("");
            require(result, 'Transfer failed');
        }
       
        emit OrderFulfilled(orderId, msg.sender);
    }

    function cancelOrder(uint256 orderId) external validOrder(orderId) {
        Order storage order = orders[orderId];

        // cannot cancel an order that was already fulfilled 
        require(!order.fulfilled, 'This order was already fullfilled');
        // needs to be called by the seller
        require(order.seller == msg.sender, "You cannot cancel someone else's order");

        // reset seller so the order cannot be fulfilled
        order.seller = address(0);

        // transfer the nft back 
        IERC721(order.nftAddress).transferFrom(
            address(this), 
            msg.sender,  // we already ensured that the caller is the order creator
            order.tokenId
        );

        emit OrderCancelled(orderId);
    }

    function claimExpiredOrder(uint256 orderId) external validOrder(orderId) {
        Order storage order = orders[orderId];

        // cannot claim back the item once the order has been fulfilled
        require(!order.fulfilled, 'This order was fulfilled already');
        // cannot claim for someone else
        require(msg.sender == order.seller, 'This is not your order');
        // the order needs to be expired
        require(block.timestamp > order.deadline, 'This order is not expired');

        // set the seller to address zero so it cannot be fulfilled
        order.seller = address(0);

        // transfer back the nft to the seller
        IERC721(order.nftAddress).transferFrom(
            address(this),
            msg.sender, // we already ensured that the caller is the order creator
            order.tokenId
        );

        emit OrderExpiredClaimed(orderId);
    }

    function createOffer(
        address offerToken,
        uint256 orderId, 
        uint256 amount, 
        uint256 deadline
        )
        external validOrder(orderId) 
        {
        Order memory order = orders[orderId];

        // can only offer an ERC20
        require(offerToken != address(0), 'Cannot create Ether offer');
        // cannot offer on a fulfilled order
        require(!order.fulfilled, 'This order was fulfilled already');
        // the sale has expired
        require(block.timestamp < order.deadline, 'The order is expired');
        // seller == address(0) means the order was cancelled
        require(order.seller != address(0), 'This order was cancelled');
        // cannot make an offer to yourself
        require(order.seller != msg.sender, 'Cannot make offer to yourself');
        // the offer cannot expire after the sale offer deadline
        require(block.timestamp + deadline <= order.deadline, 'The offer cannot expire after the order');
        // the proposer needs to have enough tokens to make an offer
        require(
            IERC20(offerToken).balanceOf(msg.sender) >= amount, 
            'You do not own enough tokens to create an offer'
        );

        // the proposer needs to have setup an allowance 
        require(
            IERC20(offerToken).allowance(msg.sender, address(this))
            >= 
            amount,
            'You need to approve the contract to spend your tokens' 
        );

        // store the id and increase
        uint256 offerId = nextOfferId;
        unchecked {
            nextOfferId++;
        }

        // create the offer
        offers[offerId] = Offer(
            false, // a new offer is not fulfilled by default
            msg.sender,
            offerToken, // which token they are offering
            amount, // how much they are offering
            block.timestamp + deadline, // how long will it last
            orderId // the order id which the offer is linked to
        );

        emit OfferCreated(offerId);
    }

    function cancelOffer(uint256 offerId) external validOffer(offerId){
        Offer storage offer = offers[offerId];

        // can only cancel own offer
        require(msg.sender == offer.proposer, 'This is not your offer');
        // cannot cancel an offer that was already fulfilled
        require(!offer.fulfilled, 'Cannot cancel an order fulfilled offer');

        // set proposer to zero so it cannot be filled
        offer.proposer = address(0);

        emit OfferCancelled(offerId);
    }

    function acceptOffer(uint256 offerId) external validOffer(offerId) {
        Offer storage offer = offers[offerId];
        Order storage order = orders[offer.orderId];

        // cannot accept an offer that was fulfilled
        require(offer.proposer != address(0), 'The offer was cancelled');
        // only the order creator can accept it
        require(order.seller == msg.sender, 'Cannot accept the offer for someone else');
        // neither the offer nor the order needs to be already fulfilled 
        require(!offer.fulfilled && !order.fulfilled, 'The order was already fulfilled');

        // set order and offer as fulfilled
        order.fulfilled = true;
        offer.fulfilled = true;

        // check if we have an allowance so that we can send the funds to the seller
        // if not this would have reverted later but wanted to keep it more clean
        require(
            IERC20(offer.offerToken).allowance(offer.proposer, address(this)) 
            >=
            offer.amount,
            'The proposer of the offer removed the allowance'
        );

        // ensure that the token is not a fee on transfer
        uint256 balanceBefore = IERC20(offer.offerToken).balanceOf(order.seller);
        IERC20(order.paymentToken).safeTransferFrom(address(this), order.seller, offer.amount);
        uint256 balanceAfter = IERC20(offer.offerToken).balanceOf(order.seller);
        require(balanceBefore + offer.amount == balanceAfter, 'Fee on transfer token');
        
        emit OfferFulfilled(offerId, offer.orderId);
    }

    // view function to get an order from the mapping
    function getOrder(uint256 orderId) external view validOrder(orderId) returns(Order memory) {
        return orders[orderId];
    }
    
    // view function to get an offer from the mapping
    function getOffer(uint256 offerId) external view validOffer(offerId) returns (Offer memory) {
        return offers[offerId];
    }
}
