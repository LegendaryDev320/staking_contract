// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IERC20.sol";
import "./SafeMath.sol";

contract StakingContract {
    using SafeMath for uint256;

    //Token being staked;
    IERC20 public token;
    //Mapping of Stakes
    struct StakeInfo {
        uint256 stake;
        uint256 stakeTime;
        uint256 lastWithdrawTime;
    }
    mapping (address => StakeInfo[]) private stakeInfos;
    //Annual interest rate
    uint256 public annualInterestRate = 20; //20%

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }
    //Function for users to see their staking information
    function getStakeInfo() external view returns (StakeInfo[] memory) {
        return stakeInfos[msg.sender];
    }
    //Function for users to stake tokens
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        //Check allowance
        require(token.allowance(msg.sender, address(this)) >= _amount, "Allowance is not enough");
        //Transfer tokens from sender to contract
        token.transferFrom(msg.sender, address(this), _amount);
        //Save staking amount and time
        StakeInfo memory info = StakeInfo({stake: _amount, stakeTime: block.timestamp, lastWithdrawTime: block.timestamp});
        stakeInfos[msg.sender].push(info);
    }
    //Function for users to withdraw total rewards
    function withdrawAll() external {
        require(stakeInfos[msg.sender].length > 0, "No stakes");
        //Calculate rewards
        for (uint256 i = 0; i < stakeInfos[msg.sender].length; i++) {
            withdraw(i);
        }
    }
    //Function for users to see their rewards
    function getRewards() external view returns (uint256) {
        require(stakeInfos[msg.sender].length > 0, "No stakes");
        //Calculate rewards
        uint256 rewards = 0;
        for (uint256 i = 0; i < stakeInfos[msg.sender].length; i++) {
            rewards += calculateRewards(msg.sender, i);
        }
        return  rewards;
    }
    //Function for users to withdraw staked tokens and rewards
    function withdraw(uint256 _stakingIndex) internal {
        require(_stakingIndex < stakeInfos[msg.sender].length && _stakingIndex >= 0, "Index out of bounds");
        //Stake check
        require(stakeInfos[msg.sender][_stakingIndex].stake > 0, "No stakes to withdraw");
        //Calculate rewards
        uint256 rewards = calculateRewards(msg.sender, _stakingIndex);
        //Transfer staked tokens and rewards back to user
        token.transfer(msg.sender, rewards);
        //Reset staking amount 
        stakeInfos[msg.sender][_stakingIndex].lastWithdrawTime = block.timestamp;
    }
    //Function for users to unstake staked tokens
    function unstake(uint256 _stakingIndex) external {
        require(_stakingIndex < stakeInfos[msg.sender].length && _stakingIndex >= 0, "Index out of bounds");
        //Stake check
        require(stakeInfos[msg.sender][_stakingIndex].stake > 0, "No stakes to withdraw");
        //Calculate lock time based on the staking time
        require(block.timestamp >= stakeInfos[msg.sender][_stakingIndex].stakeTime.add(30 days), "Lock time not over");
        //Transfer staked tokens back to user
        uint256 rewards = calculateRewards(msg.sender, _stakingIndex);
        token.transfer(msg.sender, stakeInfos[msg.sender][_stakingIndex].stake.add(rewards));
        //Reset staking amount
        delete stakeInfos[msg.sender][_stakingIndex];
    }
    //Internal function to calculate rewards based on lock time
    function calculateRewards(address _user, uint256 stakingIndex) internal view returns(uint256) {
        uint256 stakingTime = stakeInfos[_user][stakingIndex].lastWithdrawTime;

        //Calculate duration of staking
        uint256 duration = block.timestamp.sub(stakingTime);
        //Calculate rewards based on lock time
        uint256 stakedAmount = stakeInfos[_user][stakingIndex].stake;
        uint256 yearAsSecond = 365 * 24 * 60 * 60;
        uint256 rewards = annualInterestRate.mul(stakedAmount).mul(duration).div(100).div(yearAsSecond);
        return rewards;
    }
}