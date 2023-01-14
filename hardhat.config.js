require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.13",
  networks:{
    goerli:{
      url: process.env.ALCHEMY_GOERLI_URL,
      accounts:[process.env.PRIVATE_KEY]
    }
  }
};
