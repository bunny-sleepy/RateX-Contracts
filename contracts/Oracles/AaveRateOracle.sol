// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import "./BaseRateOracle.sol";
import "../Interface/Aave/IAaveV2LendingPool.sol";
import "../Utils/WadRayMath.sol";

contract AaveRateOracle is BaseRateOracle {
    
    IAaveV2LendingPool public aaveV2LendingPool;

    constructor(
        address _aaveV2LendingPoolAddress,
        IERC20Minimal _underlying
    ) BaseRateOracle(_underlying, 3600) {
        require(
            address(_aaveV2LendingPoolAddress) != address(0),
            "aave pool must exist"
        );
        aaveV2LendingPool = IAaveV2LendingPool(_aaveV2LendingPoolAddress);
        require(address(_underlying) != address(0), "underlying must exist");
    }

    function getRateFromTo(uint _from, uint _to) external view override returns (uint) {
        require(_from <= _to, "from > to");
        uint rateFrom = getRateByTimestamp(_from);
        uint rateTo = getRateByTimestamp(_to);
        if(getStandardTime(_to)>lastUpdateTimestamp){
            rateTo = aaveV2LendingPool.getReserveNormalizedIncome(
                underlying
            );
        }
        if (rateTo >= rateFrom) {
            return WadRayMath.rayToWad(
                WadRayMath.rayDiv(rateTo, rateFrom) - WadRayMath.RAY
            );
        } else {
            return 0;
        }
    }

    function recordRate() external override {
        uint resultRay = aaveV2LendingPool.getReserveNormalizedIncome(
            underlying
        );
        if(resultRay != 0) {
            _setRate(resultRay);
        }     
    }
}