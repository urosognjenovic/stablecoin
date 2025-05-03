// SDPX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployZeni} from "../../script/DeployZeni.s.sol";
import {Zeni} from "../../src/Zeni.sol";
import {ZeniEngine} from "../../src/ZeniEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract InvariantTest is StdInvariant, Test {
    DeployZeni private s_deployer;
    Zeni private s_zeni;
    ZeniEngine private s_zeniEngine;
    HelperConfig private s_helperConfig;
    Handler private s_handler;
    address[] private s_collaterals;

    function setUp() external {
        s_deployer = new DeployZeni();
        (s_zeni, s_zeniEngine, s_helperConfig) = s_deployer.run();
        s_collaterals = s_zeniEngine.getSupportedCollaterals();
        s_handler = new Handler(s_zeniEngine, s_zeni);
        targetContract(address(s_handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() external view {
        uint256 totalSupply = s_zeni.totalSupply();
        uint256 length = s_collaterals.length;
        uint256 totalCollateralValueInUSD;
        IERC20 collateral;

        for (uint256 i; i < length; ) {
            collateral = IERC20(s_collaterals[i]);
            totalCollateralValueInUSD += s_zeniEngine.getCollateralValueInUSD(
                s_collaterals[i],
                collateral.balanceOf(address(s_zeni))
            );
            unchecked {
                ++i;
            }
        }
        assert(totalCollateralValueInUSD >= totalSupply);
    }
}
