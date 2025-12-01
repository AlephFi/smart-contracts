// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract ERC4626MathTest is Test {
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

    function test_previewMint() public pure {
        uint256 shares = 100 ether;
        uint256 totalAssets = 1000 ether;
        uint256 totalShares = 1000 ether;

        uint256 assets = ERC4626Math.previewMint(shares, totalAssets, totalShares);
        assertEq(assets, 100 ether, "100 shares should equal 100 assets when 1:1");
    }

    function test_previewMint_withExistingShares() public pure {
        uint256 shares = 50 ether;
        uint256 totalAssets = 1000 ether;
        uint256 totalShares = 2000 ether; // 2:1 ratio

        uint256 assets = ERC4626Math.previewMint(shares, totalAssets, totalShares);
        // Using Ceil rounding, so it may round up slightly
        assertApproxEqRel(assets, 25 ether, 0.01e18, "50 shares should equal ~25 assets at 2:1 ratio");
    }

    function test_previewMint_zeroTotalShares() public pure {
        uint256 shares = 100 ether;
        uint256 totalAssets = 1000 ether;
        uint256 totalShares = 0;

        uint256 assets = ERC4626Math.previewMint(shares, totalAssets, totalShares);
        // When totalShares is 0, it should use the decimals offset
        assertGt(assets, 0, "Should return assets even with zero total shares");
    }
}

