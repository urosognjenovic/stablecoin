// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployZeni} from "../../script/DeployZeni.s.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZeniEngineTest is Test {
    DeployZeni private s_deployer;
    Zeni private s_zeni;
    ZeniEngine private s_zeniEngine;
    HelperConfig private s_config;
    uint256 private constant COLLATERAL_AMOUNT = 5e18;
    uint256 private s_decimalsPrecision;
    address private immutable i_alice = makeAddr("Alice");
    address private constant INVALID_COLLATERAL_ADDRESS = address(1);
    uint256 private constant AMOUNT = 10e18;

    modifier aliceDepositedCollateral() {
        address collateral = s_config.getActiveConfig().collaterals[0];
        ERC20Mock(collateral).mint(i_alice, COLLATERAL_AMOUNT);
        vm.startPrank(i_alice);
        ERC20Mock(collateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        s_zeniEngine.depositCollateral(collateral, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function setUp() external {
        s_deployer = new DeployZeni();
        (s_zeni, s_zeniEngine, s_config) = s_deployer.run();
        s_decimalsPrecision = 10 ** s_config.DECIMALS();
    }

    function testGetCollateralValueInUSD() external view {
        address token = s_config.getActiveConfig().collaterals[0];
        uint256 actualCollateralValueInUSD = s_zeniEngine.getCollateralValueInUSD(token, COLLATERAL_AMOUNT);
        uint256 expectedCollateralValueInUSD = (COLLATERAL_AMOUNT * uint256(s_config.ETH_USD_INITIAL_ANSWER())) /
            s_decimalsPrecision;
        assertEq(actualCollateralValueInUSD, expectedCollateralValueInUSD);
    }

    function testDepositCollateralRevertsIfCollateralNotSupported() external {
        vm.prank(i_alice);
        vm.expectRevert(ZeniEngine.ZeniEngine__CollateralNotSupported.selector);
        s_zeniEngine.depositCollateral(INVALID_COLLATERAL_ADDRESS, AMOUNT);
    }

    function testDepositCollateralRevertsIfCollateralAmountIsZero() external {
        address collateral = s_config.getActiveConfig().collaterals[0];
        ERC20Mock(collateral).mint(i_alice, COLLATERAL_AMOUNT);
        vm.startPrank(i_alice);
        ERC20Mock(collateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(ZeniEngine.ZeniEngine__AmountIsZero.selector);
        s_zeniEngine.depositCollateral(collateral, 0);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesBalanceAndEmitsEvent() external {
        address collateral = s_config.getActiveConfig().collaterals[0];
        ERC20Mock(collateral).mint(i_alice, COLLATERAL_AMOUNT);
        vm.startPrank(i_alice);
        ERC20Mock(collateral).approve(address(s_zeniEngine), COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, false, true);
        emit ZeniEngine.CollateralDeposited(i_alice, collateral, COLLATERAL_AMOUNT);
        s_zeniEngine.depositCollateral(collateral, COLLATERAL_AMOUNT);
        vm.stopPrank();
        assertEq(s_zeniEngine.getCollateralBalance(i_alice, collateral), COLLATERAL_AMOUNT);
    }
}
