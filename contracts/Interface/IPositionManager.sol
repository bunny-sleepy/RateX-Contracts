// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPositionManager {
    function AddPosition(address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate, bool is_fixed_rate_receiver) external;
    function AddPositionData(uint256 position_id, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate) external;
}