// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract TokenV1 is UUPSUpgradeable{
    mapping(address => uint256) private balances;
    uint256 private totalSupply;
    string private name;
    string private symbol;
    address private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public {
        require(_owner != address(0), "Already initialized");
        name = _name;
        symbol = _symbol;
        owner = _owner;
    }

    function mint(address to, uint amount) public onlyOwner{
        require(to != address(0), "Invalid address");
        balances[to] += amount;
        totalSupply += amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to]         += amount;
        return true;
    }

    // Only the owner can authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        
    }
}


//add new logic: multi-sig upgrade, _authorizeUpgrade to check multi-sig
contract TokenV2 is UUPSUpgradeable{
    mapping(address => uint256) private balances;
    uint256 private totalSupply;
    string private name;
    string private symbol;
    address private owner;
    //new state variables for multi-sig
    address[3] private admins;
    // keeps track of how many people have approved the upgrade and which contract they have approved
    mapping(address => mapping(address => bool)) private approvals; 

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not an admin");
        _;
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public {
        require(_owner != address(0), "Already initialized");
        name = _name;
        symbol = _symbol;
        owner = _owner;
    }

    function mint(address to, uint amount) public onlyOwner{
        require(to != address(0), "Invalid address");
        balances[to] += amount;
        totalSupply += amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to]         += amount;
        return true;
    }

    // Only the owner can authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        require(approvalCount(newImplementation) >= 2, "Not enough approvals");

        approvals[newImplementation][admins[0]] = false;
        approvals[newImplementation][admins[1]] = false;
        approvals[newImplementation][admins[2]] = false;
        
        
    }

    function isAdmin(address account) internal view returns(bool) {
        for (uint i = 0; i < admins.length; i++) {
            if (admins[i] == account) {
                return true;
            }
        }
        return false;
    }

    function initV2(address[3] memory _admins) public onlyOwner {
        for (uint i = 0; i < _admins.length; i++) {
            require(_admins[i] != address(0), "Invalid admin address");
            admins[i] = _admins[i];
        }
    }

    function approveUpgrade(address newImplementation) public onlyAdmin {
        require(!approvals[msg.sender][newImplementation], "Already approved");
        approvals[msg.sender][newImplementation] = true;
    }

    function approvalCount(address newImplementation) public view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < admins.length; i++) {
            if (approvals[admins[i]][newImplementation]) {
                count++;
            }
        }
        return count;
    }
}

contract TokenV3 is UUPSUpgradeable{
    mapping(address => uint256) private balances;
    uint256 private totalSupply;
    string private name;
    string private symbol;
    address private owner;
    address[3] private admins;
    mapping(address => mapping(address => bool)) private approvals; 
    //adding state variable for time lock
    mapping(address => uint256) private upgradeTimestamps;
    uint256 private constant TIME_LOCK = 24 hours;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not an admin");
        _;
    }

    function initialize(string memory _name, string memory _symbol, address _owner) public {
        require(_owner != address(0), "Already initialized");
        name = _name;
        symbol = _symbol;
        owner = _owner;
    }

    function mint(address to, uint amount) public onlyOwner{
        require(to != address(0), "Invalid address");
        balances[to] += amount;
        totalSupply += amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to]         += amount;
        return true;
    }

   

    function isAdmin(address account) internal view returns(bool) {
        for (uint i = 0; i < admins.length; i++) {
            if (admins[i] == account) {
                return true;
            }
        }
        return false;
    }

    function initV2(address[3] memory _admins) public onlyOwner {
        for (uint i = 0; i < _admins.length; i++) {
            require(_admins[i] != address(0), "Invalid admin address");
            admins[i] = _admins[i];
        }
    }

    function approveUpgrade(address newImplementation) public onlyAdmin {
        require(!approvals[msg.sender][newImplementation], "Already approved");
        approvals[msg.sender][newImplementation] = true;
    }

    function approvalCount(address newImplementation) public view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < admins.length; i++) {
            if (approvals[admins[i]][newImplementation]) {
                count++;
            }
        }
        return count;
    }

    function proposedUpgrade(address newImplementation) public onlyAdmin {
        require(newImplementation != address(0), "Invalid address");
        require(upgradeTimestamps[newImplementation] == 0, "Already proposed");
        upgradeTimestamps[newImplementation] = block.timestamp;
    }

    function timeUntilExecutable(address newImplementation) public view returns (uint256){
        require(upgradeTimestamps[newImplementation] != 0, "Upgrade not proposed");
        uint256 earliest = upgradeTimestamps[newImplementation] + TIME_LOCK;
        if (block.timestamp >= earliest) {
            return 0;
        } else {
            return earliest - block.timestamp;
        }
    }

    // add implementaion for timelock
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        require(approvalCount(newImplementation) >= 2, "Not enough approvals");
        require(timeUntilExecutable(newImplementation) != 0, "Not proposed");
        require(block.timestamp >= upgradeTimestamps[newImplementation] + TIME_LOCK, "Time lock not expired");
        require(approvalCount(newImplementation) >= 2, "Not enough approvals");

        approvals[newImplementation][admins[0]] = false;
        approvals[newImplementation][admins[1]] = false;
        approvals[newImplementation][admins[2]] = false;
        upgradeTimestamps[newImplementation] = 0;
        
        
    }
}


