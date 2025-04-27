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

    function buyLaLoTokens(uint256 _hotelId, uint256 _buyInUSDC) external onlyRegisteredHotel(_hotelId) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Withdraw shares (LaLoVault will burn and send USDC)
        vault.buyShares(
            msg.sender,
            _buyInUSDC
        );

        emit TokensBought(
            _hotelId,
            msg.sender,
            _buyInUSDC
        );
    }

    function withdrawUSDC(uint256 _hotelId, uint256 _withdrawInUSDC) external onlyRegisteredHotel(_hotelId) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Withdraw shares
        vault.withdraw(
            msg.sender,
            _withdrawInUSDC
        );

        emit USDCWithdrawn(
            _hotelId,
            msg.sender,
            _withdrawInUSDC
        );
    }

    function ownerDepositUSDC(uint256 _hotelId, uint256 _depositInUSDC) external onlyRegisteredHotel(_hotelId) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Deposit to ault
        vault.deposit(
            msg.sender,
            _depositInUSDC
        );

        emit USDCWithdrawn(
            _hotelId,
            msg.sender,
            _depositInUSDC
        );
    }

    function getAvailableTokens(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.getAvailableTokens();
    }

    function getAvailableRevenues(uint256 _hotelId) external view returns (uint256) {
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);
        LaLoVault vault = LaLoVault(vaultAddress);
        return vault.getAvailableRevenues();
    }

    function getTransferLimit(uint256 _hotelId) external view returns (uint256 limit) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        limit = vault.getTransferLimit(msg.sender);
    }

    function getVaultAddress(uint256 _hotelId) external view returns (address vaultAddress) {
        return hotelRegistry.getVaultAddress(_hotelId);
    }

    function getCurrentTokens(uint256 _hotelId) external view returns (uint256 lloTokens) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        lloTokens = vault.checkBalance(msg.sender);
    }

    function getCollectedRevenues(uint256 _hotelId) external view returns (uint256 usdcs) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        usdcs = vault.getClaimedRevenues(msg.sender);
    }

    function getRemainingPromisedRevenues(uint256 _hotelId) external view returns (uint256 remainingRevs) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        remainingRevs = vault.getRemainingPromisedRevenues();
    }

    // Testing purposes
    function setMonthTest(uint256 _hotelId, uint256 _month) external {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Set
        vault.setTestPurposes(msg.sender, _month);
    }

    function getMonthTest(uint256 _hotelId) external view returns (uint256 month) {
        // Get the vault address associated with the hotel
        address vaultAddress = hotelRegistry.getVaultAddress(_hotelId);

        // Cast the vault address to LaLoVault contract
        LaLoVault vault = LaLoVault(vaultAddress);

        // Get return value
        month = vault.getMonths();
    }
}
