// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "./IVault.sol";

contract LaLoVault is ERC20, IVault {
    IERC20 public immutable usdcToken;  // mUSDC
    address public hotelToken;          // LaLoToken (ERC20)
    address public booker;              // Set after deployment

    constructor(address _usdcToken, address _hotelToken, address _booker)
        ERC20("Yield Vault", "VAULT")
    {
        usdcToken = IERC20(_usdcToken);
        hotelToken = _hotelToken;
        booker = _booker;
    }

    modifier onlyBooker() {
        if(msg.sender != booker) revert NotBooker(msg.sender);
        _;
    }

    function deposit(address sender, uint256 amount) external onlyBooker {
        // Check if the transfer succeeds
        bool success = usdcToken.transferFrom(sender, address(this), amount);
       if (!success) {
            revert TransferFailed(); // Custom error for transfer failure
        }
    }

    function withdraw(uint256 shares) external {
        // Check if the sender has enough shares to withdraw
        uint256 userShares = balanceOf(msg.sender);
        if (shares > userShares) {
            revert (); // Revert if the user doesn't have enough shares
        }

        uint256 amount = (shares * usdcToken.balanceOf(address(this))) / totalSupply();
        _burn(msg.sender, shares);  // Burn the shares
        usdcToken.transfer(msg.sender, amount);  // Transfer the USDC to the user
    }

    function mintShares() external {
        uint256 balance = IERC20(hotelToken).balanceOf(msg.sender);
        if (balance == 0) revert InsufficientHotelToken();

        _mint(msg.sender, balance);
    }
}
