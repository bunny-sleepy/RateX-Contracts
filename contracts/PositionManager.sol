// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import "./Interface/IPool.sol";
import "./Interface/IRateOracle.sol";
import "./Interface/IInsuranceFund.sol";

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

    function GetTraderPositionNumber(address trader_address) public view returns (uint) {
        uint position_number = 0;
        for (uint i = 0; i < num_positions; i++) {
            if (position_valid[i] == true) {
                if (positions[i].trader_address == trader_address) {
                    position_number++;
                }
            }
        }
        return position_number;
    }

    function GetTraderPosition(
        address trader_address,
        uint position_id
    ) external view returns (
        uint256 swap_rate,
        uint256 notional_amount,
        uint256 margin_amount,
        bool is_fixed_receiver,
        bool is_liquidable,
        uint256 health_factor
    ) {
        uint position_number = GetTraderPositionNumber(trader_address);
        require(position_id < position_number, "position id exceeds");
        position_number = position_id;
        for (uint i = 0; i < num_positions; i++) {
            if (position_valid[i] == true) {
                if (positions[i].trader_address == trader_address) {
                    if (position_number == 0) {
                        (notional_amount, swap_rate) = CalculateNotionalAndRate(position_id);
                        margin_amount = positions[i].margin_amount;
                        is_fixed_receiver = positions[i].is_fixed_receiver;
                        is_liquidable = positions[i].is_liquidable;
                        health_factor = GetPositionHealthFactor(i);
                        return (swap_rate, notional_amount, margin_amount, is_fixed_receiver, is_liquidable, health_factor);
                    }
                }
            }
        }
    }

    function GetPositionTimeData(uint position_id, uint data_id) external view PositionValid(position_id) returns (uint256 notional_amount, uint256 trading_time, uint256 swap_rate) {
        uint num_data = positions[position_id].num_data;
        require(num_data > data_id, "Data ID invalid");
        notional_amount = positions[position_id].data[data_id].notional_amount;
        trading_time = positions[position_id].data[data_id].trading_time;
        swap_rate = positions[position_id].data[data_id].swap_rate;
    }

    function CalculatePnL(uint position_id) public view PositionValid(position_id) returns (int256 PnL) {
        IPool pool = IPool(pool_address);
        IRateOracle oracle = IRateOracle(pool.oracle_address());
        uint256 time = block.timestamp;
        if (time > pool.end_time()) {
            time = pool.end_time();
        }
        uint num_data = positions[position_id].num_data;
        bool is_fixed_receiver = positions[position_id].is_fixed_receiver;
        for (uint i = 0; i < num_data; i++) {
            uint256 avg_rate = oracle.getRateFromTo(positions[position_id].data[i].trading_time, time);
            uint256 rate = positions[position_id].data[i].swap_rate;
            uint256 notional_amount = positions[position_id].data[i].notional_amount;
            if (is_fixed_receiver) {
                PnL += (int256(rate) - int256(avg_rate)) * int256(notional_amount) / int256(RATE_PRECISION);
            } else {
                PnL += (int256(avg_rate) - int256(rate)) * int256(notional_amount) / int256(RATE_PRECISION);
            }
        }
    }

    function CalculateNotionalAndRate(uint position_id) public view returns (uint256, uint256) {
        uint256 notional_amount = 0;
        uint256 rate = 0;
        uint num_data = positions[position_id].num_data;
        for (uint i = 0; i < num_data; i++) {
            uint256 data_notional = positions[position_id].data[i].notional_amount;
            notional_amount += data_notional;
            rate += positions[position_id].data[i].swap_rate * data_notional;
        }
        if (notional_amount == 0) {
            rate = 0;
        } else {
            rate = rate / notional_amount;
        }
        return (notional_amount, rate);
    }

    // returns 1e6 view
    // if less than PRICE_PRECISION, it is not healthy
    function GetPositionHealthFactor(uint position_id) public view PositionValid(position_id) returns (uint256 factor) {
        uint256 margin_amount = positions[position_id].margin_amount;
        uint256 notional_amount = 0;
        uint256 rate = 0;
        IPool pool = IPool(pool_address);
        require((block.timestamp < pool.end_time()) && (block.timestamp > pool.start_time()), "Time unavailable");
        (notional_amount, rate) = CalculateNotionalAndRate(position_id);
        // calculate PnL
        int256 PnL = 0;
        
        if (rate > 0) {
            PnL = CalculatePnL(position_id);
        }

        // margin_amount update
        if (PnL + int256(margin_amount) >= int256(0)) {
            margin_amount = uint256(PnL + int256(margin_amount));
        } else {
            margin_amount = 0;
        }

        if (notional_amount == 0) {
            factor = 0;
        } else {
            uint256 time_diff = pool.end_time() - block.timestamp;
            uint256 rate_diff = pool.rate_upper() - pool.rate_lower();
            factor = margin_amount * (365 * 86400) * RATE_PRECISION * PRICE_PRECISION / time_diff / notional_amount / rate_diff;
        }
    }

    function ExistLiquidablePosition() external view returns (bool) {
        bool flag = false;
        for (uint i = 0; i < num_positions; i++) {
            if (position_valid[i] == true) {
                if (positions[i].is_liquidable || (GetPositionHealthFactor(i) < PRICE_PRECISION)) {
                    flag = true;
                    break;
                }
            }
        }
        return flag;
    }

    function ClosePosition(address trader_address, uint256 position_id) external OnlyPool {
        require(trader_address == positions[position_id].trader_address, "You are not trader");
        positions[position_id].is_liquidable = true;
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
        require(GetPositionHealthFactor(position_id) >= PRICE_PRECISION, "Position Unhealthy");
        emit MarginUpdate(trader_address, position_id, old_amount, new_amount);
    }

    function LiquidatePosition(address liquidator, uint256 position_id) internal PositionValid(position_id) {
        // liquidate
        if (positions[position_id].trader_address == liquidator) return; // return if already liquidated
        // TODO: increase margin amount
        IPool pool = IPool(pool_address);

        uint256 margin_amount = positions[position_id].margin_amount;
        uint256 notional_amount = 0;
        uint256 rate = 0;
        (notional_amount, rate) = CalculateNotionalAndRate(position_id);

        // calculate PnL
        int256 PnL = 0;
        if (rate > 0) {
            PnL = CalculatePnL(position_id);
        }
        
        uint256 time_diff = pool.end_time() - block.timestamp;
        uint256 rate_diff = 0;
        if (positions[position_id].is_fixed_receiver) {
            if (rate == 0) {
                rate_diff = pool.rate_upper() - pool.rate_lower();
            } else {
                rate_diff = pool.rate_upper() - rate;
            }
        } else {
            if (rate == 0) {
                rate_diff = pool.rate_upper() - pool.rate_lower();
            } else {
                rate_diff = rate - pool.rate_lower();
            }   
        }

        // margin to liquidator
        uint256 margin_to_go = notional_amount * time_diff * rate_diff / (365 * 86400) / RATE_PRECISION;
        if (-PnL + int256(margin_to_go) >= int256(0)) {
            margin_to_go = uint256(-PnL + int256(margin_to_go));
        } else {
            margin_to_go = 0;
        }
        
        if (margin_to_go > margin_amount) {
            margin_to_go = margin_amount;
        }
        // margin to liquidator
        // pool.TransferAsset(liquidator, margin_to_go);
        uint256 bonus_margin = pool.TransferMarginBonus(notional_amount);

        // margin to trader
        pool.TransferAsset(positions[position_id].trader_address, margin_amount - margin_to_go);

        // transfer position
        positions[position_id].trader_address = liquidator;
        positions[position_id].margin_amount = margin_to_go + bonus_margin;
        positions[position_id].is_liquidable = false;
    }

    function LiquidateAllPosition() external {
        for (uint i = 0; i < num_positions; i++) {
            if (position_valid[i] == true) {
                if (positions[i].is_liquidable || (GetPositionHealthFactor(i) < PRICE_PRECISION)) {
                    LiquidatePosition(msg.sender, i);
                    emit LiquidateUpdate(i);
                }
            }
        }
    }

    function RedeemMargin(uint position_id) external OnlyPool PositionValid(position_id) returns (uint256 margin_amount) {
        // TODO: enable users to redeem margin after pool has expired
        IPool pool = IPool(pool_address);
        require(block.timestamp >= pool.end_time(), "Pool not ended");
        margin_amount = positions[position_id].margin_amount;
        uint256 notional_amount;
        uint256 rate;
        (notional_amount, rate) = CalculateNotionalAndRate(position_id);

        int256 PnL = 0;
        if (rate > 0) {
            PnL = CalculatePnL(position_id);
        }

        // margin_amount update
        if (PnL + int256(margin_amount) >= int256(0)) {
            margin_amount = uint256(PnL + int256(margin_amount));
        } else {
            margin_amount = 0;
        }
        pool.TransferAsset(positions[position_id].trader_address, margin_amount);

        // remove position after redeem
        delete positions[position_id];
        delete position_valid[position_id];
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