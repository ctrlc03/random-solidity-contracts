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
    event EmergencyWithdraw(address account, uint256 poolId, uint256 amount);

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
        baseToken.mint(address(this), reward);

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
        require(_pid != 0, "Invalid id");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "Not enough funds to withdraw");

        updatePool(_pid);

        uint256 userAmount = user.amount;
        uint256 userRewardDebt = user.rewardDebt;
        unchecked {
            user.amount -= _amount;
            user.rewardDebt = userAmount * pool.accRewardPerShare / 1e12; 
        }

        uint256 pendingReward = (userAmount * pool.accRewardPerShare / 1e12) - userRewardDebt;
        if (pendingReward != 0) {
            baseToken.safeTransfer(msg.sender, pendingReward);
        } 
        if (_amount != 0) {
            pool.lpToken.safeTransfer(msg.sender, _amount);
        }
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

    /**
     * @notice Allows an user to exit a pool in emergency situations
     * and lose all of the rewards so far
     * @param _pid <uint256> - the pool to exit
     */
    function emergencyWithdraw(uint256 _pid) public {
        require(_pid != 0, "invalid pid");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 userAmount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, userAmount);
        emit EmergencyWithdraw(msg.sender, _pid, userAmount);
    }

    // only owner 
    /**
     * @notice Allows the owner to add a LP token 
     * @param _allocPoint <uint256> - allocation points for this lp
     * @param _lpToken <IERC20> - the lp token address to add
     * @param _withUpdate <bool> - update pools or not
     */
    function add(      
        uint256 _allocPoint,
        address _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) massUpdatePools();

        unchecked {
            totalAllocPoint += _allocPoint; 

        }

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;

        PoolInfo memory _pool = PoolInfo(
            IExtendedERC20(_lpToken), 
            _allocPoint, 
            lastRewardBlock, 
            0
        );

        poolInfo.push(_pool);
    }

    /**
     * @notice Allows the owner to update a pool's reward allocation points
     * @param _pid <uint256> - the pool to amend
     * @param _allocationPoint <uint256> - the new allocatin point
     * @param withUpdate <bool> - should we update all pools or not
     */
    function set(
        uint256 _pid, 
        uint256 _allocationPoint,
        bool withUpdate
    ) public onlyOwner {
        if (withUpdate) massUpdatePools();

        uint256 previousAllocationPoint = poolInfo[_pid].allocPoints;

        // if it's different then update the stored one and the total 
        if (previousAllocationPoint != _allocationPoint) {
            poolInfo[_pid].allocPoints = _allocationPoint;
            unchecked {
                totalAllocPoint = totalAllocPoint - previousAllocationPoint + _allocationPoint;
            }
        }
    }

    /**
     * @notice Allows the owner to updat the bonus multiplier
     * @param _multiplier <uint256> - the new multiplier
     */
    function updateBonus(uint256 _multiplier) public onlyOwner {
        BONUS_MULTIPLIER = _multiplier;
    }

    // view functions

    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256) {
        return _to - _from * BONUS_MULTIPLIER;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @notice Get the rewards pending for a user
     * @param _pid <uint256> - the id of the pool
     * @param _user <address> - the user for which we want to get the info
     */
    function getPendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];

        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 reward = multiplier * inflation * pool.allocPoints / totalAllocPoint;
            accRewardPerShare = accRewardPerShare + reward * 1e12 / lpSupply;
        }

        return user.amount * accRewardPerShare / 1e12 - user.rewardDebt;
    }
}