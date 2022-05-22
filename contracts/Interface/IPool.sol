// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPool {
    function start_time() external view returns (uint256);
    function end_time() external view returns (uint256);
    function rate_lower() external view returns (uint256);
    function rate_upper() external view returns (uint256);
    function asset_address() external view returns (address);
}