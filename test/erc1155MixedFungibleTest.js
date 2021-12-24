const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const ERC1155MixedFungible = await hre.ethers.getContractFactory("ERC1155MixedFungible");
    const erc1155MixedFungible = await ERC1155MixedFungible.deploy();
    await erc1155MixedFungible.deployed();
    console.log("ERC1155 deployed to:", erc1155MixedFungible.address);
  });
});
