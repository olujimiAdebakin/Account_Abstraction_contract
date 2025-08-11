// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {AA_Contract} from "src/ethereum/AA_Contract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployAA_Account} from "script/DeployAA_Account.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract AA_ContractTest is Test {
    using MessageHashUtils for bytes32;

    // State Variables
    HelperConfig helperConfig;
    AA_Contract aaContract;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    // unsignedUserOp userOp;

    // address randomAddress = address(0x1234567890123456789012345678901234567890);
    address randomUser = makeAddr("randomUser");
    uint256 AMOUNT = 1e21; // 1 thousand USDC in wei

    function setUp() public {
        DeployAA_Account deployAA_Contract = new DeployAA_Account();
        (helperConfig, aaContract) = deployAA_Contract.deployAA_Contract();
        assertTrue(address(aaContract) != address(0), "AA_Contract deployment failed");
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Approval

    // msg.sender -> AA_Contract
    // approve some amount
    // USDC contract
    // come from the entrypoint

    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Act
        vm.prank(address(aaContract.owner()));
        aaContract.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(aaContract)), AMOUNT, "Mint failed");
    }

    function testNonOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Act + Assert
        vm.startPrank(randomUser);
        vm.expectRevert(AA_Contract.AA_Account_NotFromEntryPointOrOwner.selector); // or your custom error
        aaContract.execute(dest, value, functionData);
        vm.stopPrank();
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Build calldata for AA_Contract.execute(...)
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector, // must be a function in AA_Contract
            dest,
            value,
            functionData
        );

        // Call helper to create the PackedUserOperation
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, address(aaContract), helperConfig.getConfig(), address(aaContract));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Get the userOpHash

        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, aaContract.owner(), "Recovered signer should match AA_Contract owner");

        // assertEq(recovered, address(aaContract), "Recovered signer should match AA_Contract owner");

        // console.log("Recovered signer: %s", recovered);
    }

    //  1. Sign user Ops
    //  2. Call validate userops
    // 3. Assert the return is correct
    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Build calldata for AA_Contract.execute(...)
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector, // must be a function in AA_Contract
            dest,
            value,
            functionData
        );

        // Call helper to create the PackedUserOperation
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, address(aaContract), helperConfig.getConfig(), address(aaContract));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        //     Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = aaContract.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);

            assertEq(validationData, 0, "UserOp validation failed");
        
    }

    function testEntryPointCanExecuteCommands() public {

                // Arrange
        assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

        address dest = address(usdc);
        uint256 value = 0;

        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(aaContract), AMOUNT);

        // Build calldata for AA_Contract.execute(...)
        bytes memory executeCallData = abi.encodeWithSelector(
            AA_Contract.execute.selector, // must be a function in AA_Contract
            dest,
            value,
            functionData
        );

        // Call helper to create the PackedUserOperation
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, address(aaContract), helperConfig.getConfig(), address(aaContract));
        // bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

         vm.deal(address(aaContract) , 1e18); // Send some ether to the AA_Contract

         PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;
        // Act

        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser)
        );

        assertEq(usdc.balanceOf(address(aaContract)), AMOUNT,
            "AA_Contract should have received minted USDC"
        );
        // aaContract.executeFromEntryPoint(packedUserOp, userOpHash);

    }

//     function testEntryPointCanExecuteCommands() public {
//     // -------- Arrange --------
//     // Ensure AA_Contract starts with zero USDC balance
//     assertEq(usdc.balanceOf(address(aaContract)), 0, "Initial balance should be zero");

//     address dest = address(usdc);
//     uint256 value = 0;

//     // Prepare function call to mint tokens to the AA_Contract
//     bytes memory functionData = abi.encodeWithSelector(
//         ERC20Mock.mint.selector,
//         address(aaContract),
//         AMOUNT
//     );

//     // Prepare calldata for AA_Contract.execute(...)
//     bytes memory executeCallData = abi.encodeWithSelector(
//         AA_Contract.execute.selector, 
//         dest,
//         value,
//         functionData
//     );

//     // Create PackedUserOperation with signed data
//     PackedUserOperation memory packedUserOp =
//         sendPackedUserOp.generateSignedUserOp(
//             executeCallData,
//             address(aaContract),
//             helperConfig.getConfig()
//         );

//     // Compute UserOp hash (for verification if needed)
//     bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint)
//         .getUserOpHash(packedUserOp);

//     // -------- Act --------
//     // Execute the user operation through the EntryPoint
//     IEntryPoint(helperConfig.getConfig().entryPoint)
//         .handleOps(
//             _toSingletonArray(packedUserOp), // helper to wrap into array
//             payable(address(0)) // beneficiary (could be a test address)
//         );

//     // -------- Assert --------
//     // Verify AA_Contract received the minted USDC
//     assertEq(
//         usdc.balanceOf(address(aaContract)),
//         AMOUNT,
//         "AA_Contract should have received minted USDC"
//     );
// }

// // Helper: wrap a single op in an array
// function _toSingletonArray(
//     PackedUserOperation memory op
// ) internal pure returns (PackedUserOperation[] memory arr) {
//     arr = new PackedUserOperation ;
//     arr[0] = op;
// }


}
