// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

// Returns random number between 1 and 4 included.
contract RandomNumbers{
    function random() public view returns(uint){
        uint randomNum = uint(keccak256(abi.encodePacked(block.timestamp,block.difficulty,  
        msg.sender))) % 5;

        if(randomNum <= 0) {
            randomNum = 2;
        }

        return randomNum;
    }
}