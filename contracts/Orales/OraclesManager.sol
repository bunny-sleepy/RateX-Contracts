// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AaveRateOracle.sol";
import "./CompoundRateOracle.sol";
import "../interface/oracle/IRateOracle.sol";

contract OraclesManager is Ownable {
    uint public totalOracles = 0;
    mapping(uint=>mapping(address=>address)) oracleTypeMap; // oracleType =>(asset address => orale address)
    mapping(uint=>address) oracleMap; // index => oracle address

    address public aaveAddress;
    address public compoundAddress;

    constructor(address _aaveAddress, address _compoundAddress) {
        aaveAddress = _aaveAddress;
        compoundAddress = _compoundAddress;
    }

    // it is for pool
    // TODO：modifier onlyPool()
    function createOracle(uint oracleType, IERC20Minimal asset) public {
        if(oracleTypeMap[oracleType][address(asset)] == address(0)) {
            if(oracleType == 1) {
                oracleTypeMap[oracleType][address(asset)] = address(new AaveRateOracle(aaveAddress, asset));
                oracleMap[totalOracles] = oracleTypeMap[oracleType][address(asset)];
                totalOracles = totalOracles + 1;
            } else if (oracleType == 2) {
                oracleTypeMap[oracleType][address(asset)] = address(new CompoundRateOracle(compoundAddress, asset));
                oracleMap[totalOracles] = oracleTypeMap[oracleType][address(asset)];
                totalOracles = totalOracles + 1;
            }
        }
    }

    // it is for Chainlink Keepers or users.
    function UpdateAllOraclesRate(uint _fromIndex, uint _toIndex) external {
        require(_fromIndex<=_toIndex,"_fromIndex <= _toIndex");
        for(uint i=_fromIndex; i<totalOracles; i++) {
            if(oracleMap[i] != address(0)) {
                // TODO: Determine whether there is a corresponding pool now to save gas
                // if(IPool().maxEndTime > block.timestamp){}
                IRateOracle(oracleMap[i]).recordRate();
            }
        }
    }
}