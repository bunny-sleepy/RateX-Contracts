// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { parseUnits } = require("ethers/lib/utils");
const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    let USDC = await MockERC20.deploy("USDC", "USDC", 18);
    await USDC.deployed();

    // TODO: MockOracle
    const MockOracle = await hre.ethers.getContractFactory("MockOracle");
    let oracle = await MockOracle.deploy(USDC.address, 3600);
    await oracle.deployed();

    const BasePool = await hre.ethers.getContractFactory("BasePool");
    let pool = await BasePool.deploy(USDC.address, oracle.address);
    await pool.deployed();

    let position_manager_address = await pool.position_manager_address();
    let position_manager = await hre.ethers.getContractAt("PositionManager", position_manager_address);

    let insurance_fund_address = await pool.insurance_fund_address();
    let insurance_fund = await hre.ethers.getContractAt("InsuranceFund", insurance_fund_address);

    console.log("Pool address: ", pool.address);
    console.log("PositionManager address: ", position_manager.address);
    console.log("InsufanceFund address: ", insurance_fund.address);
    console.log("Oracle address: ", oracle.address);
    console.log("USDC address: ", USDC.address);
    
    // TEST ONLY
    await USDC.approve(pool.address, parseUnits("1", 25));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
