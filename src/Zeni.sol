// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Zeni
/// @author Uroš Ognjenović
/// @notice This is a decentralized stablecoin that is pegged to $1 (1 USD) and collateralized by WETH and WBTC. This contract is governed by the ZeniEngine contract. Zeni is the main currency used on Earth in Dragon Ball.
/// @custom:collateral WETH and WBTC
contract Zeni is ERC20Burnable, Ownable {
    error Zeni__AmountIsZero();
    error Zeni__BurnAmountExceedsBalance();
    error Zeni__MintingToZeroAddress();

    constructor() ERC20("Zeni", "ZENI") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        require(to != address(0), Zeni__MintingToZeroAddress());
        require(amount != 0, Zeni__AmountIsZero());
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOwner {
        require(amount > 0, Zeni__AmountIsZero());
        uint256 balance = balanceOf(msg.sender);
        require(balance >= amount, Zeni__BurnAmountExceedsBalance());
        super.burn(amount);
    }
}
