// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract PledgerNFT is ERC721 {

    address public owner;
    uint256 public nextTokenId = 1; 
    
    error NotOwner();
    error AlreadyMinted();

    constructor(string memory _name, string memory _symbol) payable ERC721(_name, _symbol) {
        owner = msg.sender;
    }

    /// @notice owner can mint (only one per user)
    function mint(address to) external returns(uint256 tokenId) {
        _isOwner();
        _hasMinted(to);
        tokenId = nextTokenId;
        unchecked {
            nextTokenId++;
        }
        _safeMint(to, tokenId);
    }


    /// @notice owner can burn if one removes donation 
    function burn(uint256 tokenId) external {
        _isOwner();
        _burn(tokenId);
    }

    function _isOwner() private view {
        if (msg.sender != owner) revert NotOwner();
    }

    function _hasMinted(address user) private view {
        if (balanceOf(user) != 0) revert AlreadyMinted();
    } 
}

/// @notice The contract allows to crowd fund someone
contract CrowdFund {

    address public owner;
    uint128 public end;
    uint128 public goal;
    PledgerNFT public nft;
    IWETH public immutable WETH;

    mapping(address => uint256) public donations;
    mapping(address => uint256) public donorNFTs;

    event Donated(address who, uint256 amount);
    event Withdrawn(address who, uint256 amount);

    error NotOwner();
    error IsNotCompleted();
    error IsCompleted();
    error UserBalanceTooLow();
    error NotEnoughEther();
    error GoalNotReached();
    error GoalReached();

    constructor(uint128 _duration, uint128 _goal, address _owner, string memory campaignName, address _WETH) payable {
        owner = _owner;
        end = uint128(block.timestamp) + _duration;
        goal = _goal;
        WETH = IWETH(_WETH);

        string memory nftName = string.concat("Donor-", campaignName);
        nft = new PledgerNFT(nftName, nftName);
    }

    function pledge() external payable {
        _donation();
    }

    function unpledge(uint256 amount) external {
        // must be ongoing
        _isOngoing();
        // user needs to have enough balance to withraw
        if (amount > donations[msg.sender]) revert UserBalanceTooLow();

        // cannot underflow because of above check
        unchecked {
            donations[msg.sender] -= amount;
        }

        // if they are left with 0 donation, then burn their NFT
        if (donations[msg.sender] == 0) _burnNFT(donorNFTs[msg.sender]);

        emit Withdrawn(msg.sender, amount);

        // transfer back the Ether
        _sendEth(msg.sender, amount);
    }

    // accept donation 
    receive() external payable {
        _donation();
    }

    function ownerClaim() external payable {
        _onlyOwner();
        _isCompleted();
        if (_hasReachedGoal()) selfdestruct(payable(msg.sender));
        else revert GoalNotReached();
    }

    function userClaim() external payable {
        if (!_hasReachedGoal()) {
            uint256 amount = donations[msg.sender];
            donations[msg.sender] = 0;
            if (amount != 0) {
                _sendEth(msg.sender, amount);
            }
        } else revert GoalReached();

    }

    function _donation() private {
        // must be ongoing
        _isOngoing();
        // cannot overflow realistically
        unchecked {
            donations[msg.sender] += msg.value;
        }

        emit Donated(msg.sender, msg.value);

        // try and mint an NFT for the donor
        _mintNFT(msg.sender);
    }
    function _onlyOwner() private view {
        if (msg.sender != owner) revert NotOwner();
    }

    function _isOngoing() private view {
        if (block.timestamp > end) revert IsCompleted();
    }

    function _isCompleted() private view {
        if (block.timestamp < end) revert IsNotCompleted();
    }

    function _mintNFT(address to) private {
        try nft.mint(to) returns(uint256 tokenId) {
            donorNFTs[to] = tokenId;
        } catch Error(string memory) {}
    }

    function _burnNFT(uint256 tokenId) private {
        nft.burn(tokenId);
    }

    function _hasReachedGoal() private view returns(bool) {
        _isCompleted();
        return address(this).balance >= goal;
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

contract CrowdFundFactory {

    mapping(uint256 => address) public deployedContracts;

    uint256 public nextCrowdFundId;

    event CrowdFundDeployed(uint256 id, address crowdFundAddress);

    constructor() payable {}

    function deployCrowdFund(
        uint128 duration,
        uint128 goal,
        string memory campaignName,
        address WETH
    ) external payable returns(address crowdFundAddress) {
        uint256 id = nextCrowdFundId;
        unchecked {
            nextCrowdFundId++;
        }
        CrowdFund _contract = new CrowdFund(duration, goal, msg.sender, campaignName, WETH);
        crowdFundAddress = address(_contract);

        emit CrowdFundDeployed(id, crowdFundAddress);
    }
}