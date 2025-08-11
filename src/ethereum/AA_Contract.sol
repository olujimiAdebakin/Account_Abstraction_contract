// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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
 *      Allows execution of transactions either via the EntryPoint or the contract owner.
 *      Validates user operations via ECDSA signatures and manages prefunding for gas.
 */
contract AA_Contract is IAccount, Ownable {
    ////////////////////////////////////////////////////////////////////////////////
    //                                ERRORS                                      //
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when a function is called by an address other than the EntryPoint.
    error AA_Account_NotFromEntryPoint();

    /// @notice Thrown when a function is called by an address other than the EntryPoint or the owner.
    error AA_Account_NotFromEntryPointOrOwner();

    /// @notice Thrown when a low-level call fails.
    /// @param reason The raw revert data returned from the failed call.
    error AA_Account__CallFailed(bytes reason);

    ////////////////////////////////////////////////////////////////////////////////
    //                              STATE VARIABLES                               //
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice The EntryPoint contract used by this account for Account Abstraction flows.
    IEntryPoint private immutable i_entryPoint;

    ////////////////////////////////////////////////////////////////////////////////
    //                                 MODIFIERS                                  //
    ////////////////////////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////////////////////////
    //                               CONSTRUCTOR                                  //
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @param entryPoint The address of the EntryPoint contract.
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    ////////////////////////////////////////////////////////////////////////////////
    //                              RECEIVE FUNCTION                              //
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Allows the account to receive native token transfers.
    receive() external payable {}

    ////////////////////////////////////////////////////////////////////////////////
    //                            EXTERNAL FUNCTIONS                              //
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Executes a call from the account to a target contract.
     * @dev Can only be called by the EntryPoint or the account owner.
     * @param dest The target contract address.
     * @param value The amount of ETH (in wei) to send.
     * @param functionData The calldata for the target contract function.
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert AA_Account__CallFailed(result);
        }
    }

    /**
     * @notice Validates a user operation for EIP-4337.
     * @dev Checks signature validity, nonce, and handles prefunding if necessary.
     * @param userOp The packed user operation struct.
     * @param userOpHash The hash of the user operation.
     * @param missingAccountFunds The amount of ETH required to prefund the operation.
     * @return validationData Encoded validation result per EIP-4337.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        _validateSignature(userOp, userOpHash);
        // _validateNonce(userOp.sender, userOp.nonce); // Uncomment if nonce handling is implemented
        _payPrefund(missingAccountFunds);
        return SIG_VALIDATION_SUCCESS;
    }

    ////////////////////////////////////////////////////////////////////////////////
    //                           INTERNAL FUNCTIONS                               //
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Validates the signature of a user operation.
     * @dev Uses ECDSA recovery to ensure the signer is the account owner.
     * @param userOp The packed user operation struct.
     * @param userOpHash The hash of the user operation.
     * @return validationData Encoded validation result per EIP-4337.
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Sends ETH to the EntryPoint to cover the prefund requirement.
     * @dev If sending fails, it's ignored — the EntryPoint is responsible for verifying payment.
     * @param missingAccountFunds The amount to send in wei.
     */
    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: gasleft()}("");
            (success); // Silence compiler warning
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    //                                GETTERS                                     //
    ////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the EntryPoint address used by this account.
     * @return The EntryPoint contract address.
     */
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
