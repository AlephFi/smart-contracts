// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Get trace-stack using calldata
// forge script GetCallDataTrace --sig="run(string,address,address,bytes)" <rpc> <from> <to> <data>
contract GetCallDataTrace is Script {
    function run(string memory _chainId, address _from, address _to, bytes calldata _callData) external {
        vm.createSelectFork(_chainId);
        vm.startPrank(_from);
        address target = _to;
        bytes memory data = _callData;

        (bool success,) = target.call(data);
        require(success, "Call failed");
    }
}
