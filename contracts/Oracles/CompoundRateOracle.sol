// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.6;

import "./BaseRateOracle.sol";
import "../Interface/Compound/ICToken.sol";
import "../Utils/WadRayMath.sol";

contract CompoundRateOracle is BaseRateOracle {
    
    ICToken public iCToken;
    uint256 private immutable scaleDownFactor;
    uint256 private immutable scaleUpFactor;

    constructor(
        address _iCTokenAddress,
        IERC20Minimal _underlying
    ) BaseRateOracle(_underlying, 3600) {
        require(
            address(_iCTokenAddress) != address(0),
            "Compound pool must exist"
        );
        iCToken = ICToken(_iCTokenAddress);
        require(address(_underlying) != address(0), "underlying must exist");

        uint8 decimals = _underlying.decimals();
        scaleDownFactor =  decimals >= 17 ? 10**(decimals - 17) : 0;
        scaleUpFactor  = decimals < 17 ? 10**(17 - decimals) : 0;
    }

    function getRateFromTo(uint _from, uint _to) external view override returns (uint) {
        require(_from <= _to, "from > to");
        uint rateFrom = getRateByTimestamp(_from);
        uint rateTo = getRateByTimestamp(_to);
        if(getStandardTime(_to)>lastUpdateTimestamp){
            rateTo = exchangeRateInRay();
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
        uint resultRay = exchangeRateInRay();
        if(resultRay != 0) {
            _setRate(resultRay);
        }     
    }


    function exchangeRateInRay() internal view returns (uint256 resultRay) {
        uint256 exchangeRateStored = iCToken.exchangeRateStored();
        if (exchangeRateStored == 0) {
            return 0;
        }
        // cToken exchangeRateStored() returns the current exchange rate as an unsigned integer, scaled by 1 * 10^(10 + Underlying Token Decimals)
        // source: https://compound.finance/docs/ctokens#exchange-rate and https://compound.finance/docs#protocol-math
        // We want the same number scaled by 10^27 (ray)
        // So: if Underlying Token Decimals == 17, no scaling is required
        //     if Underlying Token Decimals > 17, we scale down by a factor of 10^difference
        //     if Underlying Token Decimals < 17, we scale up by a factor of 10^difference
        if (decimals >= 17) {   
            resultRay = exchangeRateStored / scaleDownFactor;
        } else {
            resultRay = exchangeRateStored * scaleUpFactor;
        }
        return resultRay;
    }
}