async function main() {
    // 1. Deploy the implementation
    const Implementation = await ethers.getContractFactory("Implementation");
    const implementation = await Implementation.deploy();
    await implementation.waitForDeployment();

    // 2. Deploy the proxy pointing to the implementation
    const CalcProxy = await ethers.getContractFactory("SimpleCalculator");
    const proxy = await CalcProxy.deploy(implementation.target);
    await proxy.waitForDeployment();

    // 3. Interact through the proxy
    // This is the trick: we use the Implementation ABI but the proxy address
    const proxyAsImplementation = Implementation.attach(proxy.target);
    await proxyAsImplementation.add(3, 4);

    console.log("Sum:", await proxyAsImplementation.getResults());

    await proxyAsImplementation.multiply(3, 4);
    console.log("Product:", await proxyAsImplementation.getResults());
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
