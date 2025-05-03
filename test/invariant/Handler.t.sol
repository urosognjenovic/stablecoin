// SDPX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    ZeniEngine private s_zeniEngine;
    Zeni private s_zeni;
    address[] private s_supportedCollaterals;
    uint256 private constant MAXIMUM_DEPOSIT_SIZE = type(uint96).max;
    uint256 private constant MINIMUM_DEPOSIT_SIZE = 1;

    constructor(ZeniEngine zeniEngine, Zeni zeni) {
        s_zeniEngine = zeniEngine;
        s_zeni = zeni;
        s_supportedCollaterals = s_zeniEngine.getSupportedCollaterals();
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) external {
        address collateral = _pickCollateralFromSeed(collateralSeed);
        collateralAmount = bound(collateralAmount, MINIMUM_DEPOSIT_SIZE, MAXIMUM_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        ERC20Mock(collateral).mint(msg.sender, MAXIMUM_DEPOSIT_SIZE);
        ERC20Mock(collateral).approve(address(s_zeniEngine), collateralAmount);
        s_zeniEngine.depositCollateral(collateral, collateralAmount);
        vm.stopPrank();
    }

    function _pickCollateralFromSeed(uint256 collateralSeed) private view returns (address collateral) {
        uint256 collateralsLength = s_supportedCollaterals.length;
        uint256 collateralIndex = collateralSeed % collateralsLength;
        collateral = s_supportedCollaterals[collateralIndex];
        return collateral;
    }
}
