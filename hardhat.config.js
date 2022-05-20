require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const PRIVATE_KEY = "21949c4833fb30532017af5112fe604261b5851ffd570d977008df7b8427999a";
// const YOUR_ADDRESS = "0x7A55229DBC2A1ff9B64B5A54dbf1A10Ab9EF0DF3";
// const PRIVATE_KEY = "YOUR ROPSTEN PRIVATE KEY";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    oasisTestnet: {
      // url: "https://testnet.emerald.oasis.dev/",
      // accounts: [`0x${PRIVATE_KEY}`]
    }
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  } 
}