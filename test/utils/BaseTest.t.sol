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

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {TestToken} from "@aleph-test/exposes/TestToken.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract BaseTest is Test {
    using SafeERC20 for IERC20;

    address public mockUser_1 = makeAddr("mockUser_1");
    address public mockUser_2 = makeAddr("mockUser_2");

    ExposedVault public vault;
    uint48 public batchDuration;
    address public manager;
    address public operationsMultisig;
    address public custodian;
    address public feeRecipient;
    address public oracle;
    address public guardian;
    uint32 public maxManagementFee;
    uint32 public maxPerformanceFee;
    uint48 public managementFeeTimelock;
    uint48 public performanceFeeTimelock;
    uint48 public feeRecipientTimelock;

    TestToken public underlyingToken = new TestToken();

    IAlephVault.ConstructorParams public defaultConstructorParams = IAlephVault.ConstructorParams({
        operationsMultisig: makeAddr("operationsMultisig"),
        oracle: makeAddr("oracle"),
        guardian: makeAddr("guardian"),
        maxManagementFee: 100,
        maxPerformanceFee: 500,
        managementFeeTimelock: 7 days,
        performanceFeeTimelock: 7 days,
        feeRecipientTimelock: 7 days
    });

    IAlephVault.InitializationParams public defaultInitializationParams = IAlephVault.InitializationParams({
        name: "test",
        manager: makeAddr("manager"),
        underlyingToken: address(underlyingToken),
        custodian: makeAddr("custodian"),
        feeRecipient: makeAddr("feeRecipient")
    });

    function _setUpNewAlephVault(
        IAlephVault.ConstructorParams memory _constructorParams,
        IAlephVault.InitializationParams memory _initializationParams
    ) public {
        // set up constructor params
        operationsMultisig = _constructorParams.operationsMultisig;
        oracle = _constructorParams.oracle;
        guardian = _constructorParams.guardian;
        maxManagementFee = _constructorParams.maxManagementFee;
        maxPerformanceFee = _constructorParams.maxPerformanceFee;
        managementFeeTimelock = _constructorParams.managementFeeTimelock;
        performanceFeeTimelock = _constructorParams.performanceFeeTimelock;
        feeRecipientTimelock = _constructorParams.feeRecipientTimelock;

        // set up vault
        vault = new ExposedVault(_constructorParams);

        // set up initialization params
        manager = _initializationParams.manager;
        custodian = _initializationParams.custodian;
        feeRecipient = _initializationParams.feeRecipient;

        // initialize vault
        vault.initialize(_initializationParams);
    }

    function _unpauseVaultFlows() public {
        vm.startPrank(manager);
        vault.unpause(PausableFlows.DEPOSIT_REQUEST_FLOW);
        vault.unpause(PausableFlows.REDEEM_REQUEST_FLOW);
        vault.unpause(PausableFlows.SETTLE_DEPOSIT_FLOW);
        vault.unpause(PausableFlows.SETTLE_REDEEM_FLOW);
        vm.stopPrank();
    }
}
