// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Decentralized Stablecoin
/// @author Uroš Ognjenović
/// @notice This is a decentralized stablecoin that is pegged to $1 (1 USD) and collateralized by WETH and WBTC. This contract is governed by the StablecoinEngine contract.
/// @custom:collateral WETH and WBTC
contract Stablecoin is ERC20Burnable, Ownable {
    error Stablecoin__AmountIsZero();
    error Stablecoin__BurnAmountExceedsBalance();
    error Stablecoin__MintingToZeroAddress();

    constructor() ERC20("Decentralized Stablecoin", "DSC") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        require(to != address(0), Stablecoin__MintingToZeroAddress());
        require(amount != 0, Stablecoin__AmountIsZero());
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOwner {
        require(amount > 0, Stablecoin__AmountIsZero());
        uint256 balance = balanceOf(msg.sender);
        require(balance >= amount, Stablecoin__BurnAmountExceedsBalance());
        super.burn(amount);
    }
}
