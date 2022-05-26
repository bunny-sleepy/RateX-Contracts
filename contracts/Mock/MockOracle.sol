// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../Oracles/BaseRateOracle.sol";

contract MockOracle is BaseRateOracle {
    constructor(
        IERC20Minimal _underlying,
        uint256 _minSeconds
    ) BaseRateOracle(_underlying, _minSeconds) {
        
    }

    function getRateFromTo(uint from, uint to) external view override returns (uint) {
        // TODO
        return 0;
    }

    function recordRate() external override {
        // TODO
    }
}