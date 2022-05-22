// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../Orderbook.sol";

abstract contract BasePool {
    uint256 public start_time;
    uint256 public end_time;
    // estimated lower / upper rates
    uint256 public rate_lower;
    uint256 public rate_upper;
    uint256 public reserve_factor = 1500000;

    address public oracle_address;
    address public position_manager_address;

    address public underlying_asset;

    uint256 constant PRICE_PRECISION = 1e6;

    uint256 ratio_to_insurance_fund; // set to 100
    uint256 ratio_to_owner; // set to 100

    
}