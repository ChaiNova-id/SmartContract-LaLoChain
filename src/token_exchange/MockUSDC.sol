// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor(uint256 initialTokens, string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, initialTokens * 10 ** 6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
