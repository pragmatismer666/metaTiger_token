const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Meta Tiger", function () {
  it("deploys contact and prints deployement address", async function () {
    const tigerTokenFactory = await ethers.getContractFactory('MetaTiger');
    const tigerToken = await tigerTokenFactory.deploy();
    await tigerToken.deployed();
    console.log("Tiger is deployed to ", tigerToken.address);
  });
});