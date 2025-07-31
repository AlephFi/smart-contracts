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
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {KycAuthLibrary} from "@aleph-vault/libraries/KycAuthLibrary.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {TestToken} from "@aleph-test/exposes/TestToken.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract BaseTest is Test {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;

    address public mockUser_1 = makeAddr("mockUser_1");
    address public mockUser_2 = makeAddr("mockUser_2");

    ExposedVault public vault;
    address public manager;
    address public operationsMultisig;
    address public custodian;
    address public feeRecipient;
    address public oracle;
    address public guardian;
    address public kycAuthSigner;
    uint32 public managementFee;
    uint32 public performanceFee;
    uint48 public minDepositAmountTimelock;
    uint48 public maxDepositCapTimelock;
    uint48 public managementFeeTimelock;
    uint48 public performanceFeeTimelock;
    uint48 public feeRecipientTimelock;
    uint48 public batchDuration;

    uint256 public kycAuthSignerPrivateKey;

    KycAuthLibrary.KycAuthSignature public kycAuthSignature_1;
    KycAuthLibrary.KycAuthSignature public kycAuthSignature_2;

    TestToken public underlyingToken = new TestToken();

    IAlephVault.ConstructorParams public defaultConstructorParams;

    IAlephVault.InitializationParams public defaultInitializationParams;

    function setUp() public virtual {
        (address _kycAuthSigner, uint256 _kycAuthSignerPrivateKey) = makeAddrAndKey("kycAuthSigner");
        kycAuthSignerPrivateKey = _kycAuthSignerPrivateKey;

        defaultConstructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: 7 days,
            maxDepositCapTimelock: 7 days,
            managementFeeTimelock: 7 days,
            performanceFeeTimelock: 7 days,
            feeRecipientTimelock: 7 days,
            batchDuration: 1 days
        });

        defaultInitializationParams = IAlephVault.InitializationParams({
            name: "test",
            manager: makeAddr("manager"),
            operationsMultisig: makeAddr("operationsMultisig"),
            oracle: makeAddr("oracle"),
            guardian: makeAddr("guardian"),
            kycAuthSigner: _kycAuthSigner,
            underlyingToken: address(underlyingToken),
            custodian: makeAddr("custodian"),
            feeRecipient: makeAddr("feeRecipient"),
            managementFee: 200, // 2%
            performanceFee: 2000 // 20%
        });
    }

    function _setUpNewAlephVault(
        IAlephVault.ConstructorParams memory _constructorParams,
        IAlephVault.InitializationParams memory _initializationParams
    ) public {
        // set up constructor params
        minDepositAmountTimelock = _constructorParams.minDepositAmountTimelock;
        maxDepositCapTimelock = _constructorParams.maxDepositCapTimelock;
        managementFeeTimelock = _constructorParams.managementFeeTimelock;
        performanceFeeTimelock = _constructorParams.performanceFeeTimelock;
        feeRecipientTimelock = _constructorParams.feeRecipientTimelock;
        batchDuration = _constructorParams.batchDuration;

        // set up vault
        vault = new ExposedVault(_constructorParams);

        // set up initialization params
        manager = _initializationParams.manager;
        operationsMultisig = _initializationParams.operationsMultisig;
        oracle = _initializationParams.oracle;
        guardian = _initializationParams.guardian;
        kycAuthSigner = _initializationParams.kycAuthSigner;
        custodian = _initializationParams.custodian;
        feeRecipient = _initializationParams.feeRecipient;
        managementFee = _initializationParams.managementFee;
        performanceFee = _initializationParams.performanceFee;

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

    function _setKycAuthSignatures() public {
        kycAuthSignature_1 = _getKycAuthSignature(mockUser_1, type(uint256).max);
        kycAuthSignature_2 = _getKycAuthSignature(mockUser_2, type(uint256).max);
    }

    function _getKycAuthSignature(address _user, uint256 _expiryBlock)
        internal
        returns (KycAuthLibrary.KycAuthSignature memory)
    {
        bytes32 _kycAuthMessage = keccak256(abi.encode(_user, address(vault), block.chainid, _expiryBlock));
        bytes32 _ethSignedMessage = _kycAuthMessage.toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(kycAuthSignerPrivateKey, _ethSignedMessage);
        bytes memory _authSignature = abi.encodePacked(_r, _s, _v);
        return KycAuthLibrary.KycAuthSignature({authSignature: _authSignature, expiryBlock: _expiryBlock});
    }
}
