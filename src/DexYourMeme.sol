// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INonfungiblePositionManager} from "./Interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract DexYourMeme is Ownable, IERC721Receiver {
    /// @dev Errors
    error DYM__SwapETHFailed();
    error DYM__DexMemeFailed();
    error DYM__NotMemeCoinMinterCaller();
    error DYM__NotEnoughTimePassed();

    /// @dev Immutables
    address private immutable i_mcm;

    /// @dev Arrays
    uint[] private s_received_NFTs;
    address[] private s_memeCoinsDexed;

    /// @dev Constants
    address private constant NFT_POSITION_MANAGER = 0x1238536071E1c677A632429e3655c799b22cDA52;
    /** @dev Calculation Formula: ((sqrtPriceX96**2)/(2**192))*(10**(token0 decimals - token1 decimals))
     * This  gives us the price of token0 in token1, where token0 -> meme token ERC20, token1 -> WETH
     */
    /// @dev InitialPrice expression: 0.01 WETH for 1 000 000 AST | 79228162514264337593543950 -> 0.1 WETH for 100 000 AST
    uint160 private constant INITIAL_PRICE = 7922816251426433759354395;
    address private constant WETH_ADDRESS = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    uint24 private constant FEE = 3000;
    uint private constant WETH_AMOUNT = 0.1 * 10 ** 18;
    uint private constant MEME_AMOUNT = 1_000_000 * 10 ** 18;

    /// @dev Mappings
    mapping(uint => uint) private s_nftToTimeLeft;

    /// @dev Events
    event FundsReceived(uint indexed amount);
    event Swapped_ETH_For_WETH(uint indexed amount);
    event MemeDexRequestReceived(address indexed token);
    event MemeDexedSuccessfully(address indexed token);

    /// @dev Constructor
    constructor(address mcm) Ownable(msg.sender) {
        i_mcm = mcm;
    }

    //////////////////////////////////// @notice DYM External Functions ////////////////////////////////////

    /// @notice Adds possibility to receive funds by this contract, which is required by MFM contract
    receive() external payable {
        emit FundsReceived(msg.value);
    }

    /// @notice Swaps ETH into WETH, creates, initializes and adds liquidity pool for new meme token
    /// @param memeToken Address of ERC20 meme token minted by MCM contract
    function dexMeme(address memeToken) external {
        if (msg.sender != i_mcm) revert DYM__NotMemeCoinMinterCaller();
        emit MemeDexRequestReceived(memeToken);

        swapETH();

        /// @dev Creating And Initializing Pool
        INonfungiblePositionManager(NFT_POSITION_MANAGER).createAndInitializePoolIfNecessary(memeToken, WETH_ADDRESS, FEE, INITIAL_PRICE);

        // Approve tokens for the position manager
        IERC20(WETH_ADDRESS).approve(NFT_POSITION_MANAGER, WETH_AMOUNT);
        IERC20(memeToken).approve(NFT_POSITION_MANAGER, MEME_AMOUNT);

        // Add liquidity to the new pool using mint
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: memeToken,
            token1: WETH_ADDRESS,
            fee: FEE, // Fee tier 0.30%
            tickLower: -887220, // Near 0 price
            tickUpper: 887220, // Extremely high price
            amount0Desired: MEME_AMOUNT, // Meme token amount sent to manager to provide liquidity
            amount1Desired: WETH_AMOUNT, // WETH token amount sent to manager to provide liquidity
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this), // Address that will receive NFT representing liquidity pool
            deadline: block.timestamp + 1200 // 20 minutes deadline
        });

        (uint tokenId, , , ) = INonfungiblePositionManager(NFT_POSITION_MANAGER).mint(params);

        /// s_received_NFTs.push(tokenId); -> @dev CHECK IF 'onERC721Received()' adds it properly
        s_nftToTimeLeft[tokenId] = (block.timestamp + 52 weeks);
        s_memeCoinsDexed.push(memeToken);

        emit MemeDexedSuccessfully(memeToken);
    }

    /// @notice This is needed as NonfungiblePositionManager is issuing NFT once we initialize liquidity pool
    /// @param tokenId The ID of the NFT
    function onERC721Received(address /* operator */, address /* from */, uint tokenId, bytes memory /* data */) external override returns (bytes4) {
        s_received_NFTs.push(tokenId);

        return this.onERC721Received.selector;
    }

    //////////////////////////////////// @notice DYM Internal Functions ////////////////////////////////////

    /// @notice Swaps ETH for WETH to be able to proceed with 'dexMeme()' function
    function swapETH() internal {
        (bool success, ) = WETH_ADDRESS.call{value: address(this).balance}(abi.encodeWithSignature("deposit()"));

        if (!success) revert DYM__SwapETHFailed();

        emit Swapped_ETH_For_WETH(IERC20(WETH_ADDRESS).balanceOf(address(this)));
    }

    //////////////////////////////////// @notice DYM Team Functions ////////////////////////////////////

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param tokenId The ID of the NFT for which tokens are being collected
    function collectFees(uint tokenId) external payable onlyOwner {
        (, , , , , , , , , , uint128 tokensOwed0, uint128 tokensOwed1) = INonfungiblePositionManager(NFT_POSITION_MANAGER).positions(tokenId);

        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId, // NFT token Id that represents liquidity pool
            recipient: owner(), // DYM Team wallet address
            amount0Max: tokensOwed0, // ERC20 meme token
            amount1Max: tokensOwed1 // WETH
        });

        INonfungiblePositionManager(NFT_POSITION_MANAGER).collect(params);

        emit INonfungiblePositionManager.Collect(tokenId, owner(), tokensOwed0, tokensOwed1);
    }

    /// @dev THIS FUNCTION IS BLOCKED FOR 1 YEAR TO PREVENT RUG PULL ACTIONS ON NEWLY DEXED MEME COINS
    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param tokenId The ID of the token for which liquidity is being decreased
    /// @param liquidity The amount by which liquidity will be decreased
    /// @param memeTokenAmount The minimum amount of token0 that should be accounted for the burned liquidity
    /// @param wethAmount The minimum amount of token1 that should be accounted for the burned liquidity
    function decreaseLiquidity(uint tokenId, uint128 liquidity, uint memeTokenAmount, uint wethAmount) external payable onlyOwner {
        if (s_nftToTimeLeft[tokenId] > block.timestamp) revert DYM__NotEnoughTimePassed();

        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId, // The ID of the token for which liquidity was decreased
            liquidity: liquidity, // The amount by which liquidity for the NFT position was decreased
            amount0Min: memeTokenAmount, // The amount of token0 that was accounted for the decrease in liquidity
            amount1Min: wethAmount, // The amount of token1 that was accounted for the decrease in liquidity
            deadline: block.timestamp + 1200 // 20 minutes deadline
        });

        INonfungiblePositionManager(NFT_POSITION_MANAGER).decreaseLiquidity(params);

        emit INonfungiblePositionManager.DecreaseLiquidity(tokenId, liquidity, memeTokenAmount, wethAmount);
    }

    /// @dev THIS FUNCTION IS BLOCKED FOR 1 YEAR TO PREVENT RUG PULL ACTIONS ON NEWLY DEXED MEME COINS
    /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens must be collected first.
    /// @param tokenId The ID of the token that is being burned
    function burn(uint tokenId) external payable onlyOwner {
        if (s_nftToTimeLeft[tokenId] > block.timestamp) revert DYM__NotEnoughTimePassed();

        INonfungiblePositionManager(NFT_POSITION_MANAGER).burn(tokenId);
    }

    //////////////////////////////////// @notice DYM Getter Functions ////////////////////////////////////

    /// @notice Returns all NFT tokens received from NonfungiblePositionManager
    function getAllTokens() external view returns (uint[] memory) {
        return s_received_NFTs;
    }

    /// @notice Returns all dexed meme coins
    function getDexedCoins() external view returns (address[] memory) {
        return s_memeCoinsDexed;
    }

    /// @notice Returns given token balance for certain user
    function getUserTokenBalance(address user, address token) external view returns (uint) {
        return IERC20(token).balanceOf(user);
    }
}
