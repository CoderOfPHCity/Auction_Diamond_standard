// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "../../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {Auction} from "../libraries/AppStorage.sol";

contract Auctions {
    Auction.AuctionStorage internal ds;

    function CreateAuction(
        address contractAddress,
        uint tokenID,
        uint price
    ) public {
        ds.auctionItemiD++;
        uint256 itemIds = ds.auctionItemiD;
        require(contractAddress != address(0), "No zero address call");
        Auction.AuctionDetails storage _b = ds.OwnerAuctionItem[msg.sender];

        _b.NFTowner = msg.sender;
        _b.tokenID = tokenID;
        _b.price = price;
        _b.status = true;
        Auction.NFTSToAuction storage _a = ds.TobeAuctioned[itemIds];
        _a.AuctionID = itemIds;
        _a.tokenID = tokenID;
        ds.seller[itemIds] = msg.sender;
        if (isERC721(_b.contractAddress)) {
            require(isERC721(contractAddress), "Not an ERC721 contract");

            IERC721(contractAddress).transferFrom(
                msg.sender,
                address(this),
                tokenID
            );
        } else {
            require(!isERC721(contractAddress), "Not an ERC1155 contract");
            IERC1155(contractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenID,
                1,
                ""
            );
        }
    }

    function startBidding() public {
        address owner_ = LibDiamond.contractOwner();
        require(msg.sender == owner_, "You are not the owner");
        Auction.AuctionDetails storage _id = ds.OwnerAuctionItem[msg.sender];
        _id.status = true;
    }

    function getSeller(uint id) public view returns (address _seller) {
        _seller = ds.seller[id];
    }

    function bid(uint auctionID_, uint _amount) public {
        require(
            hasEnoughTokens(msg.sender, _amount) == true,
            "You dont have enough AUCTokens"
        );
        Auction.AuctionDetails storage id_ = ds.OwnerAuctionItem[msg.sender];
        uint256 balance = ds.balances[msg.sender];
        require(balance >= _amount, "NotEnough AUCtokens");
        Auction.NFTSToAuction storage _a = ds.TobeAuctioned[auctionID_];
        uint _highestbid = _a.highestBid;
        _highestbid = balance;
        uint bidderStatus = ds.bids[msg.sender][auctionID_];
        require(id_.status == true, "Auction is not open");
        require(balance >= id_.price, "price below auction");
        require(balance != 0, "cannot bid 0");
        require(bidderStatus == 0, "Cannot bid twice");
        if (_highestbid != 0 && balance > _highestbid) {
            ds.bids[msg.sender][auctionID_] += balance;
            _a.highestBid = balance;
            _a.highestBidder = msg.sender;
        }

        uint feeValue = _a.highestBid - calculateTotalFee(_highestbid);

        distributeFees(feeValue);
    }

    function calculateTotalFee(
        uint256 _highestBid
    ) internal pure returns (uint256) {
        return (_highestBid * 90) / 100;
    }

    function distributeFees(uint256 _totalFee) internal {
        // Calculate fees according to percentages
        uint256 burnAmount = (_totalFee * Auction.BURN_PERCENT) / 100;
        uint256 daoAmount = (_totalFee * Auction.DAO_PERCENT) / 100;
        uint256 outbidAmount = (_totalFee * Auction.OUTBID_PERCENT) / 100;
        uint256 teamAmount = (_totalFee * Auction.TEAM_PERCENT) / 100;
        uint256 lastInteractedAmount = (_totalFee *
            Auction.LAST_INTERACTED_PERCENT) / 100;

        Auction._transferFrom(address(this), Auction.BURN_ADDRESS, burnAmount);
        Auction._transferFrom(
            address(this),
            Auction.RANDOM_DAO_ADDRESS,
            daoAmount
        );
        Auction._transferFrom(
            address(this),
            Auction.OUTBID_ADDRESS,
            outbidAmount
        );
        Auction._transferFrom(
            address(this),
            Auction.TEAM_WALLET_ADDRESS,
            teamAmount
        );
        Auction._transferFrom(
            address(this),
            Auction.LAST_INTERACTED_ADDRESS,
            lastInteractedAmount
        );
    }

    function settleBid(uint auctionIDm__) public {
        address owner_ = LibDiamond.contractOwner();
        require(msg.sender == owner_, "Not authorized");
        Auction.NFTSToAuction storage _idm_ = ds.TobeAuctioned[auctionIDm__];
        address _highestBidder_ = _idm_.highestBidder;
        Auction.AuctionDetails storage id_ = ds.OwnerAuctionItem[msg.sender];
        require(id_.status == true, "Auction not active");
        id_.status = false;

        address contractAddress = id_.contractAddress;
        uint nftID = id_.tokenID;
        address _seller = getSeller(auctionIDm__);
        require(_highestBidder_ == address(0), "invalid address!!");

        if (isERC721(contractAddress)) {
            require(isERC721(contractAddress), "Not an ERC721 contract");

            IERC721(contractAddress).transferFrom(
                address(this),
                _seller,
                nftID
            );
        } else if (!isERC721(contractAddress)) {
            IERC721(contractAddress).transferFrom(
                address(this),
                _highestBidder_,
                nftID
            );
        } else {
            IERC1155(contractAddress).safeTransferFrom(
                address(this),
                _highestBidder_,
                nftID,
                1,
                ""
            );
        }
    }

    function isERC721(address contractAddress) internal view returns (bool) {
        try IERC721(contractAddress).balanceOf(address(this)) returns (
            uint256
        ) {
            return true;
        } catch {
            return false;
        }
    }

    function hasEnoughTokens(
        address bidder,
        uint256 amount
    ) internal view returns (bool) {
        return IERC20(ds.tokenAddress).balanceOf(bidder) >= amount;
    }
}
