// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Proxy{
    //implementation address 
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implemenntation")) - 1 );
    //admin address
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1 );

    constructor(address _implementation){
        _setAdmin(msg.sender);
        _setImplementation(_implementation);
    }

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Not admin");
        _;
        
    }

    function upgrade(address newImplementation) external onlyAdmin {
        _setImplementation(newImplementation);
    }

    function _setImplementation(address newImplementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getImplementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _getAdmin() public view returns(address adm){
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot) 
        }
    }

    receive() external payable {}

    fallback() external payable {
        address impl = _getImplementation();

        assembly {
            // Copy msg.data to memory
            calldatacopy(0, 0, calldatasize())

            // Delegatecall to implementation
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // Copy return data
            returndatacopy(0, 0, returndatasize())

            // Return or revert
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}


//first implementaion of token contract
contract TokenV1 {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) public {
        balances[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;

    }

    function balanceOf(address user) public view returns (uint256){
        return balances[user];
    }    
}


//upgrade for implementation of token contract
contract TokenV2 {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) public {
        balances[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;

    }

    function balanceOf(address user) public view returns (uint256){
        return balances[user];
    } 

    //new function added in V2
    function burn(uint256 amount) public {  
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalSupply -= amount;
    }
}