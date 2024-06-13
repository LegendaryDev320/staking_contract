const { expect } = require("chai");

const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("StakingContract", function () {
  async function deployTokenFixture() {
    // Get the Signers here.
    const [owner, addr1] = await ethers.getSigners();
    const CToken = await ethers.getContractFactory("ClimaxToken");
    let cToken = await CToken.deploy("ClimaxToken", "CTK", 8);
    await cToken.waitForDeployment();
    const StakingContract = await ethers.getContractFactory("StakingContract");
    const stakingContract = await StakingContract.deploy(cToken);
    await stakingContract.waitForDeployment();
    return { cToken, stakingContract, owner, addr1 };
  }

  // You can nest describe calls to create subsections.
  describe("Transactions", function () {
    it("Should stake tokens", async function () {
      const { cToken, stakingContract, owner, addr1 } = await loadFixture(
        deployTokenFixture
      );
      const tokenAmount = 1000;
      await cToken.approve(stakingContract.target, tokenAmount);
      await stakingContract.stake(tokenAmount);
      const stakeInfos = await stakingContract.getStakeInfo();
      const [stake, stakeTime, lastWithdrawTime] = stakeInfos[0];
      expect(stake).to.equal(tokenAmount);
    });
    
    it("Should unstake tokens", async function () {
        const { cToken, stakingContract, owner, addr1 } = await loadFixture(
            deployTokenFixture
        );
        //Send tokens to addr1
        await cToken.transfer(addr1.address, 300);
        //addr1 stake
        await cToken.connect(addr1).approve(stakingContract.target, 200);

        await stakingContract.connect(addr1).stake(200);
        //owner stake
        const tokenAmount = 500;
        await cToken.approve(stakingContract.target, tokenAmount);
        await stakingContract.stake(tokenAmount);
        //add time
        const lockTime = 30 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [lockTime]);
        await ethers.provider.send("evm_mine");

        await stakingContract.unstake(0);
        const stakeInfos = await stakingContract.getStakeInfo();
        const [stake, stakeTime, lastWithdrawTime] = stakeInfos[0];
        expect(stake).to.equal(0);
    })

    it("Should withdraw tokens", async function () {
        const { cToken, stakingContract, owner, addr1 } = await loadFixture(
            deployTokenFixture
        );
        const tokenAmount = 1000;
        await cToken.approve(stakingContract.target, tokenAmount);
        await stakingContract.stake(tokenAmount);
        //add time
        const lockTime = 365 * 24 * 60 * 60;
        await ethers.provider.send("evm_increaseTime", [lockTime]);
        await ethers.provider.send("evm_mine");

        const rewards = await stakingContract.getRewards();
        const balance = await cToken.balanceOf(owner.address);
        await stakingContract.withdrawAll();
        expect(balance + rewards).to.equal(await cToken.balanceOf(owner.address));
        expect(rewards).not.to.equal(0);
    })
  });
});