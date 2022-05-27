// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IInsuranceFund {
    function TransferLiquidationBonus(uint256 notional_amount) external returns (uint256);
}