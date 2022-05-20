// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import "../IERC20Minimal.sol";

interface IRateOracle {
    event RecordRate(uint _timestamp, uint _rate);
    event MinSecondsUpdate(uint256 _minSecondsUpdate);

    function underlying() external view returns (IERC20Minimal);
    function decimals() external view returns (uint8);
    function minSeconds() external view returns (uint256);
    function setMinSeconds(uint256 _minSeconds) external;
    function getRateFromTo(uint from, uint to) external view returns (uint);
    function recordRate() external;
}