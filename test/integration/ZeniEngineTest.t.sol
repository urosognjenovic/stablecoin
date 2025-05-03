// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployZeni} from "../../script/DeployZeni.s.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZeniEngineTest is Test {
    // Contracts
    DeployZeni private s_deployer;
    Zeni private s_zeni;
    ZeniEngine private s_zeniEngine;
    HelperConfig private s_config;

    // Constants
    uint256 private constant COLLATERAL_AMOUNT = 5e18;
    uint256 private constant AMOUNT_TO_MINT = 2e18;
    uint256 private constant INVALID_AMOUNT_TO_MINT = 5000e18;
    uint256 private constant AMOUNT_TO_BURN = AMOUNT_TO_MINT;
    uint256 private constant VALID_AMOUNT_TO_WITHDRAW = 1e18;
    uint256 private constant ZERO_AMOUNT = 0;
    uint256 private constant FIRST_COLLATERAL_INDEX = 0;
    // Initialized in setUp()
    uint256 private s_decimalsPrecision;
    address private s_firstCollateral;
    // Addresses for interactions
    address private immutable i_alice = makeAddr("Alice");
    address private immutable i_invalidCollateralAddress = makeAddr("Invalid Collateral Address");

    modifier prankAlice() {
        vm.prank(i_alice);
        _;
    }

    modifier startStopPrankAlice() {
        vm.startPrank(i_alice);
        _;
        vm.stopPrank();
    }

    modifier mintedCollateralToAlice() {
        ERC20Mock(s_firstCollateral).mint(i_alice, COLLATERAL_AMOUNT);
        _;
    }

    modifier aliceDepositedCollateral() {
        vm.startPrank(i_alice);
        ERC20Mock(s_firstCollateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        s_zeniEngine.depositCollateral(s_firstCollateral, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier aliceMintedZeni() {
        vm.prank(i_alice);
        s_zeniEngine.mintZeni(AMOUNT_TO_MINT);
        _;
    }

    function setUp() external {
        s_deployer = new DeployZeni();
        (s_zeni, s_zeniEngine, s_config) = s_deployer.run();
        s_decimalsPrecision = 10 ** s_config.DECIMALS();
        s_firstCollateral = s_config.getActiveConfig().collaterals[FIRST_COLLATERAL_INDEX];
    }

    function testGetCollateralValueInUSD() external view {
        uint256 actualCollateralValueInUSD = s_zeniEngine.getCollateralValueInUSD(s_firstCollateral, COLLATERAL_AMOUNT);
        uint256 expectedCollateralValueInUSD = (COLLATERAL_AMOUNT * uint256(s_config.ETH_USD_INITIAL_ANSWER())) /
            s_decimalsPrecision;
        assertEq(actualCollateralValueInUSD, expectedCollateralValueInUSD);
    }

    function testDepositCollateralRevertsIfCollateralNotSupported() external prankAlice {
        vm.expectRevert(ZeniEngine.ZeniEngine__CollateralNotSupported.selector);
        s_zeniEngine.depositCollateral(i_invalidCollateralAddress, COLLATERAL_AMOUNT);
    }

    function testDepositCollateralRevertsIfCollateralAmountIsZero() external mintedCollateralToAlice {
        vm.startPrank(i_alice);
        ERC20Mock(s_firstCollateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(ZeniEngine.ZeniEngine__AmountIsZero.selector);
        s_zeniEngine.depositCollateral(s_firstCollateral, FIRST_COLLATERAL_INDEX);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesBalanceAndEmitsEvent() external mintedCollateralToAlice {
        vm.startPrank(i_alice);
        ERC20Mock(s_firstCollateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit ZeniEngine.CollateralDeposited(i_alice, s_firstCollateral, COLLATERAL_AMOUNT);
        s_zeniEngine.depositCollateral(s_firstCollateral, COLLATERAL_AMOUNT);
        vm.stopPrank();
        assertEq(s_zeniEngine.getCollateralBalance(i_alice, s_firstCollateral), COLLATERAL_AMOUNT);
    }

    function testRedeemCollateralRevertsWhenAmountIsZero() external {
        vm.expectRevert(ZeniEngine.ZeniEngine__AmountIsZero.selector);
        s_zeniEngine.redeemCollateral(s_firstCollateral, ZERO_AMOUNT);
    }

    function testRedeemCollateralRevertsWhenMinimumHealthFactorIsBelowMinimumThreshold()
        external
        mintedCollateralToAlice
        aliceDepositedCollateral
        aliceMintedZeni
        prankAlice
    {
        vm.expectRevert(ZeniEngine.ZeniEngine__HealthFactorBelowMinimumThreshold.selector);
        s_zeniEngine.redeemCollateral(s_firstCollateral, COLLATERAL_AMOUNT);
    }

    function testRedeemCollateral()
        external
        mintedCollateralToAlice
        aliceDepositedCollateral
        aliceMintedZeni
        prankAlice
    {
        s_zeniEngine.redeemCollateral(s_firstCollateral, VALID_AMOUNT_TO_WITHDRAW);
    }

    function testMintZeniRevertsWhenAmountIsZero() external prankAlice {
        vm.expectRevert(ZeniEngine.ZeniEngine__AmountIsZero.selector);
        s_zeniEngine.redeemCollateral(s_firstCollateral, ZERO_AMOUNT);
    }

    function testMintZeniRevertsWhenHealthFactorIsBelowMinimumThreshold()
        external
        mintedCollateralToAlice
        aliceDepositedCollateral
        prankAlice
    {
        vm.expectRevert(ZeniEngine.ZeniEngine__HealthFactorBelowMinimumThreshold.selector);
        s_zeniEngine.mintZeni(INVALID_AMOUNT_TO_MINT);
    }

    function testMintZeni() external mintedCollateralToAlice aliceDepositedCollateral prankAlice {
        s_zeniEngine.mintZeni(AMOUNT_TO_MINT);
    }

    function testBurnZeniRevertsWhenAmountIsZero() external prankAlice {
        vm.expectRevert(ZeniEngine.ZeniEngine__AmountIsZero.selector);
        s_zeniEngine.burnZeni(ZERO_AMOUNT);
    }

    function testBurnZeni()
        external
        mintedCollateralToAlice
        aliceDepositedCollateral
        aliceMintedZeni
        startStopPrankAlice
    {
        s_zeni.approve(address(s_zeniEngine), AMOUNT_TO_BURN);
        s_zeniEngine.burnZeni(AMOUNT_TO_BURN);
    }

    function testDepositCollateralAndMintZeni() external mintedCollateralToAlice startStopPrankAlice {
        ERC20Mock(s_firstCollateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        s_zeniEngine.depositCollateralAndMintZeni(s_firstCollateral, COLLATERAL_AMOUNT, AMOUNT_TO_MINT);
    }
}
