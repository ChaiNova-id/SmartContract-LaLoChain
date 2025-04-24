// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaLoVault} from "./LaLoVault.sol";
import {IHotelRegistry} from "./IHotelRegistry.sol";

contract LaLoHotelVaultWithdraw {
    error HotelNotRegistered();
    error InsufficientSharesToWithdraw();

    event SharesWithdrawn(uint256 indexed hotelId, address indexed user, uint256 shares);

    IHotelRegistry public hotelRegistry;

    constructor(address _hotelRegistry) {
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    // Function to allow a user to withdraw from the vault by specifying the number of shares
    function withdrawFromVault(uint256 hotelId, uint256 shares) external {
        // Ensure the hotel is registered
        if (!hotelRegistry.isHotelRegistered(hotelId)) revert HotelNotRegistered();

        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getHotel(hotelId).vaultAddress;

        // Cast the vault address to the LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Check if the user has enough shares to withdraw
        uint256 userShares = vault.balanceOf(msg.sender);
        if (shares > userShares) revert InsufficientSharesToWithdraw();

        // Call the withdraw function of the LaLoVault contract
        vault.withdraw(shares); // This will burn the shares and transfer the corresponding USDC

        emit SharesWithdrawn(hotelId, msg.sender, shares);
    }
}
