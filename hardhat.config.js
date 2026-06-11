require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.10",
  networks: {
    base: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
