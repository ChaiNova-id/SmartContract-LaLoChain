// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RevenueToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {}

    // Mint function that can only be called by the owner
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
