// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import "./BaseRateOracle.sol";
import "../Interface/yearn/IYVault.sol";
import "../Utils/WadRayMath.sol";

contract YearnRateOracle is BaseRateOracle {
    
    IYVault public iYVault;

    constructor(
        address _yVaultAddress,
        IERC20Minimal _underlying
    ) BaseRateOracle(_underlying, 3600) {
        require(
            address(_yVaultAddress) != address(0),
            "yVault must exist"
        );
        iYVault = IYVault(_yVaultAddress);
        require(address(_underlying) != address(0), "underlying must exist");
    }

    function getRateFromTo(uint _from, uint _to) external view override returns (uint) {
        require(_from <= _to, "from > to");
        uint rateFrom = getRateByTimestamp(_from);
        uint rateTo = getRateByTimestamp(_to);
        if(getStandardTime(_to)>lastUpdateTimestamp){
            rateTo = iYVault.pricePerShare();
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
        uint resultRay = iYVault.pricePerShare();
        if(resultRay != 0) {
            _setRate(resultRay);
        }     
    }
}