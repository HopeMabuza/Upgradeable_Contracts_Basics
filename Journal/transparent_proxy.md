
# Transparent Proxy Pattern

## The Problem

In upgradeable contracts, we face a critical issue called **function selector collision**. This occurs when:

- The proxy contract has administrative functions (e.g., `upgradeTo()`)
- The implementation contract has functions with the same signature
- Both functions have the same 4-byte selector

When selectors collide, the EVM doesn't know which function to execute, leading to:
- Ambiguous function calls
- Security vulnerabilities (users accidentally calling admin functions)
- Unpredictable behavior

## The Solution: Transparent Proxy Pattern

We solve this by implementing **role-based call routing**:

- **Admin calls** → Execute proxy's own functions (upgrade logic)
- **User calls** → Delegated to implementation (business logic)

The proxy checks `msg.sender` and routes calls accordingly, making the proxy "transparent" to users.

### How It Works

1. Proxy stores an admin address
2. On every call, proxy checks if `msg.sender == admin`
3. If admin: execute proxy functions (no delegation)
4. If user: delegate to implementation contract

This ensures admins can never accidentally call implementation functions, and users can never call admin functions.

## Implementation

See [contracts/transparent_proxy.sol](../contracts/transparent_proxy.sol)

### Key Components

**Admin Management:**
```solidity
address private admin;

modifier onlyAdmin() {
    require(msg.sender == admin, "Only admin");
    _;
}
```

**Upgrade Function:**
```solidity
function upgradeTo(address newImplementation) external onlyAdmin {
    implementation = newImplementation;
}
```
Only admin can change the implementation address.

**Fallback with Routing:**
```solidity
fallback() external payable {
    require(msg.sender != admin, "Admin cannot call implementation");
    _delegate(implementation);
}
```
Prevents admin from calling implementation functions, ensuring clean separation.

**Why initialize() Instead of constructor()?**

Critical concept for upgradeable contracts:

- **Constructors** execute during deployment and set storage in the implementation contract
- **Delegatecall** executes implementation code in the proxy's context
- Implementation's constructor never runs in proxy's context
- **initialize()** is a regular function that runs via delegatecall, setting proxy's storage correctly

Without `initialize()`, the proxy's state would never be set up!

## Deployment Script Walkthrough

See [scripts/transparent_proxy.js](../scripts/transparent_proxy.js)

### Step-by-Step Execution

**1. Get Signers**
```javascript
const [admin, user] = await ethers.getSigners();
```
Retrieves test accounts: admin for upgrades, user for interactions.

**2. Deploy Implementation V1**
```javascript
const BoxV1 = await ethers.getContractFactory("BoxV1");
const boxV1 = await BoxV1.deploy();
await boxV1.waitForDeployment();
```
Deploys the first implementation (logic contract).

**3. Deploy Transparent Proxy**
```javascript
const TransparentProxy = await ethers.getContractFactory("TransparentProxy");
const proxy = await TransparentProxy.deploy(boxV1.target, admin.address);
await proxy.waitForDeployment();
```
Deploys proxy pointing to BoxV1, sets admin address.

**4. Initialize Through Proxy**
```javascript
const proxyAsV1 = BoxV1.attach(proxy.target);
await proxyAsV1.connect(user).initialize(42);
```
User calls `initialize()` which:
- Hits proxy's fallback (user is not admin)
- Delegates to BoxV1's initialize()
- Sets storage in proxy contract

**5. Interact as User**
```javascript
const value = await proxyAsV1.connect(user).getValue();
console.log("Value:", value.toString()); // Output: 42

await proxyAsV1.connect(user).setValue(100);
const newValue = await proxyAsV1.connect(user).getValue();
console.log("New Value:", newValue.toString()); // Output: 100
```
User can call implementation functions normally through the proxy.

**6. Deploy Implementation V2**
```javascript
const BoxV2 = await ethers.getContractFactory("BoxV2");
const boxV2 = await BoxV2.deploy();
await boxV2.waitForDeployment();
```
Deploys upgraded version with new `increment()` function.

**7. Upgrade (Admin Only)**
```javascript
await proxy.connect(admin).upgradeTo(boxV2.target);
```
Admin calls `upgradeTo()` which:
- Executes on proxy (not delegated)
- Changes implementation address to BoxV2
- Preserves all existing storage

**8. Interact with V2**
```javascript
const proxyAsV2 = BoxV2.attach(proxy.target);
const valueAfterUpgrade = await proxyAsV2.connect(user).getValue();
console.log("Value after upgrade:", valueAfterUpgrade.toString()); // Output: 100

await proxyAsV2.connect(user).increment();
const incrementedValue = await proxyAsV2.connect(user).getValue();
console.log("Incremented Value:", incrementedValue.toString()); // Output: 101
```
User can now call the new `increment()` function from V2.

**9. Admin Cannot Call Implementation**
```javascript
try {
    await proxyAsV2.connect(admin).getValue();
} catch (error) {
    console.log("Admin blocked from calling implementation"); // This executes
}
```
Admin is prevented from calling implementation functions, maintaining separation.

### Key Observations

1. **Role Separation**: Admin and users have completely different interaction patterns
2. **Storage Persistence**: Value survives upgrade (100 → 101 after increment)
3. **No Selector Collision**: Admin's `upgradeTo()` never conflicts with implementation functions
4. **Initialization Pattern**: `initialize()` replaces constructor for proxy-compatible setup

### Why This Works

- **Admin calls**: Checked at proxy level, never delegated
- **User calls**: Always delegated to implementation
- **Storage**: Lives in proxy, survives upgrades
- **Logic**: Lives in implementation, can be swapped

The transparent proxy pattern ensures clean separation between governance and business logic!