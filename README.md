# 🚀 EIP-4337 Smart Account Contracts

## Overview
This project presents a robust implementation of an Account Abstraction (EIP-4337) compatible smart wallet, developed using Solidity and Foundry. It enables enhanced user experiences on the Ethereum Virtual Machine (EVM) by abstracting away the complexities of traditional wallet management, supporting both direct owner-initiated transactions and bundler-driven `UserOperation` execution.

## Features
- **EIP-4337 Compliance**: Fully integrates with the ERC-4337 standard for secure and flexible account abstraction.
- **Flexible Transaction Execution**: Supports direct transaction execution by the owner and indirect execution via an `EntryPoint` contract for `UserOperations`.
- **ECDSA Signature Validation**: Verifies `UserOperation` signatures using industry-standard ECDSA cryptography for strong security.
- **Gas Fee Management**: Includes logic for prefunding gas fees to the `EntryPoint` contract, essential for sponsored transactions.
- **Multi-Network Configuration**: Provides flexible deployment configurations for local development (Anvil), Ethereum Sepolia, and zkSync Sepolia testnets.
- **Foundry Development Workflow**: Leverages Foundry's powerful toolkit for streamlined smart contract development, testing, and deployment.
- **Modular Design**: Separates concerns into distinct contracts and scripts for clarity and maintainability.

## Project Structure
The repository is organized to clearly delineate contracts, deployment scripts, and configuration:

```
.
├── lib/
├── script/
│   ├── DeployAA_Account.s.sol      # Script to deploy the AA_Contract and HelperConfig.
│   ├── HelperConfig.s.sol          # Manages network configurations and deploys EntryPoint mocks.
│   └── SendPackedUserOp.s.sol      # Utility to generate and sign PackedUserOperations.
├── src/
│   ├── ethereum/
│   │   └── AA_Contract.sol         # The core EIP-4337 compatible smart account.
│   └── zksync/
│       └── ZkSmartWallet.sol       # Placeholder for zkSync native account abstraction.
├── foundry.toml                    # Foundry project configuration.
├── remappings.txt                  # Solidity import remappings.
└── ...other Foundry files (cache, broadcast)
```

## Getting Started

### Prerequisites 🛠️
Before you begin, ensure you have the following installed:

-   **Git**: For cloning the repository.
    ```bash
    # Check if Git is installed
    git --version
    ```
-   **Foundry**: A blazing-fast, portable, and modular toolkit for Ethereum application development written in Rust.
    ```bash
    # Install Foundry
    curl -L https://foundry.paradigm.xyz | bash
    foundryup

    # If targeting zkSync Era, you might need specific Foundry ZKsync tools:
    # curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/foundryup-zksync/foundryup-zksync -o foundryup-zksync
    # chmod +x foundryup-zksync
    # ./foundryup-zksync
    ```

### Installation ⬇️
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/olujimiAdebakin/Account_Abstraction_contract.git
    cd Account_Abstraction_contract
    ```
2.  **Install Foundry Dependencies**:
    ```bash
    forge install
    ```
3.  **Build Contracts**:
    ```bash
    forge build
    ```

### Environment Variables ⚙️
To interact with public testnets like Sepolia, you need to set up environment variables.
Create a `.env` file in the root directory and populate it with:

-   `PRIVATE_KEY`: The private key of your Ethereum account (without `0x` prefix). This account will be used for deploying contracts and signing transactions.
    Example: `PRIVATE_KEY=your_burner_wallet_private_key_here`
-   `ETH_SEPOLIA_RPC_URL`: Your RPC URL for the Ethereum Sepolia network (e.g., from Alchemy or Infura).
    Example: `ETH_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY`
-   `ZKSYNC_SEPOLIA_RPC_URL`: Your RPC URL for the zkSync Sepolia network. (Optional, if only targeting Ethereum)
    Example: `ZKSYNC_SEPOLIA_RPC_URL=https://sepolia.era.zksync.dev`

### Deployment 🚀
You can deploy the `AA_Contract` to your local Anvil instance or a testnet using Foundry scripts.

1.  **Deploy to Local Anvil**:
    First, start an Anvil instance in a separate terminal:
    ```bash
    anvil
    ```
    Then, deploy the contract:
    ```bash
    forge script script/DeployAA_Account.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --ffi
    ```
    This will deploy a mock `EntryPoint` and your `AA_Contract` to your local Anvil chain.

2.  **Deploy to Ethereum Sepolia**:
    Ensure your `PRIVATE_KEY` and `ETH_SEPOLIA_RPC_URL` are set in your `.env` file.
    ```bash
    source .env
    forge script script/DeployAA_Account.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --broadcast --verify -vvvv
    ```
    The `--verify` flag attempts to verify the contract on Etherscan. You might need to set up Etherscan API keys.

### Testing ✅
Run unit and integration tests using `forge test`:

```bash
forge test
```
To run tests with detailed verbosity:
```bash
forge test -vvvv
```

## Usage
The `AA_Contract` acts as a smart wallet that can be controlled by its owner or by an `EntryPoint` contract for EIP-4337 `UserOperations`.

### AA_Contract API

