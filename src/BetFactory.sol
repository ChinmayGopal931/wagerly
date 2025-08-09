// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PnlBet.sol";

contract BetFactory is Ownable {
    using Clones for address;

    address public immutable pnlBetLogic;
    address[] public allBets;

    mapping(address => address[]) public userCreatedBets;
    mapping(address => address[]) public targetUserBets;

    event BetCreated(
        address indexed newBetAddress,
        address indexed creator,
        address indexed targetUser,
        uint32 perpId,
        uint256 endTime
    );

    error InvalidDuration();
    error InvalidTargetUser();

    constructor(address _pnlBetLogic) Ownable(msg.sender) {
        pnlBetLogic = _pnlBetLogic;
    }

    function createBet(address _targetUser, uint32 _perpId, uint256 _duration) external returns (address) {
        if (_targetUser == address(0)) revert InvalidTargetUser();
        if (_duration == 0 || _duration > 365 days) revert InvalidDuration();

        uint256 endTime = block.timestamp + _duration;

        // Deploy minimal proxy using EIP-1167
        address newBet = pnlBetLogic.clone();

        // Initialize the new bet proxy
        PnlBet(newBet).initialize(_targetUser, _perpId, endTime);

        // Add to registries
        allBets.push(newBet);
        userCreatedBets[msg.sender].push(newBet);
        targetUserBets[_targetUser].push(newBet);

        emit BetCreated(newBet, msg.sender, _targetUser, _perpId, endTime);

        return newBet;
    }

    function getAllBets() external view returns (address[] memory) {
        return allBets;
    }

    function getUserCreatedBets(address user) external view returns (address[] memory) {
        return userCreatedBets[user];
    }

    function getTargetUserBets(address targetUser) external view returns (address[] memory) {
        return targetUserBets[targetUser];
    }

    function getBetCount() external view returns (uint256) {
        return allBets.length;
    }

    function getActiveBets() external view returns (address[] memory) {
        uint256 activeCount = 0;

        // First pass: count active bets
        for (uint256 i = 0; i < allBets.length; i++) {
            PnlBet bet = PnlBet(allBets[i]);
            if (!bet.isSettled() && block.timestamp < bet.endTime()) {
                activeCount++;
            }
        }

        // Second pass: populate active bets array
        address[] memory activeBets = new address[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allBets.length; i++) {
            PnlBet bet = PnlBet(allBets[i]);
            if (!bet.isSettled() && block.timestamp < bet.endTime()) {
                activeBets[currentIndex] = allBets[i];
                currentIndex++;
            }
        }

        return activeBets;
    }

    function getSettlableBets() external view returns (address[] memory) {
        uint256 settlableCount = 0;

        // First pass: count settlable bets
        for (uint256 i = 0; i < allBets.length; i++) {
            PnlBet bet = PnlBet(allBets[i]);
            if (!bet.isSettled() && block.timestamp >= bet.endTime()) {
                settlableCount++;
            }
        }

        // Second pass: populate settlable bets array
        address[] memory settlableBets = new address[](settlableCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allBets.length; i++) {
            PnlBet bet = PnlBet(allBets[i]);
            if (!bet.isSettled() && block.timestamp >= bet.endTime()) {
                settlableBets[currentIndex] = allBets[i];
                currentIndex++;
            }
        }

        return settlableBets;
    }

    // Batch settle multiple bets (useful for keeper bots)
    function batchSettle(address[] calldata betAddresses) external {
        for (uint256 i = 0; i < betAddresses.length; i++) {
            PnlBet bet = PnlBet(betAddresses[i]);
            if (!bet.isSettled() && block.timestamp >= bet.endTime()) {
                bet.settle();
            }
        }
    }
}
