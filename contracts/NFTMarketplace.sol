// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint listPrice = 0.001 ether;

    struct ListedToken {
        uint tokenId;
        address owner;
        address seller;
        uint price;
        bool listed;
    }

    event TokenListed (
        uint tokenId,
        address owner,
        address seller,
        uint price,
        bool listed
    );

    mapping(uint => ListedToken) public idToListedToken;

    constructor() ERC721("NFT Marketplace", "NFTM") {
        _tokenIds.increment();
    }

    function updateListPrice(uint _newListPrice) public onlyOwner {
        listPrice = _newListPrice;
    }

    function getListPrice() public view returns(uint) {
        return listPrice;
    }

    function getListedTokenById(uint _tokenId) public view returns(ListedToken memory) {
        return idToListedToken[_tokenId];
    }

    function getCurrentTokenId() public view returns(uint) {
        return _tokenIds.current();
    }

    function createToken(string memory _tokenURI, uint _price) public payable {
        uint newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, _tokenURI);

        listedToken(newTokenId, _price);

        _tokenIds.increment();
    }

    function listedToken(uint _tokenId, uint _price) private {
        require(msg.value == listPrice, "Hopefully sending the correct price");
        require(_price > 0, "Make sure the price isn't negative");

        idToListedToken[_tokenId] = ListedToken(
            _tokenId,
            address(this),
            msg.sender,
            _price,
            true
        );

        _transfer(msg.sender, address(this), _tokenId);

        emit TokenListed(_tokenId, address(this), msg.sender, _price, true);
    }

    function buyToken(uint _tokenId) public payable {
        uint price = idToListedToken[_tokenId].price;
        address seller = idToListedToken[_tokenId].seller;

        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        idToListedToken[_tokenId].seller = msg.sender;

        _transfer(address(this), msg.sender, _tokenId);
        approve(address(this), _tokenId);

        (bool sentForContractOwner, ) = owner().call{value: listPrice}("");
        require(sentForContractOwner, "Fail send list price for contract owner");

        (bool sentForNFTOwner, ) = seller.call{value: msg.value}("");

        require(sentForNFTOwner, "Fail send nft price for owner");
    }

    function getAllNFTs() public view returns(ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        
        uint nftIndex = 0;

        for(uint count=1; count <= nftCount; count++) {
            ListedToken storage nftItem = idToListedToken[count];
            tokens[nftIndex] = nftItem;

            nftIndex++;
        }

        return tokens;
    }

    function getMyNFTs() public view returns(ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint nftIndex = 0;

        for(uint count=1; count <= nftCount; count++) {
            if(idToListedToken[count].owner == msg.sender || idToListedToken[count].seller == msg.sender) {
                ListedToken storage nftItem = idToListedToken[count];
                tokens[nftIndex] = nftItem;

                nftIndex++;
            }
        }

        return tokens;
    }

    function withdraw(uint _value) public payable onlyOwner {
        require(_value > 0, "withdrawal amount must be more than zero");
        require(_value <= address(this).balance, "no funds to withdraw");

        (bool sent, ) = owner().call{value: _value}("");
        
        require(sent, "Fail to withdraw");
    }
}
