// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPositionManager {
    function AddPositionData(uint256 position_id, uint256 notional_amount, uint256 margin_amount, uint256 trading_time, uint256 swap_rate) external;
}