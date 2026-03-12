const {ethers} = require("hardhat");


async function main(){
    const [admin, user1] = await ethers.getSigners();    

    //deploy V1 implementation
    const CounterV1 = await ethers.getContractFactory("CounterV1");
    const counterV1 = await CounterV1.deploy();
    await counterV1.waitForDeployment();

    // Encode initialization data
    const initData = counterV1.interface.encodeFunctionData("initialize", [50]);

    //deploy Proxy
    const Proxy = await ethers.getContractFactory("TransparentUpgradeableProxy");
    const proxy = await Proxy.deploy(counterV1.target, admin.address, initData);
    await proxy.waitForDeployment();

    //deploy V2 implementation
    const CounterV2 = await ethers.getContractFactory("CounterV2");
    const counterV2 = await CounterV2.deploy();
    await counterV2.waitForDeployment();


    //interact with proxy using V1 ABI
    const proxyAsV1 = CounterV1.attach(proxy.target);

    //increment count (call from user1, not admin)
    await proxyAsV1.connect(user1).increment();

    const count = await proxyAsV1.connect(user1).getCount();
    console.log("Count :", count.toString());

    //upgrade to V2
    await proxy.connect(admin).upgradeTo(counterV2.target);

    const proxyAsV2 = CounterV2.attach(proxy.target);

    //check if balance is still the same
    const count2 = await proxyAsV2.connect(user1).getCount();
    console.log("Count after upgrade :", count2.toString());

    //decrement count using V2 function
    await proxyAsV2.connect(user1).decrement();
    const countAfterDecrement = await proxyAsV2.connect(user1).getCount();
    console.log("Count after decrement :", countAfterDecrement.toString());

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });