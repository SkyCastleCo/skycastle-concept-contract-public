# SkyCastle Concepts - ERC 1155 Smart Contract

## Features
- ERC1155 NFT
- Only allow purchases when it is opened for public purchases
    - `onlyDuringOpenedForPublicPurchase` modifier
- Only allow purchases, mint and burn if the contract is not paused
	- `whenNotPaused` modifier
- Uses [operator-filter-registry](https://github.com/ProjectOpenSea/operator-filter-registry) from OpenSea to enforce royalties
    - Not a foolproof approach
- Only allow trading the tokens after the release timestamp (trading lockup period)
	- `onlyAfterRelease` modifier
    - hardcoded timestamp limit to a maximum of 31st December 2024
- Allow holders to burn their tokens
    - Once a token is burnt, it should not be part of the collection anymore
    - tracker to keep track of burnt tokens

## Events Emitted
- `UriUpdated(string newURI)`
    - Emitted when Base URI is updated.
- `ReleaseTimestamp(uint256 newReleaseTimestamp)`
    - Emitted when Release Timestamp has been changed/updated
- `OpenForPublicPurchase(bool isPublicPurchaseOpened)`
    - Emitted when Public Purchase has been changed/Updated
- `TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value)`
    - Emitted when a transfer / mint takes place.

## Functions
### External
- `burn`
	- `whenNotPaused`
    - Takes a Token Id + Amount. Burns those token and amount if the holder has the correct amount.
- `setURI`
	- `onlyOwner`
    - Updates the base URI, this is important as we'll be using SCAI file system first, and migrating to IPFS when finalized.
    - contractURI and URI (of token) shares this same base URI
- `setReleaseTimestamp`
	- `onlyOwner`
    - Updates the release timestamp, Only allow trading the tokens after the release timestamp (trading lockup period)
- `setIsPublicPurchaseOpen`
    - `onlyOwner`
    - Updates the Public Purchase Open, so that the Public can start using the purchase function to start minting from the contract
- `withdraw`
	- `onlyOwner`
    - `nonReentrant`
    - Withdraws the balance ethereum to the owner's address.
- `purchase`
	- `whenNotPaused`
    - `onlyDuringOpenedForPublicPurchase`
    - Allows a member of the public to purchase/mint an NFT during a public sale
- `mint`
	- `onlyOwner`
	- `whenNotPaused`
    - Allows the contract owner to "airdrop" tokens to addresses he/she chooses
- `getTotalBurnedTokensByType`
    - Tracker to get burnt tokens by token type
### Public
- `pause`
	- `onlyOwner`
    - Pause is for Emergency Usage only.
- `unpause`
	- `onlyOwner`
    - Unpause is for Emergency Usage following a Pause Scenario.
- `setRoyaltyInfo`
	- `onlyOwner`
    - Updates the Royalty Address + Basis Points in case there are changes.
- `setApprovalForAll`
	- Make sure the operator is allowed by `OperatorFilterRegistry`
	- `onlyAllowedOperatorApproval`
- `safeTransferFrom`
	- Make sure the operator is allowed by `OperatorFilterRegistry`
	- `onlyAfterRelease`
- `safeBatchTransferFrom`
	- Make sure the operator is allowed by `OperatorFilterRegistry`
	- `onlyAfterRelease`
- `uri`
    - Takes a _tokenId, returns a URI of the specific token's metadata.
- `contractURI`
    - returns a URI of the contract's metadata.
- `totalMinted`
    - Total Minted NFTs. Mint only, does not count burnt tokens
- `totalSupply`
    - Total Supply for the Current NFTs. Includes minted and burnt tokens.

### Private
- `_safeMint`
	- `whenNotPaused`
    - a wrapper on the _mint of the ERC1155 Contract and increments SCAI counters / trackers
- `getCurrentTokenCounter`
    - Mint Tracker - get current count for specified token id
- `incrementCurrentTokenCounter`
    - Mint Tracker - increment current count for specified token id

## Deployment

### Deployment to Development or Production Environments using SCAI API
1. Ensure your .env is set correctly. `production` points to Ethereum Mainnet, `development` points to Goerli Mainnet. For Test, please set NODE_ENV to `development`
2. ```npx hardhat compile```
3. Initialise a Wallet to hold the contract by calling ```createPrivateWallet``` API
4. Fund the wallet with enough ether. Ensure you're clear what type of ether is needed. (Ether or Goerli Ether)
5. Deploy Contract on Ethereum Net with the ```deployNFTContract``` API

### Alternative Deployment Method to Development using Remix
1. Create a Blank Workspace on Remix
2. Copy and Paste SCAIToken.sol into the contracts folder. (create a contracts folder if it isn't there)
3. Navigate to Solidity Compiler and choose 0.8.16. Click Compile SCAIToken.sol
4. Click Deploy and Run Transactions to start the deployment process
5. Consider testing in the VM Environments Remix has provided
6. Deploy to Goerli Environments to test Opensea Testnet etc
7. To Deploy with Metamask, Click Injected Provider - Metamask
8. Fill in the 3 variables, sample variables could be: 1000, https://public-accessibles.com/dev/metadata/concepts/,  1704067199
9. Click Transact, approve transaction on metamask and wait for etherscan link to appear
10. Contract should be deployed.

## Transfer to MultiSig Ownership
1. Ensure the contract is in correct state. Ensure the Opensea is set correctly before initiating transfer.
2. Call the TransferOwnership function to the multisig contract. Openzeppelin's Defender will be a good tool to handle this.
3. https://defender.openzeppelin.com/