// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPositionManager {
    function IncreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external returns (uint256 old_amount, uint256 new_amount);
    function DecreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external returns (uint256 old_amount, uint256 new_amount);
    function LiquidatePosition() external;
    function AddPosition(address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate, bool is_fixed_rate_receiver) external returns(uint256 position_id);
    function AddPositionData(uint256 position_id, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate) external;
}