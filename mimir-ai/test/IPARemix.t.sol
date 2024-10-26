// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { IPALicenseToken } from "../src/IPALicenseToken.sol";
import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPARemix.t.sol
contract IPARemixTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xC8f165950411504eA130692B87A7148e469f7090;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistryAddr = 0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542;
    // Protocol Core - LicenseToken
    address internal licenseTokenAddr = 0xd8aEF404432a2b3363479A6157285926B6B3b743;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAPAddr = 0x793Df8d32c12B0bE9985FFF6afB8893d347B6686;
    // Protocol Core - SUSD
    address internal susdAddr = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

    IPAssetRegistry public ipAssetRegistry;
    LicensingModule public licensingModule;
    LicenseRegistry public licenseRegistry;
    LicenseToken public licenseToken;

    IPALicenseToken public ipaLicenseToken;
    IPALicenseTerms public ipaLicenseTerms;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licensingModule = LicensingModule(licensingModuleAddr);
        licenseRegistry = LicenseRegistry(licenseRegistryAddr);
        licenseToken = LicenseToken(licenseTokenAddr);
        ipaLicenseTerms = new IPALicenseTerms(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            royaltyPolicyLAPAddr,
            susdAddr
        );
        ipaLicenseToken = new IPALicenseToken(licensingModuleAddr, pilTemplateAddr);
        simpleNft = SimpleNFT(ipaLicenseTerms.SIMPLE_NFT());

        vm.label(address(ipAssetRegistryAddr), "IPAssetRegistry");
        vm.label(address(licensingModuleAddr), "LicensingModule");
        vm.label(address(licenseRegistryAddr), "LicenseRegistry");
        vm.label(address(licenseTokenAddr), "LicenseToken");
        vm.label(address(pilTemplateAddr), "PILicenseTemplate");
        vm.label(address(simpleNft), "SimpleNFT");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_remixIp() public {
        //
        // Alice mints License Tokens for Bob.
        //

        uint256 expectedTokenId = simpleNft.nextTokenId();
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(simpleNft), expectedTokenId);

        vm.prank(alice);
        (address parentIpId, uint256 tokenId, uint256 licenseTermsId) = ipaLicenseTerms.attachLicenseTerms();

        uint256 startLicenseTokenId = ipaLicenseToken.mintLicenseToken({
            ipId: parentIpId,
            licenseTermsId: licenseTermsId,
            ltAmount: 2,
            ltRecipient: bob
        });

        assertEq(parentIpId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);

        assertEq(licenseToken.ownerOf(startLicenseTokenId), bob);
        assertEq(licenseToken.ownerOf(startLicenseTokenId + 1), bob);

        //
        // Bob uses the minted License Token from Alice to register a derivative IP.
        //

        vm.prank(address(ipaLicenseTerms)); // need to prank to mint simpleNft
        tokenId = simpleNft.mint(address(bob));
        address childIpId = ipAssetRegistry.register(block.chainid, address(simpleNft), tokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        licensingModule.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "" // empty for PIL
        });

        assertTrue(licenseRegistry.hasDerivativeIps(parentIpId));
        assertTrue(licenseRegistry.isParentIp(parentIpId, childIpId));
        assertTrue(licenseRegistry.isDerivativeIp(childIpId));
        assertEq(licenseRegistry.getDerivativeIpCount(parentIpId), 1);
        assertEq(licenseRegistry.getParentIpCount(childIpId), 1);
        assertEq(licenseRegistry.getParentIp({ childIpId: childIpId, index: 0 }), parentIpId);
        assertEq(licenseRegistry.getDerivativeIp({ parentIpId: parentIpId, index: 0 }), childIpId);
    }
}
