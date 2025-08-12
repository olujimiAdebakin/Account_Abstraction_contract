# Account Abstraction Smart Account 🔐

## Overview
This project implements an Account Abstraction (EIP-4337) compatible smart account on the Ethereum blockchain, allowing for flexible transaction execution and signature validation. Developed using Solidity and the Foundry development framework, it provides core functionalities for managing user operations through an EntryPoint contract.

## Features
- **EIP-4337 Compliance**: Built to integrate seamlessly with an EIP-4337 EntryPoint contract, enabling gasless transactions and customizable signature schemes.
- **Flexible Execution**: Supports transaction execution initiated directly by the account owner or via a bundled `UserOperation` processed by an EntryPoint.
- **Customizable Signature Validation**: Features an `_validateSignature` mechanism that recovers the signer from a UserOperation hash using ECDSA, ensuring only authorized parties can initiate actions.
- **Gas Prefunding Mechanism**: Includes logic to prefund gas fees to the EntryPoint contract during `validateUserOp` calls, adhering to the EIP-4337 specification.
- **Foundry Tooling**: Leverages Foundry for robust development, testing, and deployment scripting, providing a streamlined workflow for smart contract management.
- **Error Handling**: Implements custom error types for clear and specific feedback on failed operations, such as unauthorized access or low-level call failures.

## Getting Started
To get a copy of the project up and running on your local machine, follow these steps.

