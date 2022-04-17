// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/console.sol";
import "../FlashRedeem.sol";
import { IERC721Upgradeable } from "nftx/token/IERC721Upgradeable.sol";

interface CheatCodes {
    function startPrank(address) external;
    function stopPrank() external;
}

contract FlashRedeemTest is DSTest {

    address private BAYC_NFTX_ADDR = 0xEA47B64e1BFCCb773A0420247C0aa0a3C1D2E5C5;
    address private BAYC_NFT_ADDR = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address private SENSEI_ADDR = 0x6703741e913a30D6604481472b6d81F3da45e6E8;

    FlashRedeem flashRedeem;
    IERC721Upgradeable private BAYC_NFT = IERC721Upgradeable(BAYC_NFT_ADDR);


    function setUp() public {
        flashRedeem = new FlashRedeem();
    }

    function testFlashRedeem() public {
        // 5.2e18 (1e18 is decimal configuration for BAYC Token - flash loan 5.2 tokens)
        // why 5.2? NFTX vault charges 4% redeem fee, 5.2 allows us to redeem exactly 5 NFTs
        uint256 amount =  5200000000000000000;
        address flashRedeemContractAddr = address(flashRedeem);
        console.log("flashRedeemContractAddr", flashRedeemContractAddr);

        CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
        cheats.startPrank(SENSEI_ADDR);

        BAYC_NFT.setApprovalForAll(flashRedeemContractAddr, true);
        flashRedeem.flashBorrow(BAYC_NFTX_ADDR, amount);

        cheats.stopPrank();
    }
}
