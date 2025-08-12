// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

////////////////////////////////////////////////////////////////////////////////
//                                CONTRACT FLOW                               //
////////////////////////////////////////////////////////////////////////////////
//
// This contract's main flow is the creation of a fully signed UserOperation.
// It is a utility script that follows these steps:
//
// 1. generateSignedUserOp() is called with transaction details.
//         |
//         V
// 2. It calls _generateUnsignedUserOp() to create the basic UserOp struct.
//         |
//         V
// 3. It requests a unique hash of the UserOp from the EntryPoint contract.
//         |
//         V
// 4. It signs the UserOp hash using the appropriate private key.
//         |
//         V
// 5. It encodes the signature and adds it to the UserOp struct.
//         |
//         V
// 6. Returns the complete, signed PackedUserOperation.
//
////////////////////////////////////////////////////////////////////////////////

import {Script} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";

/**
 * @title SendPackedUserOp
 * @author Adebakin Olujimi
 * @notice A Foundry script for generating a signed EIP-4337 `PackedUserOperation`.
 * @dev This contract provides a utility function to create and sign a `UserOperation` object, ready to be sent to an EntryPoint contract.
 */
contract SendPackedUserOp is Script {
    /// @notice A reference to the HelperConfig script to get network configurations.
    HelperConfig helperConfig;

    /// @notice Enables direct calls to functions like `toEthSignedMessageHash` on `bytes32` variables.
    using MessageHashUtils for bytes32;

    /**
     * @notice The main entry point for the Foundry script.
     * @dev This function is required by Foundry's `Script` contract but is left empty as the core logic is in other utility functions.
     */
    function run() public {
        
    }

    /**
     * @notice Generates a fully signed `PackedUserOperation` for an Account Abstraction contract.
     * @dev This function orchestrates the process of creating a user operation, hashing it, signing it with the appropriate private key, and returning the final object.
     * @param callData The encoded function call to be executed on the smart account.
     * @param config The network configuration struct containing the EntryPoint address and account address.
     * @param aaContract The address of the smart account contract.
     * @return unsignedUserOp The complete, signed `PackedUserOperation` struct.
     */
    function generateSignedUserOp(bytes memory callData, HelperConfig.NetworkConfig memory config, address aaContract)
        public
        view
        returns (PackedUserOperation memory)
    {
        // Get the nonce for the account. Note: In a real scenario, you would use a proper nonce management system.
        // This example uses a simplified approach to get a working nonce for a test.
        uint256 nonce = vm.getNonce(aaContract) - 1;

        // 1. Generate the unsigned `PackedUserOperation` struct using a helper function.
        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(
            callData,
            aaContract,
            nonce
        );

        // 2. Get the UserOperation hash from the EntryPoint contract, which is the message that needs to be signed.
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unsignedUserOp);
        
        // 3. Hash the UserOp hash into an Ethereum-signed message digest using the standard prefix.
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 4. Sign the digest with the appropriate private key.
        uint8 v;
        bytes32 r;
        bytes32 s;
        // The default private key for Anvil's first account is used for local testing.
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            // Sign with the Anvil default private key on the local network.
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            // Placeholder for signing on a testnet. This would be replaced by actual signing logic.
            (v, r, s) = vm.sign(config.account, digest);
        }

        // 5. Pack the signature components (r, s, v) into a single bytes variable.
        unsignedUserOp.signature = abi.encodePacked(r, s, v);

        // 6. Return the fully signed user operation.
        return unsignedUserOp;
    }

    /**
     * @notice An internal helper function to generate the basic unsigned `PackedUserOperation` struct.
     * @dev This function populates the `PackedUserOperation` with the necessary transaction details and hardcoded gas values for simplicity.
     * @param callData The calldata for the transaction.
     * @param sender The address of the smart account.
     * @param nonce The unique nonce for the transaction.
     * @return The unsigned `PackedUserOperation` struct.
     */
    function _generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        // Hardcoded gas limits and fees for demonstration purposes.
        uint128 verificationGasLimit = 16_777_216;
        uint128 callGasLimit = 100_000;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = 256;

        // Pack gas limits and fees into `bytes32` variables as required by the EIP-4337 standard.
        bytes32 accountGasLimits = bytes32((uint256(verificationGasLimit) << 128) | uint256(callGasLimit));
        bytes32 gasFees = bytes32((uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas));

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "", // Assuming the account is already deployed.
            callData: callData,
            accountGasLimits: accountGasLimits,
            preVerificationGas: verificationGasLimit,
            gasFees: gasFees,
            paymasterAndData: "", // Assuming no paymaster is used.
            signature: "" // The signature field is initially empty.
        });
    }
}
