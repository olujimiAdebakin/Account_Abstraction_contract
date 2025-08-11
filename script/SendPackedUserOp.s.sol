// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    HelperConfig helperConfig;

    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOp(bytes memory callData, address sender, HelperConfig.NetworkConfig memory config)
        public
        view
        returns (PackedUserOperation memory)
    {
        // This function would generate a packed User Operation
        // and return it as bytes.
        // The actual implementation would depend on the User Operation structure.

        // 1. Generate the unsigned Data
        uint256 nonce = vm.getNonce(sender); // Example nonce
        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOp(
            callData, // The method call to execute on this account
            config.account, // The sender account of this request
            nonce // Unique value the sender uses to verify it is not a replay
        );

        // 2. Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unsignedUserOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // 3. Sign it, and return it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest); // Replace with actual private key or signing logic
        }

        unsignedUserOp.signature = abi.encodePacked(r, s, v);

        return unsignedUserOp;
    }

    function _generateUnsignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16_777_216;
        uint128 callGasLimit = 100_000;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = 256;

        // Pack into uint256, then cast to bytes32
        bytes32 accountGasLimits = bytes32((uint256(verificationGasLimit) << 128) | uint256(callGasLimit));
        bytes32 gasFees = bytes32((uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas));

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
