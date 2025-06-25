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
import {ERC7540} from "../src/ERC7540.sol";
import {IERC7540} from "../src/interfaces/IERC7540.sol";
import {ExposedERC7540} from "./exposes/ExposedERC7540.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TestToken} from "./exposes/TestToken.sol";
import {IERC7540Deposit} from "../src/interfaces/IERC7540Deposit.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ERC7540Test is Test {
    using SafeERC20 for IERC20;
    ExposedERC7540 public erc7540;
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    address public manager = makeAddr("manager");
    address public operationsMultisig = makeAddr("operationsMultisig");
    address public operator = makeAddr("operator");
    address public custodian = makeAddr("custodian");

    TestToken public erc20 = new TestToken();

    function setUp() public {
        erc20.mint(user, 1000);
        erc20.mint(user2, 1000);
        erc7540 = new ExposedERC7540();
        erc7540.initialize(IERC7540.InitializationParams({
            manager: manager,
            operationsMultisig: operationsMultisig,
            operator: operator,
            erc20: address(erc20),
            custodian: custodian
        }));
    }

    function test_requestMoreThanOneInTheSameBatchDeposit() public {
        uint256 _amount = 100;
        vm.startPrank(user);
        erc20.approve(address(erc7540), _amount * 2);
        erc7540.requestDeposit(_amount);
        vm.expectRevert(IERC7540Deposit.OnlyOneRequestPerBatchAllowed.selector);
        erc7540.requestDeposit(_amount);
        vm.stopPrank();
    }

    function test_requestDeposit() public {
        uint256 _amount = 100;
        vm.startPrank(user);
        erc20.approve(address(erc7540), _amount * 2);
        erc7540.requestDeposit(_amount);      
        vm.stopPrank();
    }
}
