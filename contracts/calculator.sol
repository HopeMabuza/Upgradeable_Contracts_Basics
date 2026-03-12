// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Implementation{
    uint256 aValue;
    uint256 bValue;
    uint256 results;

    function add(uint256 a, uint256 b) public {
        aValue = a;
        bValue = b;
        results = aValue + bValue;
        
    }

    function multiply(uint256 a, uint256 b) public {
        aValue = a;
        bValue = b;
        results = aValue * bValue;

    }

    function getResults() public view returns(uint256){
        return results;
    }
}

contract SimpleCalculator{
    uint256 aValue;
    uint256 bValue;
    uint256 results;
    address implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    fallback() external payable {
        address impl = implementation;

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