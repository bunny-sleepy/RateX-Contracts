// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract PositionManager {

    uint256 constant public PRICE_PRECISION = 1e6;
    uint256 constant public RATE_PRECISION = 1e4; // maximum allow 0.01% rate for order

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
        bool is_fixed_rate_receiver; // true if trader is fixed rate receiver, false if trader is variable rate receiver
        bool is_liquidable; // true if trader wants to liquidate this order, originally set to false
    }

    mapping(uint256 => PositionInfo) positions;
    mapping(uint256 => bool) position_valid;
    uint256 public num_positions;

    modifier PositionValid(uint position_id) {
        require(position_valid[position_id] == true, "Position invalid");
        _;
    }

    modifier OnlyPositionOwner(uint position_id) {
        require(positions[position_id].trader_address == msg.sender, "Only Position Owner");
        _;
    }

    function IncreaseMargin(uint position_id, uint256 margin_amount) external PositionValid(position_id) OnlyPositionOwner(position_id) {
        uint256 old_amount = positions[position_id].margin_amount;
        positions[position_id].margin_amount += margin_amount;
        emit MarginUpdate(msg.sender, position_id, old_amount, positions[position_id].margin_amount);
    }

    function DecreaseMargin(uint position_id, uint256 margin_amount) external PositionValid(position_id) OnlyPositionOwner(position_id) {
        require(positions[position_id].margin_amount >= margin_amount,"margin_amount is too big");
        uint256 old_amount = positions[position_id].margin_amount;
        positions[position_id].margin_amount -= margin_amount;
        if(positions[position_id].margin_amount == 0) {
            positions[position_id].is_liquidable = true;
        }
        emit MarginUpdate(msg.sender, position_id, old_amount, positions[position_id].margin_amount);
    }

    function LiquidatePosition() external {
        for(uint i=0; i<num_positions; i++) {
            if(position_valid[i] == true && positions[i].margin_amount == 0) {
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
        bool is_fixed_rate_receiver
    ) external {
        PositionTimeData memory data = PositionTimeData(
            notional_amount,
            block.timestamp,
            swap_rate
        );

        positions[num_positions].margin_amount = margin_amount;
        positions[num_positions].trader_address = trader_address;
        positions[num_positions].is_fixed_rate_receiver = is_fixed_rate_receiver;
        positions[num_positions].is_liquidable = false;
        positions[num_positions].data[0] = data;
        positions[num_positions].num_data = 1;

        position_valid[num_positions] = true;
        num_positions += 1;
    }

    function AddPositionData(
        uint256 position_id,
        uint256 notional_amount,
        uint256 margin_amount,
        uint256 swap_rate
    ) external PositionValid(position_id) {
        PositionTimeData memory data = PositionTimeData(
            notional_amount,
            block.timestamp,
            swap_rate
        );
        positions[position_id].data[positions[position_id].num_data] = data;
        positions[position_id].margin_amount += margin_amount;
        positions[position_id].num_data += 1;
    }

    event MarginUpdate(address user,uint position_id, uint256 old_amount, uint256 new_amount);
    event LiquidateUpdate(uint position_id);
}