// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";

contract Handler is Test {
    ZeniEngine private s_zeniEngine;
    Zeni private s_zeni;
    address private s_firstCollateralPriceFeed;

    address[] private s_supportedCollaterals;
    address[] private s_depositors;
    uint256 private constant MAXIMUM_DEPOSIT_AMOUNT = type(uint96).max;
    uint256 private constant MINIMUM_DEPOSIT_AMOUNT = 1;
    uint256 private constant MINIMUM_REDEEM_AMOUNT = 0;
    uint256 private constant MINIMUM_MINT_AMOUNT = 0;

    constructor(ZeniEngine zeniEngine, Zeni zeni) {
        s_zeniEngine = zeniEngine;
        s_zeni = zeni;
        s_supportedCollaterals = s_zeniEngine.getSupportedCollaterals();
        s_firstCollateralPriceFeed = s_zeniEngine.getPriceFeed(s_supportedCollaterals[0]);
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) external {
        address collateral = _pickCollateralFromSeed(collateralSeed);
        collateralAmount = bound(collateralAmount, MINIMUM_DEPOSIT_AMOUNT, MAXIMUM_DEPOSIT_AMOUNT);
        vm.startPrank(msg.sender);
        ERC20Mock(collateral).mint(msg.sender, collateralAmount);
        ERC20Mock(collateral).approve(address(s_zeniEngine), collateralAmount);
        s_zeniEngine.depositCollateral(collateral, collateralAmount);
        vm.stopPrank();
        s_depositors.push(msg.sender);
    }

    function mintZeni(uint256 amount, uint256 depositorSeed) external {
        address user = _pickRandomDepositor(depositorSeed);
        vm.assume(user != address(0));
        uint256 collateralValueInUSD = s_zeniEngine.getAccountCollateralValueInUSD(user);
        uint256 zeniMinted = s_zeniEngine.getAmountMinted(user);
        int256 maximumAmountToMint = int256(collateralValueInUSD / 2 - zeniMinted);

        vm.assume(maximumAmountToMint > 0);
        amount = bound(amount, MINIMUM_MINT_AMOUNT, uint256(maximumAmountToMint));
        vm.assume(amount > 0);
        vm.prank(user);
        s_zeniEngine.mintZeni(amount);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 collateralAmount) external {
        address collateral = _pickCollateralFromSeed(collateralSeed);
        uint256 userCollateralBalance = s_zeniEngine.getCollateralBalance(msg.sender, collateral);
        collateralAmount = bound(collateralAmount, MINIMUM_REDEEM_AMOUNT, userCollateralBalance);
        if (collateralAmount == 0) {
            return;
        }
        vm.prank(msg.sender);
        s_zeniEngine.redeemCollateral(collateral, collateralAmount);
    }

    function _pickCollateralFromSeed(uint256 collateralSeed) private view returns (address collateral) {
        uint256 collateralsLength = s_supportedCollaterals.length;
        uint256 collateralIndex = collateralSeed % collateralsLength;
        collateral = s_supportedCollaterals[collateralIndex];
        return collateral;
    }

    function _pickRandomDepositor(uint256 depositorSeed) private view returns (address depositor) {
        uint256 length = s_depositors.length;
        if (length != 0) {
            return s_depositors[depositorSeed % length];
        }
    }
}
