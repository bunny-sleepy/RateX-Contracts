// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "../Oracles/BaseRateOracle.sol";
import "../Utils/WadRayMath.sol";

contract MockOracle is BaseRateOracle {
    uint private mockRate = 200;

    constructor(
        IERC20Minimal _underlying,
        uint256 _minSeconds
    ) BaseRateOracle(_underlying, _minSeconds) {
        require(address(_underlying) != address(0), "underlying must exist");
    }

    // TEST ONLY
    function getRateFromTo(uint _from, uint _to) external view override returns (uint) {
        require(_from <= _to, "from > to");
        // uint rateFrom = getRateByTimestamp(_from);
        // uint rateTo = getRateByTimestamp(_to);
        // if (getStandardTime(_to) > lastUpdateTimestamp){
        //     rateTo = getCurrentRate(address(underlying));
        // }
        // if (rateTo >= rateFrom) {
        //     return WadRayMath.rayToWad(
        //         WadRayMath.rayDiv(rateTo, rateFrom) - WadRayMath.RAY
        //     );
        // } else {
        //     return 0;
        // }
        return mockRate;
    }

    function recordRate() external override {
        // setCurrentRate(address(underlying));
        // uint resultRay = getCurrentRate(address(underlying));
        // if(resultRay != 0) {
        //     _setRate(resultRay);
        // } 
    }

    function setCurrentRate(address _underlying) internal {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, _underlying, block.timestamp))) % 200;
        mockRate = mockRate + block.timestamp + random;
    }

    function getCurrentRate(address _underlying) internal view returns(uint) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, _underlying, block.timestamp))) % 200;
        return mockRate + random;
    }

    function setMockRate(uint256 _rate) external {
        mockRate = _rate;
    }
}