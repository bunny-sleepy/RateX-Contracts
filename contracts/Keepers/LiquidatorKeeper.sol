// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "../PositionManager.sol";

contract LiquidatorKeeper is KeeperCompatibleInterface {
    uint public immutable interval;
    uint public lastTimeStamp;

    PositionManager public positionManager;

    constructor(uint updateInterval, address _positionManagerAddress) {
      interval = updateInterval;
      lastTimeStamp = block.timestamp;
      positionManager = PositionManager(_positionManagerAddress);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastTimeStamp) > interval ) {
            lastTimeStamp = block.timestamp;
            // Liquidate Position
            positionManager.LiquidatePosition();
        }
    }
}
