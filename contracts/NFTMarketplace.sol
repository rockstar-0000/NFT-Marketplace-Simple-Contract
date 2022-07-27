// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    using ERC165Checker for address;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    uint256 public marketFeePercent; // the fee percentage on sales (default: 250) 1: 100, 50: 5000, 100: 10000

    struct FeeItem {
        address payable feeAccount; // the account that recieves fees
        uint256 feePercent; // the fee percentage on sales 1: 100, 50: 5000, 100: 10000
    }
    mapping(address => FeeItem) public _feeData;

    constructor(uint256 _marketFeePercent) {
        marketFeePercent = _marketFeePercent;
    }

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct MarketItem {
        ListingStatus status;
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    event MarketItemSold(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price
    );

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public nonReentrant {
        require(price > 0, "Price must be greater than 0");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            ListingStatus.Active,
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        MarketItem storage item = idToMarketItem[itemId];
        address seller = idToMarketItem[itemId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        require(!item.sold, "This Sale has alredy finnished");
        require(item.status == ListingStatus.Active, "Listing is not active");
        emit MarketItemSold(itemId, tokenId, seller, msg.sender, price);
        uint256 feeAmount = (_feeData[nftContract].feePercent * price) / 10000;
        uint256 marketFee = (250 * price) / 10000;
        // transfer the (item price - royalty amount - fee amount) to the seller
        item.seller.transfer(price - feeAmount - marketFee);
        payable(_feeData[nftContract].feeAccount).transfer(feeAmount);

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        _itemsSold.increment();

        item.status = ListingStatus.Sold;
        item.owner = payable(msg.sender);
        item.sold = true;
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Cancel Sale
    function cancelSale(uint256 _itemId) public {
        MarketItem storage item = idToMarketItem[_itemId];

        require(msg.sender == item.seller, "Only seller can cancel listing");
        require(item.status == ListingStatus.Active, "Listing is not active");

        item.status = ListingStatus.Cancelled;

        IERC721(item.nftContract).transferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );
    }

    //only owner
    function setFeePercent(address nftContract, uint256 _feePercent)
        public
        onlyOwner
    {
        // feePercent = _feePercent;
        _feeData[nftContract].feePercent = _feePercent;
    }

    function setFeeAccount(address nftContract, address _feeAccount)
        public
        onlyOwner
    {
        // feeAccount = payable(_feeAccount);
        _feeData[nftContract].feeAccount = payable(_feeAccount);
    }

    function setMarketFeePercent(uint256 _marketFeePercent) public onlyOwner {
        marketFeePercent = _marketFeePercent;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "not owner you can't withdraw");
    }
}
