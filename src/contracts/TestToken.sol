// SPDX-License-Identifier: MIT
// Created by Alexorbit - https://linkd.in/alexorbit
    pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// PEPOWToken inherits the ERC20 contract
contract PEPOWToken is ERC20 {
    using SafeMath for uint256;

    // Struct to store miner data
    struct MinerData {
        uint256 lastMinedBlock;      // The last block mined by the miner
        uint256 stakeAmount;         // The amount staked by the miner
        uint256 lastStakeChangeTime; // Time when the miner last changed their stake
    }

    uint256 public miningDifficulty;      // Mining difficulty which is adjusted based on total stake and number of stakers
    uint256 public lastMinedBlock;        // Last block that was mined
    uint256 public blockReward;           // Reward for mining a block
    uint256 public totalStake;            // Total stake across all miners
    uint256 public totalStakers;          // Total number of stakers
    uint256 public maxStakeSize = 500000; // Maximum allowable stake per miner
    bool public miningStopped;            // Flag to indicate if mining is stopped

    mapping(address => MinerData) public minerData; // Mapping from miner address to their data

    event Staked(address indexed user, uint256 amount, uint256 totalAmount);
    event Unstaked(address indexed user, uint256 amount, uint256 totalAmount);
    event Mined(address indexed user, uint256 reward);
    event MiningStopped();

    // Constructor function sets initial supply, difficulty, and block reward
    constructor(uint256 initialSupply, uint256 difficulty, uint256 reward) ERC20("PEPOW Token", "PPOW") {
        _mint(msg.sender, initialSupply);
        miningDifficulty = difficulty;
        blockReward = reward;
        miningStopped = false; // Initialize miningStopped flag to false
    }

    // Overriding decimals function to set token decimal places to 6
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // Function to adjust mining difficulty based on total stake and number of stakers
    function adjustDifficulty() private {
        miningDifficulty = miningDifficulty.add(totalStake.div(totalStakers));
    }

    // Function to stake tokens
    function stake(uint256 amount) public {
        // Check that the new stake size doesn't exceed the maximum limit
        require(minerData[msg.sender].stakeAmount.add(amount) <= maxStakeSize, "Stake size exceeds maximum limit");
        _burn(msg.sender, amount); // Burn the staked tokens
        minerData[msg.sender].stakeAmount = minerData[msg.sender].stakeAmount.add(amount); // Increase stake amount
        totalStake = totalStake.add(amount); // Increase total stake
        // If this is the first time the miner is staking, increase the number of stakers
        if (minerData[msg.sender].stakeAmount == amount) totalStakers = totalStakers.add(1);
        minerData[msg.sender].lastStakeChangeTime = block.timestamp; // Update last stake change time
        adjustDifficulty(); // Adjust mining difficulty
        emit Staked(msg.sender, amount, minerData[msg.sender].stakeAmount); // Emit Staked event
    }

    // Function to withdraw staked tokens
    function withdrawStake(uint256 amount) public {
        // Check that the miner has enough staked tokens to withdraw
        require(minerData[msg.sender].stakeAmount >= amount, "You don't have enough staked tokens");
        _mint(msg.sender, amount); // Mint the withdrawn tokens
        minerData[msg.sender].stakeAmount = minerData[msg.sender].stakeAmount.sub(amount); // Decrease stake amount
        totalStake = totalStake.sub(amount); // Decrease total stake
        // If the miner has withdrawn all their staked tokens, decrease the number of stakers
        if (minerData[msg.sender].stakeAmount == 0) totalStakers = totalStakers.sub(1);
        minerData[msg.sender].lastStakeChangeTime = block.timestamp; // Update last stake change time
        adjustDifficulty(); // Adjust mining difficulty
        emit Unstaked(msg.sender, amount, minerData[msg.sender].stakeAmount); // Emit Unstaked event
    }

    // Function to mine tokens
    function mine(uint256 nonce) public {
        // Check that mining is not stopped
        require(!miningStopped, "Mining is stopped");

        // Check that a block has not been mined too recently
        require(block.number.sub(lastMinedBlock) >= miningDifficulty, "Block has already been mined");
        // Check that the miner is not mining too fast
        require(block.number.sub(minerData[msg.sender].lastMinedBlock) >= miningDifficulty, "You are mining too fast");

        // Compute the hash from the block number, miner address, and nonce
        bytes32 hash = keccak256(abi.encodePacked(block.number, msg.sender, nonce));
        // Check that the hash is less than a threshold determined by the mining difficulty and miner's stake
        require(uint256(hash) < type(uint256).max.div(miningDifficulty).div(1 + minerData[msg.sender].stakeAmount), "Incorrect nonce");

        // Mint the block reward
        _mint(msg.sender, blockReward);
        // Emit Mined event
        emit Mined(msg.sender, blockReward);
        // Update the last mined block
        lastMinedBlock = block.number;
        // Update the miner's last mined block
        minerData[msg.sender].lastMinedBlock = block.number;
    }

    // Function to stop mining
    function stopMining() public {
        require(!miningStopped, "Mining is already stopped");
        miningStopped = true;
        emit MiningStopped();
    }
}
