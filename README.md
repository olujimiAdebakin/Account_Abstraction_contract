# Account Abstraction Smart Contract 🔐

## Overview
This project implements an Account Abstraction (EIP-4337) compatible smart account contract written in Solidity, developed using the Foundry development framework. It enables gasless transactions, multi-signature capabilities, and other advanced functionalities by allowing users to pay for transactions and interact with the blockchain in a more flexible manner.

## Features
-   **Solidity**: Core smart contract logic for the account abstraction functionality.
-   **Foundry**: Robust development toolkit for building, testing, and deploying Solidity smart contracts.
-   **EIP-4337 Compatibility**: Adheres to the ERC-4337 standard for smart contract wallets, enabling decentralized account abstraction without protocol-level changes.
-   **Gas Abstraction**: Allows transactions to be sponsored by paymasters, abstracting gas costs from the end-user.
-   **Signature Validation**: Implements secure ECDSA signature recovery for `UserOperation` validation, ensuring only authorized operations are processed.
-   **Modular Design**: Integrates with the official `account-abstraction` library and OpenZeppelin contracts for secure and efficient smart contract development.
-   **Deployment Scripts**: Automated deployment scripts for various Ethereum networks, including Sepolia and local Anvil environments.

## Getting Started
To get a local copy up and running, follow these simple steps.

