// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract PositionManager {

    uint256 constant public PRICE_PRECISION = 1e6;
    uint256 constant public RATE_PRECISION = 1e4; // maximum allow 0.01% rate for order

    struct PositionTimeData {
        uint256 notional_amount; // amount of notional with 1e6 precision
        uint256 margin_amount; // amount of margin with 1e6 precision
        uint256 trading_time; // trading time
        uint256 swap_rate; // swap rate with 1e4 precision
    }

    struct PositionInfo {
        address trader_address; // address of trader
        PositionTimeData[] data;
        bool is_fixed_rate_receiver; // true if trader is fixed rate receiver, false if trader is variable rate receiver
        bool is_liquidable; // true if trader wants to liquidate this order, originally set to false
    }

    PositionInfo[] positions;
    mapping(uint256 => bool) position_valid;

    modifier PositionValid(uint position_id) {
        require(position_valid[position_id] == true, "Position invalid");
        _;
    }

    function IncreaseMargin(uint position_id, uint256 margin_amount) external PositionValid(position_id) {

    }

    function DecreaseMargin(uint position_id, uint256 margin_amount) external PositionValid(position_id) {

    }

    function LiquidatePosition() external PositionValid(position_id) {

    }

    function AddPositionData(
        uint256 position_id,
        uint256 notional_amount,
        uint256 margin_amount,
        uint256 trading_time,
        uint256 swap_rate
    ) external PositionValid(position_id) {

    }

}