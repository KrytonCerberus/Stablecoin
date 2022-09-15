// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract UserMessage {
  string message;
  constructor(string memory _message){
     message = _message;
  }
}

contract DeployUserMessage {
  
  UserMessage public childContract;

  function Deploy(string memory message) public {
    childContract = new UserMessage(message);
    
  }
}