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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "@aleph-vault/modules/AlephVaultRedeem.sol";
import {AlephVaultSettlement} from "@aleph-vault/modules/AlephVaultSettlement.sol";
import {FeeManager} from "@aleph-vault/modules/FeeManager.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {TestToken} from "@aleph-test/exposes/TestToken.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract BaseTest is Test {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    struct ConfigParams {
        uint48 minDepositAmountTimelock;
        uint48 maxDepositCapTimelock;
        uint48 managementFeeTimelock;
        uint48 performanceFeeTimelock;
        uint48 feeRecipientTimelock;
        uint48 batchDuration;
    }

    address public mockUser_1 = makeAddr("mockUser_1");
    address public mockUser_2 = makeAddr("mockUser_2");

    ExposedVault public vault;
    address public manager;
    address public operationsMultisig;
    address public custodian;
    address public feeRecipient;
    address public oracle;
    address public guardian;
    address public authSigner;
    uint32 public managementFee;
    uint32 public performanceFee;
    uint48 public minDepositAmountTimelock;
    uint48 public maxDepositCapTimelock;
    uint48 public managementFeeTimelock;
    uint48 public performanceFeeTimelock;
    uint48 public feeRecipientTimelock;
    uint48 public batchDuration;

    uint256 public authSignerPrivateKey;

    AuthLibrary.AuthSignature public authSignature_1;
    AuthLibrary.AuthSignature public authSignature_2;

    TestToken public underlyingToken = new TestToken();

    ConfigParams public defaultConfigParams;

    IAlephVault.InitializationParams public defaultInitializationParams;

    struct SettleDepositExpectations {
        uint256 expectedTotalAssets;
        uint256 expectedTotalShares;
        uint256 newSharesToMint;
        uint256 managementFeeShares;
        uint256 performanceFeeShares;
        uint256 expectedPricePerShare;
    }

    struct SettleRedeemExpectations {
        uint256 expectedTotalAssets;
        uint256 expectedTotalShares;
        uint256 assetsToWithdraw;
        uint256 managementFeeShares;
        uint256 performanceFeeShares;
        uint256 expectedPricePerShare;
    }

    function setUp() public virtual {
        (address _authSigner, uint256 _authSignerPrivateKey) = makeAddrAndKey("authSigner");
        authSignerPrivateKey = _authSignerPrivateKey;

        defaultConfigParams = ConfigParams({
            minDepositAmountTimelock: 7 days,
            maxDepositCapTimelock: 7 days,
            managementFeeTimelock: 7 days,
            performanceFeeTimelock: 7 days,
            feeRecipientTimelock: 7 days,
            batchDuration: 1 days
        });

        defaultInitializationParams = IAlephVault.InitializationParams({
            operationsMultisig: makeAddr("operationsMultisig"),
            oracle: makeAddr("oracle"),
            guardian: makeAddr("guardian"),
            authSigner: _authSigner,
            feeRecipient: makeAddr("feeRecipient"),
            managementFee: 200, // 2%
            performanceFee: 2000, // 20%
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: "test",
                configId: "test-123",
                manager: makeAddr("manager"),
                underlyingToken: address(underlyingToken),
                custodian: makeAddr("custodian")
            }),
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: makeAddr("AlephVaultDeposit"),
                alephVaultRedeemImplementation: makeAddr("AlephVaultRedeem"),
                alephVaultSettlementImplementation: makeAddr("AlephVaultSettlement"),
                feeManagerImplementation: makeAddr("FeeManager")
            })
        });
    }

    function _setUpNewAlephVault(
        ConfigParams memory _configParams,
        IAlephVault.InitializationParams memory _initializationParams
    ) public {
        // set up config params
        minDepositAmountTimelock = _configParams.minDepositAmountTimelock;
        maxDepositCapTimelock = _configParams.maxDepositCapTimelock;
        managementFeeTimelock = _configParams.managementFeeTimelock;
        performanceFeeTimelock = _configParams.performanceFeeTimelock;
        feeRecipientTimelock = _configParams.feeRecipientTimelock;
        batchDuration = _configParams.batchDuration;

        // deploy modules
        defaultInitializationParams.moduleInitializationParams = IAlephVault.ModuleInitializationParams({
            alephVaultDepositImplementation: address(
                new AlephVaultDeposit(minDepositAmountTimelock, maxDepositCapTimelock, batchDuration)
            ),
            alephVaultRedeemImplementation: address(new AlephVaultRedeem(batchDuration)),
            alephVaultSettlementImplementation: address(new AlephVaultSettlement(batchDuration)),
            feeManagerImplementation: address(
                new FeeManager(managementFeeTimelock, performanceFeeTimelock, feeRecipientTimelock, batchDuration)
            )
        });

        // set up vault
        vault = new ExposedVault(batchDuration);

        // set up initialization params
        manager = _initializationParams.userInitializationParams.manager;
        operationsMultisig = _initializationParams.operationsMultisig;
        oracle = _initializationParams.oracle;
        guardian = _initializationParams.guardian;
        authSigner = _initializationParams.authSigner;
        custodian = _initializationParams.userInitializationParams.custodian;
        feeRecipient = _initializationParams.feeRecipient;
        managementFee = _initializationParams.managementFee;
        performanceFee = _initializationParams.performanceFee;

        // set up module implementations
        _initializationParams.moduleInitializationParams = defaultInitializationParams.moduleInitializationParams;

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

    function _setAuthSignatures() public {
        authSignature_1 = _getAuthSignature(mockUser_1, type(uint256).max);
        authSignature_2 = _getAuthSignature(mockUser_2, type(uint256).max);
    }

    function _getAuthSignature(address _user, uint256 _expiryBlock)
        internal
        view
        returns (AuthLibrary.AuthSignature memory)
    {
        bytes32 _authMessage = keccak256(abi.encode(_user, address(vault), block.chainid, _expiryBlock));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: _expiryBlock});
    }

    function _getSettleDepositExpectations(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _depositAmount,
        uint48 _batchesElapsed
    ) internal view returns (SettleDepositExpectations memory) {
        uint256 _expectedManagementFeeShares =
            vault.getManagementFeeShares(_newTotalAssets, _totalShares, _batchesElapsed);
        uint256 _expectedPerformanceFeeShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
        _totalShares += _expectedManagementFeeShares + _expectedPerformanceFeeShares;
        uint256 _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
        uint256 _expectedTotalAssets = _newTotalAssets + _depositAmount;
        uint256 _expectedTotalShares = _totalShares + _newSharesToMint;
        return SettleDepositExpectations({
            expectedTotalAssets: _expectedTotalAssets,
            expectedTotalShares: _expectedTotalShares,
            newSharesToMint: _newSharesToMint,
            managementFeeShares: _expectedManagementFeeShares,
            performanceFeeShares: _expectedPerformanceFeeShares,
            expectedPricePerShare: Math.ceilDiv(_expectedTotalAssets * vault.PRICE_DENOMINATOR(), _expectedTotalShares)
        });
    }

    function _getSettleRedeemExpectations(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _userShares,
        uint48 _batchesElapsed
    ) internal view returns (SettleRedeemExpectations memory) {
        uint256 _expectedManagementFeeShares =
            vault.getManagementFeeShares(_newTotalAssets, _totalShares, _batchesElapsed);
        uint256 _expectedPerformanceFeeShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
        _totalShares += _expectedManagementFeeShares + _expectedPerformanceFeeShares;
        uint256 _assetsToWithdraw = ERC4626Math.previewRedeem(_userShares, _newTotalAssets, _totalShares);
        uint256 _expectedTotalAssets = _newTotalAssets - _assetsToWithdraw;
        uint256 _expectedTotalShares = _totalShares - _userShares;
        return SettleRedeemExpectations({
            expectedTotalAssets: _expectedTotalAssets,
            expectedTotalShares: _expectedTotalShares,
            assetsToWithdraw: _assetsToWithdraw,
            managementFeeShares: _expectedManagementFeeShares,
            performanceFeeShares: _expectedPerformanceFeeShares,
            expectedPricePerShare: Math.ceilDiv(_expectedTotalAssets * vault.PRICE_DENOMINATOR(), _expectedTotalShares)
        });
    }
}
