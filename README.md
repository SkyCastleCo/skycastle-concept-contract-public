# SkyCastle - ERC 1155 Smart Contract

## Features
- Only allow purchases, mint and burn if the contract is not paused
	- `whenNotPaused` modifier
- Uses [operator-filter-registry](https://github.com/ProjectOpenSea/operator-filter-registry) from OpenSea to enforce royalties
- Only allow trading after the release timestamp
	- `onlyAfterRelease` modifier
- Allow holders to burn their tokens
## Functions

### Public
- `pause`
	- `onlyOwner`
- `unpause`
	- `onlyOwner`
- `purchase`
	- Early access and public sale
	- `whenNotPaused`
- `mint`
	- `onlyOwner`
	- `whenNotPaused`
- `setRoyaltyInfo`
	- `onlyOwner`
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
- `contractURI`
- `totalSupply`
- `getTotalBurnedTokens`
### External
- `burn`
	- `whenNotPaused`
- `setURI`
	- `onlyOwner`
- `setReleaseTimestamp`
	- `onlyOwner`
- `withdraw`
	- `onlyOwner`
### Private
- `_safeMint`
	- `whenNotPaused`
- `getCurrentTokenCounter`
- `incrementCurrentTokenCounter`


