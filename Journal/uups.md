# UUPS (Universal Upgradeable Proxy Standard)

## Problem with Transparent Proxy
The transparent proxy pattern has a gas cost issue: every function call requires checking if the caller is the admin attempting an upgrade, adding overhead to all transactions.

## UUPS Solution
UUPS moves the upgrade logic from the proxy into the implementation contract itself. This means:
- **Lower gas costs**: No admin checks on every call
- **Simpler proxy**: Proxy only delegates calls and stores state
- **Implementation-controlled upgrades**: The implementation contract manages its own upgrade authorization

## Architecture
- **Proxy Contract**: Minimal - only delegates calls and stores state
- **Implementation Contract**: Contains business logic AND upgrade authorization logic

---

## Contract Walkthrough: [uups.sol](../contracts/uups.sol)

### TokenV1 - Basic UUPS Implementation

**Key Features:**
- Inherits from `UUPSUpgradeable` (OpenZeppelin)
- Basic ERC20-like token functionality (mint, transfer, balanceOf)
- Owner-controlled upgrades via `_authorizeUpgrade`

**State Variables:**
```solidity
mapping(address => uint256) private balances;
uint256 private totalSupply;
string private name;
string private symbol;
address private owner;
```

**Critical Function:**
- `_authorizeUpgrade(address newImplementation)`: Only owner can authorize upgrades. This is the core UUPS function that controls who can upgrade the contract.

**Initialization:**
- Uses `initialize()` instead of constructor (proxies can't use constructors)
- Sets token name, symbol, and owner

---

### TokenV2 - Multi-Signature Upgrades

**New Features:**
- Multi-sig upgrade authorization (requires 2 of 3 admins)
- Adds admin management system

**New State Variables:**
```solidity
address[3] private admins;  // 3 admin addresses
mapping(address => mapping(address => bool)) private approvals;  // tracks approvals per implementation
```

**Upgrade Process:**
1. `initV2()`: Owner initializes the 3 admin addresses
2. `approveUpgrade(address)`: Each admin approves the new implementation
3. `_authorizeUpgrade()`: Requires 2+ approvals, then resets approval state

**Key Functions:**
- `isAdmin()`: Checks if address is in admin array
- `approveUpgrade()`: Admin approves a specific implementation address
- `approvalCount()`: Returns number of approvals for an implementation

---

### TokenV3 - Timelock Protection

**New Features:**
- 24-hour timelock on upgrades
- Prevents immediate upgrades even with approvals

**New State Variables:**
```solidity
mapping(address => uint256) private upgradeTimestamps;  // tracks when upgrade was proposed
uint256 private constant TIME_LOCK = 24 hours;
```

**Enhanced Upgrade Process:**
1. `proposedUpgrade()`: Admin proposes upgrade, starts 24-hour timer
2. `approveUpgrade()`: Admins approve (need 2+)
3. Wait 24 hours
4. `_authorizeUpgrade()`: Executes if timelock expired and 2+ approvals exist
5. Resets approvals and timestamp

**Key Functions:**
- `proposedUpgrade()`: Starts the timelock countdown
- `timeUntilExecutable()`: Returns remaining time before upgrade can execute
- `_authorizeUpgrade()`: Now checks timelock + approvals

---

## UUPS vs Transparent Proxy

| Feature | UUPS | Transparent Proxy |
|---------|------|-------------------|
| Upgrade logic location | Implementation | Proxy |
| Gas cost | Lower | Higher (admin checks) |
| Proxy complexity | Minimal | More complex |
| Risk | Implementation must include upgrade logic | Safer (upgrade logic always in proxy) |

## Security Considerations

1. **Critical**: Never deploy a UUPS implementation without `_authorizeUpgrade` - you'll lose upgradeability forever
2. **Storage layout**: Must maintain storage variable order across versions (V1 → V2 → V3)
3. **Initialization**: Always use `initialize()` functions, never constructors
4. **Timelock**: V3's 24-hour delay protects against malicious rapid upgrades
