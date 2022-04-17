// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/console.sol";
import { INFTXVault } from "nftx/interface/INFTXVault.sol";
import { IERC3156FlashBorrowerUpgradeable, IERC3156FlashLenderUpgradeable } from "nftx/interface/IERC3156Upgradeable.sol";
import { IERC20Upgradeable } from "nftx/token/IERC20Upgradeable.sol";
import { IERC721Upgradeable } from "nftx/token/IERC721Upgradeable.sol";
import { IERC721ReceiverUpgradeable } from "nftx/token/IERC721ReceiverUpgradeable.sol";
import { IUniswapV2Router02 } from "uni/interfaces/IUniswapV2Router02.sol";

interface ApeCoinAirdrop {
    function claimTokens() external;
}

contract FlashRedeem is IERC3156FlashBorrowerUpgradeable, IERC721ReceiverUpgradeable {

    // ============ Private constants ============
    address private BAYC_NFTX_ADDR = 0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5;
    address private BAYC_NFT_ADDR = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address private APE_COIN_AIRDROP_ADDR = 0x025C6da5BD0e6A5dd1350fda9e3B6a614B205a1F;
    address private APE_COIN_ADDR = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
    address private SUSHI_ROUTER_ADDR = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address private WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256[] private baycTokenArr;

    IERC20Upgradeable private BAYC_NFTX_TOKEN = IERC20Upgradeable(BAYC_NFTX_ADDR);
    IERC721Upgradeable private BAYC_NFT = IERC721Upgradeable(BAYC_NFT_ADDR);
    INFTXVault private BAYC_NFTX_VAULT = INFTXVault(BAYC_NFTX_ADDR);
    IERC20Upgradeable private APE_COIN_TOKEN = IERC20Upgradeable(APE_COIN_ADDR);
    IERC20Upgradeable private WETH_TOKEN = IERC20Upgradeable(WETH_ADDR);
    IERC3156FlashLenderUpgradeable private lender = IERC3156FlashLenderUpgradeable(BAYC_NFTX_ADDR);
    ApeCoinAirdrop private apeCoinAirdrop = ApeCoinAirdrop(APE_COIN_AIRDROP_ADDR);
    IUniswapV2Router02 private sushiRouter = IUniswapV2Router02(SUSHI_ROUTER_ADDR);

    // ============ Constructor ============

    constructor() {}

    // ============ Functions ============

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bytes32) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );
        console.log("New BAYC_NFTX token balance: ", BAYC_NFTX_TOKEN.balanceOf(address(this)));

        // Redeem BAYC NFTX Vault Tokens for BAYC NFTs.
        // Pay 4% (5 * 0.04 = 0.2) random redeem fee (https://nftx.io/vault/0xea47b64e1bfccb773a0420247c0aa0a3c1d2e5c5/info/)
        uint256[] memory emptySpecificIdsArr;
        BAYC_NFTX_VAULT.redeem(5, emptySpecificIdsArr);
        console.log("New BAYC_NFT token balance: ", BAYC_NFT.balanceOf(address(this)));

        // Claim ApeCoin airdrop
        apeCoinAirdrop.claimTokens();
        console.log("New ApeCoin token balance: ", APE_COIN_TOKEN.balanceOf(address(this)));

        // Set approval on BAYC NFTs and Mint NFTX tokens for flash loan fee repayment. Pay 10% fee (6 NFTs = 0.6 fee) to mint
        BAYC_NFT.setApprovalForAll(BAYC_NFTX_ADDR, true);
        uint256[] memory emptyAmountsArr;
        BAYC_NFTX_VAULT.mint(baycTokenArr, emptyAmountsArr);

        // Set approval on NFTX tokens for Sushi, swap extra NFTX tokens for ETH
        // SushiSwap (BAYC-NFTX -> WETH) path
        address[] memory path = new address[](2);
        path[0] = BAYC_NFTX_ADDR;
        path[1] = sushiRouter.WETH();

        uint256 excessApeNftxTokens = BAYC_NFTX_TOKEN.balanceOf(address(this)) - amount;
        console.log("excessApeNftxTokens: ", excessApeNftxTokens);

        console.log("ETH balance before swap: %s\n", address(this).balance);
        BAYC_NFTX_TOKEN.approve(SUSHI_ROUTER_ADDR, excessApeNftxTokens);
        sushiRouter.swapExactTokensForETH(excessApeNftxTokens, 0, path, address(this), block.timestamp);
        console.log("ETH balance after swap: %s\n", address(this).balance);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        BAYC_NFT.safeTransferFrom(msg.sender, address(this), 1060);
        uint256 _allowance = IERC20Upgradeable(token).allowance(address(this), address(lender));
        uint256 _fee = lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20Upgradeable(token).approve(address(lender), _allowance + _repayment);
        lender.flashLoan(this, token, amount, new bytes(0));
    }

    // Make contract payable to receive funds
    event Received(address, uint);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        baycTokenArr.push(tokenId);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")); // IERC721Receiver.onERC721Received.selector
    }

}