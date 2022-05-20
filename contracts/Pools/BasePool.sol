// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

abstract contract BasePool {
    uint256 public start_time;
    uint256 public end_time;
    // estimated lower / upper rates
    uint256 public rate_lower;
    uint256 public rate_upper;

    address public oracle_address;

    uint256 constant PRICE_PRECISION = 1e6;
    uint256 ratio_to_insurance_fund; // set to 100
    uint256 ratio_to_owner; // set to 100
}