// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface FriendtechSharesV1 {
    function sharesSupply(address friendTechSubject) external view returns(uint256);

    function sharesBalance(address friendTechSubject, address user) external view returns(uint256);

}

/*
    Balance must be added to contract prior to executing the addToWhitelist function 
    which is a snapshot function based on freindtech.share holder balance
    calling the sharesBalance() from the friendtech.share contract.
*/

contract OnChainWhitelistContract is Ownable {

    //FriendtechSharesV1 immutable friendTech = FriendtechSharesV1(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);
    FriendtechSharesV1 immutable friendTech = FriendtechSharesV1(0x473327ee9C9c7cF4144db5FbBEaAA173C7EDdb6a);
    address public friendTechSubject; 

    uint256 public round;
    address public token;

        //All mappings are called by [round] as the first parameter.   [round][address] => whitelist
    mapping(uint256 => mapping(address => bool)) public whitelist;
        //holders balance at the time of the last snapshot. [round][address] => holderBalance 
    mapping(uint256 => mapping(address => uint256)) internal holderBalance;
        //decided amount per share at the time of snapshot [round] => roundBalance 
    mapping(uint256 => uint256) internal roundBalance;
        //calculates airdrop amount for round depending on holderBalance [round][address] => airdropValue;
    mapping(uint256 => mapping(address => uint256)) public airdropValue;
        //holders count of shares at the time of snapshot [round] => holderCount
    mapping(uint256 => uint256) internal holderCount;
        //tracks the number of completed airdrops [round] => dropCount
    mapping(uint256 => uint256) internal dropCount;
        //tracks if airdrop has been completed in a round to a specific address
    mapping(uint256 => mapping(address => bool)) public airdropToUserStatus;

        //0x875D6ec5C6293B12BD391CCE7faaF9F5df37afFC
    constructor(address _friendTechSubject){
        friendTechSubject = _friendTechSubject;
        token = 0x5104d35A6dE00b19cd5BD0649e3c31c7469fbF1A;
    }
        //@FinderSquid on X
    function updateRewardsToken(address _token) public onlyOwner {
        token = _token;
    }

    function updateSubject(address _friendTechSubject) public onlyOwner {
        friendTechSubject = _friendTechSubject;
    }

    function rewardsTokenBalance() public view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getSharesSupply() public view returns (uint256) {
        return friendTech.sharesSupply(friendTechSubject);
    }

    function getShareCount(address user) public view returns (uint256) {
        return friendTech.sharesBalance(friendTechSubject, user);
    }

    /**
     * @notice Add to whitelist
     */
    function addToWhitelist(address[] calldata toAddAddresses) 
    external onlyOwner
    {
        require(IERC20(token).balanceOf(address(this)) > 0, "Balance of this address is 0.");
        
        if(roundBalance[round] == 0) {
            calculateAirdropAmount();
        }

        for (uint i = 0; i < toAddAddresses.length; i++) {
            uint256 userBalance = getShareCount(toAddAddresses[i]);
            if(userBalance > 0 && whitelist[round][toAddAddresses[i]] == false) {
                whitelist[round][toAddAddresses[i]] = true;
                holderCount[round] += 1;
            } 

            if(userBalance == 0 && whitelist[round][toAddAddresses[i]] == true) {
                delete whitelist[round][toAddAddresses[i]];
                holderCount[round] -= 1;
            }

            holderBalance[round][toAddAddresses[i]] = userBalance;
            airdropValue[round][toAddAddresses[i]] = roundBalance[round] * userBalance;
        }
    }

    //@FinderSquid on X

    /**
     * @notice Remove from whitelist
     */
    function removeFromWhitelist(address[] calldata toRemoveAddresses)
    external onlyOwner
    {
        for (uint i = 0; i < toRemoveAddresses.length; i++) {
            uint256 userBalance = getShareCount(toRemoveAddresses[i]);
            if(whitelist[round][toRemoveAddresses[i]] == true) {
                delete whitelist[round][toRemoveAddresses[i]];
                holderBalance[round][toRemoveAddresses[i]] = userBalance;
                holderCount[round] -= 1;
            }
        }
    }

    function calculateAirdropAmount() internal {
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        roundBalance[round] = contractBalance / getSharesSupply();
    }
 
    function airdropTowhitelist(address[] calldata toAddresses) external
    {
        for (uint i = 0; i < toAddresses.length; i++) {
            if(whitelist[round][toAddresses[i]]) {
                if(!airdropToUserStatus[round][toAddresses[i]]){
                    airdropToUserStatus[round][toAddresses[i]] = true;
                    dropCount[round] += 1;
                    uint256 amount = airdropValue[round][toAddresses[i]];
                    IERC20(token).transfer(toAddresses[i], amount);
                }
            }
        }
        if(holderCount[round] <= dropCount[round]) {
                round += 1;
        } 
    }
}
