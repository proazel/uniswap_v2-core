const UniswapV2ERC20 = artifacts.require("UniswapV2ERC20");

module.exports = function (deployer) {
  deployer.deploy(UniswapV2ERC20);
};
