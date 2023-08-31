// SPDX-License-Identifier: MIT
// SCAI NFTs are governed by the following terms and conditions: https://www.skycastle.ai/terms-of-use

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

/**
 * @author SkycastleAI Team
 * @title Skycastle Concepts NFT
 * @dev By default, the owner account will be the one that deploys the contract. This will be
 * changed with {transferOwnership} to a multisig to secure the NFT Contract. The transfer will occur
 * AFTER setting up the basics like Opensea Collections etc.
 */
contract SCAIToken is ERC1155, ERC2981, Ownable, Pausable, ReentrancyGuard, DefaultOperatorFilterer {
    using Counters for Counters.Counter;

    string public constant name = "SCAI Concepts";
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 private constant MAX_SUPPLY = 480;
    uint256 private constant MAX_MINT_PER_CHARACTER = 60;
    uint256 private constant AMOUNT_OF_DIFFERENT_CHARACTERS = 8;
    /// GMT Time - end of 2024
    uint256 private constant TIMESTAMP_END_OF_2024 = 1735689599;

    /// Base URI
    string private baseURI;

    /// unix timestamp of trading date
    uint256 public releaseTimestamp;

    /// flag for when public purchase allowed
    bool public isPublicPurchaseOpened;

    /**
    * @notice counter for the mapping of token type id to the number of tokens of that type
    * @dev this does not change even when theres burning occuring
    */
    mapping(uint256 => Counters.Counter ) private _tokenCounts;

    /// tracker for total & burned tokens
    mapping(uint256 => uint256) private _totalSupply;

    /// tracker for total burned tokens
    mapping(uint256 => uint256) private _totalBurnedTokens;

    /// emit events for critical state updates
    /// For URI updating
    event UriUpdated(string newURI);
    /// For Release Timestamp Updates
    event ReleaseTimestamp(uint256 newReleaseTimestamp);
    /// For Opened to Public Purchase Updates
    event OpenForPublicPurchase(bool isPublicPurchaseOpened);

    /// Modifier to Prevent Trading / Transfer of NFT until after releaseTimestamp
    modifier onlyAfterRelease() {
        require(block.timestamp >= releaseTimestamp, "Trading is not allowed until release");
        _;
    }

    /// Modifier to Prevent Public purchase of NFT until after isPublicPurchaseOpened is set to true
    modifier onlyDuringOpenedForPublicPurchase() {
        require(isPublicPurchaseOpened, "Please wait for public purchase to open");
        _;
    }

    /**
    * @dev constructor
    *
    * @param _royaltyFeesInBasisPoints // value of 100 to 1000 (in bips) 1000 = 10%
    * @param _contractURI // base url of the metadata. this will be in IPFS
    * @param _releaseTimestamp //unix timestamp, must be before end december 2024
    */
    constructor(uint16 _royaltyFeesInBasisPoints, string memory _contractURI, uint256 _releaseTimestamp) ERC1155(_contractURI) {
        // validating release timestamp here, and not using setReleaseTimestamp because it should not emit an event in constructor
        require(_releaseTimestamp <= TIMESTAMP_END_OF_2024, "Please use a timestamp BEFORE end of 2024.");

        baseURI = _contractURI;
        setRoyaltyInfo(msg.sender, _royaltyFeesInBasisPoints);
        releaseTimestamp = _releaseTimestamp;
        isPublicPurchaseOpened = false;
    }

    /**
    * @notice Purchase function is used in public sale when it gets opened by scai
    * @dev this is dependent on isPublicPurchaseOpened variable for public access
    *
    * @param tokenId the id of token type to mint
    */
    function purchase(uint256 tokenId) payable external whenNotPaused onlyDuringOpenedForPublicPurchase {
        // Check if the user has the required funds
        require(msg.value == MINT_PRICE, "Purchase: Incorrect payment");
        require(totalMinted() + 1 <= MAX_SUPPLY, "Mint: Max supply reached");
        // get current token count
        uint256 currentTokenCount = getCurrentTokenCounter(tokenId);
        // test for overflow.
        require((currentTokenCount + 1) <= MAX_MINT_PER_CHARACTER, "Mint: Max supply reached for character type");
        _safeMint(msg.sender, tokenId, 1);
    }

    /**
    * @notice this is for the contract owner to airdrop tokens to specific users.
    * @dev wrapping the mint function for airdrop
    *
    * @param toAddress //address of eth to send to
    * @param tokenId // the token type to mint
    * @param amount  //amount of tokens to mint for account
    */
    function mint(address toAddress, uint256 tokenId, uint256 amount) external onlyOwner whenNotPaused
    {
        require(totalMinted() + amount <= MAX_SUPPLY, "Mint: Max supply reached");
        uint256 currentTokenCount = getCurrentTokenCounter(tokenId);
        require((currentTokenCount + amount ) <= MAX_MINT_PER_CHARACTER, "Mint: Max supply reached for character type");

        _safeMint(toAddress, tokenId, amount);
    }

    /**
     * @notice Burn Function to reduce total supply.
     * @dev burn function for sender.
     * @param _tokenId // the token type to burn
     * @param _amount  //amount of tokens to burn for account
     */
    function burn(uint256 _tokenId, uint256 _amount) external whenNotPaused {
        require(balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance");
        _burn(msg.sender, _tokenId, _amount);
        _totalBurnedTokens[_tokenId] += _amount;
        _totalSupply[_tokenId] -= _amount;
    }

    /**
     * @dev Updates the base URI that will be used to retrieve metadata.
     * @param _newuri The base URI to be used.
     */
    function setURI(string memory _newuri) external onlyOwner
    {
        baseURI = _newuri;
        emit UriUpdated(_newuri);
    }

    /**
     * @notice SCAI has regulatory compliance on when this NFT can be traded. New Values cannot be beyond 31st Dec 2024
     * @dev Updates the releaseTimestamp should situation change.
     * @param _newTimestamp The new timestamp that should be used.
     */
    function setReleaseTimestamp(uint256 _newTimestamp) external onlyOwner {
        require(_newTimestamp <= TIMESTAMP_END_OF_2024, "Please use a timestamp BEFORE end of 2024.");
        releaseTimestamp = _newTimestamp;
        emit ReleaseTimestamp(_newTimestamp);
    }

    /**
     * @notice Allows the owner to open or close public purchases for NFT of this contract
     * @dev Updates the condition on whether public purchases is opened.
     * @param _isPublicPurchaseOpened boolean flag to toggle open or close
     */
    function setIsPublicPurchaseOpen(bool _isPublicPurchaseOpened) external onlyOwner
    {
        isPublicPurchaseOpened = _isPublicPurchaseOpened;
        emit OpenForPublicPurchase(_isPublicPurchaseOpened);
    }

    /**
     * @notice tracker to obtain total burned tokens by token type
     * @param _tokenId the token type
     */
    function getTotalBurnedTokensByType(uint256 _tokenId) external view returns (uint256) {
        return _totalBurnedTokens[_tokenId];
    }

    /**
     * @dev Withdraws the amount to owner address
     */
    function withdraw() external onlyOwner nonReentrant
    {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    /**
     * @notice for the pausing of contract in emergencies only
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice for the unpausing of contract when emergencies are rectified
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Updates the Royalty Amount should situation changes
     * @dev Allows the owner to update the royalty information
     * @param _receiver the receiver of the royalty
     * @param _royaltyFeesInBasisPoints in basis points. ie. 1000 bips = 10%
     */
    function setRoyaltyInfo(address _receiver, uint16 _royaltyFeesInBasisPoints) public onlyOwner
    {
        _setDefaultRoyalty(_receiver, _royaltyFeesInBasisPoints);
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     *      In this contract, the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     *      In this contract, the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     * @notice you might have to use [] for the last argument
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    )
        public override onlyAllowedOperator(from) onlyAfterRelease
    {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     *      In this contract, the added modifier ensures that the operator is allowed by the OperatorFilterRegistry.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) onlyAfterRelease {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return ERC1155.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /**
     * @notice gets the metadata uri of the specific token id. eg. https://public-accessibles.com/dev/metadata/concepts/1.json
     * @dev concatenates the baseUri with the tokenId to get the token specific uri
     * @param _tokenId The token id (nft type) of token
     */
    function uri(uint256 _tokenId) override public view returns (string memory) 
    {
        require(_tokenId >= 0 && _tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Incorrect Token Type");
        return string (
            abi.encodePacked(
                baseURI,
                Strings.toString(_tokenId),
                ".json"
            )
        );
    }

    /**
     * @notice gets the contract uri of the project. eg. https://public-accessibles.com/dev/metadata/concepts/contractMetadata.json
     * @dev concatenates the base uri and contractMetadata.json to derive the contract Uri
     */
    function contractURI() public view returns (string memory) {
        return string (
            abi.encodePacked(
                baseURI,
                "contractMetadata.json"
            )
        );
    }

    /**
     * @notice gets the total minted NFTs of the NFT Project
     * @dev uses the _tokenCounts, which includes mint only
     */
    function totalMinted() public view virtual returns (uint256)
    {
        uint256 currentSupply = 0;
        // Initialize the token counts
        for (uint256 i = 0; i < AMOUNT_OF_DIFFERENT_CHARACTERS; i++) {
            currentSupply += (_tokenCounts[i].current());
        }
        return currentSupply;
    }

    /**
     * @notice check the total supply
     * @dev uses the _totalSupply that includes mint + burn
     */
    function totalSupply() public view virtual returns (uint256)
    {
        uint256 totalTokens = 0;
        // Initialize the token counts
        for (uint256 i = 0; i < AMOUNT_OF_DIFFERENT_CHARACTERS; i++) {
            totalTokens += _totalSupply[i];
        }
        return totalTokens;
    }

    /**
     * @dev Hook function that is called before any token transfer.
     *
     * This function is part of the ERC-1155 standard and is used to implement additional checks or
     * perform actions before a token transfer occurs.
     */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @notice Calls the _mint of the ERC1155 Contract and Increment SCAI Counters on Mint.
     * @dev calls _mint of the ERC1155 contract.
     * @param _to // receiver
     * @param _tokenId // token type
     * @param _amount // amount of tokens to mint
     */
    function _safeMint(address _to, uint256 _tokenId, uint256 _amount) private whenNotPaused
    {
        _mint(_to, _tokenId, _amount, "");
        //increment appropriate counters
        incrementCurrentTokenCounter(_tokenId, _amount);
        _totalSupply[_tokenId] += _amount;
    }

    /**
     * @notice increment the tracker of Token Supply for the specified token Id
     * @dev increment the token counter of the supply of a specific tokenId
     * @param _tokenId The token id (nft type) of token
     * @param _amount The amount to increment
     */
    function incrementCurrentTokenCounter(uint256 _tokenId, uint256 _amount) private
    {
        require(_tokenId >= 0 && _tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Incorrect Token Type");
        for (uint256 i = 0; i < _amount; i++) {
            _tokenCounts[_tokenId].increment();
        }
    }

    /**
     * @notice Get current token supply of specified token id.
     * @dev gets current token counter of the supply
     * @param _tokenId The token id (nft type) of token
     */
    function getCurrentTokenCounter(uint256 _tokenId) private view returns(uint256)
    {
        require(_tokenId >= 0 && _tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Incorrect Token Type");
        return _tokenCounts[_tokenId].current();
    }
}