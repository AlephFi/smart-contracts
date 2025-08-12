// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {AlephVaultFactory} from "@aleph-vault/factory/AlephVaultFactory.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVaultFactoryTest is Test {
    AlephVaultFactory factory;
    address manager = address(0xABCD);
    string name = "TestVault";
    address operationsMultisig = address(0x1234);
    address oracle = address(0x5678);
    address guardian = address(0x9ABC);
    address authSigner = address(0x1234);
    address underlyingToken = address(0xDEF0);
    address custodian = address(0x1111);
    address feeRecipient = makeAddr("feeRecipient");
    uint48 minDepositAmountTimelock = 7 days;
    uint48 maxDepositCapTimelock = 7 days;
    uint48 managementFeeTimelock = 7 days;
    uint48 performanceFeeTimelock = 7 days;
    uint48 feeRecipientTimelock = 7 days;
    uint48 batchDuration = 1 days;

    AlephVault vaultImpl = new AlephVault(
        IAlephVault.ConstructorParams({
            alephVaultDepositImplementation: makeAddr("vaultDepositImplementation"),
            alephVaultRedeemImplementation: makeAddr("vaultRedeemImplementation"),
            alephVaultSettlementImplementation: makeAddr("vaultSettlementImplementation"),
            feeManagerImplementation: makeAddr("feeManagerImplementation")
        }),
        batchDuration
    );
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), address(0x2222));

    function setUp() public {
        // Set chainid to 560048 for supported chain
        vm.chainId(560_048);
        factory = new AlephVaultFactory();
        factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                feeRecipient: feeRecipient,
                managementFee: 0,
                performanceFee: 0
            })
        );
    }

    function testInitializeOnlyOnce() public {
        vm.expectRevert(); // Should revert on second initialize
        factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                feeRecipient: feeRecipient,
                managementFee: 0,
                performanceFee: 0
            })
        );
    }

    function testDeployVaultAndIsValidVault() public {
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            manager: manager,
            underlyingToken: underlyingToken,
            custodian: custodian
        });
        address vault = factory.deployVault(params);
        assertTrue(factory.isValidVault(vault));
    }

    function testIsValidVaultFalseForUnknown() public view {
        assertFalse(factory.isValidVault(address(0xBEEF)));
    }
}
