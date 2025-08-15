
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IAccount} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";


/**
 * Lifecycle of a type 113 (0x71) transaction
 *
 * Phase 1 Validation
 *  1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 *  2. The zkSync API client checks to see the nonce is unique by querying the NonceHolder system contract
 *  3. The zkSync API client calls validateTransaction, which MUST update the nonce
 *  4. The zkSync API client checks the nonce is updated
 *  5. The zkSync API client calls payForTransaction, or prepareForPaymaster &
 *     validateAndPayForPaymasterTransaction
 *  6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 Execution
 *  7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are
 *     the same)
 *  8. The main node calls executeTransaction
 *  9. If a paymaster was used, the postTransaction is called
 */


contract ZkSmartWallet is IAccount {

          function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic)
        {

        }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable{}

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable{}

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable{}

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable{}
      
      // function validateTransaction(
      //       bytes32 _txHash,
      //       bytes32 _suggestedSignedHash,
      //       Transaction calldata _transaction
      // ) external payable override returns (bytes4 magic) {
      //       // Implementation of validation logic
      //       return ACCOUNT_VALIDATION_SUCCESS_MAGIC;
      // }
      
      // function executeTransaction(
      //       bytes32 _txHash,
      //       bytes32 _suggestedSignedHash,
      //       Transaction calldata _transaction
      // ) external payable override {
      //       // Implementation of transaction execution logic
      // }
      
      // function executeTransactionFromOutside(Transaction calldata _transaction) external payable override {
      //       // Implementation of external transaction execution logic
      // }
      
      // function payForTransaction(
      //       bytes32 _txHash,
      //       bytes32 _suggestedSignedHash,
      //       Transaction calldata _transaction
      // ) external payable override {
      //       // Implementation of payment logic for the transaction
      // }
      
      // function prepareForPaymaster(
      //       bytes32 _txHash,
      //       bytes32 _possibleSignedHash,
      //       Transaction calldata _transaction
      // ) external payable override {
      //       // Implementation of preparation for paymaster logic
      // }

}