
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";


contract HelperConfig is Script{

      // Configuration struct
    struct NetworkConfig {
        address entryPoint;
        address account; // Deployer/burner wallet address
    }


    // Chain ID Constants
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337; // Anvil default
    
    
    // Official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
//     EOA: 0x45630a7Db07604f82a1D2ccf8509eb375b1826C6
    address constant BURNER_WALLET = 0xCCe6662d417Cc62641F096e926557c5816623bf5; // Replace with your actual address
    
    
    // State Variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;


    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
    }


    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            account: BURNER_WALLET
        });
    }


    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        // ZKSync Era has native account abstraction; an external EntryPoint might not be used in the same way.
        // address(0) is used as a placeholder or to indicate reliance on native mechanisms.
        return NetworkConfig({
            entryPoint: address(0),
            account: BURNER_WALLET
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // For local Anvil network, we might need to deploy a mock EntryPoint
        // address mockEntryPointAddress = deployMockEntryPoint(); // Placeholder
        // For now, let's use Sepolia's EntryPoint or a defined mock if available
        // This part would involve deploying a mock EntryPoint if one doesn't exist.
        // For simplicity in this example, we'll assume a mock or reuse Sepolia's for structure.
        // In a real scenario, you'd deploy a MockEntryPoint.sol here.
        // Example: localNetworkConfig = NetworkConfig({ entryPoint: mockEntryPointAddress, account: BURNER_WALLET });
        // Fallback for this lesson (actual mock deployment not shown):
        NetworkConfig memory sepoliaConfig = getEthSepoliaConfig(); // Or a specific local mock entry point
        localNetworkConfig = NetworkConfig({
            entryPoint: sepoliaConfig.entryPoint, // Replace with actual mock entry point if deployed
            account: BURNER_WALLET
        });
        return localNetworkConfig;
    }


    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }
        if (networkConfigs[chainId].account != address(0)) { // Check if config exists
            return networkConfigs[chainId];
        }
        revert("HelperConfig__InvalidChainId()");
    }
    
    // deploy mocks
    // console2.log("Deploying mocks...");
    // EntryPoint entrypoint = new EntryPoint();

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
