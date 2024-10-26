// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";


contract MimirNFT is ERC721, Ownable {
    uint256 private _datasetIds;
    using SafeERC20 for IERC20;

    struct Dataset {
        string name;
        string description;
        uint256 licenseTokenId;
        address creator;
    }    

    mapping(uint256 => Dataset) public datasets;

    IIPAssetRegistry public ipAssetRegistry;
    ILicensingModule public licensingModule;
    IRoyaltyModule public royaltyModule;
    ILicenseToken public licenseToken;
    IERC20 public paymentToken;

    uint256 public datasetCreationFee;
    uint256 public constant PLATFORM_SHARE = 5;

    event DatasetCreated(uint256 indexed datasetId, address creator, string name);
    event DatasetUpdated(uint256 indexed datasetId, string name, string description);
    event RoyaltyPaid(uint256 indexed assetId, address indexed recipient, uint256 amount);

    constructor(
        uint256 _initialDatasetCreationFee,
        address _paymentTokenAddress
    ) ERC721("MimirNFT", "MIMIR") Ownable(msg.sender) {
        ipAssetRegistry = IIPAssetRegistry(0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40);
        licensingModule = ILicensingModule(0xC8f165950411504eA130692B87A7148e469f7090);
        royaltyModule = IRoyaltyModule(0xaCb5764E609aa3a5ED36bA74ba59679246Cb0963);
        licenseToken = ILicenseToken(0xd8aEF404432a2b3363479A6157285926B6B3b743);
        paymentToken = IERC20(_paymentTokenAddress);
        datasetCreationFee = _initialDatasetCreationFee;
    }

    function createDataset(string memory name, string memory description) public returns (uint256) {
        paymentToken.safeTransferFrom(msg.sender, address(this), datasetCreationFee);

        uint256 newDatasetId = _datasetIds++;
        _safeMint(msg.sender, newDatasetId);

        // Register the dataset as an IP Asset
        ipAssetRegistry.register(block.chainid, address(this), newDatasetId);

        // Create license for the dataset
        uint256 licenseTokenId = _createLicense(msg.sender, newDatasetId);

        datasets[newDatasetId] = Dataset(name, description, licenseTokenId, msg.sender);
        emit DatasetCreated(newDatasetId, msg.sender, name);

        return newDatasetId;
    }

    function _createLicense(address creator, uint256 assetId) internal returns (uint256) {
        address[] memory beneficiaries = new address[](2);
        uint256[] memory shares = new uint256[](2);
        
        beneficiaries[0] = creator;
        beneficiaries[1] = owner();
        shares[0] = 100 - PLATFORM_SHARE;
        shares[1] = PLATFORM_SHARE;

        bytes memory royaltyContext = abi.encode(beneficiaries, shares);

        return licensingModule.mintLicenseTokens(
            address(this),
            address(0), // License template address (you may need to set this appropriately)
            0, // License terms ID (you may need to set this appropriately)
            1,
            creator,
            royaltyContext
        );
    }

    function updateDataset(uint256 datasetId, string memory name, string memory description) public {
        require(_exists(datasetId), "Dataset does not exist");
        require(ownerOf(datasetId) == msg.sender, "Not the owner of the dataset");
        
        Dataset storage dataset = datasets[datasetId];
        dataset.name = name;
        dataset.description = description;
        
        emit DatasetUpdated(datasetId, name, description);
    }

    function getDataset(uint256 datasetId) public view returns (string memory, string memory, uint256, address) {
        require(_exists(datasetId), "Dataset does not exist");
        Dataset storage dataset = datasets[datasetId];
        return (dataset.name, dataset.description, dataset.licenseTokenId, dataset.creator);
    }

    function distributeRoyalties(uint256 assetId, uint256 amount) public {
        require(_exists(assetId), "Asset does not exist");
        
        address creator = datasets[assetId].creator;
        
        uint256 creatorAmount = (amount * (100 - PLATFORM_SHARE)) / 100;
        uint256 platformAmount = amount - creatorAmount;

        // Transfer creator share
        paymentToken.safeTransferFrom(msg.sender, creator, creatorAmount);
        emit RoyaltyPaid(assetId, creator, creatorAmount);

        // Transfer platform share
        paymentToken.safeTransferFrom(msg.sender, owner(), platformAmount);
        emit RoyaltyPaid(assetId, owner(), platformAmount);
    }


    function setDatasetCreationFee(uint256 _newFee) public onlyOwner {
        datasetCreationFee = _newFee;
    }

    function withdrawFees() public onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        paymentToken.safeTransfer(owner(), balance);
    }


    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}