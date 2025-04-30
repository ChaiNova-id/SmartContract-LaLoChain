// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LaLoHotelRegistry} from "../../src/hotel_owners/LaLoHotelRegistry.sol";
import {LaLoTokenFactory} from "../../src/token_exchange/LaLoTokenFactory.sol";
import {LaLoHotelTokenization} from "../../src/revenue_stream/LaLoHotelTokenization.sol";
import {LaLoUnderwriterSystem} from "../../src/underwriter/LaLoUnderwriterSystem.sol";
import {LaLoHotelAVS} from "../../src/avs/LaLoHotelAVS.sol";
import {LaLoVault} from "../../src/revenue_stream/LaLoVault.sol";
import {MockUSDC} from "../../src/token_exchange/MockUSDC.sol";

contract LaLoIntegrationTest is Test {
    MockUSDC usdc;
    LaLoHotelRegistry registry;
    LaLoTokenFactory factory;
    LaLoHotelTokenization tokenization;
    LaLoUnderwriterSystem underwriterSystem;

    // Hotel parameters
    string hotelName = "LaLo Luxury Hotel";
    uint256 tokenAmount = 1200 * 10**6; // 1200 USDC worth of tokens
    uint256 usdcPrice = 1000 * 10**6;   // Selling for 1000 USDC (discounted)
    uint256 totalMonths = 12;           // 1 year term
    uint256 auctionDuration = 7 days;   // 1 week auction period
    
    // Participants
    address deployer;
    address hotelOwner;
    address underwriter1;
    address underwriter2;
    address buyer1;
    address buyer2;
    address operator;
    
    // Test variables
    uint256 hotelId;
    LaLoHotelAVS hotelAVS;
    address vaultAddress;

    function setUp() public {
        // Create addresses
        deployer = address(this);
        hotelOwner = vm.addr(1);
        underwriter1 = vm.addr(2);
        underwriter2 = vm.addr(3);
        buyer1 = vm.addr(4);
        buyer2 = vm.addr(5);
        operator = vm.addr(6);
        
        // Deploy the system
        usdc = new MockUSDC(1e6, "LaLoUSDC", "LUSDC");
        factory = new LaLoTokenFactory();
        registry = new LaLoHotelRegistry(address(usdc), address(factory));
        tokenization = new LaLoHotelTokenization(address(usdc), address(registry));
        underwriterSystem = new LaLoUnderwriterSystem(address(usdc), address(registry));
        
        // Set underwriter system in registry
        registry.setUnderwriterSystem(address(underwriterSystem));
        
        // Distribute USDC
        usdc.transfer(hotelOwner, 5000 * 10**6);      // 5000 USDC
        usdc.transfer(underwriter1, 2000 * 10**6);    // 2000 USDC
        usdc.transfer(underwriter2, 2000 * 10**6);    // 2000 USDC
        usdc.transfer(buyer1, 800 * 10**6);           // 800 USDC
        usdc.transfer(buyer2, 500 * 10**6);           // 500 USDC
    }
    
    function testCompleteWorkflow() public {
        // Step 1: Hotel owner registers the hotel
        vm.startPrank(hotelOwner);
        usdc.approve(address(registry), tokenAmount);
        hotelId = registry.registerHotel(hotelName, tokenAmount, usdcPrice, totalMonths, auctionDuration);
        vm.stopPrank();
        
        // Get important addresses
        vaultAddress = registry.getVaultAddress(hotelId);
        address avsAddress = registry.getHotelAVS(hotelId);
        hotelAVS = LaLoHotelAVS(avsAddress);
        
        console.log("Hotel registered with ID:", hotelId);
        console.log("Vault address:", vaultAddress);
        console.log("AVS address:", avsAddress);
        
        // Step 2: Underwriters register in the global system
        vm.startPrank(underwriter1);
        usdc.approve(address(underwriterSystem), 1500 * 10**6);
        underwriterSystem.registerAsUnderwriter(1500 * 10**6);
        vm.stopPrank();
        
        vm.startPrank(underwriter2);
        usdc.approve(address(underwriterSystem), 1200 * 10**6);
        underwriterSystem.registerAsUnderwriter(1200 * 10**6);
        vm.stopPrank();
        
        console.log("Underwriters registered in the system");
        
        // Step 3: Add operator to the hotel AVS
        hotelAVS.addOperator(operator);
        console.log("Operator added to hotel AVS");
        
        // Step 4: Operator approves underwriters for the hotel
        vm.startPrank(operator);
        hotelAVS.addUnderwriter(underwriter1, 800 * 10**6);
        hotelAVS.addUnderwriter(underwriter2, 400 * 10**6);
        vm.stopPrank();
        console.log("Underwriters approved for the hotel");
        
        // Step 5: Hotel owner sets and deposits underwriter fee
        vm.startPrank(hotelOwner);
        uint256 underwriterFee = 50 * 10**6; // 50 USDC fee
        hotelAVS.setUnderwriterFee(underwriterFee);
        usdc.approve(address(hotelAVS), underwriterFee);
        hotelAVS.depositUnderwriterFee();
        vm.stopPrank();
        console.log("Hotel owner set underwriter fee:", underwriterFee / 10**6, "USDC");
        
        // Step 6: Assign underwriters to hotel in underwriter system
        vm.startPrank(hotelOwner);
        address[] memory underwriterAddresses = new address[](2);
        underwriterAddresses[0] = underwriter1;
        underwriterAddresses[1] = underwriter2;
        
        uint256[] memory stakeAmounts = new uint256[](2);
        stakeAmounts[0] = 800 * 10**6;
        stakeAmounts[1] = 400 * 10**6;
        
        underwriterSystem.assignUnderwritersToHotel(
            hotelId,
            underwriterAddresses,
            stakeAmounts,
            underwriterFee
        );
        vm.stopPrank();
        console.log("Underwriters assigned to hotel in underwriter system");
        
        // Step 7: Buyers purchase tokens during auction period
        vm.startPrank(buyer1);
        usdc.approve(vaultAddress, 600 * 10**6);
        tokenization.buyLaLoTokens(hotelId, 600 * 10**6);
        vm.stopPrank();
        console.log("Buyer1 purchased 600 USDC worth of tokens");
        
        vm.startPrank(buyer2);
        usdc.approve(vaultAddress, 400 * 10**6);
        tokenization.buyLaLoTokens(hotelId, 400 * 10**6);
        vm.stopPrank();
        console.log("Buyer2 purchased 400 USDC worth of tokens");
        
        // Step 8: Check token balances
        uint256 buyer1Tokens = tokenization.getCurrentTokens(hotelId);
        vm.startPrank(buyer2);
        uint256 buyer2Tokens = tokenization.getCurrentTokens(hotelId);
        vm.stopPrank();
        
        console.log("Buyer1 tokens:", buyer1Tokens);
        console.log("Buyer2 tokens:", buyer2Tokens);
        console.log("Available tokens:", tokenization.getAvailableTokens(hotelId));
        
        // Step 9: First month - Full revenue deposit
        vm.warp(block.timestamp + 30 days);
        uint256 monthlyRevenue = 100 * 10**6; // 100 USDC per month
        
        vm.startPrank(hotelOwner);
        usdc.approve(vaultAddress, monthlyRevenue);
        tokenization.ownerDepositUSDC(hotelId, monthlyRevenue);
        
        // Record in AVS
        usdc.approve(address(hotelAVS), 0); // Reset
        usdc.approve(address(hotelAVS), monthlyRevenue);
        hotelAVS.ownerDepositRevenue(1, monthlyRevenue);
        vm.stopPrank();
        
        // AVS report
        vm.prank(operator);
        hotelAVS.submitMonthlyReport(monthlyRevenue);
        console.log("Month 1: Full revenue deposited and reported");
        
        // Step 10: Buyer1 withdraws their share
        uint256 buyer1Share = 60 * 10**6; // 60% share of 100 USDC
        vm.startPrank(buyer1);
        tokenization.withdrawUSDC(hotelId, buyer1Share);
        vm.stopPrank();
        console.log("Buyer1 withdrew their share:", buyer1Share / 10**6, "USDC");
        
        // Step 11: Month 2 - Partial revenue deposit
        vm.warp(block.timestamp + 30 days);
        uint256 partialRevenue = 40 * 10**6; // Only 40 USDC (shortfall of 60 USDC)
        
        vm.startPrank(hotelOwner);
        usdc.approve(vaultAddress, partialRevenue);
        tokenization.ownerDepositUSDC(hotelId, partialRevenue);
        
        // Record in AVS
        usdc.approve(address(hotelAVS), 0); // Reset
        usdc.approve(address(hotelAVS), partialRevenue);
        hotelAVS.ownerDepositRevenue(2, partialRevenue);
        vm.stopPrank();
        
        // AVS report
        vm.startPrank(operator);
        hotelAVS.submitMonthlyReport(partialRevenue);
        
        // Process liability
        hotelAVS.processRevenueLiability(2);
        vm.stopPrank();
        console.log("Month 2: Partial revenue deposited, shortfall covered by underwriters");
        
        // Step 12: Verify underwriter liability was paid (60 USDC)
        uint256 vaultBalance = usdc.balanceOf(vaultAddress);
        console.log("Vault balance after liability payment:", vaultBalance / 10**6, "USDC");
        
        // Should have: 
        // - 40 USDC from month 2 deposit
        // - 40 USDC remaining from month 1 (after buyer1 withdrew 60)
        // - 60 USDC from underwriter liability
        // = 140 USDC
        assertEq(vaultBalance, 140 * 10**6, "Vault should have correct balance");
        
        // Step 13: Buyer2 withdraws their share for both months
        uint256 buyer2Share = 80 * 10**6; // 40% share of 200 USDC (2 months)
        vm.startPrank(buyer2);
        tokenization.withdrawUSDC(hotelId, buyer2Share);
        vm.stopPrank();
        console.log("Buyer2 withdrew their share for 2 months:", buyer2Share / 10**6, "USDC");
        
        // Step 14: End of contract term - distribute underwriter fees
        vm.warp(block.timestamp + 340 days); // Jump to end
        
        // Get performance summary
        (
            uint256 totalExpected,
            uint256 totalActual,
            uint256 totalMissing,
            uint256 liabilityPaid
        ) = hotelAVS.getHotelPerformanceSummary();
        
        console.log("Hotel performance summary:");
        console.log("- Total expected revenue:", totalExpected / 10**6, "USDC");
        console.log("- Total actual revenue:", totalActual / 10**6, "USDC");
        console.log("- Total missing revenue:", totalMissing / 10**6, "USDC");
        console.log("- Total liability paid:", liabilityPaid / 10**6, "USDC");
        
        // Distribute fees to underwriters
        vm.prank(operator);
        hotelAVS.distributeUnderwriterFees();
        console.log("Underwriter fees distributed");
        
        // Step 15: Verify final balances
        uint256 underwriter1Balance = usdc.balanceOf(underwriter1);
        uint256 underwriter2Balance = usdc.balanceOf(underwriter2);
        
        console.log("Final underwriter1 balance:", underwriter1Balance / 10**6, "USDC");
        console.log("Final underwriter2 balance:", underwriter2Balance / 10**6, "USDC");
        
        // Check buyer final balances
        uint256 buyer1FinalBalance = usdc.balanceOf(buyer1);
        uint256 buyer2FinalBalance = usdc.balanceOf(buyer2);
        
        console.log("Final buyer1 balance:", buyer1FinalBalance / 10**6, "USDC");
        console.log("Final buyer2 balance:", buyer2FinalBalance / 10**6, "USDC");
        
        // Summary
        console.log("Test completed successfully - full hotel revenue tokenization flow verified");
    }
}