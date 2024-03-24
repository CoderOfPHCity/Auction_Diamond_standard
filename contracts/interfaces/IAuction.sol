  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.24;
  
    interface IAuction {
        
    function CreateAuction (address contractAddress, uint tokenID, uint price) external payable;
    function getAuctionedItem() external view returns (address, uint);
    function startBidding(uint _auctionID) external;
    function getSeller(uint id) external view returns(address _seller);
    function bid(uint auctionID_) external;

    }

