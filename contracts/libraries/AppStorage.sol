// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "../../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";





// NFT auctions work by selling non-fungible art on an online marketplace using cryptocurrency. 
// The seller sets a minimum price for the NFT, and 
// interested buyers can submit their bids during a specific timeframe.
library Auction{
    event Transfer(address indexed _from, address indexed _to, uint256 _value);


     // Constants for fee distribution
    // uint constant  FEE_PERCENT_TO_TOTAL = 10; // 10% of highestBid == totalFee
    uint constant BURN_PERCENT = 2; // 2% of totalFee is burned
    uint constant DAO_PERCENT = 2; // 2% of totalFee is sent to a random DAO address
    uint constant OUTBID_PERCENT = 3; // 3% goes back to the outbid bidder
    uint constant TEAM_PERCENT = 2; // 2% goes to the team wallet
    uint constant LAST_INTERACTED_PERCENT = 1; // 1% is sent to the last address to interact with AUCToken

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant RANDOM_DAO_ADDRESS = 0x1111111111111111111111111111111111111111;
    address public constant TEAM_WALLET_ADDRESS = 0x2222222222222222222222222222222222222222;
    address public constant LAST_INTERACTED_ADDRESS = 0x3333333333333333333333333333333333333333;
     address public constant OUTBID_ADDRESS = 0x3333333333333333333333333333333333333333;



struct AuctionDetails {
        // IERC721 contractAddress721;
        // IERC1155 contractAddress1155;
        address contractAddress;
        address NFTowner;
        uint tokenID;
        uint price;
        bool status;
    }

    struct NFTSToAuction {
        uint AuctionID;
        uint tokenID;
        address highestBidder;
        uint highestBid;
    }


    
struct AuctionStorage {
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        address tokenAddress;
    uint auctionItemiD;
    NFTSToAuction itemsToAuction;
    AuctionDetails auctionDetails;
    mapping(uint => NFTSToAuction) TobeAuctioned;
    mapping (address => AuctionDetails) OwnerAuctionItem;
    mapping (address => mapping(uint => uint))bids;
    mapping (uint => address) seller;



}


    function layoutStorage() internal pure returns (AuctionStorage storage l) {
        assembly {
            l.slot := 0
        }
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        AuctionStorage storage l = layoutStorage();
        uint256 frombalances = l.balances[msg.sender];
        require(
            frombalances >= _amount,
            "ERC20: Not enough tokens to transfer"
        );
        l.balances[_from] = frombalances - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }
}