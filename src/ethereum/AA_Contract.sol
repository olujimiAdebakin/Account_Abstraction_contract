// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

////////////////////////////////////////////////////////////////////////////////
//                                CONTRACT FLOW                               //
////////////////////////////////////////////////////////////////////////////////
//
// There are two primary ways to execute transactions with this smart account:
//
// 1. Direct Execution by Owner:
//    Owner --> execute(dest, value, data) --> Target Contract
//
// 2. Execution via EIP-4337:
//    Bundler -> EntryPoint -> validateUserOp() -> Account -> _payPrefund() -> EntryPoint -> execute() -> Target Contract
//
////////////////////////////////////////////////////////////////////////////////

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title AA_contract
 * @author Adebakin Olujimi
 * @notice An Account Abstraction (EIP-4337) compatible smart account.
 * @dev Implements IAccount interface for integration with an EntryPoint contract.
 * Allows execution of transactions either via the EntryPoint or the contract owner.
 * Validates user operations via ECDSA signatures and manages prefunding for gas.
 */
contract AA_Contract is IAccount, Ownable {
    //////////////////////////////////////////////////////////////////////////////
    //                         ERRORS                                           //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when a function is called by an address other than the EntryPoint.
    error AA_Account_NotFromEntryPoint();

    /// @notice Thrown when a function is called by an address other than the EntryPoint or the owner.
    error AA_Account_NotFromEntryPointOrOwner();

    /// @notice Thrown when a low-level call fails.
    /// @param reason The raw revert data returned from the failed call.
    error AA_Account__CallFailed(bytes reason);

    //////////////////////////////////////////////////////////////////////////////
    //                         STATE VARIABLES                                  //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice The EntryPoint contract used by this account for Account Abstraction flows.
    IEntryPoint private immutable i_entryPoint;

    //////////////////////////////////////////////////////////////////////////////
    //                         MODIFIERS                                        //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Restricts function access to only the EntryPoint contract.
     */
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert AA_Account_NotFromEntryPoint();
        }
        _;
    }

    /**
     * @notice Restricts function access to the EntryPoint or the account owner.
     */
    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert AA_Account_NotFromEntryPointOrOwner();
        }
        _;
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR                                      //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Initializes the account with a specified EntryPoint contract.
     * @param entryPoint The address of the EntryPoint contract. This address is stored immutably.
     * @dev Also initializes the `Ownable` contract, setting the deployer as the initial owner.
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        // Store the address of the EntryPoint, which is used to interact with the EIP-4337 system.
        i_entryPoint = IEntryPoint(entryPoint);
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         RECEIVE FUNCTION                                 //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice Allows the account to receive native token transfers (ETH) without a specific function call.
    receive() external payable {}

    //////////////////////////////////////////////////////////////////////////////
    //                         EXTERNAL FUNCTIONS                               //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Executes a call from the account to a target contract.
     * @dev This function can only be called by the EntryPoint contract (to execute a `UserOperation`) or by the account's owner (for direct control). It performs a low-level call to the destination address.
     * @param dest The target contract address to call.
     * @param value The amount of ETH (in wei) to send with the call.
     * @param functionData The calldata for the target contract's function, which includes the function selector and arguments.
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        // Perform a low-level call to the destination address with the provided value and calldata.
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        // If the low-level call fails, revert with the reason from the called contract.
        if (!success) {
            revert AA_Account__CallFailed(result);
        }
    }

    /**
     * @notice Validates a user operation for EIP-4337.
     * @dev This function is called exclusively by the `EntryPoint` contract. It performs three key tasks: signature validation, nonce validation (if implemented), and prefunding.
     * @param userOp The packed user operation struct containing all details of the intended transaction.
     * @param userOpHash The hash of the user operation, used for signature verification.
     * @param missingAccountFunds The amount of ETH required to prefund the operation, as determined by the EntryPoint.
     * @return validationData An encoded validation result. `SIG_VALIDATION_SUCCESS` indicates the signature is valid and prefunding is handled. Other return codes would indicate failure.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        // Validate the signature on the userOpHash to ensure it was signed by the account owner.
        _validateSignature(userOp, userOpHash);
        // Note: The nonce validation is commented out but would typically be here to prevent replay attacks.
        // _validateNonce(userOp.sender, userOp.nonce);
        // Pay the required gas prefund to the EntryPoint contract.
        _payPrefund(missingAccountFunds);
        // Return a success code as defined by the EIP-4337 standard.
        return SIG_VALIDATION_SUCCESS;
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         INTERNAL FUNCTIONS                               //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Validates the signature of a user operation.
     * @dev This internal function uses the `ECDSA.recover` method to verify that the signature on the `userOpHash` was created by the account owner.
     * @param userOp The packed user operation struct, which contains the signature.
     * @param userOpHash The hash of the user operation, which is the message that was signed.
     * @return validationData Encoded validation result. Returns `SIG_VALIDATION_SUCCESS` if the signer matches the owner, otherwise `SIG_VALIDATION_FAILED`.
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        returns (uint256 validationData)
    {
        // Hash the user operation hash with the Ethereum signed message prefix "\x19Ethereum Signed Message:\n32".
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        // Recover the signer address from the signed message hash and the provided signature.
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        // Check if the recovered signer is the owner of this smart account.
        if (signer != owner()) {
            // If it doesn't match, return the failure code.
            return SIG_VALIDATION_FAILED;
        }
        // If it matches, return the success code.
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Sends ETH to the EntryPoint to cover the prefund requirement.
     * @dev This function is called during the `validateUserOp` phase. It performs a low-level `call` with the specified value to the `EntryPoint` contract. The `success` boolean is ignored because the EntryPoint is responsible for verifying the payment.
     * @param missingAccountFunds The amount of ETH to send to the EntryPoint contract.
     */
    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        // Only send ETH if there is a non-zero amount required.
        if (missingAccountFunds != 0) {
            // Perform a low-level call to the `msg.sender` (which is the EntryPoint) with the required ETH.
            // Gas is forwarded using `gasleft()` to ensure the call has enough gas.
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: gasleft()}("");
            // The success status is ignored as the EntryPoint will verify the balance increase.
            (success); // Silence compiler warning about an unused variable.
        }
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         GETTERS                                          //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the EntryPoint address used by this account.
     * @return The address of the EntryPoint contract stored in the state variable.
     */
    function getEntryPoint() external view returns (address) {
        // Returns the address of the immutable EntryPoint contract instance.
        return address(i_entryPoint);
    }
}
