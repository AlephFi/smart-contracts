// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract ERC4626MathTest is BaseTest {
    function test_previewMintUnits() public pure {
        uint256 shareUnits = 1e18; // 1 share unit
        uint256 totalAssets = 100 ether;

        uint256 assets = ERC4626Math.previewMintUnits(shareUnits, totalAssets);
        assertEq(assets, totalAssets, "1 share unit should equal total assets");
    }

    function test_previewMintUnits_partial() public pure {
        uint256 shareUnits = 5e17; // 0.5 share units
        uint256 totalAssets = 100 ether;

        uint256 assets = ERC4626Math.previewMintUnits(shareUnits, totalAssets);
        assertEq(assets, 50 ether, "0.5 share units should equal 50% of total assets");
    }

    function test_previewWithdrawUnits() public pure {
        uint256 assets = 50 ether;
        uint256 totalAssets = 100 ether;

        uint256 shareUnits = ERC4626Math.previewWithdrawUnits(assets, totalAssets);
        assertEq(shareUnits, 5e17, "50% of assets should equal 0.5 share units");
    }

    function test_previewWithdrawUnits_full() public pure {
        uint256 assets = 100 ether;
        uint256 totalAssets = 100 ether;

        uint256 shareUnits = ERC4626Math.previewWithdrawUnits(assets, totalAssets);
        assertEq(shareUnits, 1e18, "100% of assets should equal 1 share unit");
    }

    function test_previewMintUnits_zeroTotalAssets() public pure {
        uint256 shareUnits = 1e18;
        uint256 totalAssets = 0;

        uint256 assets = ERC4626Math.previewMintUnits(shareUnits, totalAssets);
        assertEq(assets, 0, "Zero total assets should return zero");
    }
}