This section details the primary interface of the `AA_Contract` that external entities (like dApps, bundlers, or the owner) interact with.

### Base Contract Address
Interaction occurs directly with the deployed `AA_Contract` address on the blockchain.
**Sepolia Deployment Example**: `0x0780FbC5eb9BfA684154A8f0220aC59707256b41` (as observed in `broadcast/DeployAA_Account.s.sol/11155111/run-latest.json`)

### Endpoints

#### `POST /execute`
Executes a low-level call from the smart account to a target address.

**Request**:
This function is typically called by the `EntryPoint` contract or the contract's `owner`.
```solidity
function execute(address dest, uint256 value, bytes calldata functionData) external;
```
-   `dest`: `address` - The address of the contract or EOA to call.
-   `value`: `uint256` - The amount of native token (ETH) to send with the call, in wei.
-   `functionData`: `bytes` - The encoded calldata for the function to be executed on `dest`.

**Response**:
Success implies the internal call completed without reverting. No explicit return value from the `execute` function itself, but state changes occur on `dest`.

**Errors**:
-   `AA_Account_NotFromEntryPointOrOwner()`: If `msg.sender` is neither the `EntryPoint` nor the contract `owner`.
-   `AA_Account__CallFailed(bytes reason)`: If the low-level call to `dest` reverts, the `reason` (raw revert data) is included.

#### `POST /validateUserOp`
Validates an EIP-4337 `UserOperation`, checking its signature and handling prefunding. This function is called exclusively by the `EntryPoint` contract.

**Request**:
```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external returns (uint256 validationData);
```
-   `userOp`: `PackedUserOperation calldata` - The full `UserOperation` struct.
    -   `sender`: `address` - The address of the smart account.
    -   `nonce`: `uint256` - The nonce for the operation (for replay protection).
    -   `initCode`: `bytes` - Code to deploy the account if it's not yet deployed (empty for deployed accounts).
    -   `callData`: `bytes` - The data for the execution call (e.g., `execute` call to `AA_Contract`).
    -   `accountGasLimits`: `bytes32` - Packed `verificationGasLimit` and `callGasLimit`.
    -   `preVerificationGas`: `uint128` - Gas required for `validateUserOp` and transaction overhead.
    -   `gasFees`: `bytes32` - Packed `maxFeePerGas` and `maxPriorityFeePerGas`.
    -   `paymasterAndData`: `bytes` - Data for paymaster, if used.
    -   `signature`: `bytes` - Signature of `userOpHash` by the account owner.
-   `userOpHash`: `bytes32` - The unique hash of the `UserOperation` to be signed.
-   `missingAccountFunds`: `uint256` - The amount of ETH required to prefund the operation to the `EntryPoint`.

**Response**:
```solidity
returns (uint256 validationData)
```
-   `validationData`: `uint256` - Returns `SIG_VALIDATION_SUCCESS` (0) if validation passes and prefunding is handled. Otherwise, specific error codes (e.g., `SIG_VALIDATION_FAILED` (1)) are returned based on EIP-4337 specification.

**Errors**:
-   `AA_Account_NotFromEntryPoint()`: If `msg.sender` is not the `EntryPoint` contract.
-   Implicit (handled by `EntryPoint`): Signature mismatch, insufficient prefund (though `EntryPoint` determines `missingAccountFunds`).

#### `GET /getEntryPoint`
Retrieves the address of the `EntryPoint` contract configured for this smart account.

**Request**:
```solidity
function getEntryPoint() external view returns (address);
```
No parameters.

**Response**:
```solidity
returns (address entryPointAddress)
```
-   `entryPointAddress`: `address` - The address of the `EntryPoint` contract this account interacts with.

## Technologies Used
| Technology | Description                                            | Link                                               |
| :--------- | :----------------------------------------------------- | :------------------------------------------------- |
| Solidity   | Smart contract programming language for Ethereum.      | [Solidity Lang](https://soliditylang.org/)         |
| Foundry    | Fast, portable, and modular toolkit for EVM dev.       | [Foundry Docs](https://book.getfoundry.sh/         |
| EIP-4337   | Account Abstraction standard for smart accounts.       | [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337) |
| OpenZeppelin| Secure smart contract libraries.                       | [OpenZeppelin](https://openzeppelin.com/           |
| zkSync Era | Layer 2 scaling solution with native account abstraction.| [zkSync Era](https://zksync.io/era)                |

## Contributing 🤝
Contributions are welcome! If you have suggestions for improvements or find a bug, please follow these steps:

-   **Fork** the repository.
-   **Clone** your forked repository.
-   **Create a new branch** for your feature or bug fix: `git checkout -b feature/your-feature-name` or `bugfix/fix-bug-name`.
-   **Make your changes** and test them thoroughly.
-   **Commit** your changes with clear, concise messages.
-   **Push** your branch to your forked repository.
-   **Open a Pull Request** against the `main` branch of this repository, describing your changes in detail.

## License 📜
This project is licensed under the MIT License.

## Author 👤
**Adebakin Olujimi**
-   LinkedIn: [YourLinkedInProfile](https://www.linkedin.com/in/yourusername)
-   Twitter: [YourTwitterHandle](https://twitter.com/yourusername)

---
[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)