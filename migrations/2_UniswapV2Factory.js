const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const address = "0x4b634Ed3CB7D5f961eEf65f3CC8Cac15Ded7cd97";

module.exports = function (deployer) {
  deployer.deploy(UniswapV2Factory, address);
};
