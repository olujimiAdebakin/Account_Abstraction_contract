// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployAA_Account is Script {
    function run() public returns (HelperConfig, AA_Contract) {
        return deployAA_Contract();
    }

    function deployAA_Contract() public returns (HelperConfig, AA_Contract) {
        // Instantiate the HelperConfig contract
        HelperConfig helperConfig = new HelperConfig();

        // Get the active network configuration
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Start broadcasting with the deployer's private key
        vm.startBroadcast(config.account);

        // Deploy the AA_Contract with the EntryPoint address
        AA_Contract aaContract = new AA_Contract(config.entryPoint);

        // Transfer ownership to the deployer (msg.sender)
        aaContract.transferOwnership(config.account);

        vm.stopBroadcast();

        return (helperConfig, aaContract);
    }
}
