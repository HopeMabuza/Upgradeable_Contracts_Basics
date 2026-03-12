# Storage Collision in Upgradeable Contracts

## The Problem

When implementing upgradeable contracts, we face a critical issue called **storage collision**. This occurs when:

- A proxy contract holds state variables
- An implementation contract has its own state variables
- Both contracts' variables occupy the same storage slots

When storage slots overlap, the contracts overwrite each other's data, leading to:
- Data corruption
- Unexpected behavior
- Security vulnerabilities

## The Solution: EIP-1967

We solve this by using **EIP-1967**, which stores the implementation and admin addresses in **pseudo-random storage slots** that are extremely unlikely to collide with normal storage.

### How It Works

1. Generate a keccak256 hash of a unique string (e.g., `"eip1967.proxy.implementation"`)
2. Subtract 1 from the resulting hash
3. Use this as the storage slot

This creates storage slots at positions like:
```
0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

These slots are so far from slot 0 that normal contract variables will never reach them.

## Implementation

See [contracts/storage_collision.sol](../contracts/storage_collision.sol)

### Key Components

**Storage Slots:**
```solidity
bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implemenntation")) - 1);
bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
```

**Assembly Access:**
The contract uses inline assembly to read/write to these specific slots:
- `_setImplementation()` - Stores implementation address using `sstore`
- `_getImplementation()` - Retrieves implementation address using `sload`
- `_setAdmin()` - Stores admin address using `sstore`
- `_getAdmin()` - Retrieves admin address using `sload`

**Proxy Pattern:**
- `fallback()` - Delegates all calls to the implementation contract
- `receive()` - Accepts plain ETH transfers
- `upgrade()` - Allows admin to change implementation (onlyAdmin)

## Deployment Script Walkthrough

See [scripts/storage_collision.js](../scripts/storage_collision.js)

### Step-by-Step Execution

**1. Get Signers**
```javascript
const [admin, user1, user2] = await ethers.getSigners();
```
Retrieves test accounts from Hardhat network.

**2. Deploy TokenV1 Implementation**
```javascript
const TokenV1 = await ethers.getContractFactory("TokenV1");
const tokenV1 = await TokenV1.deploy();
await tokenV1.waitForDeployment();
```
Deploys the first version of the token contract (implementation only, not used directly).

**3. Deploy Proxy**
```javascript
const Proxy = await ethers.getContractFactory("Proxy");
const proxy = await Proxy.deploy(tokenV1.target);
await proxy.waitForDeployment();
```
Deploys the proxy contract pointing to TokenV1. The proxy stores TokenV1's address in the EIP-1967 slot.

**4. Deploy TokenV2 Implementation**
```javascript
const TokenV2 = await ethers.getContractFactory("TokenV2");
const tokenV2 = await TokenV2.deploy();
await tokenV2.waitForDeployment();
```
Deploys the upgraded version with a new `burn()` function.

**5. Interact with Proxy Using V1 ABI**
```javascript
const proxyAsV1 = TokenV1.attach(proxy.target);
await proxyAsV1.mint(user1.address, 100);
const userBalance = await proxyAsV1.balanceOf(user1.address);
console.log("User1 Balance:", userBalance.toString()); // Output: 100
```
Attaches TokenV1's ABI to the proxy address. When we call `mint()`, it:
- Hits the proxy's fallback function
- Delegates to TokenV1 implementation
- Stores data in the proxy's storage

**6. Upgrade to V2**
```javascript
await proxy.upgrade(tokenV2.target);
```
Admin changes the implementation address in the EIP-1967 slot to point to TokenV2.

**7. Interact with Proxy Using V2 ABI**
```javascript
const proxyAsV2 = TokenV2.attach(proxy.target);
const userBalanceAfterUpgrade = await proxyAsV2.balanceOf(user1.address);
console.log("User1 Balance after upgrade:", userBalanceAfterUpgrade.toString()); // Output: 100
```
The balance persists because the storage remains in the proxy contract.

**8. Use New V2 Function**
```javascript
await proxyAsV2.connect(user1).burn(20);
const userBalanceAfterBurn = await proxyAsV2.balanceOf(user1.address);
console.log("User1 Balance after burn:", userBalanceAfterBurn.toString()); // Output: 80
```
Calls the new `burn()` function that only exists in TokenV2.

### Key Observations

1. **Storage Persistence**: User balances survive the upgrade because data lives in the proxy
2. **ABI Flexibility**: We can use different ABIs (V1 or V2) with the same proxy address
3. **New Functionality**: V2 adds `burn()` without losing existing data
4. **EIP-1967 Protection**: Implementation and admin addresses don't collide with token storage

### Why This Works

- **Proxy storage**: `balances` mapping, `totalSupply` (slots 0, 1)
- **Implementation address**: Stored at EIP-1967 slot (very high slot number)
- **Admin address**: Stored at different EIP-1967 slot

No collision occurs because the slots are far apart!