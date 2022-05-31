// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MutantSerum is ERC721A, Ownable {

  uint256 public mintPrice = 0.0069 ether;

  string _baseTokenURI;

  bool public isActive = false;

  uint256 public MAX_SUPPLY = 10000;
  uint256 public maxAllowedTokensPerPurchase = 10;
  uint256 public maxAllowedTokensPerWallet = 10;
  uint256 private counter = 90;
  uint256 private counterUP = 10;

  constructor(string memory baseURI) ERC721A("Mutant Serum", "MS") {
    setBaseURI(baseURI);
  }

  modifier saleIsOpen {
    require(totalSupply() <= MAX_SUPPLY, "Sale has ended.");
    _;
  }

  modifier onlyAuthorized() {
    require(owner() == msg.sender);
    _;
  }

  function setMaximumAllowedTokens(uint256 _count) public onlyAuthorized {
    maxAllowedTokensPerPurchase = _count;
  }

  function setMaxAllowedTokensPerWallet(uint256 _count) public onlyAuthorized {
    maxAllowedTokensPerWallet = _count;
  }

  function togglePublicSale() public onlyAuthorized {
    isActive = !isActive;
  }

  function setPrice(uint256 _price) public onlyAuthorized {
    mintPrice = _price;
  }

  function setBaseURI(string memory baseURI) public onlyAuthorized {
    _baseTokenURI = baseURI;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function freeMint_(uint256 _count) public payable saleIsOpen {
    uint256 mintIndex = totalSupply();

    if (msg.sender != owner()) {
      require(isActive, "Sale is not active currently.");
      require(balanceOf(msg.sender) + _count <= maxAllowedTokensPerWallet, "Max holding cap reached.");
    }

    require(mintIndex + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require(
      _count <= maxAllowedTokensPerPurchase,
      "Exceeds maximum allowed tokens"
    );

    if(mintIndex == (counter + counterUP)) {
        counter = counter + 100;
    }

    if(mintIndex > counter) {
        require(msg.value >= mintPrice * _count, "Insufficient ETH amount sent.");
        _safeMint(msg.sender, _count);
    }
    
    if(mintIndex <= counter) {
        _safeMint(msg.sender, _count);
    }
   
    

  }

  function withdraw() external onlyAuthorized {
    uint balance = address(this).balance;
    payable(owner()).transfer(balance);
  }
}
