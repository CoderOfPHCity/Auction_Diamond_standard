// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/Auctions.sol";
import "../contracts/facets/AUCFacet.sol";
import "../contracts/DANIELNFT.sol";
import "../contracts/libraries/AppStorage.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract DiamondDeployer is Test, IDiamondCut {
    Auction.AuctionStorage internal ds;
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    AUCFacet auctionF;
    Auctions auction;
    DANIELNFT nft;

    Auctions _auction;
    address A = address(0xa);
    address B = address(0xb);

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        auctionF = new AUCFacet();
        auction = new Auctions();
        nft = new DANIELNFT();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(auctionF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("AUCFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(auction),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("Auctions")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        A = mkaddr("bidder a");
        B = mkaddr("bidder b");

        AUCFacet(address(diamond)).mintTo(A);
        AUCFacet(address(diamond)).mintTo(B);

        _auction = Auctions(address(diamond));
        auctionF = AUCFacet(address(diamond));

        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testCreatebid() public {
        vm.expectRevert("No zero address call");
        _auction.CreateAuction(address(0), 0, 10);
    }

    function testMint() public {
        switchSigner(A);
        nft.safeMint(A, 1);
        switchSigner(B);
        vm.expectRevert();
        _auction.CreateAuction(address(nft), 0, 1);
    }

    function testbiddertoken() public {
        vm.expectRevert("You dont have enough AUCTokens");
        _auction.bid(0, 10);
    }

    function testStatus() public {
        switchSigner(A);
        Auction.AuctionDetails storage auc = ds.OwnerAuctionItem[A];
        assertEq(auc.status, false);
    }

    function testPriceBefore() public {
        Auction.AuctionDetails storage auc = ds.OwnerAuctionItem[A];
        assertEq(auc.price, 0);
    }

    function testCreateAuctionaAndBid() public {
        switchSigner(A);
        nft.safeMint(A, 1);
        IERC721(address(nft)).approve(address(diamond), 1);
        _auction.CreateAuction(address(nft), 1, 20);

        switchSigner(B);
        auctionF.approve(address(diamond), 20);

        _auction.bid(1, 20);
    }

    function testSellerIsNFTOwner() public {
        switchSigner(A);
        nft.safeMint(A, 1);
        IERC721(address(nft)).approve(address(diamond), 1);
        _auction.CreateAuction(address(nft), 1, 20);
        Auction.AuctionDetails storage auc = ds.OwnerAuctionItem[A];
        assertEq(auc.NFTowner, _auction.getSeller(0));
    }

    function testbidderCantTwice() public {
        switchSigner(A);
        nft.safeMint(A, 1);
        IERC721(address(nft)).approve(address(diamond), 1);
        _auction.CreateAuction(address(nft), 1, 20);
        switchSigner(B);
        auctionF.approve(address(diamond), 20);

        _auction.bid(1, 20);
        assertEq(0, ds.bids[B][1]);
    }

    function testHighestBidderBeforeBid() public {
        switchSigner(A);
        nft.safeMint(A, 1);
        IERC721(address(nft)).approve(address(diamond), 1);
        _auction.CreateAuction(address(nft), 1, 20);
        switchSigner(B);
        auctionF.approve(address(diamond), 20);

        _auction.bid(1, 20);
        Auction.NFTSToAuction storage n = ds.TobeAuctioned[1];

        assertEq(n.highestBidder, address(0));
    }

    function testContractID() public {
        Auction.AuctionDetails storage auc = ds.OwnerAuctionItem[address(nft)];
          assertEq(auc.tokenID, 0);

    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
