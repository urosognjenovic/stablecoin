// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

/// @title ZeniEngine
/// @author Uroš Ognjenović
/// @notice The system is designed to maintain the peg to 1 USD. Zeni stablecoin has the following properties: Exogenous Collateral, Dollar Peggeed, Algorithmically Stable. This contract is the core of the Zeni System. It handles all the logic for minting and burning Zeni, as well as depositing and withdrawing collateral. This contract is loosely based on the MakerDAO DAI stablecoin.
contract ZeniEngine {
    function depositCollateral() external {}

    function depositCollateralAndMintZeni() external {}

    function redeemCollateral() external {}

    function redeemCollateralForZeni() external {}

    function mintZeni() external {}

    function burnZeni() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
