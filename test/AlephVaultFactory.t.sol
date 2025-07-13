// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/AlephVaultFactory.sol";
import "../src/interfaces/IAlephVault.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {AlephVault} from "../src/AlephVault.sol";

contract AlephVaultFactoryTest is Test {
    AlephVaultFactory factory;
    address manager = address(0xABCD);
    string name = "TestVault";
    address operationsMultisig = address(0x1234);
    address oracle = address(0x5678);
    address guardian = address(0x9ABC);
    address underlyingToken = address(0xDEF0);
    address custodian = address(0x1111);
    AlephVault vaultImpl = new AlephVault(
        IAlephVault.ConstructorParams({operationsMultisig: operationsMultisig, oracle: oracle, guardian: guardian})
    );
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), address(0x2222));

    function setUp() public {
        // Set chainid to 560048 for supported chain
        vm.chainId(560_048);
        factory = new AlephVaultFactory();
        factory.initialize(IAlephVaultFactory.InitializationParams({beacon: address(beacon)}));
    }

    function testInitializeOnlyOnce() public {
        vm.expectRevert(); // Should revert on second initialize
        factory.initialize(IAlephVaultFactory.InitializationParams({beacon: address(beacon)}));
    }

    function testDeployVaultAndIsValidVault() public {
        IAlephVault.InitializationParams memory params = IAlephVault.InitializationParams({
            name: name,
            manager: manager,
            underlyingToken: underlyingToken,
            custodian: custodian
        });
        address vault = factory.deployVault(params);
        assertTrue(factory.isValidVault(vault));
    }

    function testIsValidVaultFalseForUnknown() public {
        assertFalse(factory.isValidVault(address(0xBEEF)));
    }
}
