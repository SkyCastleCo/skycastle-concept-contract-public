// SPDX-License-Identifier: MIT
// SCAI NFTs are governed by te following terms and conditions: https://www.skycastle.ai/terms-of-use

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract SCAIToken is ERC1155, ERC2981, Ownable, Pausable, ReentrancyGuard, DefaultOperatorFilterer {
    using Counters for Counters.Counter;

    uint256 constant MAX_SUPPLY = 480;

    uint256 public constant maxPerTx = 1;
    uint256 public constant mintPrice = 0.001 ether;

    uint256 private constant MAX_MINT_PER_CHARACTER = 60;
    uint256 private constant AMOUNT_OF_DIFFERENT_CHARACTERS = 8;

    string public name = "SCAI Concepts"; // please change this before prod

    // Base URI
    string private baseURI;

    // unix timestamp of trading date
    uint256 public releaseTimestamp;

    // The mapping from token type id to the number of tokens of that type
    mapping(uint256 => Counters.Counter ) private _tokenCounts;

    // tracker for total burned tokens
    mapping(uint256 => uint256) private totalBurnedTokens;

    modifier onlyAfterRelease() {
        require(block.timestamp >= releaseTimestamp, "Trading is not allowed until release");
        _;
    }

    constructor(uint16 _royaltyFeesInBasisPoints, string memory _contractURI, uint256 _releaseTimestamp) ERC1155(_contractURI) {
        baseURI = _contractURI;
        setRoyaltyInfo(msg.sender, _royaltyFeesInBasisPoints);
        releaseTimestamp = _releaseTimestamp;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
    * @notice global purchase function used in early access and public sale
    *
    * @param amount the amount of tokens to purchase
    * @param tokenId the id of token type to mint
    */
    function purchase(uint256 amount, uint256 tokenId) payable public whenNotPaused {

        // Check if the user has the required funds
        require(amount > 0 && amount <= maxPerTx, "Purchase: amount prohibited");
        require(msg.value == amount * mintPrice, "Purchase: Incorrect payment");
        require(totalSupply() + amount <= MAX_SUPPLY, "Mint: Max supply reached");
        // get current token count
        uint256 currentTokenCount = getCurrentTokenCounter(tokenId);
        // test for overflow.
        require((currentTokenCount + amount) <= MAX_MINT_PER_CHARACTER, "Mint: Max supply reached for character type");
        require(tokenId >= 0 && tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Error: Token Type Incorrect");

        _safeMint(msg.sender, tokenId, amount);
    }

    /**
    * @dev Wrapping the mint function for airdrop
    *
    * @param toAddress //address of eth to send to
    * @param tokenId // the token type to mint
    * @param amount  //amount of tokens to mint for account
    */
    function mint(address toAddress, uint256 tokenId, uint256 amount) public onlyOwner whenNotPaused
    {
        require(tokenId >= 0 && tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Error: Token Type Incorrect");
        require(totalSupply() + amount <= MAX_SUPPLY, "Mint: Max supply reached");
        uint256 currentTokenCount = getCurrentTokenCounter(tokenId);
        require((currentTokenCount + amount ) <= MAX_MINT_PER_CHARACTER, "Mint: Max supply reached for character type");

        _safeMint(toAddress, tokenId, amount);
    }

    /**
     * @dev burn function for sender.
     * @param _tokenId // the token type to mint
     * @param _amount  //amount of tokens to mint for account
     */
    function burn(uint256 _tokenId, uint256 _amount) external whenNotPaused {
        require(balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance");
        _burn(msg.sender, _tokenId, _amount);
        totalBurnedTokens[_tokenId] += _amount;
    }


    /**
     * @dev calls _mint of the ERC1155 contract.
     */
    function _safeMint(address to, uint256 tokenId, uint256 amount) private whenNotPaused
    {
        _mint(to, tokenId, amount, "");
        //increment appropriate counters
        incrementCurrentTokenCounter(tokenId, amount);
    }

    /**
     * @dev Allows the owner to update the royalty information
     */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Allows the owner to update the royalty information
     */
    function setRoyaltyInfo(address _receiver, uint16 _royaltyFeesInBasisPoints) public onlyOwner
    {
        require(_royaltyFeesInBasisPoints > 0 && _royaltyFeesInBasisPoints < 10000, "Invalid Royalty Fees in Bips");
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
     * @dev Updates the base URI that will be used to retrieve metadata.
     * @param _newuri The base URI to be used.
     */
    function setURI(string memory _newuri) external onlyOwner
    {
        baseURI = _newuri;
    }

    /**
     * @dev Updates the releaseTimestamp should situation change.
     * @param _newTimestamp The new timestamp that should be used.
     */
    function setReleaseTimestamp(uint256 _newTimestamp) external onlyOwner {
        releaseTimestamp = _newTimestamp;
    }

    /**
     * @dev Withdraws the amount to owner
     */
    function withdraw() external onlyOwner nonReentrant 
    {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

    /**
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
     * @dev gets the contract uri of the project.
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
     * @dev gets current token counter of the supply
     * @param _tokenId The token id (nft type) of token
     */
    function getCurrentTokenCounter(uint256 _tokenId) private view returns(uint256)
    {
        require(_tokenId >= 0 && _tokenId < AMOUNT_OF_DIFFERENT_CHARACTERS, "Incorrect Token Type");
        return _tokenCounts[_tokenId].current();
    }

    /**
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
     * @dev gets the total supply of the NFT Project
     */
    function totalSupply() public view virtual returns (uint256) 
    {
        uint256 currentSupply = 0;
        // Initialize the token counts
        for (uint256 i = 0; i < AMOUNT_OF_DIFFERENT_CHARACTERS; i++) {
            currentSupply += (_tokenCounts[i].current());
        }
        return currentSupply;
    }

    /**
     * @dev get total burned tokens by everyone
     * @param _tokenId the token type
     */
    function getTotalBurnedTokens(uint256 _tokenId) public view returns (uint256) {
        return totalBurnedTokens[_tokenId];
    }
}
