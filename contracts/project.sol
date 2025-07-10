// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SubscriptionPlatform {
    address public owner;
    uint256 public subscriptionFee;
    mapping(address => uint256) public subscribers;

    event Subscribed(address indexed user, uint256 expiry);
    event Unsubscribed(address indexed user);

    constructor(uint256 _fee) {
        owner = msg.sender;
        subscriptionFee = _fee;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlySubscriber() {
        require(subscribers[msg.sender] >= block.timestamp, "Not a valid subscriber");
        _;
    }

    function subscribe() public payable {
        require(msg.value == subscriptionFee, "Incorrect subscription fee");
        if (subscribers[msg.sender] < block.timestamp) {
            subscribers[msg.sender] = block.timestamp + 30 days;
        } else {
            subscribers[msg.sender] += 30 days;
        }
        emit Subscribed(msg.sender, subscribers[msg.sender]);
    }

    function unsubscribe() public onlySubscriber {
        subscribers[msg.sender] = 0;
        emit Unsubscribed(msg.sender);
    }

    function updateFee(uint256 _newFee) public onlyOwner {
        subscriptionFee = _newFee;
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
