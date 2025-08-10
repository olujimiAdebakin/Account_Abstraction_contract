# Account Abstraction Smart Contract

## Overview
This project implements an EIP-4337 compliant smart account in Solidity, designed to streamline user interactions on EVM-compatible blockchains by enabling gasless transactions and customizable signature validation. Built with the Foundry development toolkit, it serves as a robust foundation for next-generation dApps and user experiences.

## Features
-   **EIP-4337 Compatibility**: Fully integrates with the ERC-4337 EntryPoint contract for secure and standardized user operation processing.
-   **Flexible Execution**: Supports transaction execution initiated either by the EntryPoint contract or directly by the account owner.
-   **ECDSA Signature Validation**: Leverages standard ECDSA for cryptographically secure verification of user operation signatures.
-   **Native Token Reception**: Enables direct reception of native blockchain tokens (e.g., ETH) to the smart account.
-   **Ownership Management**: Utilizes battle-tested OpenZeppelin `Ownable` contracts for robust access control and administrative functions.

## Getting Started

### Installation
To set up this project locally, ensure you have [Foundry](https://getfoundry.sh/) installed. If not, you can install it via `foundryup`:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Once Foundry is installed, clone the repository and install its dependencies:

```bash
git clone https://github.com/your-username/account_abstraction_contract.git
cd account_abstraction_contract
forge install
forge build
```

### Environment Variables
For deployment and interaction, the following environment variables are required:

-   `PRIVATE_KEY`: Your private key for the wallet that will deploy and interact with the contract. **Ensure this key is for an account with sufficient funds.**
    *   Example: `PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` (Example Anvil development key)
-   `ETH_RPC_URL`: The RPC URL for the blockchain network you intend to deploy to (e.g., Sepolia, Anvil).
    *   Example: `ETH_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID`
    *   Example: `ETH_RPC_URL=http://localhost:8545` (for Anvil)

You can set these in your shell or create a `.env` file at the root of the project:

```
PRIVATE_KEY=your_private_key_here
ETH_RPC_URL=your_rpc_url_here
```

## Contract Interface

The `AA_Contract` exposes several external functions for interaction, primarily `execute` for general call execution and `validateUserOp` for EIP-4337 compliance.

### Contract Address
This contract is deployed per network. Its address will be available after deployment on a specific chain.

### Functions

#### function execute(address dest, uint256 value, bytes calldata functionData)
**Purpose**: Allows the smart account to execute a low-level call to a target address, optionally sending native tokens (ETH).
**Visibility**: `external`. Callable only by the designated EntryPoint contract or the account's owner.

**Parameters**:
-   `dest` (address): The target address to which the call will be made.
-   `value` (uint256): The amount of native token (in wei) to send with the call.
-   `functionData` (bytes): The ABI-encoded calldata for the function to execute on the `dest` address.

**Errors**:
-   `AA_Account_NotFromEntryPointOrOwner()`: Thrown if the function is called by an address that is neither the EntryPoint nor the contract owner.
-   `AA_Account__CallFailed(bytes reason)`: Thrown if the low-level call to `dest` fails, including the raw revert data.

#### function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) returns (uint256 validationData)
**Purpose**: Core EIP-4337 function for validating a user operation. This includes verifying the signature against the account's owner and handling the prefunding for gas.
**Visibility**: `external`. Callable only by the designated EntryPoint contract.

**Parameters**:
-   `userOp` (PackedUserOperation): The full `PackedUserOperation` struct containing details of the user's intent.
-   `userOpHash` (bytes32): The hash of the `userOp` which was signed by the account owner.
-   `missingAccountFunds` (uint256): The amount of native token (in wei) required by the EntryPoint to cover the operation's prefund.

**Returns**:
-   `validationData` (uint256): Returns `SIG_VALIDATION_SUCCESS` (1) upon successful signature validation, or `SIG_VALIDATION_FAILED` (0) if the signature is invalid.

**Errors**:
-   `AA_Account_NotFromEntryPoint()`: Thrown if the function is called by an address other than the EntryPoint.

#### function getEntryPoint() returns (address)
**Purpose**: Retrieves the address of the EntryPoint contract configured for this smart account.
**Visibility**: `external view`.

**Parameters**: None.

**Returns**:
-   `address`: The address of the `IEntryPoint` contract associated with this `AA_Contract` instance.

#### receive() external payable
**Purpose**: A fallback function that allows the smart account to receive direct native token (ETH) transfers.
**Visibility**: `external payable`.

**Parameters**: None.
**Returns**: None.

## Usage

### Deploying the Contract
To deploy your `AA_Contract` to a network (e.g., Sepolia), run the deployment script using Foundry:

```bash
forge script script/DeployAA_Account.s.sol --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```
Replace `$ETH_RPC_URL` and `$PRIVATE_KEY` with your actual environment variables or ensure they are set in your shell/`.env` file. The `-vvvv` flag provides verbose output, including the deployed contract address.

### Interacting with the Contract
Once deployed, you can interact with the contract using `cast` (Foundry's CLI tool) or through a dApp interface.

**Example: Getting the EntryPoint Address**

```bash
cast call <YOUR_AA_CONTRACT_ADDRESS> "getEntryPoint()(address)" --rpc-url $ETH_RPC_URL
```
Replace `<YOUR_AA_CONTRACT_ADDRESS>` with the address obtained from the deployment step.

**Example: Executing a Call (Owner-only)**
As the owner, you can directly call the `execute` function. This example sends 0 ETH to a dummy address.

```bash
# Example: Encode calldata for a simple transfer (e.g., 0 ETH to owner)
# Note: For complex interactions, you'd encode the actual function call
DUMMY_CALLDATA=$(cast calldata "execute(address,uint256,bytes)" "<TARGET_ADDRESS>" 0 "0x")

# Execute the call as the owner
cast send <YOUR_AA_CONTRACT_ADDRESS> "execute(address,uint256,bytes)" \
  "<TARGET_ADDRESS>" \
  0 \
  "0x" \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY
```
Replace `<TARGET_ADDRESS>` with any valid Ethereum address.

**Example: Sending a User Operation (Conceptual)**
Sending a `UserOperation` involves a Paymaster and Bundler, which are external services. This contract's `validateUserOp` function is called by the EntryPoint. A typical flow would involve:
1.  Constructing a `PackedUserOperation` object off-chain.
2.  Signing the `userOpHash` with the `AA_Contract`'s owner key.
3.  Submitting the `PackedUserOperation` to a Bundler, which then calls the EntryPoint. The EntryPoint, in turn, calls `validateUserOp` on your `AA_Contract`.

## Technologies Used

| Technology                | Description                                         |
| :------------------------ | :-------------------------------------------------- |
| <img src="https://raw.githubusercontent.com/ethereum/solidity-cdn/develop/docs/assets/logo.svg" alt="Solidity" width="20"/> Solidity | Smart contract programming language for Ethereum.   |
| <img src="https://raw.githubusercontent.com/foundry-rs/foundry/master/assets/logo.svg" alt="Foundry" width="20"/> Foundry   | Blazing fast, portable, and modular toolkit for Ethereum application development. |
| <img src="https://raw.githubusercontent.com/ethereum/EIPs/master/assets/eip-4337/logo.png" alt="EIP-4337" width="20"/> EIP-4337 | Account Abstraction standard for smart accounts.    |
| <img src="https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/openzeppelin-logo.svg" alt="OpenZeppelin" width="20"/> OpenZeppelin Contracts | Secure and community-audited smart contract libraries. |

## Contributing

Contributions are welcome! If you have suggestions for improvements, feature requests, or bug fixes, please follow these steps:

✨ **Fork the repository.**
⭐ **Create a new branch** for your changes.
🛠️ **Implement your changes** and write tests if applicable.
✅ **Ensure all tests pass**.
⬆️ **Commit your changes** with clear and concise messages.
🚀 **Push your branch** to your forked repository.
➡️ **Open a pull request** describing your changes.

## License

This project is licensed under the MIT License, as indicated by the SPDX-License-Identifier in the source code.

## Author Info

Developed by **Adebakin Olujimi**.

Connect with me:

*   **LinkedIn**: [Your LinkedIn Profile](https://linkedin.com/in/your-username)
*   **Twitter**: [Your Twitter Handle](https://twitter.com/your-username)

---

[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Built%20with%20Foundry-brightgreen?logo=foundry)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)