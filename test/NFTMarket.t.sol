// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../src/MyERC20WithTransferAndCall.sol";
import "../src/NFTMarket.sol";

contract TestNFT is ERC721 {
    uint256 public tokenIdCounter;
    constructor() ERC721("TestNFT", "TNFT") {}
    function mint(address to) external returns (uint256) {
        uint256 id = tokenIdCounter++;
        _safeMint(to, id);
        return id;
    }
}

contract NFTMarketTest is Test {
    MyERC20WithTransferAndCall public paymentToken;
    TestNFT public nft;
    NFTMarket public market;

    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address feeAddr = makeAddr("feeAddr");
    uint256 price = 100 * 1e18;
    uint256 feeRate = 50;

    function setUp() public {
        paymentToken = new MyERC20WithTransferAndCall(
            "PayToken",
            "PAY",
            10000 * 1e18
        );
        nft = new TestNFT();
        market = new NFTMarket(address(paymentToken), feeAddr, feeRate);

        paymentToken.transfer(buyer, 1000 * 1e18);
        vm.prank(seller);
        nft.mint(seller);
    }

    function testListAndBuyNormal() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        uint256 listingId = market.list(address(nft), 0, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(market), price);
        market.buyNFT(listingId);
        vm.stopPrank();

        uint256 fee = (price * feeRate) / 1000;
        uint256 sellerGet = price - fee;
        assertEq(nft.ownerOf(0), buyer);
        assertEq(paymentToken.balanceOf(feeAddr), fee);
        assertEq(paymentToken.balanceOf(seller), sellerGet);
    }

    function testBuyViaTransferAndCallTokensReceived() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        uint256 listingId = market.list(address(nft), 0, price);
        vm.stopPrank();

        vm.prank(buyer);
        paymentToken.transferAndCall(
            address(market),
            price,
            abi.encode(listingId)
        );

        uint256 fee = (price * feeRate) / 1000;
        uint256 sellerGet = price - fee;
        assertEq(nft.ownerOf(0), buyer);
        assertEq(paymentToken.balanceOf(feeAddr), fee);
        assertEq(paymentToken.balanceOf(seller), sellerGet);
    }

    function testCancelList() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        uint256 listingId = market.list(address(nft), 0, price);
        market.cancelList(listingId);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), seller);
        vm.expectRevert("listing not active");
        market.buyNFT(listingId);
    }

    function testOnlySellerCanCancel() public {
        vm.startPrank(seller);
        nft.setApprovalForAll(address(market), true);
        uint256 listingId = market.list(address(nft), 0, price);
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("only seller can cancel");
        market.cancelList(listingId);
    }
}
