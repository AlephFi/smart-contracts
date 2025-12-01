// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {IMigrationManager} from "@aleph-vault/interfaces/IMigrationManager.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {AlephVaultFactory} from "@aleph-vault/factory/AlephVaultFactory.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";
import {Mocks} from "@aleph-test/utils/Mocks.t.sol";

contract AlephVaultFactoryTest is Test {
    using MessageHashUtils for bytes32;

    Mocks public mocks = new Mocks();

    AlephVaultFactory factory;
    address manager = address(0xABCD);
    string name = "TestVault";
    address operationsMultisig = address(0x1234);
    address oracle = address(0x5678);
    address guardian = address(0x9ABC);
    address authSigner;
    address underlyingToken = address(0xDEF0);
    address custodian = address(0x1111);
    address vaultTreasury = address(0x2222);
    address accountant = makeAddr("accountant");
    address alephVaultDepositImplementation = makeAddr("AlephVaultDeposit");
    address alephVaultRedeemImplementation = makeAddr("AlephVaultRedeem");
    address alephVaultSettlementImplementation = makeAddr("AlephVaultSettlement");
    address feeManagerImplementation = makeAddr("FeeManager");
    address migrationManagerImplementation = makeAddr("MigrationManager");
    uint256 authSignerPrivateKey;
    uint48 batchDuration = 1 days;

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
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
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
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function testDeployVaultAndIsValidVault() public {
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address vault = factory.deployVault(params);
        assertTrue(factory.isValidVault(vault));
    }

    function testIsValidVaultFalseForUnknown() public view {
        assertFalse(factory.isValidVault(address(0xBEEF)));
    }

    /*//////////////////////////////////////////////////////////////
                    INITIALIZE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_revertsWhenBeaconIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(0),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenOperationsMultisigIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: address(0),
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenOracleIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: address(0),
                guardian: guardian,
                authSigner: authSigner,
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenGuardianIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: address(0),
                authSigner: authSigner,
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenAuthSignerIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: address(0),
                accountant: accountant,
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenAccountantIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                accountant: address(0),
                alephVaultDepositImplementation: alephVaultDepositImplementation,
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    function test_initialize_revertsWhenDepositImplementationIsZero() public {
        AlephVaultFactory _factory = new AlephVaultFactory();
        vm.expectRevert(IAlephVaultFactory.InvalidInitializationParams.selector);
        _factory.initialize(
            IAlephVaultFactory.InitializationParams({
                beacon: address(beacon),
                operationsMultisig: operationsMultisig,
                oracle: oracle,
                guardian: guardian,
                authSigner: authSigner,
                accountant: accountant,
                alephVaultDepositImplementation: address(0),
                alephVaultRedeemImplementation: alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: alephVaultSettlementImplementation,
                feeManagerImplementation: feeManagerImplementation,
                migrationManagerImplementation: migrationManagerImplementation
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SET OPERATIONS MULTISIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setOperationsMultisig_revertsWhenZeroAddress() public {
        vm.prank(operationsMultisig);
        vm.expectRevert(IAlephVaultFactory.InvalidParam.selector);
        factory.setOperationsMultisig(address(0));
    }

    function test_setOperationsMultisig_revertsWhenUnauthorized() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        factory.setOperationsMultisig(address(0x8888));
    }

    function test_setOperationsMultisig_setsNewOperationsMultisig() public {
        address _newOperationsMultisig = address(0x7777);
        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAlephVaultFactory.OperationsMultisigSet(_newOperationsMultisig);
        factory.setOperationsMultisig(_newOperationsMultisig);
    }

    function test_setOperationsMultisig_migratesToAllVaults() public {
        // Deploy a vault first
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault = factory.deployVault(params);

        address _newOperationsMultisig = address(0x7777);
        vm.mockCall(_vault, abi.encodeCall(IMigrationManager.migrateOperationsMultisig, (_newOperationsMultisig)), abi.encode());

        vm.prank(operationsMultisig);
        factory.setOperationsMultisig(_newOperationsMultisig);
    }

    /*//////////////////////////////////////////////////////////////
                    SET ORACLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setOracle_revertsWhenZeroAddress() public {
        vm.prank(operationsMultisig);
        vm.expectRevert(IAlephVaultFactory.InvalidParam.selector);
        factory.setOracle(address(0));
    }

    function test_setOracle_revertsWhenUnauthorized() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        factory.setOracle(address(0x8888));
    }

    function test_setOracle_setsNewOracle() public {
        address _newOracle = address(0x7777);
        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAlephVaultFactory.OracleSet(_newOracle);
        factory.setOracle(_newOracle);
    }

    function test_setOracle_migratesToAllVaults() public {
        // Deploy a vault first
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault = factory.deployVault(params);

        address _newOracle = address(0x7777);
        vm.mockCall(_vault, abi.encodeCall(IMigrationManager.migrateOracle, (_newOracle)), abi.encode());

        vm.prank(operationsMultisig);
        factory.setOracle(_newOracle);
    }

    /*//////////////////////////////////////////////////////////////
                    SET GUARDIAN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setGuardian_revertsWhenZeroAddress() public {
        vm.prank(operationsMultisig);
        vm.expectRevert(IAlephVaultFactory.InvalidParam.selector);
        factory.setGuardian(address(0));
    }

    function test_setGuardian_revertsWhenUnauthorized() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        factory.setGuardian(address(0x8888));
    }

    function test_setGuardian_setsNewGuardian() public {
        address _newGuardian = address(0x7777);
        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAlephVaultFactory.GuardianSet(_newGuardian);
        factory.setGuardian(_newGuardian);
    }

    function test_setGuardian_migratesToAllVaults() public {
        // Deploy a vault first
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault = factory.deployVault(params);

        address _newGuardian = address(0x7777);
        vm.mockCall(_vault, abi.encodeCall(IMigrationManager.migrateGuardian, (_newGuardian)), abi.encode());

        vm.prank(operationsMultisig);
        factory.setGuardian(_newGuardian);
    }

    /*//////////////////////////////////////////////////////////////
                    SET AUTH SIGNER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setAuthSigner_revertsWhenZeroAddress() public {
        vm.prank(operationsMultisig);
        vm.expectRevert(IAlephVaultFactory.InvalidParam.selector);
        factory.setAuthSigner(address(0));
    }

    function test_setAuthSigner_revertsWhenUnauthorized() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        factory.setAuthSigner(address(0x8888));
    }

    function test_setAuthSigner_setsNewAuthSigner() public {
        address _newAuthSigner = address(0x7777);
        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAlephVaultFactory.AuthSignerSet(_newAuthSigner);
        factory.setAuthSigner(_newAuthSigner);
    }

    function test_setAuthSigner_migratesToAllVaults() public {
        // Deploy a vault first
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault = factory.deployVault(params);

        address _newAuthSigner = address(0x7777);
        vm.mockCall(_vault, abi.encodeCall(IMigrationManager.migrateAuthSigner, (_newAuthSigner)), abi.encode());

        vm.prank(operationsMultisig);
        factory.setAuthSigner(_newAuthSigner);
    }

    /*//////////////////////////////////////////////////////////////
                    SET MODULE IMPLEMENTATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setModuleImplementation_revertsWhenZeroAddress() public {
        vm.prank(operationsMultisig);
        vm.expectRevert(IAlephVaultFactory.InvalidParam.selector);
        factory.setModuleImplementation(bytes4(0x12345678), address(0));
    }

    function test_setModuleImplementation_revertsWhenUnauthorized() public {
        vm.prank(address(0x9999));
        vm.expectRevert();
        factory.setModuleImplementation(bytes4(0x12345678), address(0x8888));
    }

    function test_setModuleImplementation_setsNewImplementation() public {
        bytes4 _module = bytes4(0x12345678);
        address _newImplementation = address(0x7777);
        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, false, false);
        emit IAlephVaultFactory.ModuleImplementationSet(_module, _newImplementation);
        factory.setModuleImplementation(_module, _newImplementation);
    }

    function test_setModuleImplementation_migratesToAllVaults() public {
        // Deploy a vault first
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault = factory.deployVault(params);

        bytes4 _module = bytes4(0x12345678);
        address _newImplementation = address(0x7777);
        vm.mockCall(_vault, abi.encodeCall(IMigrationManager.migrateModules, (_module, _newImplementation)), abi.encode());

        vm.prank(operationsMultisig);
        factory.setModuleImplementation(_module, _newImplementation);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPLOY VAULT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_deployVault_revertsWhenInvalidAuthSignature() public {
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        // Modify signature to make it invalid
        _authSignature[0] = bytes1(uint8(_authSignature[0]) ^ 1);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        vm.expectRevert();
        factory.deployVault(params);
    }

    function test_deployVault_emitsVaultDeployedEvent() public {
        bytes32 _authMessage =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        AuthLibrary.AuthSignature memory authSignature =
            AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;
        IAlephVault.UserInitializationParams memory params = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature
        });
        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        // Check that event is emitted with correct manager, name, and configId (vault address is unpredictable)
        vm.expectEmit(false, true, false, true);
        emit IAlephVaultFactory.VaultDeployed(address(0), manager, name, "test");
        address _vault = factory.deployVault(params);
        assertTrue(factory.isValidVault(_vault));
        assertNotEq(_vault, address(0));
    }

    function test_deployVault_sameNameDifferentManagerCreatesDifferentVaults() public {
        bytes32 _authMessage1 =
            keccak256(abi.encode(manager, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage1 = _authMessage1.toEthSignedMessageHash();
        (uint8 _v1, bytes32 _r1, bytes32 _s1) = vm.sign(authSignerPrivateKey, _ethSignedMessage1);
        bytes memory _authSignature1 = abi.encodePacked(_r1, _s1, _v1);
        AuthLibrary.AuthSignature memory authSignature1 =
            AuthLibrary.AuthSignature({authSignature: _authSignature1, expiryBlock: type(uint256).max});

        address _manager2 = address(0x9999);
        bytes32 _authMessage2 =
            keccak256(abi.encode(_manager2, address(factory), name, "test", block.chainid, type(uint256).max));
        bytes32 _ethSignedMessage2 = _authMessage2.toEthSignedMessageHash();
        (uint8 _v2, bytes32 _r2, bytes32 _s2) = vm.sign(authSignerPrivateKey, _ethSignedMessage2);
        bytes memory _authSignature2 = abi.encodePacked(_r2, _s2, _v2);
        AuthLibrary.AuthSignature memory authSignature2 =
            AuthLibrary.AuthSignature({authSignature: _authSignature2, expiryBlock: type(uint256).max});

        IAlephVault.ShareClassParams memory shareClassParams;
        shareClassParams.minDepositAmount = 1000;
        shareClassParams.minRedeemAmount = 1000;

        IAlephVault.UserInitializationParams memory params1 = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature1
        });
        IAlephVault.UserInitializationParams memory params2 = IAlephVault.UserInitializationParams({
            name: name,
            configId: "test",
            underlyingToken: underlyingToken,
            custodian: custodian,
            vaultTreasury: vaultTreasury,
            syncExpirationBatches: 2,
            shareClassParams: shareClassParams,
            authSignature: authSignature2
        });

        mocks.mockSetVaultTreasury(accountant, vaultTreasury);
        vm.prank(manager);
        address _vault1 = factory.deployVault(params1);
        vm.prank(_manager2);
        address _vault2 = factory.deployVault(params2);

        assertNotEq(_vault1, _vault2, "Different managers should create different vaults");
        assertTrue(factory.isValidVault(_vault1));
        assertTrue(factory.isValidVault(_vault2));
    }
}
