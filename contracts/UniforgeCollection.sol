// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
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
 * @author dapponics.io
 * @notice A smart contract for a Non-Fungible Token (NFT) collection.
 * For more info about Uniforge, visit uniforge.io.
 */
contract UniforgeCollection is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private s_supply;
    string private s_baseURI;
    uint256 private s_startSale;
    uint256 private s_maxMintAmount;
    uint256 private immutable i_maxSupply;
    uint256 private immutable i_mintFee;

    /**
     * @dev Transfers ownership to the client right at deployment and declare all the variables.
     * @param _owner The address of the new owner of the contract.
     * @param _name The name of the ERC721 token.
     * @param _symbol The symbol of the ERC721 token.
     * @param _baseURI The base URI of the ERC721 token metadata.
     * @param _mintFee The cost of minting a single token.
     * @param _maxMintAmount The maximum number of tokens that can be minted in a single transaction.
     * @param _maxSupply The maximum total number of tokens that can be minted.
     * @param _startSale The timestamp of when the public sale starts.
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
        s_baseURI = _baseURI;
        i_mintFee = _mintFee;
        s_maxMintAmount = _maxMintAmount;
        i_maxSupply = _maxSupply;
        s_startSale = _startSale;
    }

    /**
     * @dev Mints `_mintAmount` tokens to the caller of the function.
     * The caller has to send `_mintFee`*`_mintAmount` ethers and the sale should be open to mint.
     * The `_mintAmount` has to be greater than 0 and less than or equal to `s_maxMintAmount`.
     * @param _mintAmount The number of tokens to mint.
     */
    function mintNft(uint256 _mintAmount) public payable {
        if (_mintAmount <= 0 || _mintAmount > s_maxMintAmount) {
            revert UniforgeCollection__InvalidMintAmount();
        }
        if (block.timestamp < s_startSale) {
            revert UniforgeCollection__SaleIsNotOpen();
        }
        if (msg.value < i_mintFee * _mintAmount) {
            revert UniforgeCollection__NeedMoreETHSent();
        }
        _mintLoop(msg.sender, _mintAmount);
    }

    /**
     * @dev Allows the contract owner to mint tokens without constraints for marketing / strategy purposes.
     * @param _mintAmount The number of tokens to mint.
     * @param _receiver The address to receive the minted tokens.
     */
    function mintForAddress(uint256 _mintAmount, address _receiver) public payable onlyOwner {
        _mintLoop(_receiver, _mintAmount);
    }

    /**
     * @dev Sets the base URI of the ERC721 token metadata.
     * @param _baseURI The new base URI.
     */
    function setBaseURI(string memory _baseURI) public onlyOwner {
        s_baseURI = _baseURI;
    }

    /**
     * @dev Sets the maximum number of tokens that can be minted in a single transaction.
     * @param _maxMintAmount The new maximum number of tokens.
     */
    function setMaxMintAmountPerTx(uint256 _maxMintAmount) public onlyOwner {
        s_maxMintAmount = _maxMintAmount;
    }

    /**
     * @dev Sets the starting timestamp of the public sale.
     * @param _startSale The new starting timestamp.
     */
    function setStartSale(uint256 _startSale) public onlyOwner {
        s_startSale = _startSale;
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
     * This function is internal, because it doesn't perform any checks.
     * @param _receiver The address to receive the minted tokens.
     * @param _mintAmount The number of tokens to mint.
     */
    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            s_supply.increment();

            if (s_supply.current() > i_maxSupply) {
                revert UniforgeCollection__MaxSupplyExceeded();
            }

            _safeMint(_receiver, s_supply.current());
        }
    }

    /**
     * @dev Returns the maximum total number of tokens that can be minted.
     */
    function maxSupply() public view returns (uint256) {
        return i_maxSupply;
    }

    /**
     * @dev Returns the cost of minting a single token.
     */
    function mintFee() public view returns (uint256) {
        return i_mintFee;
    }

    /**
     * @dev Returns the maximum number of tokens that can be minted in a single transaction.
     */
    function maxMintAmount() public view returns (uint256) {
        return s_maxMintAmount;
    }

    /**
     * @dev Returns the current sale starting timestamp.
     */
    function startSale() public view returns (uint256) {
        return s_startSale;
    }

    /**
     * @dev Returns the base URI of the ERC721 token metadata.
     */
    function baseURI() public view returns (string memory) {
        return s_baseURI;
    }

    /**
     * @dev Returns the specific URI for a given token.
     * @param _tokenId The ID of the token to retrieve the URI for.
     * @notice The returned URI is the concatenation of the base URI and the token ID in string format.
     */
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (_tokenId <= 0 || _tokenId > s_supply.current()) {
            revert UniforgeCollection__NonexistentToken();
        }
        return string(abi.encodePacked(s_baseURI, _tokenId.toString()));
    }
}
