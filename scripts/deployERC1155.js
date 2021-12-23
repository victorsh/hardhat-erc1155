const hre = require("hardhat");

async function main() {
  const ERC1155 = await hre.ethers.getContractFactory("ERC1155");
  const erc1155 = await ERC1155.deploy();

  await erc1155.deployed();

  console.log("ERC1155 deployed to:", erc1155.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
