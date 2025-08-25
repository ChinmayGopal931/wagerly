// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OutcomeToken is ERC20 {
    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "Caller is not the minter");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        minter = msg.sender; // Initially, the factory is the minter
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }

    function transferMinter(address newMinter) external onlyMinter {
        minter = newMinter;
    }
}