// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1Read} from "../../src/interface/L1Read.sol";

/// @title MockPositionPrecompile
/// @notice Mocks the behavior of the Hyperliquid position precompile (0x...0800).
/// It uses a mapping to store a mock position for a given user and perp,
/// which can be set from a test case.
contract MockPositionPrecompile {
    mapping(address => mapping(uint16 => L1Read.Position)) public mockPositions;

    /// @notice When the precompile address is called, this fallback decodes the
    /// user and perpId, retrieves the corresponding mock position, and returns it.
    fallback(bytes calldata data) external returns (bytes memory) {
        (address user, uint16 perpId) = abi.decode(data, (address, uint16));
        return abi.encode(mockPositions[user][perpId]);
    }

    /// @notice A setter function that allows tests to define the mock position
    /// for a specific user and perp.
    function setPosition(address user, uint16 perpId, L1Read.Position calldata pos) external {
        mockPositions[user][perpId] = pos;
    }
}

/// @title MockMarkPxPrecompile
/// @notice Mocks the behavior of the Hyperliquid mark price precompile (0x...0806).
/// It stores a single price that can be set from a test case.
contract MockMarkPxPrecompile {
    uint64 public mockPrice;

    /// @notice When the precompile address is called, this fallback returns the mock price.
    /// It ignores the input (perp index) for simplicity in this mock.
    fallback(bytes calldata /*data*/ ) external returns (bytes memory) {
        return abi.encode(mockPrice);
    }

    /// @notice A setter function that allows tests to define the mock mark price.
    function setPrice(uint64 price) external {
        mockPrice = price;
    }
}
