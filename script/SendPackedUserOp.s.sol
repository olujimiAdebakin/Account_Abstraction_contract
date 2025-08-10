
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol"; 


contract SendPackedUserOp is Script{
      
      function run() public {

      }

      function  generateSignedUserOp(bytes memory callData, address sender) public returns (PackedUserOperation memory) {
            // This function would generate a packed User Operation
            // and return it as bytes.
            // The actual implementation would depend on the User Operation structure.
            
            // 1. Generate the unsigned Data
            uint256 nonce = vm.getNonce(sender); // Example nonce
            PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(
                  callData, // The method call to execute on this account
                  sender,   // The sender account of this request
                  nonce     // Unique value the sender uses to verify it is not a replay    
            );
            
            // 2. Sign it, and return it

            
      }

     function _generateUnsignedUserOp(
    bytes memory callData,
    address sender,
    uint256 nonce
)
    internal
    pure
    returns (PackedUserOperation memory)
{
    uint128 verificationGasLimit = 16_777_216; 
    uint128 callGasLimit = 100_000; 
    uint128 maxPriorityFeePerGas = 256; 
    uint128 maxFeePerGas = 256;


    // Pack into uint256, then cast to bytes32
    bytes32 accountGasLimits = bytes32(
        (uint256(verificationGasLimit) << 128) | uint256(callGasLimit)
    );
    bytes32 gasFees = bytes32(
        (uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas)
    );

    return PackedUserOperation({
        sender: sender,
        nonce: nonce,
        initCode: "",
        callData: callData,
        accountGasLimits: accountGasLimits,
        preVerificationGas: verificationGasLimit,
        gasFees: gasFees,
        paymasterAndData: "",
        signature: "" // unsigned
    });
}


 }