// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Interface/IPool.sol";

contract PositionManager {

    uint256 constant public PRICE_PRECISION = 1e6;
    uint256 constant public RATE_PRECISION = 1e4; // maximum allow 0.01% rate for order

    address pool_address;

    struct PositionTimeData {
        uint256 notional_amount; // amount of notional with 1e6 precision
        uint256 trading_time; // trading time
        uint256 swap_rate; // swap rate with 1e4 precision
    }

    struct PositionInfo {
        uint256 margin_amount; // amount of margin with 1e6 precision
        address trader_address; // address of trader
        mapping(uint256 => PositionTimeData) data;
        uint256 num_data;
        bool is_fixed_receiver; // true if trader is fixed rate receiver, false if trader is variable rate receiver
        bool is_liquidable; // true if trader wants to liquidate this order, originally set to false
    }

    mapping(uint256 => PositionInfo) positions;
    mapping(uint256 => bool) position_valid;
    uint256 public num_positions;

    modifier PositionValid(uint position_id) {
        require(position_valid[position_id] == true, "Position invalid");
        _;
    }

    modifier OnlyPositionOwner(address trader_address, uint position_id) {
        require(positions[position_id].trader_address == trader_address, "Only Position Owner");
        _;
    }

    modifier OnlyPool() {
        require(msg.sender == pool_address, "Not pool");
        _;
    }

    constructor(address _pool_address) {
        require(_pool_address != address(0), "Zero address detected");
        pool_address = _pool_address;
    }

    function GetPositionInfo(uint position_id) external view PositionValid(position_id) returns (uint256 margin_amount, address trader_address, uint256 num_data, bool is_fixed_receiver, bool is_liquidable) {
        margin_amount = positions[position_id].margin_amount;
        trader_address = positions[position_id].trader_address;
        num_data = positions[position_id].num_data;
        is_fixed_receiver = positions[position_id].is_fixed_receiver;
        is_liquidable = positions[position_id].is_liquidable;
    }

    function GetPositionTimeData(uint position_id, uint data_id) external view PositionValid(position_id) returns (uint256 notional_amount, uint256 trading_time, uint256 swap_rate) {
        uint num_data = positions[position_id].num_data;
        require(num_data > data_id, "Data ID invalid");
        notional_amount = positions[position_id].data[data_id].notional_amount;
        trading_time = positions[position_id].data[data_id].trading_time;
        swap_rate = positions[position_id].data[data_id].swap_rate;
    }

    // returns 1e6 view
    function GetPositionHealthFactor(uint position_id) external view PositionValid(position_id) returns (uint256 factor) {
        uint256 margin_amount = positions[position_id].margin_amount;
        uint num_data = positions[position_id].num_data;
        uint256 notional_amount = 0;
        uint256 time = block.timestamp;
        IPool pool = IPool(pool_address);
        require(time < pool.end_time(), "Time unavailable");
        for (uint i = 0; i < num_data; i++) {
            notional_amount += positions[position_id].data[i].notional_amount;
        }
        if (notional_amount == 0) {
            factor = 0;
        } else {
            uint256 time_diff = pool.end_time() - time;
            uint256 rate_diff = pool.rate_upper() - pool.rate_lower();
            factor = margin_amount * (365 * 86400) * RATE_PRECISION * PRICE_PRECISION / time_diff / notional_amount / rate_diff;
        }
    }

    function IncreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external OnlyPool PositionValid(position_id) OnlyPositionOwner(trader_address, position_id) returns (uint256 old_amount, uint256 new_amount) {
        old_amount = positions[position_id].margin_amount;
        positions[position_id].margin_amount += margin_amount;
        new_amount = positions[position_id].margin_amount;
        emit MarginUpdate(trader_address, position_id, old_amount, new_amount);
    }

    function DecreaseMargin(address trader_address, uint position_id, uint256 margin_amount) external OnlyPool PositionValid(position_id) OnlyPositionOwner(trader_address, position_id) returns (uint256 old_amount, uint256 new_amount) {
        require(positions[position_id].margin_amount >= margin_amount, "Margin exceeds");
        old_amount = positions[position_id].margin_amount;
        positions[position_id].margin_amount -= margin_amount;
        new_amount = positions[position_id].margin_amount;
        emit MarginUpdate(trader_address, position_id, old_amount, new_amount);
    }

    function LiquidatePosition() external {
        for (uint i = 0; i < num_positions; i++) {
            if (position_valid[i] == true && positions[i].margin_amount == 0) {
                positions[i].is_liquidable = true;
                emit LiquidateUpdate(i);
            }
        }
    }

    function AddPosition(
        address trader_address,
        uint256 notional_amount,
        uint256 margin_amount,
        uint256 swap_rate,
        bool is_fixed_receiver
    ) external OnlyPool returns(uint256 position_id) {
        PositionTimeData memory data = PositionTimeData(
            notional_amount,
            block.timestamp,
            swap_rate
        );

        positions[num_positions].margin_amount = margin_amount;
        positions[num_positions].trader_address = trader_address;
        positions[num_positions].is_fixed_receiver = is_fixed_receiver;
        positions[num_positions].is_liquidable = false;
        positions[num_positions].data[0] = data;
        positions[num_positions].num_data = 1;

        position_valid[num_positions] = true;

        position_id = num_positions;
        num_positions += 1;
    }

    function AddPositionData(
        uint256 position_id,
        uint256 notional_amount,
        uint256 margin_amount,
        uint256 swap_rate
    ) external OnlyPool PositionValid(position_id) {
        PositionTimeData memory data = PositionTimeData(
            notional_amount,
            block.timestamp,
            swap_rate
        );
        positions[position_id].data[positions[position_id].num_data] = data;
        positions[position_id].margin_amount += margin_amount;
        positions[position_id].num_data += 1;
    }

    event MarginUpdate(address user, uint position_id, uint256 old_amount, uint256 new_amount);
    event LiquidateUpdate(uint position_id);
}