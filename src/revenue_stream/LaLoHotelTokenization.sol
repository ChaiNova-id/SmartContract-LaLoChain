// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHotelTokenization} from "./IHotelTokenization.sol";
import {IHotelRegistry} from "../hotel_owners/IHotelRegistry.sol";
import {LaLoHotelRegistry} from "../hotel_owners/LaLoHotelRegistry.sol";
import {LaLoVault} from "../revenue_stream/LaLoVault.sol";

contract LaLoHotelTokenization is IHotelTokenization {
    IERC20 public usdcToken;
    LaLoHotelRegistry public hotelRegistry;

    constructor(
        address _usdcToken,
        address _hotelRegistry
    ) {
        usdcToken = IERC20(_usdcToken);
        hotelRegistry = LaLoHotelRegistry(_hotelRegistry);
    }

    modifier onlyRegisteredHotel(uint256 hotelId) {
        if (!hotelRegistry.isHotelRegistered(hotelId)) {
            revert HotelNotRegistered();
        }
        _;
    }

    function buyLaLoTokens(uint256 hotelId, uint256 buyInUSDC) external onlyRegisteredHotel(hotelId) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Withdraw shares (LaLoVault will burn and send USDC)
        vault.buyShares(
            msg.sender,
            buyInUSDC
        );

        emit TokensBought(
            hotelId,
            msg.sender,
            buyInUSDC
        );
    }

    function withdrawUSDC(uint256 hotelId, uint256 withdrawInUSDC) external onlyRegisteredHotel(hotelId) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Withdraw shares (LaLoVault will burn and send USDC)
        vault.withdraw(
            msg.sender,
            withdrawInUSDC
        );

        emit USDCWithdrawn(
            hotelId,
            msg.sender,
            withdrawInUSDC
        );
    }

    function getAvailableCurrency(uint256 hotelId) external view returns (uint256 llot, uint256 usdc) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get LLoT
        llot = vault.getAvailableTokens();

        // Get USDC
        usdc = vault.getAvailableRevenues();
    }

    function getTransferLimit(uint256 hotelId) external view returns (uint256 limit) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        limit = vault.getTransferLimit(msg.sender);
    }

    function getVaultAddress(uint256 hotelId) external view returns (address vaultAddress) {
        return hotelRegistry.getVaultAddress(hotelId);
    }

    // Testing purposes
    function setMonthTest(uint256 hotelId, uint256 month) external {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Set
        vault.setTestPurposes(msg.sender, month);
    }

    function getMonthTest(uint256 hotelId) external view returns (uint256 month) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        month = vault.getMonths();
    }
}
