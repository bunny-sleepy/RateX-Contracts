// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "../Oracles/OraclesManager.sol";

contract OracleKeeper is KeeperCompatibleInterface {
    uint public immutable interval;
    uint public lastTimeStamp;

    OraclesManager public oraclesManager;

    constructor(uint updateInterval,address _aaveAddress, address _compoundAddress) {
      interval = updateInterval; // set to 3600
      lastTimeStamp = block.timestamp;
      oraclesManager = new OraclesManager(_aaveAddress, _compoundAddress);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastTimeStamp) > interval ) {
            lastTimeStamp = block.timestamp;
            // update oracles data
            oraclesManager.updateAllOraclesRate();
        }
    }
}
