// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UniforgeCollection.sol";

error UniforgeDeployerV1__NeedMoreETHSent();
error UniforgeDeployerV1__TransferFailed();
error UniforgeDeployerV1__InvalidDiscount();

/**
 * @title Uniforge Deployer V1
 * @author d-carranza
 * @notice This contract enables users to deploy Uniforge NFT collections.
 * @notice For more information about Uniforge, visit uniforge.io.
 * @notice Powered by dapponics.io
 */
contract UniforgeDeployerV1 is Ownable {
    uint256 private deployFee;
    uint256 private deployedCollectionsCounter;
    mapping(uint256 => address) private deployedCollections;
    mapping(address => uint256) private deployerDiscounts;

    event NewCollectionCreated(address indexed newUniforgeCollection);
    event DeployFeeUpdated(uint256 indexed newDeployFee);
    event DiscountedDeployer(address indexed customer, uint256 indexed discount);

    /**
     * @dev Transfers ownership to a new owner at the contract creation.
     * @param _owner The address of the new owner of the UniforgeDeployerV1 contract.
     */
    constructor(address _owner, uint256 _deployFee) {
        transferOwnership(_owner);
        deployFee = _deployFee;
    }

    /**
     * @dev Allows the caller to deploy a new Uniforge Collection.
     * @param _owner The address of the new owner of the new UniforgeCollection contract.
     * @param _name The name of the ERC721 token.
     * @param _symbol The symbol of the ERC721 token.
     * @param _baseURI The base URI of the ERC721 token metadata.
     * @param _mintFee The cost of minting a single token.
     * @param _maxMintAmount The maximum number of tokens that can be minted in a single transaction.
     * @param _maxSupply The maximum total number of tokens that can be minted.
     * @param _saleStart The timestamp representing the start time of the public sale.
     */
    function deployUniforgeCollection(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _mintFee,
        uint256 _maxMintAmount,
        uint256 _maxSupply,
        uint256 _saleStart
    ) public payable {
        uint256 discountPercentage = 100 - deployerDiscounts[msg.sender];
        uint256 finalPrice = (deployFee * discountPercentage) / 100;
        if (msg.value < finalPrice) {
            revert UniforgeDeployerV1__NeedMoreETHSent();
        }
        address newUniforgeCollection = address(
            new UniforgeCollection(
                _owner,
                _name,
                _symbol,
                _baseURI,
                _mintFee,
                _maxMintAmount,
                _maxSupply,
                _saleStart
            )
        );

        deployedCollections[deployedCollectionsCounter] = address(
            newUniforgeCollection
        );
        deployedCollectionsCounter += 1;
        emit NewCollectionCreated(address(newUniforgeCollection));
    }

    /**
     * @dev Allows the contract owner to set the fee required to deploy a new Uniforge Collection.
     * @param _deployFee The new deployment fee amount.
     */
    function setDeployFee(uint256 _deployFee) public onlyOwner {
        deployFee = _deployFee;
        emit DeployFeeUpdated(deployFee);
    }

    /**
     * @dev Allows the contract owner to provide a discount to a specific customer.
     * @param _customer The address of the customer who gets the discount.
     * @param _discountPercentage The discount provided as a percentage.
     */
    function setDeployerDiscount(
        address _customer,
        uint256 _discountPercentage
    ) public onlyOwner {
        if (_discountPercentage > 99) {
            revert UniforgeDeployerV1__InvalidDiscount();
        }
        deployerDiscounts[_customer] = _discountPercentage;
        emit DiscountedDeployer(_customer, _discountPercentage);
    }

    /**
     * @dev Allows the contract owner to withdraw the Ether balance of the contract.
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert UniforgeDeployerV1__TransferFailed();
        }
    }

    /**
     * @dev Returns the number of Uniforge Collections deployed through this contract.
     */
    function getDeployments() public view returns (uint256) {
        return deployedCollectionsCounter;
    }

    /**
     * @dev Returns the address of a specific deployed Uniforge Collection.
     * @param _index The index of the deployed collection.
     */
    function getDeployment(uint256 _index) public view returns (address) {
        return deployedCollections[_index];
    }

    /**
     * @dev Returns the deployment fee required to deploy a new Uniforge Collection.
     */
    function getDeployFee() public view returns (uint256) {
        return deployFee;
    }

    /**
     * @dev Returns the discount percentage for a specific customer.
     * @param _customer The address of the customer.
     */
    function getDiscountForAddress(
        address _customer
    ) public view returns (uint256) {
        return deployerDiscounts[_customer];
    }

    /**
     * @dev Returns the final price required to deploy a new Uniforge Collection.
     * @param _customer The address of the customer.
     */
    function getFinalPriceForAddress(
        address _customer
    ) public view returns (uint256) {
        uint256 discountPercentage = 100 - deployerDiscounts[_customer];
        return (deployFee * discountPercentage) / 100;
    }
}