### Installation
Before you begin, ensure you have [Foundry](https://getfoundry.sh/) installed. If not, you can install it using:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Once Foundry is installed, clone the repository and install the dependencies:

✨ **Clone the Repository**:
```bash
git clone https://github.com/olujimiAdebakin/Account_Abstraction_contract.git
cd account_abstraction_contract
```

📦 **Install Foundry Dependencies**:
```bash
forge install
```

🚀 **Build the Project**:
```bash
forge build
```

### Environment Variables
For deployment to public networks, you will typically need to configure your RPC URL and a private key. While this project's `HelperConfig` script manages EntryPoint addresses for various chains, the actual private key for broadcasting transactions needs to be set up externally for Foundry.

| Variable Name   | Example Value                                  | Description                                            |
| :-------------- | :--------------------------------------------- | :----------------------------------------------------- |
| `RPC_URL`       | `https://sepolia.infura.io/v3/YOUR_API_KEY`    | The RPC endpoint for the blockchain network to connect to. |
| `PRIVATE_KEY`   | `0x...` (your private key)                     | The private key of the account used for deployment and signing transactions. **(Required for non-Anvil deployments)** |

## Usage

### Testing
To run the test suite for the smart contracts:

```bash
forge test
```

### Deployment
The project includes a Foundry script to deploy the `AA_Contract`.

1.  **Configure Network (Optional)**: The `script/HelperConfig.s.sol` contract automatically determines the EntryPoint address based on the `block.chainid`. For local Anvil, it deploys a mock EntryPoint if one doesn't exist. For Sepolia, it uses a predefined EntryPoint address.

2.  **Deploy the Account**:
    To deploy `AA_Contract` to a local Anvil network (default chain ID `31337`):
    ```bash
    forge script script/DeployAA_Account.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    ```
    Replace the `--rpc-url` and `--private-key` with your actual network details and private key for deploying to a testnet like Sepolia.

### Sending Packed User Operations
The `SendPackedUserOp.s.sol` script demonstrates how to generate a signed `PackedUserOperation` which can then be sent to an EntryPoint contract by a bundler.

To generate a signed UserOperation:

1.  **Modify `SendPackedUserOp.s.sol`**: You would typically call `generateSignedUserOp` from another script or a test. For demonstration, you could add a `run()` function to `SendPackedUserOp.s.sol` that calls `generateSignedUserOp` with example `callData`.

    Example `run()` function (add this to `SendPackedUserOp.s.sol` temporarily for testing):
    ```solidity
    function run() public {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address aaContract = 0xYourDeployedAAContractAddress; // Replace with your deployed AA_Contract address
        bytes memory callData = abi.encodeWithSelector(AA_Contract.execute.selector, address(this), 0, ""); // Example calldata

        PackedUserOperation memory signedUserOp = generateSignedUserOp(callData, config, aaContract);
        // You would typically send this signedUserOp to an EntryPoint via a bundler
        // For local testing, you might call EntryPoint.handleOps here
        console2.log("Generated UserOp signature:", signedUserOp.signature);
    }
    ```

2.  **Execute the Script**:
    ```bash
    forge script script/SendPackedUserOp.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    ```

## Smart Contract Interface

### Contract: `AA_Contract`

The primary smart account contract that integrates with EIP-4337.

#### `function execute(address dest, uint256 value, bytes calldata functionData) external`
Executes a low-level call to a target address. This function can be called by the EntryPoint contract (as part of a UserOperation) or directly by the contract owner.

**Request**:
```solidity
{
  "dest": "address",           // The target contract address for the call.
  "value": "uint256",          // The amount of ETH (in wei) to send with the call.
  "functionData": "bytes"      // The calldata for the target contract's function (function selector + arguments).
}
```
**Response**:
Successful execution returns nothing (void).

**Errors**:
- `AA_Account__CallFailed(bytes reason)`: Thrown if the low-level call to `dest` fails, including the raw revert data.
- `AA_Account_NotFromEntryPointOrOwner()`: Thrown if the caller is neither the EntryPoint nor the owner.

#### `function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external returns (uint256 validationData)`
Called by the EntryPoint contract to validate a user operation, verify its signature, and ensure prefunding is handled.

**Request**:
```solidity
{
  "userOp": {
    "sender": "address",
    "nonce": "uint256",
    "initCode": "bytes",
    "callData": "bytes",
    "accountGasLimits": "bytes32",
    "preVerificationGas": "uint256",
    "gasFees": "bytes32",
    "paymasterAndData": "bytes",
    "signature": "bytes"
  },
  "userOpHash": "bytes32",      // The hash of the user operation, used for signature verification.
  "missingAccountFunds": "uint256" // The amount of ETH required to prefund the operation.
}
```
**Response**:
Returns a `uint256` representing the validation status:
- `SIG_VALIDATION_SUCCESS`: `1` (from `lib/account-abstraction/contracts/core/Helpers.sol`) indicating successful validation.
- `SIG_VALIDATION_FAILED`: `0` (from `lib/account-abstraction/contracts/core/Helpers.sol`) indicating signature validation failure.

**Errors**:
- `AA_Account_NotFromEntryPoint()`: Thrown if the caller is not the EntryPoint contract.

#### `function getEntryPoint() external view returns (address)`
Returns the address of the EntryPoint contract associated with this smart account.

**Request**:
None

**Response**:
Returns the `address` of the EntryPoint contract.

**Errors**:
None

### Error Details

- `AA_Account_NotFromEntryPoint()`:
    - **Scenario**: A function intended for internal EntryPoint calls (e.g., `validateUserOp`) is invoked by an address other than the configured EntryPoint contract.
    - **Meaning**: Indicates unauthorized access; only the designated EntryPoint can call this function.

- `AA_Account_NotFromEntryPointOrOwner()`:
    - **Scenario**: A function intended for either the EntryPoint or the account owner (e.g., `execute`) is invoked by any other address.
    - **Meaning**: Indicates unauthorized access; ensures only trusted callers can perform critical operations.

- `AA_Account__CallFailed(bytes reason)`:
    - **Scenario**: A low-level call initiated by the `execute` function to a target contract reverts.
    - **Meaning**: The transaction attempted by the smart account failed at the destination contract. The `reason` parameter provides the raw revert data from the failing call for debugging.

## Technologies Used
This project is built upon a robust stack of blockchain and development tools.

| Technology | Category       | Purpose                                    | Link                                    |
| :--------- | :------------- | :----------------------------------------- | :-------------------------------------- |
| Solidity   | Language       | Smart contract development                 | [Solidity](https://soliditylang.org/)   |
| Foundry    | Dev Framework  | Ethereum development toolkit (Forge, Cast) | [Foundry](https://getfoundry.sh/)       |
| EIP-4337   | Standard       | Account Abstraction specification          | [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337) |
| OpenZeppelin| Library       | Secure smart contract building blocks      | [OpenZeppelin](https://docs.openzeppelin.com/contracts/5.x/) |

## Contributing
We welcome contributions to enhance this Account Abstraction smart account! Please follow these guidelines:

⭐ **Fork the Repository**: Start by forking this repository to your GitHub account.

🌿 **Create a Branch**: Create a new branch for your feature or bug fix:
`git checkout -b feature/your-feature-name` or `git checkout -b bugfix/fix-description`

💡 **Implement Changes**: Make your changes, ensuring they adhere to the project's coding style and best practices. Write comprehensive tests for new functionalities.

✅ **Run Tests**: Before submitting, ensure all tests pass:
`forge test`

⬆️ **Commit and Push**: Commit your changes with a clear, concise message and push to your forked repository.

🔄 **Create a Pull Request**: Open a pull request to the `main` branch of this repository, describing your changes in detail.

## License
This project is licensed under the MIT License. You can find the full text of the license [here](https://opensource.org/licenses/MIT).

## Author Info
Developed by Adebakin Olujimi.

- **LinkedIn**: [Your_LinkedIn_Username]
- **Twitter**: [Your_Twitter_Handle]

---
<!-- Badges Section -->
[![Solidity](https://img.shields.io/badge/Language-Solidity-363636?style=flat&logo=solidity&logoColor=white)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Build%20System-Foundry-gray?style=flat&logo=ethereum&logoColor=white)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)