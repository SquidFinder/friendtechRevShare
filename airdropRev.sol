// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface FriendtechSharesV1 {
    function sharesSupply(address friendTechSubject) external view returns(uint256);

    function sharesBalance(address friendTechSubject, address user) external view returns(uint256);

}

contract OnChainWhitelistContract is Ownable {

    //FriendtechSharesV1 immutable friendTech = FriendtechSharesV1(0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4);
    FriendtechSharesV1 immutable friendTech = FriendtechSharesV1(0x473327ee9C9c7cF4144db5FbBEaAA173C7EDdb6a);
    address public friendTechSubject; 

    uint256 public supply;
    uint256 internal round;
    uint256 public uniqueHolders;
    address internal token;

    mapping(address => bool) public whitelist;
    //Balance reflects the holders balance at the time of the last snapshot.
    mapping(address => uint256) public holderBalance;
    mapping(uint256 => uint256) internal roundBalance;
    mapping(uint256 => uint256) internal dropCount;

        //0x875D6ec5C6293B12BD391CCE7faaF9F5df37afFC
    constructor(address _friendTechSubject){
        friendTechSubject = _friendTechSubject;
    }

    function updateRewardsToken(address _token) public onlyOwner {
        token = _token;
    }

    function getSharesSupply() internal returns (uint256) {
        supply = friendTech.sharesSupply(friendTechSubject);
        return supply;
    }

    function getShareCount(address user) internal view returns (uint256) {
        return friendTech.sharesBalance(friendTechSubject, user);
    }

    /**
     * @notice Add to whitelist
     */
    function addToWhitelist(address[] calldata toAddAddresses) 
    external onlyOwner
    {
        if(roundBalance[round] == 0) {
            calculateAirdropAmount();
        }

        for (uint i = 0; i < toAddAddresses.length; i++) {
            uint256 userBalance = getShareCount(toAddAddresses[i]);
            if(userBalance > 0) {
                whitelist[toAddAddresses[i]] = true;
                holderBalance[toAddAddresses[i]] = userBalance;
                uniqueHolders += 1;
            } 

            if(userBalance == 0 && whitelist[toAddAddresses[i]] == true) {
                delete whitelist[toAddAddresses[i]];
                holderBalance[toAddAddresses[i]] = userBalance;
                uniqueHolders -= 1;
            }
        }
    }

    /**
     * @notice Remove from whitelist
     */
    function removeFromWhitelist(address[] calldata toRemoveAddresses)
    external onlyOwner
    {
        for (uint i = 0; i < toRemoveAddresses.length; i++) {
            uint256 userBalance = getShareCount(toRemoveAddresses[i]);
            delete whitelist[toRemoveAddresses[i]];
            holderBalance[toRemoveAddresses[i]] = userBalance;
            uniqueHolders -= 1;
        }
    }

    function calculateAirdropAmount() internal {
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        roundBalance[round] = contractBalance / getSharesSupply();
    }
 
    function airdropTowhitelist(address[] calldata toAddresses) external
    {
        for (uint i = 0; i < toAddresses.length; i++) {
            if(whitelist[toAddresses[i]]) {
                IERC20(token).transfer(toAddresses[i], roundBalance[round]);
                dropCount[round] += 1;
            }
            if(uniqueHolders <= dropCount[round]) {
                round += 1;
            } 
        }
    }
}
