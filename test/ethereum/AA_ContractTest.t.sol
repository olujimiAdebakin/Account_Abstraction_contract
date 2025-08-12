// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

////////////////////////////////////////////////////////////////////////////////
//                                CONTRACT FLOW                               //
////////////////////////////////////////////////////////////////////////////////
//
// This test suite validates the AA_Contract's functionality through several steps:
//
// setUp() -> Deploys all necessary contracts (AA_Contract, EntryPoint, etc.)
//    |
//    +--> testOwnerCanExecuteCommands()       (Tests direct owner control)
//    |
//    +--> testNonOwnerCanExecuteCommands()    (Tests non-owner access restriction)
//    |
//    +--> testRecoverSignedOp()              (Tests signature generation & recovery)
//    |
//    +--> testValidationOfUserOps()          (Tests the EntryPoint's validateUserOp() call)
//    |
//    +--> testEntryPointCanExecuteCommands()  (Tests the full EIP-4337 flow via handleOps())
//
////////////////////////////////////////////////////////////////////////////////

import {Test} from "forge-std/Test.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAA_Account} from "script/DeployAA_Account.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title AA_ContractTest
 * @author Adebakin Olujimi
 * @notice A Foundry test suite for the `AA_Contract` smart account.
 * @dev This contract tests both the direct owner-controlled functionality and the EIP-4337 `EntryPoint`-driven flows, including signature validation and end-to-end execution.
 */
contract AA_ContractTest is Test {
    /// @notice A utility for hashing messages with the Ethereum signed message prefix.
    using MessageHashUtils for bytes32;

    //////////////////////////////////////////////////////////////////////////////
    //                         STATE VARIABLES                                  //
    //////////////////////////////////////////////////////////////////////////////

    /// @notice A reference to the helper configuration script.
    HelperConfig helperConfig;
    /// @notice The smart account contract being tested.
    AA_Contract aaContract;
    /// @notice A mock ERC20 token used for testing transactions.
    ERC20Mock usdc;
    /// @notice A script for generating signed user operations.
    SendPackedUserOp sendPackedUserOp;

    /// @notice A random address used to simulate a non-owner account.
    address randomUser = makeAddr("randomUser");
    /// @notice A constant amount used for minting and transactions (1,000,000 USDC).
    uint256 AMOUNT = 1e21;

    //////////////////////////////////////////////////////////////////////////////
    //                         SETUP FUNCTION                                   //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Sets up the testing environment before each test case.
     * @dev This function deploys the `AA_Contract` and its dependencies (`EntryPoint`), a mock ERC20 token for testing, and the `SendPackedUserOp` script. It also asserts that the smart account was deployed successfully.
     */
    function setUp() public {
        // Deploy the AA_Contract and its dependencies using a separate script.
        DeployAA_Account deployAA_Contract = new DeployAA_Account();
        (helperConfig, aaContract) = deployAA_Contract.deployAA_Contract();
        // Assert that the contract was deployed to a valid address.
        assertTrue(address(aaContract) != address(0), "AA_Contract deployment failed");
        
        // Deploy a mock ERC20 token to use for testing transactions.
        usdc = new ERC20Mock();
        
        // Deploy the utility script for generating user operations.
        sendPackedUserOp = new SendPackedUserOp();
    }

    //////////////////////////////////////////////////////////////////////////////
    //                         TEST FUNCTIONS                                   //
    //////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Tests that the owner of the smart account can directly execute a command.
     * @dev This test simulates the owner calling `execute` to mint USDC to the smart account, and asserts that the balance is updated correctly.
     */
    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        // Encode the calldata to mint tokens.
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Act
        // Use `vm.prank` to simulate the owner calling the function.
        vm.prank(address(aaContract.owner()));
        aaContract.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(aaContract)), AMOUNT, "Mint failed");
    }

    /**
     * @notice Tests that a non-owner cannot directly execute a command.
     * @dev This test simulates a random user calling `execute` and asserts that the transaction reverts with the expected `AA_Account_NotFromEntryPointOrOwner` error.
     */
    function testNonOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Act & Assert
        // Use `vm.startPrank` and `vm.expectRevert` to check for the correct revert condition.
        vm.startPrank(randomUser);
        vm.expectRevert(AA_Contract.AA_Account_NotFromEntryPointOrOwner.selector);
        aaContract.execute(dest, value, functionData);
        vm.stopPrank();
    }

    /**
     * @notice Tests that the signature on a `UserOperation` can be recovered to the correct address.
     * @dev This test generates a `PackedUserOperation`, computes its hash, and uses `ECDSA.recover` to verify that the recovered signer address matches the smart account's owner.
     */
    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);
        
        // Build the calldata for the `AA_Contract.execute` function.
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector,
            dest,
            value,
            functionData
        );

        // Call the helper script to create a signed user operation.
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(aaContract));
        
        // Get the hash of the user operation from the EntryPoint contract.
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        // Recover the signer address from the signed hash and the signature.
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, aaContract.owner(), "Recovered signer should match AA_Contract owner");
    }

    /**
     * @notice Tests that the `validateUserOp` function returns a success code when called by the EntryPoint.
     * @dev This test simulates the EntryPoint calling the validation function and verifies that the return value is `0`, which signifies a successful validation according to the EIP-4337 standard.
     */
    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);
        
        // Build the calldata for the `AA_Contract.execute` function.
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector,
            dest,
            value,
            functionData
        );

        // Generate a signed user operation.
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(aaContract));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18; // 1 ETH for pre-funding

        // Act
        // Simulate the EntryPoint calling `validateUserOp`.
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = aaContract.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);

        // Assert
        // A return value of 0 indicates a successful validation according to EIP-4337.
        assertEq(validationData, 0, "UserOp validation failed");
    }
    
    /**
     * @notice An end-to-end test that simulates the full EIP-4337 flow via the EntryPoint.
     * @dev This test creates a signed `UserOperation`, sends it to the `EntryPoint` using `handleOps`, and then asserts that the smart account successfully executed the transaction.
     */
    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);
        
        // Build the calldata for the `AA_Contract.execute` function.
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector,
            dest,
            value,
            functionData
        );

        // Generate a signed user operation.
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(aaContract));
        
        // Send some ETH to the smart account for pre-funding.
        vm.deal(address(aaContract), 1e18);

        // Create an array containing the single user operation.
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;
        
        // Act
        // Simulate a bundler (`randomUser`) calling `handleOps` on the EntryPoint.
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        // The transaction should have been executed, so the smart account's USDC balance should have increased.
        assertEq(usdc.balanceOf(address(aaContract)), AMOUNT,
            "AA_Contract should have received minted USDC"
        );
    }
}
