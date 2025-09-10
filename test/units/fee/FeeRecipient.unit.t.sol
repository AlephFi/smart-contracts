// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
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
import {IFeeRecipient} from "@aleph-vault/interfaces/IFeeRecipient.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";
import {Mocks} from "@aleph-test/utils/Mocks.t.sol";

contract FeeRecipientTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpFeeRecipient(defaultFeeRecipientInitializationParams);
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _setFeeRecipientCut(2500, 5000);
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
        vm.expectRevert(IFeeRecipient.InvalidVault.selector);
        feeRecipient.collectFees(nonValidVault);
    }

    function test_collectFees_revertsWhenCallerIsNotManager() public {
        // Setup a non-manager user
        address nonManager = makeAddr("nonManager");

        // Mock the isValidVault function to return true
        mocks.mockIsValidVault(vaultFactory, address(vault), true);

        // collect fees
        vm.prank(nonManager);
        vm.expectRevert(IFeeRecipient.InvalidManager.selector);
        feeRecipient.collectFees(address(vault));
    }

    function test_collectFees_revertsWhenVaultTreasuryIsNotSet() public {
        // Mock the isValidVault function to return true
        mocks.mockIsValidVault(vaultFactory, address(vault), true);

        // collect fees
        vm.prank(manager);
        vm.expectRevert(IFeeRecipient.VaultTreasuryNotSet.selector);
        feeRecipient.collectFees(address(vault));
    }

    function test_collectFees_revertsWhenVaultDoesNotTransferCorrectFees() public {
        // Setup vault treasury
        address _vault = address(vault);
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        feeRecipient.setVaultTreasury(vaultTreasury);

        // collect fees
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        mocks.mockCollectFees(_vault, 100 ether, 100 ether);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(IFeeRecipient.FeesNotCollected.selector));
        feeRecipient.collectFees(_vault);
    }

    function test_collectFees_shouldSucceed() public {
        // Setup vault treasury
        address _vault = address(vault);
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(_vault);
        feeRecipient.setVaultTreasury(vaultTreasury);

        // approve fee recipient
        vm.prank(_vault);
        underlyingToken.approve(address(feeRecipient), 200 ether);

        // set up vault
        vault.setTotalAssets(0, 200 ether);
        vault.setTotalShares(0, 200 ether);
        vault.setSharesOf(0, vault.managementFeeRecipient(), 100 ether);
        vault.setSharesOf(0, vault.performanceFeeRecipient(), 100 ether);
        underlyingToken.mint(address(vault), 200 ether);

        // get treasury balances before
        uint256 _vaultTreasuryBalanceBefore = underlyingToken.balanceOf(vaultTreasury);
        uint256 _alephTreasuryBalanceBefore = underlyingToken.balanceOf(alephTreasury);

        // collect fees
        mocks.mockIsValidVault(vaultFactory, _vault, true);
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IFeeRecipient.FeesCollected(_vault, 100 ether, 100 ether, 125 ether, 75 ether);
        feeRecipient.collectFees(_vault);

        // assert fee is transferred
        assertEq(underlyingToken.balanceOf(vaultTreasury), _vaultTreasuryBalanceBefore + 125 ether);
        assertEq(underlyingToken.balanceOf(alephTreasury), _alephTreasuryBalanceBefore + 75 ether);
    }
}
