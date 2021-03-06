// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Utils/IERC20.sol";
import "./Utils/ERC20Helper.sol";
import "./Interface/IPositionManager.sol";

contract Orderbook is ERC20Helper {

    uint256 constant public PRICE_PRECISION = 1e6;
    uint256 constant public RATE_PRECISION = 1e4;

    // pool parameter
    uint256 public rate_lower;
    uint256 public rate_upper;
    uint256 public reserve_factor = 1500000;
    uint256 public start_time;
    uint256 public end_time;

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
        bool is_position; // false if the order does not have a corresponding position
    }

    struct OrderNode {
        Order order;
        uint id;
        uint previous;
        uint next;
        bool valid;
    }

    struct OrderStep {
        mapping(uint => OrderNode) order_nodes;
        uint begin;
        uint num_orders;
        uint[] invalid_idx;
    }


    mapping(uint256 => OrderStep) fixed_orders; // receive fixed rates, sellers
    uint256 min_fixed_rate = 1;
    uint256 max_fixed_rate = 0; // set to indicate that no order exist on genesis

    mapping(uint256 => OrderStep) variable_orders; // receive variable rates, buyers
    uint256 min_variable_rate = 1;
    uint256 max_variable_rate = 0; // set to indicate that no order exist on genesis

    modifier NotPaused() {
        require(orderbook_paused == false, "Orderbook paused");
        _;
    }

    modifier RateValid(uint256 rate) {
        require((rate >= min_rate) && (rate <= max_rate), "Swap rate invalid");
        _;
    }

    modifier OrderValid(uint256 margin_amount, uint256 notional_amount) {
        uint256 left = (end_time - start_time) * (rate_upper - rate_lower) * reserve_factor * notional_amount;
        uint256 right = margin_amount * 365 * RATE_PRECISION * PRICE_PRECISION;
        require(left <= right, "Order not valid");
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

    function UnlistLimitOrder(Order memory order, uint idx, bool is_fixed_receiver) internal {
        // unlist the limit order
        uint rate = order.swap_rate;
        if (order.is_position) {
            IPositionManager(position_manager_address)
                .AddPositionData(
                    order.position_id,
                    order.notional_amount,
                    order.margin_amount,
                    order.swap_rate
                );
        } else {
            IPositionManager(position_manager_address)
                .AddPosition(
                    order.trader_address,
                    order.notional_amount,
                    order.margin_amount,
                    order.swap_rate,
                    is_fixed_receiver
                );
        }
        // if i == num_orders - 1, then delete OrderStep;
        // else update OrderStep
        if (!is_fixed_receiver) {
            if (variable_orders[rate].num_orders == 1) {
                delete variable_orders[rate];
            } else {
                // OrderNode Update
                uint previous = variable_orders[rate].order_nodes[idx].previous;
                uint next = variable_orders[rate].order_nodes[idx].next;
                variable_orders[rate].begin = next;
                variable_orders[rate].order_nodes[next].previous = previous;
                variable_orders[rate].order_nodes[previous].next = next;
                delete variable_orders[rate].order_nodes[idx];
                // OrderStep Update
                variable_orders[rate].invalid_idx.push(idx);
                variable_orders[rate].num_orders -= 1;
            }
        } else {
            if (fixed_orders[rate].num_orders == 1) {
                delete fixed_orders[rate];
            } else {
                // OrderNode Update
                uint previous = fixed_orders[rate].order_nodes[idx].previous;
                uint next = fixed_orders[rate].order_nodes[idx].next;
                fixed_orders[rate].begin = next;
                fixed_orders[rate].order_nodes[next].previous = previous;
                fixed_orders[rate].order_nodes[previous].next = next;
                delete fixed_orders[rate].order_nodes[idx];
                // OrderStep Update
                fixed_orders[rate].invalid_idx.push(idx);
                fixed_orders[rate].num_orders -= 1;
            }
        }
        // TODO: transfer to position manager
    }

    function ReduceLimitOrder(Order memory order, uint idx, bool is_fixed_receiver, uint256 notional_to_reduce) internal {
        uint rate = order.swap_rate;
        uint notional = order.notional_amount - notional_to_reduce;
        uint position_id = IPositionManager(position_manager_address)
            .AddPosition(
                order.trader_address,
                order.notional_amount,
                order.margin_amount,
                order.swap_rate,
                is_fixed_receiver
            );
        if (!is_fixed_receiver) {
            variable_orders[rate].order_nodes[idx].order.margin_amount = 0;
            variable_orders[rate].order_nodes[idx].order.notional_amount = notional;
            variable_orders[rate].order_nodes[idx].order.is_position = true;
            variable_orders[rate].order_nodes[idx].order.position_id = position_id;
        } else {
            fixed_orders[rate].order_nodes[idx].order.margin_amount = 0;
            fixed_orders[rate].order_nodes[idx].order.notional_amount = notional;
            fixed_orders[rate].order_nodes[idx].order.is_position = true;
            fixed_orders[rate].order_nodes[idx].order.position_id = position_id;
        }
        // TODO: transfer to position manager
    }

    function ListFixedLimitOrder(Order memory new_order) internal returns (uint idx) {
        // add the order
        uint swap_rate = new_order.swap_rate;
        uint num_orders = fixed_orders[swap_rate].num_orders;
        if (num_orders == 0) {
            fixed_orders[swap_rate].begin = 0;
            OrderNode memory new_order_node;
            new_order_node.order = new_order;
            new_order_node.valid = true;
            new_order_node.next = 0;
            new_order_node.previous = 0;
            new_order_node.id = 0;
            fixed_orders[swap_rate].order_nodes[0] = new_order_node;
        } else {
            uint begin = fixed_orders[swap_rate].begin;
            OrderNode memory begin_order_node = fixed_orders[swap_rate].order_nodes[begin];
            uint invalid_len = fixed_orders[swap_rate].invalid_idx.length;
            uint previous = begin_order_node.previous;
            if (invalid_len > 0) {
                idx = fixed_orders[swap_rate].invalid_idx[invalid_len - 1];
                fixed_orders[swap_rate].invalid_idx.pop();
            } else {
                idx = num_orders;
            }
            OrderNode memory new_order_node;
            new_order_node.order = new_order;
            new_order_node.valid = true;
            new_order_node.next = begin;
            new_order_node.previous = previous;
            new_order_node.id = idx;
            fixed_orders[swap_rate].order_nodes[idx] = new_order_node;
            fixed_orders[swap_rate].order_nodes[previous].next = idx;
            fixed_orders[swap_rate].order_nodes[begin].previous = idx;
        }
        fixed_orders[swap_rate].num_orders += 1;
        // update global parameters
        if (min_fixed_rate > max_fixed_rate) {
            min_fixed_rate = swap_rate;
            max_fixed_rate = swap_rate;
        } else {
            if (min_fixed_rate > swap_rate) min_fixed_rate = swap_rate;
            if (max_fixed_rate < swap_rate) max_fixed_rate = swap_rate;
        }
    }

    function ListVariableLimitOrder(Order memory new_order) internal returns (uint idx) {
        // add the order
        uint swap_rate = new_order.swap_rate;
        uint num_orders = variable_orders[swap_rate].num_orders;
        if (num_orders == 0) {
            variable_orders[swap_rate].begin = 0;
            OrderNode memory new_order_node;
            new_order_node.order = new_order;
            new_order_node.valid = true;
            new_order_node.next = 0;
            new_order_node.previous = 0;
            new_order_node.id = 0;
            variable_orders[swap_rate].order_nodes[0] = new_order_node;
        } else {
            uint begin = variable_orders[swap_rate].begin;
            OrderNode memory begin_order_node = variable_orders[swap_rate].order_nodes[begin];
            uint invalid_len = variable_orders[swap_rate].invalid_idx.length;
            uint previous = begin_order_node.previous;
            if (invalid_len > 0) {
                idx = variable_orders[swap_rate].invalid_idx[invalid_len - 1];
                variable_orders[swap_rate].invalid_idx.pop();
            } else {
                idx = num_orders;
            }
            OrderNode memory new_order_node;
            new_order_node.order = new_order;
            new_order_node.valid = true;
            new_order_node.next = begin;
            new_order_node.previous = previous;
            new_order_node.id = idx;
            variable_orders[swap_rate].order_nodes[idx] = new_order_node;
            variable_orders[swap_rate].order_nodes[previous].next = idx;
            variable_orders[swap_rate].order_nodes[begin].previous = idx;
        }
        variable_orders[swap_rate].num_orders += 1;
        // Update global parameters
        if (min_variable_rate > max_variable_rate) {
            min_variable_rate = swap_rate;
            max_variable_rate = swap_rate;
        } else {
            if (min_variable_rate > swap_rate) min_variable_rate = swap_rate;
            if (max_variable_rate < swap_rate) max_variable_rate = swap_rate;
        }
    }


    function FixedMarketOrder(
        uint256 swap_rate, // the rate you would like to place an order if there is no open orders left
        uint256 margin_amount, // the amount of margin provided by trader in 1e6 precision
        uint256 notional_amount // the amount of notional to trade in 1e6 precision
    ) external NotPaused RateValid(swap_rate) OrderValid(margin_amount, notional_amount) {
        if (max_variable_rate > min_variable_rate) {
            require(swap_rate > max_variable_rate, "Swap rate too low");
        }
        uint256 rate = max_variable_rate;
        uint256 notional_amount_left = notional_amount;
        uint256 position_swap_rate = 0;

        // Transfer margin to contract
        {
            uint256 transfer_amount = margin_amount * (10 ** asset_decimals) / PRICE_PRECISION;
            TransferInToken(asset_address, msg.sender, transfer_amount);
        }

        while (rate >= min_variable_rate) {
            uint256 num_orders = variable_orders[rate].num_orders;
            bool flag = false;

            if (num_orders > 0) {
                uint256 idx = variable_orders[rate].begin;

                for (uint i = 0; i < num_orders; i++) {
                    Order memory order = variable_orders[rate].order_nodes[idx].order;
                    // uint256 order_notional_amount = order.notional_amount;
                    // require(rate == order.swap_rate, "Swap rate error");

                    if (notional_amount_left <= order.notional_amount) {
                        position_swap_rate += notional_amount_left * rate;
                        if (notional_amount_left == order.notional_amount) {
                            // Unlist the limit order
                            UnlistLimitOrder(order, idx, false);
                        } else {
                            // Reduce limit order
                            ReduceLimitOrder(order, idx, false, notional_amount_left);
                        }

                        max_variable_rate = rate;
                        notional_amount_left = 0;
                        flag = true;
                        break;
                    } else {
                        position_swap_rate += order.notional_amount * rate;
                        notional_amount_left -= order.notional_amount;
                        // unlist the limit order
                        UnlistLimitOrder(order, idx, false);
                        if (i + 1 == num_orders) break;
                    }
                    idx = variable_orders[rate].order_nodes[idx].next;
                }
            }
            if (flag) {
                break;
            }
            rate -= 1;
        }
        uint position_id;
        if (notional_amount_left < notional_amount) {
            // add a position if some notional is matched
            position_swap_rate = position_swap_rate / (notional_amount - notional_amount_left);
            position_id = IPositionManager(position_manager_address)
                .AddPosition(
                    msg.sender,
                    notional_amount - notional_amount_left,
                    margin_amount,
                    position_swap_rate,
                    true
                );
            emit FixedMarketOrderFilled(position_id, msg.sender, notional_amount - notional_amount_left, margin_amount, position_swap_rate);
        }

        if (notional_amount_left > 0) {
            // NOTE: we do this because there is no variable limit orders left
            max_variable_rate = 0;
            min_variable_rate = 1;
            // create limit order
            Order memory new_order;
            if (notional_amount_left < notional_amount) {
                new_order.is_position = true;
                new_order.position_id = position_id;
                new_order.margin_amount = 0;
                new_order.notional_amount = notional_amount_left;
                new_order.swap_rate = swap_rate;
                new_order.trader_address = msg.sender;
            } else {
                new_order.is_position = false;
                new_order.margin_amount = margin_amount;
                new_order.notional_amount = notional_amount_left;
                new_order.swap_rate = swap_rate;
                new_order.trader_address = msg.sender;
            }
            uint idx = ListFixedLimitOrder(new_order);
            emit FixedLimitOrderOpened(idx, msg.sender, new_order.notional_amount, new_order.margin_amount, new_order.swap_rate);
        }

        // TODO: swap to position manager if some position is opened
    }

    function VariableMarketOrder(
        uint256 swap_rate, // the rate you would like to place an order if there is no open orders left
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) OrderValid(margin_amount, notional_amount) {
        require(swap_rate < min_fixed_rate, "Swap rate too low");
        uint256 rate = min_fixed_rate;
        uint256 notional_amount_left = notional_amount;
        uint256 position_swap_rate = 0;

        // Transfer margin to orderbook
        {
            uint256 transfer_amount = margin_amount * (10 ** asset_decimals) / PRICE_PRECISION;
            TransferInToken(asset_address, msg.sender, transfer_amount);
        }

        while (rate <= max_fixed_rate) {
            uint256 num_orders = fixed_orders[rate].num_orders;
            bool flag = false;

            if (num_orders > 0) {
                uint256 idx = fixed_orders[rate].begin;

                for (uint i = 0; i < num_orders; i++) {
                    Order memory order = fixed_orders[rate].order_nodes[idx].order;
                    // uint256 order_notional_amount = order.notional_amount;
                    // require(rate == order.swap_rate, "Swap rate error");

                    if (notional_amount_left <= order.notional_amount) {
                        position_swap_rate += notional_amount_left * rate;
                        if (notional_amount_left == order.notional_amount) {
                            // Unlist the limit order
                            UnlistLimitOrder(order, idx, true);
                        } else {
                            // Reduce limit order
                            ReduceLimitOrder(order, idx, true, notional_amount_left);
                        }

                        min_fixed_rate = rate;
                        notional_amount_left = 0;
                        flag = true;
                        break;
                    } else {
                        position_swap_rate += order.notional_amount * rate;
                        notional_amount_left -= order.notional_amount;
                        // unlist the limit order
                        UnlistLimitOrder(order, idx, true);
                        if (i + 1 == num_orders) break;
                    }
                    idx = fixed_orders[rate].order_nodes[idx].next;
                }
            }
            if (flag) {
                break;
            }
            rate += 1;
        }
        uint position_id;
        if (notional_amount_left < notional_amount) {
            // add a position if some notional is matched
            position_swap_rate = position_swap_rate / (notional_amount - notional_amount_left);
            position_id = IPositionManager(position_manager_address)
                .AddPosition(
                    msg.sender,
                    notional_amount - notional_amount_left,
                    margin_amount,
                    position_swap_rate,
                    false
                );
            emit VariableMarketOrderFilled(position_id, msg.sender, notional_amount - notional_amount_left, margin_amount, position_swap_rate);
        }

        if (notional_amount_left > 0) {
            // NOTE: we do this because there is no variable limit orders left
            max_fixed_rate = 0;
            min_fixed_rate = 1;
            // create limit order
            Order memory new_order;
            if (notional_amount_left < notional_amount) {
                new_order.is_position = true;
                new_order.position_id = position_id;
                new_order.margin_amount = 0;
                new_order.notional_amount = notional_amount_left;
                new_order.swap_rate = swap_rate;
                new_order.trader_address = msg.sender;
            } else {
                new_order.is_position = false;
                new_order.margin_amount = margin_amount;
                new_order.notional_amount = notional_amount_left;
                new_order.swap_rate = swap_rate;
                new_order.trader_address = msg.sender;
            }
            uint idx = ListVariableLimitOrder(new_order);
            emit VariableLimitOrderOpened(idx, msg.sender, new_order.notional_amount, new_order.margin_amount, new_order.swap_rate);
        }

        // TODO: swap to position manager is some position is opened
    }

    function FixedLimitOrder(
        uint256 swap_rate,
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) OrderValid(margin_amount, notional_amount) {
        if (max_variable_rate > min_variable_rate) {
            require(swap_rate > max_variable_rate, "Swap rate too low");
        }
        // Transfer margin to orderbook
        {
            uint256 transfer_amount = margin_amount * (10 ** asset_decimals) / PRICE_PRECISION;
            TransferInToken(asset_address, msg.sender, transfer_amount);
        }
        Order memory order;
        order.is_position = false;
        order.margin_amount = margin_amount;
        order.notional_amount = notional_amount;
        order.swap_rate = swap_rate;
        order.trader_address = msg.sender;
        uint idx = ListFixedLimitOrder(order);
        emit FixedLimitOrderOpened(idx, msg.sender, order.notional_amount, order.margin_amount, order.swap_rate);
    }

    function VariableLimitOrder(
        uint256 swap_rate,
        uint256 margin_amount,
        uint256 notional_amount
    ) external NotPaused RateValid(swap_rate) OrderValid(margin_amount, notional_amount) {
        if (max_fixed_rate > min_fixed_rate) {
            require(swap_rate < min_fixed_rate, "Swap rate too high");
        }
        // Transfer margin to orderbook
        {
            uint256 transfer_amount = margin_amount * (10 ** asset_decimals) / PRICE_PRECISION;
            TransferInToken(asset_address, msg.sender, transfer_amount);
        }
        Order memory order;
        order.is_position = false;
        order.margin_amount = margin_amount;
        order.notional_amount = notional_amount;
        order.swap_rate = swap_rate;
        order.trader_address = msg.sender;
        uint idx = ListVariableLimitOrder(order);
        emit VariableLimitOrderOpened(idx, msg.sender, order.notional_amount, order.margin_amount, order.swap_rate);
    }

    function UserUnlistLimitOrder(
        uint256 swap_rate,
        uint256 order_id,
        bool is_fixed_receiver
    ) external NotPaused RateValid(swap_rate) {
        Order memory order;
        if (is_fixed_receiver) {
            require(fixed_orders[swap_rate].order_nodes[order_id].id == order_id, "Order id error");
            order = fixed_orders[swap_rate].order_nodes[order_id].order;
        } else {
            require(variable_orders[swap_rate].order_nodes[order_id].id == order_id, "Order id error");
            order = variable_orders[swap_rate].order_nodes[order_id].order;
        }
        require(order.trader_address == msg.sender, "You are not trader");

        UnlistLimitOrder(order, order_id, is_fixed_receiver);
        // transfer Margin to trader
        {
            uint256 transfer_amount = order.margin_amount * (10 ** asset_decimals) / PRICE_PRECISION;
            TransferToken(asset_address, msg.sender, transfer_amount);
        }
        emit LimitOrderUnlisted(order_id, msg.sender, is_fixed_receiver, order.notional_amount, order.margin_amount, order.swap_rate);
    }

    event FixedMarketOrderFilled(uint position_id, address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate);
    event FixedLimitOrderOpened(uint order_id, address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate);
    event VariableMarketOrderFilled(uint position_id, address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate);
    event VariableLimitOrderOpened(uint order_id, address trader_address, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate);
    event LimitOrderUnlisted(uint order_id, address trader_address, bool is_fixed_receiver, uint256 notional_amount, uint256 margin_amount, uint256 swap_rate);
}