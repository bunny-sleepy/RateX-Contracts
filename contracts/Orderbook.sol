// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Utils/IERC20.sol";
import "./Utils/ERC20Helper.sol";
import "./Interface/IPositionManager.sol";

contract Orderbook is ERC20Helper {

    uint256 constant public PRICE_PRECISION = 1e6;
    uint256 constant public RATE_PRECISION = 1e4;

    bool public orderbook_paused;

    address public position_manager_address;
    address public asset_address;
    uint8 asset_decimals;

    uint256 public min_rate;
    uint256 public max_rate;

    struct Order {
        address trader_address;
        uint256 swap_rate;
        uint256 notional_amount; // notional amount left in this order
        uint256 margin_amount; // margin amount left in this order
        uint256 position_id; 
        uint256 is_position; // false if the order does not have a corresponding position
    }

    struct OrderStep {
        Order[] orders;
        uint256 num_orders;
        uint256 begin_idx;
        uint256 end_idx; // reduce gas
    }


    mapping(uint256 => OrderStep) fixed_orders; // receive fixed rates, sellers
    uint256 min_fixed_rate;
    uint256 max_fixed_rate;

    mapping(uint256 => OrderStep) variable_orders; // receive variable rates, buyers
    uint256 min_variable_rate;
    uint256 max_variable_rate;

    modifier NotPaused() {
        require(orderbook_paused == false, "Orderbook paused");
        _;
    }

    modifier RateValid(uint256 rate) {
        require((rate >= min_rate) && (rate <= max_rate), "Swap rate invalid");
        _;
    }
    
    constructor (address _asset_address) {
        require(_asset_address != address(0), "Zero address detected");
        asset_address = _asset_address;
        asset_decimals = IERC20(asset_address).decimals();
        orderbook_paused = false;
        min_rate = 0;
        max_rate = 10000;
    }

    function FixedMarketOrder(
        uint256 swap_rate, // the rate you would like to place an order if there is no open orders left
        uint256 margin_amount, // the amount of margin provided by trader in 1e6 precision
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) {
        uint256 rate = max_variable_rate;
        uint256 notional_amount_left = notional_amount;
        uint256 position_swap_rate = 0;

        TransferInToken(asset_address, msg.sender, margin_amount * (10 ** asset_decimals) / PRICE_PRECISION);

        while (rate >= min_variable_rate) {
            uint256 num_orders = variable_orders[rate].num_orders;

            if (num_orders > 0) {
                uint256 order_len = variable_orders[rate].orders.length;
                uint256 idx = variable_orders[rate].begin_idx;

                for (uint i = 0; i < num_orders; i++) {
                    Order memory order = variable_orders[rate].orders[i + idx];
                    uint256 order_notional_amount = order.notional_amount;
                    require(rate == order.swap_rate, "Swap rate error");

                    if (notional_amount_left <= order_notional_amount) {
                        position_swap_rate += order_notional_amount * rate;
                    } else {
                        
                        notional_amount_left -= order_notional_amount;
                    }
                }
            }
            rate -= 1;
        }
    }

    function VariableMarketOrder(
        uint256 swap_rate, // the rate you would like to place an order if there is no open orders left
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) {

    }

    function FixedLimitOrder(
        uint256 swap_rate,
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) {

    }

    function VariableLimitOrder(
        uint256 swap_rate,
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) {

    }

}