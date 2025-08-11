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

      // address randomAddress = address(0x1234567890123456789012345678901234567890);
      address randomUser = makeAddr("randomUser");
         uint256 AMOUNT = 1e21; // 1 thousand USDC in wei


      function setUp() public{

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

    bytes memory functionData = abi.encodeWithSelector(
        ERC20Mock.mint.selector,
        address(aaContract),
        AMOUNT
    );

    // Build calldata for AA_Contract.execute(...)
    bytes memory executeCallData = abi.encodeWithSelector(
        AA_Contract.execute.selector, // must be a function in AA_Contract
        dest,
        value,
        functionData
    );

    // Call helper to create the PackedUserOperation
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOp(
        executeCallData,
        address(aaContract),
        helperConfig.getConfig()
    );
    bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

      // Get the userOpHash

      address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

      assertEq(actualSigner, aaContract.owner(), "Recovered signer should match AA_Contract owner");
      
      // assertEq(recovered, address(aaContract), "Recovered signer should match AA_Contract owner");
      
      // console.log("Recovered signer: %s", recovered);
}


      // function testValidationOfUserOps() public {
            
      // }
}