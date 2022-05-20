// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;
import "../Aave/IAaveV2LendingPool.sol";
import "./IRateOracle.sol";
import "../../Utils/CustomErrors.sol";

interface IAaveRateOracle is IRateOracle {

    /// @notice Gets the address of the Aave Lending Pool
    /// @return Address of the Aave Lending Pool
    function aaveLendingPool() external view returns (IAaveV2LendingPool);

}