### Installation
Ensure you have [Foundry](https://getfoundry.sh/) installed. If not, you can install it using `foundryup`:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Then, clone the repository and install project dependencies:

```bash
git clone https://github.com/olujimiAdebakin/Account_Abstraction_contract.git
cd Account_Abstraction_contract
forge install
forge build
```

### Environment Variables
This project primarily uses network configurations defined within `script/HelperConfig.s.sol`. However, for deploying or interacting with contracts on a live network, you will need to set your private key as an environment variable for Foundry.

| Variable             | Description                                          | Example Value (Testnet)           |
| :------------------- | :--------------------------------------------------- | :-------------------------------- |
| `FOUNDRY_PRIVATE_KEY` | The private key of the deployer/signer wallet.      | `0xac0974bec39a17e36ba4a6b4d238cff` |
| `RPC_URL`            | RPC URL for the target blockchain network. (Optional, if using `forge script` with `--rpc-url`) | `https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID` |

You can set these in your terminal session or in a `.env` file (e.g., using `source .env`):

```bash
export FOUNDRY_PRIVATE_KEY="YOUR_PRIVATE_KEY_HERE"
export RPC_URL="YOUR_RPC_URL_HERE" # Only if not passed via command line
```

## Smart Contract Interface

This section details the publicly exposed functions (endpoints) of the `AA_Contract` smart account.

### Base Contract
The `AA_Contract` is deployed to a specific address on the blockchain. Interaction occurs directly with this deployed instance.

### Endpoints

#### `external payable receive()`
Allows the smart account to receive native cryptocurrency (ETH) transfers.

**Request**:
Direct ETH transfer to the contract address.

**Response**:
Successful ETH transfer.

**Errors**:
None, as it's a fallback `receive` function.

---

#### `external requireFromEntryPointOrOwner execute(address dest, uint256 value, bytes calldata functionData)`
Executes an arbitrary call to a target contract from the context of the smart account. This function is typically invoked by the EntryPoint contract as part of a `UserOperation` or directly by the contract owner.

**Request**:
-   `dest`: `address` - The address of the target contract to call.
-   `value`: `uint256` - The amount of native token (wei) to send with the call.
-   `functionData`: `bytes calldata` - The encoded function call data for `dest`.

**Response**:
None, on successful execution.

**Errors**:
-   `AA_Account_NotFromEntryPointOrOwner()`: If `msg.sender` is neither the EntryPoint nor the account owner.
-   `AA_Account__CallFailed(bytes reason)`: If the low-level call to `dest` reverts, `reason` contains the raw revert data.

---

#### `external requireFromEntryPoint validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) returns (uint256 validationData)`
Validates an incoming `UserOperation` according to EIP-4337. This function is called exclusively by the EntryPoint contract. It verifies the signature and ensures the account has sufficient funds.

**Request**:
-   `userOp`: `PackedUserOperation calldata` - The user operation struct containing details like sender, nonce, callData, signature, etc.
    ```solidity
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits; // (verificationGasLimit << 128) | callGasLimit
        uint256 preVerificationGas;
        bytes32 gasFees;          // (maxFeePerGas << 128) | maxPriorityFeePerGas
        bytes paymasterAndData;
        bytes signature;
    }
    ```
-   `userOpHash`: `bytes32` - The EIP-712 hash of the `UserOperation`.
-   `missingAccountFunds`: `uint256` - The amount of native token (wei) the EntryPoint expects the account to provide for prefunding.

**Response**:
-   `validationData`: `uint256` - A status code indicating the validation result.
    -   `SIG_VALIDATION_SUCCESS`: `0` (or `0x1` based on EIP-4337 return value interpretation). Indicates successful validation.
    -   `SIG_VALIDATION_FAILED`: `1` (or `0xffffffff` based on EIP-4337). Indicates signature validation failed.

**Errors**:
-   `AA_Account_NotFromEntryPoint()`: If `msg.sender` is not the EntryPoint contract.
-   Internally returns `SIG_VALIDATION_FAILED` if the signature recovery fails or the recovered signer is not the account's owner.

---

#### `external view getEntryPoint() returns (address)`
Returns the address of the EntryPoint contract that this smart account is configured to use.

**Request**:
None.

**Response**:
-   `address`: The address of the associated EntryPoint contract.

**Errors**:
None.

## Usage
### Deployment
To deploy the `AA_Contract` to a local Anvil instance or a testnet:

1.  **Start an Anvil instance (for local testing):**
    ```bash
    anvil
    ```
    This will typically run on `http://127.0.0.1:8545`.

2.  **Deploy the contract:**
    For local Anvil:
    ```bash
    forge script script/DeployAA_Account.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $FOUNDRY_PRIVATE_KEY
    ```
    For Sepolia (requires `RPC_URL` and `FOUNDRY_PRIVATE_KEY` set):
    ```bash
    forge script script/DeployAA_Account.s.sol --rpc-url $RPC_URL --broadcast --private-key $FOUNDRY_PRIVATE_KEY --verify --etherscan-api-key YOUR_ETHERSCAN_API_KEY
    ```
    The deployment script will output the deployed contract address.

### Sending a Packed User Operation
To demonstrate sending a `UserOperation` through the EntryPoint:

1.  **Ensure you have a deployed `AA_Contract` and an EntryPoint contract configured.** The `DeployAA_Account.s.sol` script deploys the `AA_Contract` and uses a pre-configured EntryPoint address.
2.  **Use the `SendPackedUserOp.s.sol` script as a template** to construct and sign a `PackedUserOperation`. You would need to adapt its `run()` function to actually send the `UserOperation` to the EntryPoint (e.g., calling `EntryPoint.handleOps`).
    
    Example of how you might call `generateSignedUserOp` from a test or another script:
    ```solidity
    // In a test or script context where `vm` is available
    function testSendOp() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        AA_Contract aaContract = new AA_Contract(config.entryPoint); // Or load existing AA_Contract
        
        // Example call data (e.g., transfer 1 wei to an address)
        bytes memory callData = abi.encodeWithSelector(
            aaContract.execute.selector,
            address(0xRecipientAddress), // Replace with an actual recipient
            1,                            // 1 wei
            ""                            // Empty bytes for value transfer
        );

        SendPackedUserOp sendOpScript = new SendPackedUserOp();
        PackedUserOperation memory userOp = sendOpScript.generateSignedUserOp(
            callData,
            address(aaContract), // The sender is the AA_Contract itself
            config // Pass the network config
        );

        // Now, send this userOp to the EntryPoint:
        // IEntryPoint(config.entryPoint).handleOps(userOp, address(0)); // This would be the next step
    }
    ```
    *Note: The `SendPackedUserOp.s.sol` currently only contains the logic for generating a signed UserOp. To actually send it, you would typically integrate with an EIP-4337 bundler or call `handleOps` on the EntryPoint (which is usually done off-chain by a bundler).*

## Technologies Used

| Technology                                                                | Description                                                                 |
| :------------------------------------------------------------------------ | :-------------------------------------------------------------------------- |
| [Solidity](https://soliditylang.org/)                                     | Smart contract programming language.                                        |
| [Foundry](https://getfoundry.sh/)                                         | Ethereum development framework written in Rust.                             |
| [EIP-4337 Account Abstraction](https://eips.ethereum.org/EIPS/eip-4337) | Standard for smart contract wallets without protocol changes.               |
| [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/)   | Reusable smart contracts for secure development (e.g., `Ownable`).         |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std)       | Collection of useful utilities for Foundry scripts and tests.               |

## Contributing
Contributions are welcome! Please follow these steps to contribute:

✨ **Fork the repository:** Start by forking the project to your GitHub account.

🌳 **Create a new branch:** For each new feature or bug fix, create a dedicated branch.
   ```bash
   git checkout -b feature/your-feature-name
   ```

💡 **Implement your changes:** Write clear, concise code and ensure it adheres to the existing coding style.

🧪 **Write tests:** Add appropriate tests to cover your new features or bug fixes.

✅ **Run tests:** Ensure all existing tests pass and your new tests are successful.
   ```bash
   forge test
   ```

📝 **Update documentation:** If your changes affect the contract's interface or usage, update the README and relevant documentation.

⬆️ **Commit and push:** Commit your changes with a descriptive message and push them to your forked repository.

🔄 **Create a Pull Request (PR):** Open a pull request to the `main` branch of this repository. Provide a detailed description of your changes and why they are needed.

We appreciate your contributions!

## Author Info

Connect with me:

*   LinkedIn: [YourLinkedInUsername]
*   Twitter: [YourTwitterUsername]

## Badges
[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Rust-red?logo=rust)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)