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
import {IFeeRecipient} from "@aleph-vault/interfaces/IFeeRecipient.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "@aleph-vault/modules/AlephVaultRedeem.sol";
import {AlephVaultSettlement} from "@aleph-vault/modules/AlephVaultSettlement.sol";
import {FeeManager} from "@aleph-vault/modules/FeeManager.sol";
import {FeeRecipient} from "@aleph-vault/FeeRecipient.sol";
import {MigrationManager} from "@aleph-vault/modules/MigrationManager.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {TestToken} from "@aleph-test/exposes/TestToken.sol";
import {Mocks} from "@aleph-test/utils/Mocks.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract BaseTest is Test {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    struct ConfigParams {
        uint48 minDepositAmountTimelock;
        uint48 maxDepositCapTimelock;
        uint48 noticePeriodTimelock;
        uint48 minRedeemAmountTimelock;
        uint48 managementFeeTimelock;
        uint48 performanceFeeTimelock;
        uint48 feeRecipientTimelock;
        uint48 batchDuration;
    }

    address public mockUser_1 = makeAddr("mockUser_1");
    address public mockUser_2 = makeAddr("mockUser_2");

    Mocks public mocks = new Mocks();

    ExposedVault public vault;
    FeeRecipient public feeRecipient;
    address public manager;
    address public operationsMultisig;
    address public vaultFactory;
    address public custodian;
    address public oracle;
    address public guardian;
    address public authSigner;
    uint48 public minDepositAmountTimelock;
    uint48 public maxDepositCapTimelock;
    uint48 public noticePeriodTimelock;
    uint48 public minRedeemAmountTimelock;
    uint48 public managementFeeTimelock;
    uint48 public performanceFeeTimelock;
    uint48 public feeRecipientTimelock;
    uint48 public batchDuration;
    uint32 public managementFeeCut;
    uint32 public performanceFeeCut;
    address public alephTreasury;
    address public vaultTreasury;

    uint256 public authSignerPrivateKey;

    AuthLibrary.AuthSignature public authSignature_1;
    AuthLibrary.AuthSignature public authSignature_2;
    AuthLibrary.AuthSignature public authSignature_deploy;

    TestToken public underlyingToken = new TestToken();

    ConfigParams public defaultConfigParams;

    IAlephVault.InitializationParams public defaultInitializationParams;
    FeeRecipient.InitializationParams public defaultFeeRecipientInitializationParams;

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

        vaultTreasury = makeAddr("vaultTreasury");

        defaultConfigParams = ConfigParams({
            minDepositAmountTimelock: 7 days,
            maxDepositCapTimelock: 7 days,
            noticePeriodTimelock: 7 days,
            minRedeemAmountTimelock: 7 days,
            managementFeeTimelock: 7 days,
            performanceFeeTimelock: 7 days,
            feeRecipientTimelock: 7 days,
            batchDuration: 1 days
        });

        defaultInitializationParams = IAlephVault.InitializationParams({
            operationsMultisig: makeAddr("operationsMultisig"),
            vaultFactory: makeAddr("vaultFactory"),
            oracle: makeAddr("oracle"),
            guardian: makeAddr("guardian"),
            authSigner: _authSigner,
            feeRecipient: makeAddr("feeRecipient"),
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: "test",
                configId: "test-123",
                manager: makeAddr("manager"),
                underlyingToken: address(underlyingToken),
                custodian: makeAddr("custodian"),
                managementFee: 200, // 2%
                performanceFee: 2000, // 20%
                noticePeriod: 0,
                minDepositAmount: 10 ether,
                maxDepositCap: 1_000_000 ether,
                minRedeemAmount: 10 ether,
                authSignature: authSignature_deploy
            }),
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: makeAddr("AlephVaultDeposit"),
                alephVaultRedeemImplementation: makeAddr("AlephVaultRedeem"),
                alephVaultSettlementImplementation: makeAddr("AlephVaultSettlement"),
                feeManagerImplementation: makeAddr("FeeManager"),
                migrationManagerImplementation: makeAddr("MigrationManager")
            })
        });

        defaultFeeRecipientInitializationParams = IFeeRecipient.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            alephTreasury: makeAddr("alephTreasury")
        });
    }

    function _setUpFeeRecipient(IFeeRecipient.InitializationParams memory _initializationParams) public {
        FeeRecipient _feeRecipient = new FeeRecipient();
        _feeRecipient.initialize(_initializationParams);
        vm.prank(_initializationParams.operationsMultisig);
        _feeRecipient.setVaultFactory(defaultInitializationParams.vaultFactory);
        defaultInitializationParams.feeRecipient = address(_feeRecipient);
        feeRecipient = _feeRecipient;
        alephTreasury = _initializationParams.alephTreasury;
    }

    function _setFeeRecipientCut(uint32 _managementFeeCut, uint32 _performanceFeeCut) public {
        mocks.mockIsValidVault(vaultFactory, address(vault), true);
        vm.startPrank(operationsMultisig);
        feeRecipient.setManagementFeeCut(address(vault), _managementFeeCut);
        feeRecipient.setPerformanceFeeCut(address(vault), _performanceFeeCut);
        vm.stopPrank();
        managementFeeCut = _managementFeeCut;
        performanceFeeCut = _performanceFeeCut;
    }

    function _setUpNewAlephVault(
        ConfigParams memory _configParams,
        IAlephVault.InitializationParams memory _initializationParams
    ) public {
        // set up config params
        minDepositAmountTimelock = _configParams.minDepositAmountTimelock;
        maxDepositCapTimelock = _configParams.maxDepositCapTimelock;
        noticePeriodTimelock = _configParams.noticePeriodTimelock;
        minRedeemAmountTimelock = _configParams.minRedeemAmountTimelock;
        managementFeeTimelock = _configParams.managementFeeTimelock;
        performanceFeeTimelock = _configParams.performanceFeeTimelock;
        feeRecipientTimelock = _configParams.feeRecipientTimelock;
        batchDuration = _configParams.batchDuration;

        // deploy modules
        defaultInitializationParams.moduleInitializationParams = IAlephVault.ModuleInitializationParams({
            alephVaultDepositImplementation: address(
                new AlephVaultDeposit(minDepositAmountTimelock, maxDepositCapTimelock, batchDuration)
            ),
            alephVaultRedeemImplementation: address(
                new AlephVaultRedeem(noticePeriodTimelock, minRedeemAmountTimelock, batchDuration)
            ),
            alephVaultSettlementImplementation: address(new AlephVaultSettlement(batchDuration)),
            feeManagerImplementation: address(
                new FeeManager(managementFeeTimelock, performanceFeeTimelock, feeRecipientTimelock, batchDuration)
            ),
            migrationManagerImplementation: address(new MigrationManager(batchDuration))
        });

        // set up vault
        vault = new ExposedVault(batchDuration);

        // set up initialization params
        manager = _initializationParams.userInitializationParams.manager;
        operationsMultisig = _initializationParams.operationsMultisig;
        vaultFactory = _initializationParams.vaultFactory;
        oracle = _initializationParams.oracle;
        guardian = _initializationParams.guardian;
        authSigner = _initializationParams.authSigner;
        custodian = _initializationParams.userInitializationParams.custodian;

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
        authSignature_1 = _getDepositAuthSignature(mockUser_1, type(uint256).max);
        authSignature_2 = _getDepositAuthSignature(mockUser_2, type(uint256).max);
    }

    function _getDepositAuthSignature(address _user, uint256 _expiryBlock)
        internal
        view
        returns (AuthLibrary.AuthSignature memory)
    {
        bytes32 _authMessage = keccak256(abi.encode(_user, address(vault), block.chainid, 1, _expiryBlock));
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: _expiryBlock});
    }

    function _getSettlementAuthSignature(bytes4 _flow, uint48 _toBatchId, uint256[] memory _newTotalAssets)
        internal
        view
        returns (AuthLibrary.AuthSignature memory)
    {
        bytes32 _authMessage = keccak256(
            abi.encode(_flow, manager, address(vault), block.chainid, 1, _toBatchId, _newTotalAssets, type(uint256).max)
        );
        bytes32 _ethSignedMessage = _authMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(authSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return AuthLibrary.AuthSignature({authSignature: _authSignature, expiryBlock: type(uint256).max});
    }

    function _getSettleDepositExpectations(
        bool _newSeries,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _depositAmount,
        uint48 _batchesElapsed
    ) internal view returns (SettleDepositExpectations memory) {
        uint256 _expectedManagementFeeShares =
            vault.getManagementFeeShares(_newTotalAssets, _totalShares, _batchesElapsed);
        uint256 _expectedPerformanceFeeShares = vault.getPerformanceFeeShares(_newTotalAssets, _totalShares);
        uint256 _newSharesToMint;
        uint256 _expectedTotalAssets = _depositAmount;
        uint256 _expectedTotalShares;
        if (_newSeries) {
            _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, 0, 0);
            _expectedTotalShares = _newSharesToMint;
        } else {
            _totalShares += _expectedManagementFeeShares + _expectedPerformanceFeeShares;
            _newSharesToMint = ERC4626Math.previewDeposit(_depositAmount, _totalShares, _newTotalAssets);
            _expectedTotalAssets += _newTotalAssets;
            _expectedTotalShares = _totalShares + _newSharesToMint;
        }
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
