// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../contracts/crowdFund.sol";
import "../contracts/mocks/mockERC721.sol";
import "../contracts/mocks/mockERC20.sol";
import "../contracts/mocks/mockWETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CrowdFundTest is Test {
    address public user1;
    address public user2;
    address public user3;

    CrowdFundFactory public factory;

    MockWETH mockWETH;

    uint256 user1PrivateKey = 5678;
    uint256 user2PrivateKey = 9876;
    uint256 user3PrivateKey = 1234;

    function setUp() public {
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        user3 = vm.addr(user3PrivateKey);
        mockWETH = new MockWETH('Wrapped Ethereum', 'WETH');
        factory = new CrowdFundFactory();
    }

    function deployCrowdFund() public {
        address crowdfundAddress = factory.deployCrowdFund(
            1 days,
            1 ether,
            "Make me rich",
            address(mockWETH)
        );

        CrowdFund crowdFund = CrowdFund(payable(crowdfundAddress));

        assertEq(crowdFund.goal(), 1 ether);
    }

    function contribute() public {
        address crowdfundAddress = factory.deployCrowdFund(
            1 days,
            1 ether,
            "Make me rich",
            address(mockWETH)
        );

        CrowdFund crowdFund = CrowdFund(payable(crowdfundAddress));

        assertEq(crowdFund.goal(), 1 ether);

        hoax(user2, 2 ether);
        crowdFund.pledge{value: 1 ether}();
        assertEq(crowdfundAddress.balance, 1 ether);

        PledgerNFT nft = PledgerNFT(crowdFund.nft());
        assertEq(nft.ownerOf(1), user2);
    }

    
}