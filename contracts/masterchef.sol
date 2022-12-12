// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IExtendedERC20.sol";

contract MasterChef is Ownable {
    using SafeERC20 for IExtendedERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IExtendedERC20 lpToken;
        uint256 allocPoints;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    // how many tokens are released per block
    uint256 public inflation;

    // bonus
    uint256 public BONUS_MULTIPLIER = 1;

    uint256 public totalAllocPoint;
    // point to where it starts emitting rewards
    uint256 public startBlock;

    // all pools
    PoolInfo[] public poolInfo;
    // users deposits
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    IExtendedERC20 public baseToken;

    event Deposit(address depositor, uint256 poolId, uint256 amount);

    // making it payable to save a little gas
    constructor(uint256 _startBlock, address _baseToken) payable {
        startBlock = _startBlock;
        baseToken = IExtendedERC20(_baseToken);
    }

    // external/public functions

    /**
     * @notice updates a pool
     * @param _pid <uint256> - the pool id to update
     */
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.number <= pool.lastRewardBlock) return;

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        pool.lastRewardBlock = block.number;

        if (lpSupply == 0) return;

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward = multiplier * inflation * pool.allocPoints / totalAllocPoint;

        baseToken.mint(owner(), reward/10);

        // @todo syrup mint 
        pool.accRewardPerShare = pool.accRewardPerShare + reward * 1e12 / lpSupply;
    }

    /**
     * @notice allows to deposit into a pool
     * @param _pid <uint256> - the pool id
     * @param _amount <uint256> - the amount to deposit
     */
    function deposit(uint256 _pid, uint256 _amount) public {
        require(_pid != 0, "Invalid pool");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount != 0) {
            uint256 pendingReward = (user.amount * pool.accRewardPerShare / 1e12) - user.rewardDebt;
            if (pendingReward != 0) {
                baseToken.safeTransfer(msg.sender, pendingReward);
            }
        }

        if (_amount != 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            unchecked {
                user.amount += _amount;
            }
        }

        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice Allows an user to withdraw their tokens and claim rewards
     * @param _pid <uint256> - the pool id to withdraw from 
     * @param _amount <uint256> - the amount to withdraw
     */
    function withdraw(uint256 _pid, uint256 _amount) public {

    }

    /**
     * @notice Allows to update all pools in one go
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 i; i < length;) {
            updatePool(i);
            unchecked {
                ++i;
            }
        }
    }

    // only owner 


    // view functions

    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256) {
        return _to - _from * BONUS_MULTIPLIER;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
}