// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {AlephVaultFactory} from "@aleph-vault/factory/AlephVaultFactory.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVaultFactoryTest is Test {
    using MessageHashUtils for bytes32;

    AlephVaultFactory factory;
    address manager = address(0xABCD);
    string name = "TestVault";
    address operationsMultisig = address(0x1234);
    address oracle = address(0x5678);
    address guardian = address(0x9ABC);
    address authSigner;
    address underlyingToken = address(0xDEF0);
    address custodian = address(0x1111);
    address feeRecipient = makeAddr("feeRecipient");
    address alephVaultDepositImplementation = makeAddr("AlephVaultDeposit");
    address alephVaultRedeemImplementation = makeAddr("AlephVaultRedeem");
    address alephVaultSettlementImplementation = makeAddr("AlephVaultSettlement");
    address feeManagerImplementation = makeAddr("FeeManager");
    uint48 minDepositAmountTimelock = 7 days;
    uint48 maxDepositCapTimelock = 7 days;
    uint48 managementFeeTimelock = 7 days;
    uint48 performanceFeeTimelock = 7 days;
    uint48 feeRecipientTimelock = 7 days;
    uint48 batchDuration = 1 days;
    uint256 authSignerPrivateKey;

    AlephVault vaultImpl = new AlephVault(batchDuration);
    UpgradeableBeacon beacon = new UpgradeableBeacon(address(vaultImpl), address(0x2222));

    function setUp() public {
        // Set chainid to 560048 for supported chain
        vm.chainId(560_048);
        (authSigner, authSignerPrivateKey) = makeAddrAndKey("authSigner");
        factory = new AlephVaultFactory();
        factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                feeRecipient: feeRecipient,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation
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
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation
            })
        );
    }

    function testDeployVaultAndIsValidVault() public {
        bytes32 _salt = keccak256(abi.encodePacked(manager, name));
        bytes32 _authMessage = keccak256(abi.encode(block.chainid, _salt, "test", type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            manager: manager,
            underlyingToken: underlyingToken,
            custodian: custodian,
            managementFee: 0,
            performanceFee: 0,
            minDepositAmount: 0,
            maxDepositCap: 0,
            authSignature: authSignature
        });
        address vault = factory.deployVault(params);
        assertTrue(factory.isValidVault(vault));
    }

    function testIsValidVaultFalseForUnknown() public view {
        assertFalse(factory.isValidVault(address(0xBEEF)));
    }
}
