// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MerkleTreeWhitelist is ERC721, Ownable {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenSupply;
  Counters.Counter private _nextTokenId;
  
  uint256 public mintPrice = 0.08 ether;
  uint256 public presalePrice = 0.1 ether;

  uint256 private reserveAtATime = 37;
  uint256 private reservedCount = 0;
  uint256 private maxReserveCount = 37;

  bytes32 public merkleRoot;

  string _baseTokenURI;

  bool public isActive = false;
  bool public isPresaleActive = false;

  uint256 public MAX_SUPPLY = 5000;
  uint256 public maximumAllowedTokensPerPurchase = 5;
  uint256 public maximumAllowedTokensPerWallet = 7;
  uint256 public allowListMaxMint = 2;


  mapping(address => bool) private _allowList;

  // Whitelisted
  mapping(address => bool) public whitelistClaimed;

  event SaleActivation(bool isActive);

  constructor(string memory baseURI) ERC721("Merkle Tree Whitelist", "MTW") {
    setBaseURI(baseURI);
    setSyncAddress(YOU_MERKLE_ROOT_HASH);
  }

  modifier saleIsOpen {
    require(_tokenSupply.current() <= MAX_SUPPLY, "Sale has ended.");
    _;
  }

  modifier onlyAuthorized() {
    require(owner() == msg.sender);
    _;
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

  function setActive(bool val) public onlyAuthorized {
    isActive = val;
    emit SaleActivation(val);
  }

  function setSyncAddress(address _root) public onlyOwner {
    merkleRoot = _root;
  }

  function setMaxMintSupply(uint256 maxMintSupply) external  onlyAuthorized {
    MAX_SUPPLY = maxMintSupply;
  }

  function setIsPresaleActive(bool _isPresaleActive) external onlyAuthorized {
    isPresaleActive = _isPresaleActive;
  }

  function setAllowListMaxMint(uint256 maxMint) external  onlyAuthorized {
    allowListMaxMint = maxMint;
  }

  function checkIfOnAllowList(address addr) external view returns (bool) {
    return _allowList[addr];
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

  function setPresalePrice(uint256 _preslaePrice) public onlyAuthorized {
    presalePrice = _preslaePrice;
  }

  function setBaseURI(string memory baseURI) public onlyAuthorized {
    _baseTokenURI = baseURI;
  }

  function getReserveAtATime() external view returns (uint256) {
    return reserveAtATime;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function reserveNft() public onlyAuthorized {
    require(reservedCount <= maxReserveCount, "Max Reserves taken already!");
    uint256 i;

    for (i = 0; i < reserveAtATime; i++) {
      _tokenSupply.increment();
      _safeMint(msg.sender, _tokenSupply.current());
      reservedCount++;
    }
  }

  function verifyUser (bytes32[] calldata _merkleProof) public view returns (bool) {
      // Generate leaf node from callee
    bytes32 leaf = keccak256(abi.encode(msg.sender));

    return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
  }

  function reserveToCustomWallet(address _walletAddress, uint256 _count) public onlyAuthorized {
    for (uint256 i = 0; i < _count; i++) {
      _tokenSupply.increment();
      _safeMint(_walletAddress, _tokenSupply.current());
    }
  }

  function preSaleMint(bytes32[] calldata _merkleProof, uint256 _count) public payable saleIsOpen {
    uint256 mintIndex = _tokenSupply.current();

    require(isPresaleActive, 'Allow List is not active');
    
    // Make sure user has not already claimed the tokens
    require(!whitelistClaimed[msg.sender], 'Address already claimed');
    
    // Generate leaf node from callee
    bytes32 leaf = keccak256(abi.encode(msg.sender));

    // Check the proof
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid Merkle Proof");

    whitelistClaimed[msg.sender] = true;
    
    require(mintIndex < MAX_SUPPLY, 'All tokens have been minted');
    require(balanceOf(msg.sender) + _count <= allowListMaxMint, 'Cannot purchase this many tokens');
    require(msg.value >= presalePrice * _count, 'Insuffient ETH amount sent.');

    for (uint256 i = 0; i < _count; i++) {
      _tokenSupply.increment();
      _safeMint(msg.sender, _tokenSupply.current());
    }
  }

  function withdraw() external onlyAuthorized {
    uint balance = address(this).balance;
    payable(owner()).transfer(balance);
  }
}