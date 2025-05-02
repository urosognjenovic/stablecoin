// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Zeni} from "../../src/Zeni.sol";

contract ZeniTest is Test {
    Zeni private s_zeni;
    address private i_alice = makeAddr("Alice");
    address private constant ADDRESS_ZERO = address(0);
    uint256 private constant MINT_AMOUNT = 10e18;
    uint256 private constant BURN_AMOUNT = 10e18;
    uint256 private constant BURN_AMOUNT_GREATER_THAN_MINT_AMOUNT = 20e18;
    uint256 private constant ZERO_AMOUNT = 0;

    modifier prankAddressThis() {
        vm.prank(address(this));
        _;
    }

    modifier startStopPrankAddressThis() {
        vm.startPrank(address(this));
        _;
        vm.stopPrank();
    }

    function setUp() external {
        s_zeni = new Zeni();
    }

    function testMintFailsWhenToIsAddressZero() external prankAddressThis {
        vm.expectRevert(Zeni.Zeni__MintingToZeroAddress.selector);
        s_zeni.mint(ADDRESS_ZERO, MINT_AMOUNT);
    }

    function testMintFailsWhenAmountIsZero() external prankAddressThis {
        vm.expectRevert(Zeni.Zeni__AmountIsZero.selector);
        s_zeni.mint(i_alice, ZERO_AMOUNT);
    }

    function testMintUpdatesStateVariables() external prankAddressThis {
        s_zeni.mint(i_alice, MINT_AMOUNT);
    }

    function testBurnFailsWhenAmountIsZero() external prankAddressThis {
        vm.expectRevert(Zeni.Zeni__AmountIsZero.selector);
        s_zeni.burn(ZERO_AMOUNT);
    }

    function testBurnFailsWhenAmountIsGreaterThanBalance() external startStopPrankAddressThis {
        s_zeni.mint(address(this), MINT_AMOUNT);
        s_zeni.burn(BURN_AMOUNT);
    }

    function testBurn() external startStopPrankAddressThis {
        s_zeni.mint(address(this), MINT_AMOUNT);
        vm.expectRevert(Zeni.Zeni__BurnAmountExceedsBalance.selector);
        s_zeni.burn(BURN_AMOUNT_GREATER_THAN_MINT_AMOUNT);
    }
}
