//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/* solhint-disable no-console */

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

// contracts
import { WorkflowStructs } from "../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseTest } from "../utils/BaseTest.t.sol";

contract DerivativeWorkflowsTest is BaseTest {
    using Strings for uint256;

    address internal ipIdParent;

    function setUp() public override {
        super.setUp();
    }

    modifier withParentIp(bool isCommercial) {
        (ipIdParent, , ) = licenseAttachmentWorkflows.mintAndRegisterIpAndAttachPILTerms({
            spgNftContract: address(nftContract),
            recipient: caller,
            ipMetadata: ipMetadataDefault,
            terms: isCommercial ? PILFlavors.commercialUse({
                mintingFee: 100 * 10 ** mockToken.decimals(),
                currencyToken: address(mockToken),
                royaltyPolicy: address(royaltyPolicyLAP)
            }) : PILFlavors.nonCommercialSocialRemixing()
        });
        _;
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(false)
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withNonCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(false)
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(true)
    {
        _mintAndRegisterIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivative_withCommercialLicense()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(true)
    {
        _registerIpAndMakeDerivativeBaseTest();
    }

    function test_DerivativeWorkflows_mintAndRegisterIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(false)
    {
        _testWithLicenseTokens();
    }

    function test_DerivativeWorkflows_registerIpAndMakeDerivativeWithLicenseTokens()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(false)
    {
        _testWithLicenseTokensRegistration();
    }

    function test_SPG_multicall_mintAndRegisterIpAndMakeDerivative()
        public
        withCollection
        whenCallerHasMinterRole
        withEnoughTokens(address(derivativeWorkflows))
        withParentIp(false)
    {
        _testMulticallMintAndRegister();
    }

    function _mintAndRegisterIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivative({
            spgNftContract: address(nftContract),
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: new uint256  {licenseTermsIdParent},
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            recipient: caller
        });

        _assertIpRegistration(ipIdChild, tokenIdChild, licenseTemplateParent, licenseTermsIdParent);
    }

    function _registerIpAndMakeDerivativeBaseTest() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(
            ipIdParent,
            0
        );

        uint256 tokenIdChild = nftContract.mint(caller, ipMetadataDefault.nftMetadataURI);
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);

        (bytes memory sigMetadata, bytes32 expectedState) = _generateSignatures(ipIdChild);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        address ipIdChildActual = derivativeWorkflows.registerIpAndMakeDerivative({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            derivData: WorkflowStructs.MakeDerivative({
                parentIpIds: parentIpIds,
                licenseTemplate: address(pilTemplate),
                licenseTermsIds: new uint256  {licenseTermsIdParent},
                royaltyContext: ""
            }),
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: block.timestamp + 1000, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: block.timestamp + 1000, signature: sigMetadata })
        });

        _assertIpRegistration(ipIdChildActual, tokenIdChild, licenseTemplateParent, licenseTermsIdParent);
    }

    function _testWithLicenseTokens() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(ipIdParent, 0);
        
        uint256 startLicenseTokenId = _mintLicenseToken(licenseTermsIdParent);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (address ipIdChild, uint256 tokenIdChild) = derivativeWorkflows.mintAndRegisterIpAndMakeDerivativeWithLicenseTokens({
            spgNftContract: address(nftContract),
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            recipient: caller
        });

        _assertIpRegistration(ipIdChild, tokenIdChild, licenseTemplateParent, licenseTermsIdParent);
    }

    function _testWithLicenseTokensRegistration() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(ipIdParent, 0);

        uint256 tokenIdChild = nftContract.mint(caller, ipMetadataDefault.nftMetadataURI);
        address ipIdChild = ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild);
        uint256 startLicenseTokenId = _mintLicenseToken(licenseTermsIdParent);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        (bytes memory sigMetadata, bytes32 expectedState) = _generateSignatures(ipIdChild);

        derivativeWorkflows.registerIpAndMakeDerivativeWithLicenseTokens({
            nftContract: address(nftContract),
            tokenId: tokenIdChild,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            ipMetadata: ipMetadataDefault,
            sigMetadata: WorkflowStructs.SignatureData({ signer: u.alice, deadline: block.timestamp + 1000, signature: sigMetadata }),
            sigRegister: WorkflowStructs.SignatureData({ signer: u.alice, deadline: block.timestamp + 1000, signature: sigMetadata })
        });

        _assertIpRegistration(ipIdChild, tokenIdChild, licenseTemplateParent, licenseTermsIdParent);
    }

    function _testMulticallMintAndRegister() internal {
        (address licenseTemplateParent, uint256 licenseTermsIdParent) = licenseRegistry.getAttachedLicenseTerms(ipIdParent, 0);
        
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipIdParent;

        bytes[] memory data = new bytes[](10);
        for (uint256 i = 0; i < 10; i++) {
            data[i] = abi.encodeWithSelector(
                derivativeWorkflows.mintAndRegisterIpAndMakeDerivative.selector,
                address(nftContract),
                WorkflowStructs.MakeDerivative({
                    parentIpIds: parentIpIds,
                    licenseTemplate: address(pilTemplate),
                    licenseTermsIds: new uint256  {licenseTermsIdParent},
                    royaltyContext: ""
                }),
                ipMetadataDefault,
                caller
            );
        }

        bytes[] memory results = derivativeWorkflows.multicall(data);

        for (uint256 i = 0; i < 10; i++) {
            (address ipIdChild, uint256 tokenIdChild) = abi.decode(results[i], (address, uint256));
            _assertIpRegistration(ipIdChild, tokenIdChild, licenseTemplateParent, licenseTermsIdParent);
        }
    }

    function _assertIpRegistration(address ipIdChild, uint256 tokenIdChild, address licenseTemplate, uint256 licenseTermsId) internal {
        assertEq(nftContract.ownerOf(tokenIdChild), caller);
        assertEq(ipAssetRegistry.ipId(block.chainid, address(nftContract), tokenIdChild), ipIdChild);
        assertEq(licenseRegistry.getAttachedLicenseTerms(ipIdChild, 0), (licenseTemplate, licenseTermsId));
    }
}
