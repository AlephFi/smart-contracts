// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
/*
  ______   __                      __
 /      \ /  |                    /  |
/$$$$$$  |$$ |  ______    ______  $$ |____
$$ |__$$ |$$ | /      \  /      \ $$      \
$$    $$ |$$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |
$$$$$$$$ |$$ |$$    $$ |$$ |  $$ |$$ |  $$ |
$$ |  $$ |$$ |$$$$$$$$/ $$ |__$$ |$$ |  $$ |
$$ |  $$ |$$ |$$       |$$    $$/ $$ |  $$ |
$$/   $$/ $$/  $$$$$$$/ $$$$$$$/  $$/   $$/
                        $$ |
                        $$ |
                        $$/
*/

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";
import {Mocks} from "@aleph-test/utils/Mocks.t.sol";

contract AccountantTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpAccountant(defaultAccountantInitializationParams);
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _setAccountantCut(2500, 5000);
        _unpauseVaultFlows();
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_collectFees_revertsWhenVaultIsNotValid() public {
        // Setup a non-valid vault
        address nonValidVault = makeAddr("nonValidVault");

        // Mock the isValidVault function to return false
        mocks.mockIsValidVault(vaultFactory, nonValidVault, false);

        // collect fees
        vm.prank(manager);
        vm.expectRevert(IAccountant.InvalidVault.selector);
        accountant.collectFees(nonValidVault);
    }

    function test_collectFees_revertsWhenCallerIsNotManager() public {
        // Setup a non-manager user
        address nonManager = makeAddr("nonManager");

        // Mock the isValidVault function to return true
        mocks.mockIsValidVault(vaultFactory, address(vault), true);

        // collect fees
        vm.prank(nonManager);
        vm.expectRevert(IAccountant.InvalidManager.selector);
        accountant.collectFees(address(vault));
    }

    function test_collectFees_revertsWhenVaultTreasuryIsNotSet() public {
        // Mock the isValidVault function to return true
        mocks.mockIsValidVault(vaultFactory, address(vault), true);

        // collect fees
        vm.prank(manager);
        vm.expectRevert(IAccountant.VaultTreasuryNotSet.selector);
        accountant.collectFees(address(vault));
    }

    function test_collectFees_revertsWhenCallToVaultToCollectFeeFails() public {
        // Setup vault treasury
        address _vault = address(vault);
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        accountant.setVaultTreasury(_vaultTreasury);

        // collect fees
        mocks.mockIsValidVault(vaultFactory, address(vault), true);
        mocks.mockCollectFees(address(vault), 100 ether, 100 ether, true);
        vm.prank(manager);
        vm.expectRevert("revert message");
        accountant.collectFees(address(vault));
    }

    function test_collectFees_revertsWhenVaultDoesNotTransferCorrectFees() public {
        // Setup vault treasury
        address _vault = address(vault);
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        accountant.setVaultTreasury(_vaultTreasury);

        // collect fees
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        mocks.mockCollectFees(_vault, 100 ether, 100 ether, false);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IAccountant.FeesNotCollected.selector));
        accountant.collectFees(_vault);
    }

    function test_collectFees_shouldSucceed() public {
        // Setup vault treasury
        address _vault = address(vault);
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        accountant.setVaultTreasury(_vaultTreasury);

        // approve accountant
        vm.prank(_vault);
        underlyingToken.approve(address(accountant), 200 ether);

        // set up vault
        vault.setTotalAssets(0, 200 ether);
        vault.setTotalShares(0, 200 ether);
        vault.setSharesOf(0, vault.managementFeeRecipient(), 100 ether);
        vault.setSharesOf(0, vault.performanceFeeRecipient(), 100 ether);
        underlyingToken.mint(address(vault), 200 ether);

        // get treasury balances before
        uint256 _vaultTreasuryBalanceBefore = underlyingToken.balanceOf(_vaultTreasury);
        uint256 _alephTreasuryBalanceBefore = underlyingToken.balanceOf(alephTreasury);

        // collect fees
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAccountant.FeesCollected(_vault, 100 ether, 100 ether, 125 ether, 75 ether, new uint256[](0));
        accountant.collectFees(_vault);

        // assert fee is transferred
        assertEq(underlyingToken.balanceOf(_vaultTreasury), _vaultTreasuryBalanceBefore + 125 ether);
        assertEq(underlyingToken.balanceOf(alephTreasury), _alephTreasuryBalanceBefore + 75 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_vaultTreasury_returnsTreasuryAddress() public {
        address _vault = address(vault);
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        accountant.setVaultTreasury(_vaultTreasury);

        vm.prank(_vault);
        address _result = accountant.vaultTreasury();
        assertEq(_result, _vaultTreasury);
    }

    function test_vaultTreasury_revertsWhenVaultIsNotValid() public {
        address nonValidVault = makeAddr("nonValidVault");
        mocks.mockIsValidVault(vaultFactory, nonValidVault, false);

        vm.prank(nonValidVault);
        vm.expectRevert(IAccountant.InvalidVault.selector);
        accountant.vaultTreasury();
    }

    /*//////////////////////////////////////////////////////////////
                        SETTER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setOperationsMultisig_setsNewOperationsMultisig() public {
        address _newOperationsMultisig = makeAddr("newOperationsMultisig");
        address _oldOperationsMultisig = operationsMultisig;

        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAccountant.OperationsMultisigSet(_newOperationsMultisig);
        accountant.setOperationsMultisig(_newOperationsMultisig);

        assertFalse(accountant.hasRole(RolesLibrary.OPERATIONS_MULTISIG, _oldOperationsMultisig));
        assertTrue(accountant.hasRole(RolesLibrary.OPERATIONS_MULTISIG, _newOperationsMultisig));
    }

    function test_setOperationsMultisig_revertsWhenUnauthorized() public {
        address _newOperationsMultisig = makeAddr("newOperationsMultisig");
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.setOperationsMultisig(_newOperationsMultisig);
    }

    function test_setVaultFactory_setsNewVaultFactory() public {
        address _newVaultFactory = makeAddr("newVaultFactory");
        address _oldVaultFactory = vaultFactory;

        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAccountant.VaultFactorySet(_newVaultFactory);
        accountant.setVaultFactory(_newVaultFactory);

        assertFalse(accountant.hasRole(RolesLibrary.VAULT_FACTORY, _oldVaultFactory));
        assertTrue(accountant.hasRole(RolesLibrary.VAULT_FACTORY, _newVaultFactory));
    }

    function test_setVaultFactory_revertsWhenUnauthorized() public {
        address _newVaultFactory = makeAddr("newVaultFactory");
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.setVaultFactory(_newVaultFactory);
    }

    function test_setAlephTreasury_setsNewAlephTreasury() public {
        address _newAlephTreasury = makeAddr("newAlephTreasury");

        vm.prank(operationsMultisig);
        vm.expectEmit(true, false, false, false);
        emit IAccountant.AlephTreasurySet(_newAlephTreasury);
        accountant.setAlephTreasury(_newAlephTreasury);
    }

    function test_setAlephTreasury_revertsWhenUnauthorized() public {
        address _newAlephTreasury = makeAddr("newAlephTreasury");
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.setAlephTreasury(_newAlephTreasury);
    }

    function test_setVaultTreasury_setsTreasuryForVault() public {
        address _vault = address(vault);
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(_vault);
        vm.expectEmit(true, true, false, false);
        emit IAccountant.VaultTreasurySet(_vault, _vaultTreasury);
        accountant.setVaultTreasury(_vaultTreasury);

        vm.prank(_vault);
        assertEq(accountant.vaultTreasury(), _vaultTreasury);
    }

    function test_setVaultTreasury_revertsWhenZeroAddress() public {
        address _vault = address(vault);
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(_vault);
        vm.expectRevert(IAccountant.InvalidVaultTreasury.selector);
        accountant.setVaultTreasury(address(0));
    }

    function test_setVaultTreasury_revertsWhenVaultIsNotValid() public {
        address nonValidVault = makeAddr("nonValidVault");
        address _vaultTreasury = makeAddr("testVaultTreasury");
        mocks.mockIsValidVault(vaultFactory, nonValidVault, false);

        vm.prank(nonValidVault);
        vm.expectRevert(IAccountant.InvalidVault.selector);
        accountant.setVaultTreasury(_vaultTreasury);
    }

    function test_setManagementFeeCut_setsFeeCut() public {
        address _vault = address(vault);
        uint32 _managementFeeCut = 3000; // 30%
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, false, false);
        emit IAccountant.ManagementFeeCutSet(_vault, _managementFeeCut);
        accountant.setManagementFeeCut(_vault, _managementFeeCut);
    }

    function test_setManagementFeeCut_revertsWhenUnauthorized() public {
        address _vault = address(vault);
        uint32 _managementFeeCut = 3000;
        address unauthorized = makeAddr("unauthorized");
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.setManagementFeeCut(_vault, _managementFeeCut);
    }

    function test_setManagementFeeCut_revertsWhenVaultIsNotValid() public {
        address nonValidVault = makeAddr("nonValidVault");
        uint32 _managementFeeCut = 3000;
        mocks.mockIsValidVault(vaultFactory, nonValidVault, false);

        vm.prank(operationsMultisig);
        vm.expectRevert(IAccountant.InvalidVault.selector);
        accountant.setManagementFeeCut(nonValidVault, _managementFeeCut);
    }

    function test_setPerformanceFeeCut_setsFeeCut() public {
        address _vault = address(vault);
        uint32 _performanceFeeCut = 4000; // 40%
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, false, false);
        emit IAccountant.PerformanceFeeCutSet(_vault, _performanceFeeCut);
        accountant.setPerformanceFeeCut(_vault, _performanceFeeCut);
    }

    function test_setPerformanceFeeCut_revertsWhenUnauthorized() public {
        address _vault = address(vault);
        uint32 _performanceFeeCut = 4000;
        address unauthorized = makeAddr("unauthorized");
        mocks.mockIsValidVault(vaultFactory, _vault, true);

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.setPerformanceFeeCut(_vault, _performanceFeeCut);
    }

    function test_setPerformanceFeeCut_revertsWhenVaultIsNotValid() public {
        address nonValidVault = makeAddr("nonValidVault");
        uint32 _performanceFeeCut = 4000;
        mocks.mockIsValidVault(vaultFactory, nonValidVault, false);

        vm.prank(operationsMultisig);
        vm.expectRevert(IAccountant.InvalidVault.selector);
        accountant.setPerformanceFeeCut(nonValidVault, _performanceFeeCut);
    }

    function test_initializeVaultTreasury_setsTreasury() public {
        address _vault = makeAddr("newVault");
        address _vaultTreasury = makeAddr("testVaultTreasury");

        // vaultFactory should already have VAULT_FACTORY role from setUp
        // Verify it has the role
        bool hasRole = accountant.hasRole(RolesLibrary.VAULT_FACTORY, vaultFactory);
        if (!hasRole) {
            // If not, grant it
            vm.prank(operationsMultisig);
            accountant.setVaultFactory(vaultFactory);
        }

        vm.prank(vaultFactory);
        vm.expectEmit(true, true, false, false);
        emit IAccountant.VaultTreasurySet(_vault, _vaultTreasury);
        accountant.initializeVaultTreasury(_vault, _vaultTreasury);

        // Mock vault as valid so we can call vaultTreasury()
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        assertEq(accountant.vaultTreasury(), _vaultTreasury);
    }

    function test_initializeVaultTreasury_revertsWhenZeroAddress() public {
        address _vault = makeAddr("newVault");

        vm.prank(vaultFactory);
        vm.expectRevert(IAccountant.InvalidVaultTreasury.selector);
        accountant.initializeVaultTreasury(_vault, address(0));
    }

    function test_initializeVaultTreasury_revertsWhenUnauthorized() public {
        address _vault = makeAddr("newVault");
        address _vaultTreasury = makeAddr("testVaultTreasury");
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert();
        accountant.initializeVaultTreasury(_vault, _vaultTreasury);
    }
}
