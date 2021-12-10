/**
 * BossDrops: The Gauntlet Collection
*/


pragma solidity ^0.7.0;



/**
 * @title Gauntlet contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract Gauntlet is ERC721, Ownable {
    using SafeMath for uint256;

    // The base price is set here. Price will change based on how quickly the gauntlets sell.
    uint256 public nftPrice = 70000000000000000; // 0.07 ETH

    // At each tier the price increases by 0.1 ETH.
    uint public tierPriceIncrease = 100000000000000000; // 0.1 ETH

    // The token ids are split into 5 tiers of 2000.
    uint public constant tierSize = 2000; 

    uint public currentTier = 0;

    // Only 10 gauntlets can be purchased per transaction.
    uint public constant maxNumPurchase = 10;

    // Only 10,000 total gauntlets.
    uint256 public constant MAX_TOKENS = 10000;

    // How many tokens an early access member is allowed to mint.
    uint public earlyAccessTokensPerUser = 1;

    uint public totalEarlyAccessTokensAllowed = 269;

    uint public currentEarlyAccessTokensClaimed = 0;
    
    /**
     * The hash of the concatented hash string of all the images.
     */
    string public provenance = "";

    mapping (address => bool) private earlyAccessAllowList;

    mapping (address => uint) private earlyAccessClaimedTokens;
    
    /**
     * The state of the sale:
     * 0 = closed
     * 1 = early access
     * 2 = open
     */
    uint public saleState = 0;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {  
        // On contract creation, reserve the first token for the owner.
        _safeMint(msg.sender, totalSupply());
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    /**
     * Set some tokens aside.
     */
    function reserveTokens(uint number) public onlyOwner { 
        require(totalSupply().add(number) <= MAX_TOKENS, "Reservation would exceed max supply");       
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < number; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
    
    /**
     * Set the state of the sale.
     */
    function setSaleState(uint newState) public onlyOwner {
        require(newState >= 0 && newState <= 2, "Invalid state");
        saleState = newState;
    }
    
    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function setProvenanceHash(string memory hash) public onlyOwner {
        provenance = hash;
    }

    function setPrice(uint value) public onlyOwner {
        nftPrice = value;
    }

    function setTierPriceIncrease(uint value) public onlyOwner {
        tierPriceIncrease = value;
    }

    function setEarlyAccessTokensPerUser(uint num) public onlyOwner {
        earlyAccessTokensPerUser = num;
    }

    function setTotalEarlyAccessTokensAllowed(uint num) public onlyOwner {
        totalEarlyAccessTokensAllowed = num;
    }

    function addEarlyAccessMembers(address[] memory addresses) public onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            earlyAccessAllowList[addresses[i]] = true;
        }
    }

    function _checkRegularSale(uint numberOfTokens) pure internal {
        require(numberOfTokens <= maxNumPurchase, "Can only mint 10 tokens at a time");
    }

    function _checkEarlyAccess(address sender, uint numberOfTokens) view internal {
        require(earlyAccessAllowList[sender], "Sender is not on the early access list");
        require(currentEarlyAccessTokensClaimed < totalEarlyAccessTokensAllowed, "Minting would exceed total allowed for early access");
        require(earlyAccessClaimedTokens[sender] < earlyAccessTokensPerUser, "Sender cannot claim any more early access gauntlets at this time");
        require(numberOfTokens == 1, "Can only mint 1 token in the early access sale");
    }

    function canClaimEarlyAccessToken(address addr) view public returns (bool) {
        return earlyAccessAllowList[addr] && earlyAccessClaimedTokens[addr] < earlyAccessTokensPerUser && currentEarlyAccessTokensClaimed < totalEarlyAccessTokensAllowed;
    }

    /**
    * Mints an NFT
    */
    function mintNft(uint numberOfTokens) public payable {
        require(saleState == 1 || saleState == 2, "Sale must be active to mint");
        if (saleState == 1) {
            _checkEarlyAccess(msg.sender, numberOfTokens);
            earlyAccessClaimedTokens[msg.sender] = earlyAccessClaimedTokens[msg.sender].add(1);
            currentEarlyAccessTokensClaimed = currentEarlyAccessTokensClaimed.add(1);
        } else if (saleState == 2) {
            _checkRegularSale(numberOfTokens);
        }
        require(totalSupply().add(numberOfTokens) <= MAX_TOKENS, "Purchase would exceed max supply");
        require(nftPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            uint thisTier = mintIndex / tierSize;
            if (thisTier > currentTier) {
                // Price adjustment will not affect this transaction, but will affect following ones.
                nftPrice = nftPrice.add(tierPriceIncrease);
                currentTier = thisTier;
            }
            _safeMint(msg.sender, mintIndex);
        }
    }
}