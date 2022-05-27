// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IPool {
    function start_time() external view returns (uint256);
    function end_time() external view returns (uint256);
    function rate_lower() external view returns (uint256);
    function rate_upper() external view returns (uint256);
    function asset_address() external view returns (address);
    function asset_decimals() external view returns (uint8);
    function oracle_address() external view returns (address);

    function TransferAsset(address trader, uint256 margin_amount) external;
    function TransferMarginBonus(uint256 notional_amount) external returns (uint256);
}