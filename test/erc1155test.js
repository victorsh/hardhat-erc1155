const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const ERC1155 = await hre.ethers.getContractFactory("ERC1155");
    const erc1155 = await ERC1155.deploy();
    await erc1155.deployed();
    console.log("ERC1155 deployed to:", erc1155.address);

    assert(1 === 1)
  });
});
