// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleContract is ERC721, Ownable {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenSupply;
  Counters.Counter private _nextTokenId;
  
  uint256 public mintPrice = 0.06 ether;

  uint256 private reserveAtATime = 50;
  uint256 private reservedCount = 0;
  uint256 private maxReserveCount = 50;

  string _baseTokenURI;

  uint256 public MAX_SUPPLY = 10000;
  uint256 public maximumAllowedTokensPerPurchase = 10;
  uint256 public maximumAllowedTokensPerWallet = 100;

  address public syncAddress;

  struct SaleConfig {
    uint256 startTime;
    uint256 duration;
  }

  enum WorkflowStatus {
        Before,
        Presale,
        Sale,
        SoldOut
  }

  WorkflowStatus public workflow;
  SaleConfig public saleConfig;

  event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
  event ChangeSaleConfig(uint256 _startTime, uint256 _maxCount);

  constructor(string memory baseURI) ERC721("Simple Contract", "SC") {
    setBaseURI(baseURI);
    workflow = WorkflowStatus.Before;
    setSyncAddress(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);
  }

  modifier saleIsOpen {
    require(_tokenSupply.current() <= MAX_SUPPLY, "Sale has ended.");
    _;
  }

  modifier onlyAuthorized() {
    require(owner() == msg.sender);
    _;
  }

  function setWorkflowID(WorkflowStatus _workflowID) public onlyOwner {
      workflow = _workflowID;
  }

  function setSyncAddress(address _newSyncAddress) public onlyOwner {
    syncAddress = _newSyncAddress;
  }

  function tokensMinted() public view returns (uint256) {
    return _tokenSupply.current();
  }

  function setMaximumAllowedTokens(uint256 _count) public onlyAuthorized {
    maximumAllowedTokensPerPurchase = _count;
  }

  function setMaximumAllowedTokensPerWallet(uint256 _count) public onlyAuthorized {
    maximumAllowedTokensPerWallet = _count;
  }

  function setMaxMintSupply(uint256 maxMintSupply) external  onlyAuthorized {
    MAX_SUPPLY = maxMintSupply;
  }

  function setReserveAtATime(uint256 val) public onlyAuthorized {
    reserveAtATime = val;
  }

  function setMaxReserve(uint256 val) public onlyAuthorized {
    maxReserveCount = val;
  }

  function setPrice(uint256 _price) public onlyAuthorized {
    mintPrice = _price;
  }

  function setBaseURI(string memory baseURI) public onlyAuthorized {
    _baseTokenURI = baseURI;
  }

  function getReserveAtATime() external view returns (uint256) {
    return reserveAtATime;
  }

  function getLeftDuration() public view returns (uint256) {
        SaleConfig memory _saleConfig = saleConfig;
        return (_saleConfig.startTime + _saleConfig.duration) - block.timestamp;
  }

  function checkPresaleStatus() public returns (bool) {
        bool isPresaleEnded = false;
        SaleConfig memory _saleConfig = saleConfig;

         if (block.timestamp > _saleConfig.startTime + _saleConfig.duration) {
            isPresaleEnded = true;
            workflow = WorkflowStatus.Sale;
        } 
        
        return isPresaleEnded;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

 function reserveNft() public onlyAuthorized {
    require(reservedCount <= maxReserveCount, "Max Reserves taken already!");
    uint256 i;

    if(_exists(_tokenSupply.current())) {
        _tokenSupply.increment();
    }

    for (i = 0; i < reserveAtATime; i++) {
      _tokenSupply.increment();
      _safeMint(msg.sender, _tokenSupply.current());
      reservedCount++;
    }
  }

  function setUpPresale() external onlyOwner {
        workflow = WorkflowStatus.Presale;
        uint256 _startTime = block.timestamp;
        uint256 _duration = 24 hours;
        saleConfig = SaleConfig(_startTime, _duration);
        emit ChangeSaleConfig(_startTime, _duration);
  }

  function setUpSale() external onlyOwner {
        workflow = WorkflowStatus.Sale;
        emit WorkflowStatusChange(WorkflowStatus.Presale, WorkflowStatus.Sale);
    }

  function mint(uint256 _count) public payable saleIsOpen {
    if(_exists(_tokenSupply.current())) {
      _tokenSupply.increment();
    }

    uint256 mintIndex = _tokenSupply.current();
    bool presaleEnded = checkPresaleStatus();
    
    if (msg.sender != owner()) {
      require(presaleEnded && workflow == WorkflowStatus.Sale, "Sale is not active currently.");
      require(balanceOf(msg.sender) + _count <= maximumAllowedTokensPerWallet, "Max holding cap reached.");
    }

    if (mintIndex + _count >= MAX_SUPPLY) {
      workflow = WorkflowStatus.SoldOut;
    }

    require(mintIndex + _count <= MAX_SUPPLY, "Total supply exceeded.");
    require(
      _count <= maximumAllowedTokensPerPurchase,
      "Exceeds maximum allowed tokens"
    );

    require(msg.value >= mintPrice * _count, "Insufficient ETH amount sent.");

    for (uint256 i = 0; i < _count; i++) {
      _tokenSupply.increment();
      if(_exists(_tokenSupply.current())) {
        _tokenSupply.increment();
      }
      _safeMint(msg.sender, _tokenSupply.current());
    }
  }

  function preSaleMint(uint256[] calldata _ownedTokenIDs) public payable saleIsOpen {
      // Get Sync Addres
      IERC721 token =  IERC721(syncAddress);
      bool presaleStatus = checkPresaleStatus();
      require(!presaleStatus, "Presale Has Ended");
      require(msg.value >= mintPrice, "Insuffient ETH amount sent.");
      require(
      _ownedTokenIDs.length <= maximumAllowedTokensPerPurchase,
      "Exceeds maximum allowed tokens"
    );

      for (uint256 i = 0; i < _ownedTokenIDs.length; i++) {
          // As front end need some time to get newly done Transaction, the contract will check passing ids also to be 100% sure that someone won't mint the the same token twice.
          require(!_exists(_ownedTokenIDs[i]), "This token has already minted");

          address isOwner = token.ownerOf(_ownedTokenIDs[i]);
          require(isOwner == msg.sender, "You are not the holder of this NFT");
          _safeMint(msg.sender, _ownedTokenIDs[i]);
      }
  }

  function adminAirdrop(address _BAYCHolderAddress, uint256[] calldata _tokenIDs) external onlyOwner {
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
          require(!_exists(_tokenIDs[i]), "This token has already minted");
          _safeMint(_BAYCHolderAddress, _tokenIDs[i]);
      }
  }

  function withdraw() external onlyAuthorized {
    uint balance = address(this).balance;
    payable(owner()).transfer(balance);
  }
}