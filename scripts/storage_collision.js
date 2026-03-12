const {ethers} = require("hardhat");


async function main(){
    const [admin, user1, user2] = await ethers.getSigners();    

    //deploy V1 implementation
    const TokenV1 = await ethers.getContractFactory("TokenV1");
    const tokenV1 = await TokenV1.deploy();
    await tokenV1.waitForDeployment();

    //deploy Proxy
    const Proxy = await ethers.getContractFactory("Proxy");
    const proxy = await Proxy.deploy(tokenV1.target);
    await proxy.waitForDeployment();

    //deploy V2 implementation
    const TokenV2 = await ethers.getContractFactory("TokenV2");
    const tokenV2 = await TokenV2.deploy();
    await tokenV2.waitForDeployment();


    //interact with proxy using V1 ABI
    const proxyAsV1 = TokenV1.attach(proxy.target);

    //mint tokens and check balance
    await proxyAsV1.mint(user1.address, 100);
    const userBalance = await proxyAsV1.balanceOf(user1.address);
    console.log("User1 Balance:", userBalance.toString());

    //upgrade to V2
    await proxy.upgrade(tokenV2.target);

    const proxyAsV2 = TokenV2.attach(proxy.target);

    //check if balance is still the same
    const userBalanceAfterUpgrade = await proxyAsV2.balanceOf(user1.address);
    console.log("User1 Balance after upgrade:", userBalanceAfterUpgrade.toString());

    await proxyAsV2.connect(user1).burn(20);

    const userBalanceAfterBurn = await proxyAsV2.balanceOf(user1.address);
    console.log("User1 Balance after burn:", userBalanceAfterBurn.toString());

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });