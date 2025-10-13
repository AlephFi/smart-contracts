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
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract FeeManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpAccountant(defaultAccountantInitializationParams);
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    /*//////////////////////////////////////////////////////////////
                        ACCUMALATE FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_accumalateFees_whenNewTotalAssetsIs0_shouldNotAccumalateFees() public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;

        // accumalate fees
        vault.accumulateFees(1, 0, currentBatchId, lastFeePaidId, 0, 0);

        // check no fees are accumalated
        address managementFeeRecipient = vault.managementFeeRecipient();
        address performanceFeeRecipient = vault.performanceFeeRecipient();
        assertEq(vault.sharesOf(1, 0, managementFeeRecipient), 0);
        assertEq(vault.sharesOf(1, 0, performanceFeeRecipient), 0);
    }

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsHigherThanPricePerShare_shouldAccumalateOnlyManagementFees(
    ) public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;

        // set high water mark to 2
        uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
        uint256 _highWaterMark = 2 * _priceDenominator;
        vault.setHighWaterMark(_highWaterMark);

        // set total assets and shares
        uint256 _newTotalAssets = 1200;
        vault.setTotalAssets(0, 1000);
        vault.setTotalShares(0, 1000);

        // accumalate fees
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesAccumulated(
            1,
            0,
            currentBatchId,
            lastFeePaidId,
            _newTotalAssets,
            1005,
            IFeeManager.FeesAccumulatedParams({
                managementFeeAmount: 7,
                managementFeeSharesToMint: 5,
                performanceFeeAmount: 0,
                performanceFeeSharesToMint: 0
            })
        );
        uint256 _totalSharesMinted = vault.accumulateFees(1, 0, currentBatchId, lastFeePaidId, _newTotalAssets, 1000);

        // assert total shares minted
        assertEq(_totalSharesMinted, 5);

        // check high water mark is not updated
        assertEq(vault.highWaterMark(1, 0), _highWaterMark);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.managementFeeRecipient();
        assertEq(vault.sharesOf(1, 0, managementFeeRecipient), 5);

        // check no fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.performanceFeeRecipient();
        assertEq(vault.sharesOf(1, 0, performanceFeeRecipient), 0);
    }

    function test_accumalateFees_whenNewTotalAssetsIsGreaterThan0_givenHighWaterMarkIsLowerThanPricePerShare_shouldAccumalateBothPerformanceAndManagementFees(
    ) public {
        // set up context
        uint48 currentBatchId = 100;
        uint48 lastFeePaidId = 0;

        // set high water mark to 1
        uint256 _priceDenominator = vault.PRICE_DENOMINATOR();
        uint256 _highWaterMark = 1 * _priceDenominator;
        vault.setHighWaterMark(_highWaterMark);

        // set total assets and shares
        uint256 _newTotalAssets = 1200;
        uint256 _newHighWaterMark = 1_154_957;
        vault.setTotalAssets(0, 1000);
        vault.setTotalShares(0, 1000);

        // accumalate fees
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewHighWaterMarkSet(1, 0, 100, _newHighWaterMark);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesAccumulated(
            1,
            0,
            currentBatchId,
            lastFeePaidId,
            _newTotalAssets,
            1039,
            IFeeManager.FeesAccumulatedParams({
                managementFeeAmount: 7,
                managementFeeSharesToMint: 5,
                performanceFeeAmount: 40,
                performanceFeeSharesToMint: 34
            })
        );
        uint256 _totalSharesMinted = vault.accumulateFees(1, 0, currentBatchId, lastFeePaidId, _newTotalAssets, 1000);

        // assert total shares minted
        assertEq(_totalSharesMinted, 39);

        // check high water mark is updated
        assertEq(vault.highWaterMark(1, 0), _newHighWaterMark);

        // check fees are accumalated to management fee recipient
        address managementFeeRecipient = vault.managementFeeRecipient();
        assertEq(vault.sharesOf(1, 0, managementFeeRecipient), 5);

        // check fees are accumalated to performance fee recipient
        address performanceFeeRecipient = vault.performanceFeeRecipient();
        assertEq(vault.sharesOf(1, 0, performanceFeeRecipient), 34);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_collectFees_revertsWhenCallerIsNotAccountant() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // collect fees
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.ACCOUNTANT
            )
        );
        vault.collectFees();
    }

    function test_collectFees_revertsWhenThereAreInsufficientAssetsToCollectFees() public {
        // accumalate fees to recipients
        uint256 _managementShares = 120 ether;
        uint256 _performanceShares = 120 ether;
        vault.setSharesOf(0, vault.managementFeeRecipient(), _managementShares);
        vault.setSharesOf(0, vault.performanceFeeRecipient(), _performanceShares);

        // set total assets and shares
        uint256 _totalAssets = 1000 ether;
        uint256 _totalShares = 1200 ether;
        vault.setTotalAssets(0, _totalAssets);
        vault.setTotalShares(0, _totalShares);

        // set total amount to deposit and withdraw
        vault.setTotalAmountToDeposit(100 ether);
        vault.setTotalAmountToWithdraw(100 ether);

        // mint balance for vault
        underlyingToken.mint(address(vault), 200 ether);

        // collect fees
        vm.prank(address(accountant));
        vm.expectRevert(abi.encodeWithSelector(IFeeManager.InsufficientAssetsToCollectFees.selector, 400 ether));
        vault.collectFees();
    }

    function test_collectFees_whenCallerIsAccountant_shouldSucceed() public {
        // accumalate fees to recipients
        uint256 _managementShares = 120 ether;
        uint256 _performanceShares = 120 ether;
        vault.setSharesOf(0, vault.managementFeeRecipient(), _managementShares);
        vault.setSharesOf(0, vault.performanceFeeRecipient(), _performanceShares);

        // set total assets and shares
        uint256 _totalAssets = 1000 ether;
        uint256 _totalShares = 1200 ether;
        vault.setTotalAssets(0, _totalAssets);
        vault.setTotalShares(0, _totalShares);

        // expected fees to collect
        uint256 _expectedManagementFeesToCollect = 100 ether;
        uint256 _expectedPerformanceFeesToCollect = 100 ether;
        uint256 _expectedTotalFeesToCollect = _expectedManagementFeesToCollect + _expectedPerformanceFeesToCollect;

        // set vault balance
        underlyingToken.mint(address(vault), _expectedTotalFeesToCollect);
        uint256 _accountantBalanceBefore = underlyingToken.balanceOf(address(accountant));

        // collect fees
        vm.prank(address(accountant));
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeesCollected(0, _expectedManagementFeesToCollect, _expectedPerformanceFeesToCollect);
        vault.collectFees();

        // check recipient shares are burned
        assertEq(vault.sharesOf(1, 0, vault.managementFeeRecipient()), 0);
        assertEq(vault.sharesOf(1, 0, vault.performanceFeeRecipient()), 0);

        // check total assets and total shares are updated
        assertEq(
            vault.totalAssetsPerSeries(1, 0),
            _totalAssets - _expectedManagementFeesToCollect - _expectedPerformanceFeesToCollect
        );
        assertEq(vault.totalSharesPerSeries(1, 0), _totalShares - _managementShares - _performanceShares);

        // check fee is collected
        assertEq(underlyingToken.balanceOf(address(accountant)), _accountantBalanceBefore + _expectedTotalFeesToCollect);
    }
}
