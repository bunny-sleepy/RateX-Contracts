// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPositionManager {
    struct TraderPosition {
        uint256 idx; // idx to get from positions[idx]
        uint256 swap_rate;
        uint256 notional_amount;
        uint256 margin_amount;
        bool is_fixed_receiver;
        bool is_liquidable;
        int256 PnL;
        uint256 health_factor;
    }
    function IncreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external returns (uint256 old_amount, uint256 new_amount);
    function DecreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external returns (uint256 old_amount, uint256 new_amount);
    function LiquidatePosition() external;
    function AddPosition(address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate, bool is_fixed_rate_receiver) external returns(uint256 position_id);
    function AddPositionData(uint256 position_id, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate) external;
    function ClosePosition(address trader_address, uint256 position_id) external;
    function RedeemMargin(uint position_id) external returns (uint256 margin_amount);
    function GetTraderPositionList(address trader_address) external view returns (TraderPosition[] memory);
}