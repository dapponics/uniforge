// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
/**            _ ____                    
  __  ______  (_) __/___  _________ ____ 
 / / / / __ \/ / /_/ __ \/ ___/ __ `/ _ \
/ /_/ / / / / / __/ /_/ / /  / /_/ /  __/
\__,_/_/ /_/_/_/  \____/_/   \__, /\___/ 
                            /____/  
*/
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error UniforgeCollection__InvalidMintAmount();
error UniforgeCollection__SaleIsNotOpen();
error UniforgeCollection__NeedMoreETHSent();
error UniforgeCollection__MaxSupplyExceeded();
error UniforgeCollection__TransferFailed();
error UniforgeCollection__NonexistentToken();

/**
 * @title Uniforge Collection
 * @author d-carranza
 * @notice A smart contract for a Uniforge NFT collection.
 * @notice For more info about Uniforge, visit uniforge.io.
 * @notice Powered by dapponics.io
 */
contract UniforgeCollection is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private supply;
    string private baseURI;
    uint256 private mintFee;
    uint256 private maxMintAmount;
    uint256 private maxSupply;
    uint256 private startSale;

    event MintFeeUpdated(address indexed collectionAddress, uint256 indexed newMintFee);
    event MaxMintAmountUpdated(address indexed collectionAddress, uint256 indexed newMaxMintAmount);
    event MaxSupplyUpdated(address indexed collectionAddress, uint256 indexed newMaxSupply);
    event StartSaleUpdated(address indexed collectionAddress, uint256 indexed newStartSale);

    /**
     * @dev Transfers ownership to the client right at deployment and declare all the variables.
     * @param _owner The address of the new owner of the contract.
     * @param _name The name of the ERC721 token.
     * @param _symbol The symbol of the ERC721 token.
     * @param _baseURI The base URI of the ERC721 token metadata.
     * @param _mintFee The cost of minting a single token.
     * @param _maxMintAmount The maximum number of tokens that can be minted in a single transaction.
     * @param _maxSupply The maximum total number of tokens that can be minted.
     * @param _startSale The timestamp representing the start time of the public sale.
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _mintFee,
        uint256 _maxMintAmount,
        uint256 _maxSupply,
        uint256 _startSale
    ) ERC721(_name, _symbol) {
        transferOwnership(_owner);
        baseURI = _baseURI;
        mintFee = _mintFee;
        maxMintAmount = _maxMintAmount;
        maxSupply = _maxSupply;
        startSale = _startSale;
    }

    /**
     * @dev Mints `_mintAmount` tokens to the caller of the function.
     * The caller has to send `_mintFee`*`_mintAmount` ethers and the sale should be open to mint.
     * The `_mintAmount` has to be greater than 0 and less than or equal to `maxMintAmount`.
     * @param _mintAmount The number of tokens to mint.
     */
    function mintNft(uint256 _mintAmount) public payable {
        if (_mintAmount <= 0 || _mintAmount > maxMintAmount) {
            revert UniforgeCollection__InvalidMintAmount();
        }
        if (block.timestamp < startSale) {
            revert UniforgeCollection__SaleIsNotOpen();
        }
        if (msg.value < mintFee * _mintAmount) {
            revert UniforgeCollection__NeedMoreETHSent();
        }
        _mintLoop(_mintAmount, msg.sender);
    }

    /**
     * @dev Allows the contract owner to mint free tokens without time or mint limit constraints.
     * @param _mintAmount The number of tokens to mint.
     * @param _receiver The address to receive the minted tokens.
     */
    function mintForAddress(uint256 _mintAmount, address _receiver) public payable onlyOwner {
        _mintLoop(_mintAmount, _receiver);
    }

    /**
     * @dev Allows the contract owner to set the base URI of the ERC721 token metadata.
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Allows the contract owner to set the fee required to mint a single token.
     * @param _mintFee The fee of minting a single token.
     */
    function setMintFee(uint256 _mintFee) public onlyOwner {
        mintFee = _mintFee;
        emit MintFeeUpdated(address(this), mintFee);
    }

    /**
     * @dev Allows the contract owner to set the maximum amount of tokens that can be minted at once.
     * @param _maxMintAmount The new maximum number of minteable tokens in a single transaction.
     */
    function setMaxMintAmount(uint256 _maxMintAmount) public onlyOwner {
        maxMintAmount = _maxMintAmount;
        emit MaxMintAmountUpdated(address(this), maxMintAmount);
    }

    /**
     * @dev Sets the upper limit on the total number of tokens that can be created.
     * @param _maxSupply The maximum total number of tokens that can be minted.
     */
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(address(this), maxSupply);
    }

    /**
     * @dev Sets the starting timestamp of the public sale.
     * @param _startSale The new starting timestamp.
     */
    function setStartSale(uint256 _startSale) public onlyOwner {
        startSale = _startSale;
        emit StartSaleUpdated(address(this), startSale);
    }

    /**
     * @dev Allows the contract owner to withdraw the Ether balance of the contract.
     */
    function withdraw() public onlyOwner {
        (bool _ownerSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!_ownerSuccess) {
            revert UniforgeCollection__TransferFailed();
        }
    }

    /**
     * @dev Helper function for minting `_mintAmount` tokens to `_receiver`.
     * @param _mintAmount The number of tokens to mint.
     * @param _receiver The address to receive the minted tokens.
     */
    function _mintLoop(uint256 _mintAmount, address _receiver) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            if (supply.current() >= maxSupply) {
                revert UniforgeCollection__MaxSupplyExceeded();
            }

            _safeMint(_receiver, supply.current());

            supply.increment();
        }
    }

    /**
     * @dev Returns the maximum total number of tokens that can be minted.
     */
    function getMaxSupply() public view returns (uint256) {
        return maxSupply;
    }

    /**
     * @dev Returns the fee for minting a single token.
     */
    function getMintFee() public view returns (uint256) {
        return mintFee;
    }

    /**
     * @dev Returns the maximum number of tokens that can be minted in a single transaction.
     */
    function getMaxMintAmount() public view returns (uint256) {
        return maxMintAmount;
    }

    /**
     * @dev Returns the starting timestamp of the public sale.
     */
    function getStartSale() public view returns (uint256) {
        return startSale;
    }

    /**
     * @dev Returns the base URI of the ERC721 token metadata.
     */
    function getBaseURI() public view returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Returns the specific URI for a given token.
     * @param _tokenId The ID of the token to retrieve the URI for.
     * @notice The returned URI is the concatenation of the base URI and the token ID strings.
     */
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (_tokenId >= supply.current()) {
            revert UniforgeCollection__NonexistentToken();
        }
        return string(abi.encodePacked(baseURI, _tokenId.toString()));
    }
}
