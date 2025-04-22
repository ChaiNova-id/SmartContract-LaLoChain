// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/HotelRegistry.sol";
import "../src/RevenueTokenFactory.sol";

contract HotelRegistryTest is Test {
    HotelRegistry registry;
    RevenueTokenFactory factory;
    address overwriter = address(0xBEEF);
    address hotelOwner = address(0xCAFE);

    function setUp() public {
        factory = new RevenueTokenFactory();
        registry = new HotelRegistry(address(factory));
        registry.grantRole(registry.OVERWRITER_ROLE(), overwriter);
        vm.deal(hotelOwner, 10 ether);
    }

    function testRegisterHotel() public {
        vm.prank(hotelOwner);
        registry.registerHotel{value: 1 ether}();
        (address owner,,) = registry.hotels(0);
        assertEq(owner, hotelOwner);
    }

    function testApproveHotelCreatesToken() public {
        vm.prank(hotelOwner);
        registry.registerHotel{value: 1 ether}();

        vm.prank(overwriter);
        registry.approveHotel(0);

        address tokenAddr = registry.hotelToToken(0);
        assertTrue(tokenAddr != address(0));
    }

    function testBookingHotel() public {
        vm.prank(hotelOwner);
        registry.registerHotel{value: 1 ether}();

        vm.prank(overwriter);
        registry.approveHotel(0);

        vm.deal(address(this), 1 ether);
        registry.bookHotel{value: 0.1 ether}(0);
    }
}
