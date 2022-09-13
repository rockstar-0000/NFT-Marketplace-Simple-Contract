async function main() {
  // update the name here
  const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");

  // Start deployment, returning a promise that resolves to a contract object
  const market = await NFTMarketplace.deploy();

  console.log("Contract deployed to address:", market.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
