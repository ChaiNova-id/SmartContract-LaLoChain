// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHotelTokenization} from "./IHotelTokenization.sol";
import {IHotelRegistry} from "../hotel_owners/IHotelRegistry.sol";
import {LaLoVault} from "./LaLoVault.sol";

contract LaLoHotelTokenization is IHotelTokenization {
    IERC20 public usdcToken;
    IHotelRegistry public hotelRegistry;

    constructor(address _usdcToken, address _hotelRegistry) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = IHotelRegistry(_hotelRegistry);
    }

    function buyHotelTokens(uint256 hotelId, uint256 amountInUSDC) external {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }

        IHotelRegistry.Hotel memory hotel = hotelRegistry.getHotel(hotelId);

        // Cast the vault address
        LaLoVault vault = LaLoVault(hotel.vaultAddress);

        // Deposit on behalf of buyer to issue shares
        vault.deposit(msg.sender, amountInUSDC); 

        // (optional) If you still want to transfer "hotel tokens" as a bonus/ownership proof
        if(!IERC20(hotel.tokenAddress).transfer(msg.sender, amountInUSDC)) {
            revert LLOTTransferFailed();
        }

        emit TokensBought(hotelId, msg.sender, amountInUSDC);
    }


    function withdrawFromVault(uint256 hotelId, uint256 shares) external {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }

        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getHotel(hotelId).vaultAddress;

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Check user balance
        uint256 userShares = vault.balanceOf(msg.sender);
        if (shares > userShares) {
            revert InsufficientSharesToWithdraw();
        }

        // Withdraw shares (LaLoVault will burn and send USDC)
        vault.withdraw(shares);

        emit SharesWithdrawn(hotelId, msg.sender, shares);
    }
}
