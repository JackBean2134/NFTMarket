// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyERC20WithTransferAndCall.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarket is ERC721Holder, ReentrancyGuard, Ownable {
    struct Listing {
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    MyERC20WithTransferAndCall public immutable paymentToken;
    uint256 public listingCounter;
    mapping(uint256 => Listing) public listings;

    uint256 public feeRate;
    address public feeRecipient;
    uint256 public constant FEE_BASE = 1000;

    event Listed(
        uint256 indexed listingId,
        address indexed nft,
        uint256 tokenId,
        address seller,
        uint256 price
    );
    event Bought(
        uint256 indexed listingId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 fee
    );
    event Canceled(uint256 indexed listingId);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address oldAddr, address newAddr);

    constructor(
        address _paymentToken,
        address _feeRecipient,
        uint256 _feeRate
    ) Ownable(msg.sender) {
        require(_paymentToken != address(0), "paymentToken zero");
        require(_feeRecipient != address(0), "feeRecipient zero");
        paymentToken = MyERC20WithTransferAndCall(_paymentToken);
        require(_feeRate < FEE_BASE, "fee too high");
        feeRecipient = _feeRecipient;
        feeRate = _feeRate;
    }

    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant returns (uint256 listingId) {
        require(price > 0, "price can't be zero");
        //先emit事件
        emit Listed(listingId, nftContract, tokenId, msg.sender, price);
        //再外部调用
        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        listingId = listingCounter++;
        listings[listingId] = Listing({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
    }

    function cancelList(uint256 listingId) external nonReentrant {
        Listing storage item = _getValidListing(listingId);
        require(msg.sender == item.seller, "only seller can cancel");
        emit Canceled(listingId);
        item.active = false;
        IERC721(item.nftContract).safeTransferFrom(
            address(this),
            item.seller,
            item.tokenId
        );
    }

    function buyNFT(uint256 listingId) external nonReentrant {
        Listing storage item = _getValidListing(listingId);
        require(msg.sender != item.seller, "cannot buy your own listing");

        address buyer = msg.sender;
        uint256 fee = (item.price * feeRate) / FEE_BASE;
        uint256 sellerReceive = item.price - fee;

        emit Bought(listingId, buyer, item.seller, item.price, fee);

        bool success1 = paymentToken.transferFrom(
            msg.sender,
            item.seller,
            sellerReceive
        );
        require(success1, "transferFrom seller failed");
        bool success2 = paymentToken.transferFrom(
            msg.sender,
            feeRecipient,
            fee
        );
        require(success2, "transferFrom fee failed");

        _deliverNFT(listingId, buyer, fee);
    }

    function tokensReceived(
        address from,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        require(
            msg.sender == address(paymentToken),
            "only payment token can call"
        );

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage item = _getValidListing(listingId);
        require(amount == item.price, "token amount not match price");

        uint256 fee = (item.price * feeRate) / FEE_BASE;
        uint256 sellerReceive = item.price - fee;

        bool ok1 = paymentToken.transfer(item.seller, sellerReceive);
        bool ok2 = paymentToken.transfer(feeRecipient, fee);
        require(ok1 && ok2, "transfer payout fail");

        _deliverNFT(listingId, from, fee);
    }

    function setFeeRate(uint256 newRate) external onlyOwner {
        require(newRate < FEE_BASE, "fee too high");
        uint256 old = feeRate;
        feeRate = newRate;
        emit FeeRateUpdated(old, newRate);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "zero address");
        address old = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(old, newRecipient);
    }

    function _getValidListing(
        uint256 listingId
    ) internal view returns (Listing storage) {
        Listing storage item = listings[listingId];
        require(item.active, "listing not active");
        return item;
    }

    function _deliverNFT(
        uint256 listingId,
        address buyer,
        uint256 /*fee*/
    ) internal {
        Listing storage item = listings[listingId];
        IERC721(item.nftContract).safeTransferFrom(
            address(this),
            buyer,
            item.tokenId
        );
        item.active = false;
    }
}
