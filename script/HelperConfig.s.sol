// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

////////////////////////////////////////////////////////////////////////////////
//                                CONTRACT FLOW                               //
////////////////////////////////////////////////////////////////////////////////
//
// The HelperConfig contract is a utility for managing deployment configurations.
// Its primary flow is centered around retrieving the correct network settings
// based on the current chain ID.
//
//    getConfig() called
//         |
//    (block.chainid)
//         |
//  +---------------------------+--------------------------+
//  |                           |                          |
//  | LOCAL_CHAIN_ID? (31337)   |  Other Chain ID?         |
//  |                           |                          |
//  +---------------------------+--------------------------+
//         |                           |
//         |                           |
//   (Yes) |                           | (No)
//         V                           V
// getOrCreateAnvilEthConfig()  ->  networkConfigs[chainId]
//         |                           |
//  (Check if local config exists)     |
//         |                           V
//  +-------------------+              (Return stored config)
//  |                   |
//  |  (Exists?)        |
//  |                   |
//  +-------------------+
//         |
//   (Yes) | (No)
//         V
// (Return existing)   -> (Deploy Mock EntryPoint, store config, return)
//
////////////////////////////////////////////////////////////////////////////////

import {Script, console2} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

/**
 * @title HelperConfig
 * @author Adebakin Olujimi
 * @notice A Foundry script contract for managing network configurations for EIP-4337 testing and deployment.
 * @dev This contract provides a structured way to get the correct EntryPoint and account addresses for various networks (local, Sepolia, zkSync Sepolia), including logic for deploying a mock EntryPoint on the local Anvil network if needed.
 */
contract HelperConfig is Script {
    //////////////////////////////////////////////////////////////////////////////
    //                           STRUCTS & CONSTANTS                            //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice A struct to hold configuration details for a specific network.
    /// @param entryPoint The address of the EntryPoint contract for the network.
    /// @param account The address of the burner/deployer wallet to be used on the network.
    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    /// @notice Constants for well-known chain IDs.
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337; // Anvil default

    /// @notice Address of a burner wallet for use on testnets.
    address constant BURNER_WALLET = 0xCCe6662d417Cc62641F096e926557c5816623bf5;

    /// @notice Default account address used by Anvil.
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    //////////////////////////////////////////////////////////////////////////////
    //                         STATE VARIABLES                                  //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice A public variable to store the configuration for the local network.
    NetworkConfig public localNetworkConfig;
    
    /// @notice A mapping to store network configurations by their chain ID.
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    //////////////////////////////////////////////////////////////////////////////
    //                         CONSTRUCTOR                                      //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Initializes the contract by setting the configuration for Sepolia and zkSync Sepolia.
     * @dev This constructor is called on deployment, populating the `networkConfigs` mapping with predefined configurations for standard testnets.
     */
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         PUBLIC FUNCTIONS                                 //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the predefined configuration for the Ethereum Sepolia testnet.
     * @dev This function uses `pure` as it doesn't read or write to state. It returns a fixed configuration with the official EntryPoint address for Sepolia.
     * @return A `NetworkConfig` struct containing the EntryPoint and burner account for Sepolia.
     */
    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    /**
     * @notice Returns the predefined configuration for the zkSync Sepolia testnet.
     * @dev zkSync Era has native account abstraction, so a dedicated EntryPoint may not be needed. `address(0)` is used as a placeholder. This function is `pure`.
     * @return A `NetworkConfig` struct with a placeholder EntryPoint and the burner account for zkSync Sepolia.
     */
    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    /**
     * @notice Returns the configuration for the local Anvil network, deploying a mock EntryPoint if one doesn't exist yet.
     * @dev This function checks the `localNetworkConfig` state variable. If the configuration is not set (`address(0)`), it deploys a new `EntryPoint` contract using Anvil's default account and stores its address.
     * @return A `NetworkConfig` struct for the local development network.
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // If a local config already exists, return it to avoid redeploying the mock.
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // Log a message to the console to indicate that a mock is being deployed.
        console2.log("Deploying mocks....");

        // Use Foundry's `vm.startBroadcast` and `vm.stopBroadcast` to simulate a transaction from the Anvil default account.
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        // Store the newly deployed EntryPoint's address and the Anvil default account in the local config.
        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

        return localNetworkConfig;
    }

    /**
     * @notice Retrieves the network configuration for a given chain ID.
     * @dev This is the main getter function. It first checks for the local network configuration, then checks the mapping for other known chains. It reverts if the chain ID is not recognized.
     * @param chainId The ID of the network for which to retrieve the configuration.
     * @return A `NetworkConfig` struct for the specified network.
     */
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }
        if (networkConfigs[chainId].account != address(0)) {
            // Check if a configuration exists for the given chainId.
            return networkConfigs[chainId];
        }
        // Revert with a custom error if the chain ID is not supported.
        revert("HelperConfig__InvalidChainId()");
    }
    
    /**
     * @notice A convenience function to get the configuration for the current blockchain.
     * @dev This function calls `getConfigByChainId` with the current `block.chainid`.
     * @return A `NetworkConfig` struct for the network the contract is currently running on.
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
