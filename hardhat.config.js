require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      // For local testing
    },
    ...(process.env.SEPOLIA_RPC_URL && process.env.ADMIN_PRIVATE_KEY ? {
      sepolia: {
        url: process.env.SEPOLIA_RPC_URL,
        accounts: [process.env.ADMIN_PRIVATE_KEY],
        chainId: 11155111
      }
    } : {})
  },
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};