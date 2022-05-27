// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interface/IRateOracle.sol";

abstract contract BaseRateOracle is IRateOracle, Ownable {
    uint256 public override minSeconds; // 3600==1h
    IERC20Minimal public immutable override underlying;
    uint8 public immutable override decimals;

    uint public startTimestamp = 0;
    uint public lastUpdateTimestamp = 0;
    mapping(uint => uint) timeMap; // timestamp => recordStruct

    uint256 constant RATE_PRECISION = 1e4;

    constructor(IERC20Minimal _underlying, uint256 _minSeconds) {
        require(address(_underlying) != address(0), "underlying must exist");
        underlying = _underlying;
        decimals = _underlying.decimals();
        minSeconds = _minSeconds;
    }

    function getRate(uint _timestamp) public view returns(uint rate) {
        return timeMap[_timestamp];
    }

    function getRateByTimestamp(uint _timestamp) public view returns(uint rate) {
        uint standardTime = getStandardTime(_timestamp);
        return timeMap[standardTime];
    }

    function getStandardTime(uint _timestamp) public view returns(uint standardTime) {
        return (_timestamp/minSeconds)*minSeconds;
    }

    function setMinSeconds(uint256 _minSeconds)
        external
        override
        onlyOwner
    {
        if (minSeconds != _minSeconds) {
            minSeconds = _minSeconds;
            emit MinSecondsUpdate(_minSeconds);
        }
    }

    function getRateFromTo(uint from, uint to) external view virtual override returns (uint);
    function recordRate() external virtual override;

    function _setRate(uint _rate) internal {
        uint time = block.timestamp;
        // no need to revert if (time - minSeconds < lastUpdateTimestamp)
        if(time - minSeconds >= lastUpdateTimestamp) {
            uint standardTime = getStandardTime(time);
            timeMap[standardTime] = _rate;
            lastUpdateTimestamp = standardTime;
            emit RecordRate(standardTime, timeMap[standardTime]);
        }
    }
}