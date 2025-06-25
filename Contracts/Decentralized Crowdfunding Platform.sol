// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Project {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool completed;
        bool withdrawn;
    }
    
    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    uint256 public campaignCounter;
    uint256 public platformFeePercent = 2; // 2% platform fee
    address payable public platformOwner;
    
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    modifier onlyCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator can perform this action");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].completed, "Campaign already completed");
        _;
    }
    
    constructor() {
        platformOwner = payable(msg.sender);
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Title of the campaign
     * @param _description Description of the campaign
     * @param _goalAmount Target amount to raise (in wei)
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        campaigns[campaignCounter] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            completed: false,
            withdrawn: false
        });
        
        emit CampaignCreated(campaignCounter, msg.sender, _title, _goalAmount, deadline);
        campaignCounter++;
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        campaign.raisedAmount += msg.value;
        contributorAmounts[_campaignId][msg.sender] += msg.value;
        
        campaignContributions[_campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        // Mark campaign as completed if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.completed = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds from a successful campaign
     * @param _campaignId ID of the campaign to withdraw from
     */
    function withdrawFunds(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
        onlyCreator(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(campaign.completed || block.timestamp >= campaign.deadline, "Campaign not yet eligible for withdrawal");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.raisedAmount > 0, "No funds to withdraw");
        
        campaign.withdrawn = true;
        
        uint256 platformFee = (campaign.raisedAmount * platformFeePercent) / 100;
        uint256 creatorAmount = campaign.raisedAmount - platformFee;
        
        // Transfer platform fee
        if (platformFee > 0) {
            platformOwner.transfer(platformFee);
        }
        
        // Transfer remaining amount to creator
        campaign.creator.transfer(creatorAmount);
        
        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }
    
    /**
     * @dev Get campaign details
     * @param _campaignId ID of the campaign
     */
    function getCampaign(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool completed,
            bool withdrawn
        ) 
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.completed,
            campaign.withdrawn
        );
    }
    
    /**
     * @dev Get contribution history for a campaign
     * @param _campaignId ID of the campaign
     */
    function getCampaignContributions(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (Contribution[] memory) 
    {
        return campaignContributions[_campaignId];
    }
    
    /**
     * @dev Get contributor's total contribution to a campaign
     * @param _campaignId ID of the campaign
     * @param _contributor Address of the contributor
     */
    function getContributorAmount(uint256 _campaignId, address _contributor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return contributorAmounts[_campaignId][_contributor];
    }
    
    /**
     * @dev Get total number of campaigns
     */
    function getTotalCampaigns() external view returns (uint256) {
        return campaignCounter;
    }
    
    /**
     * @dev Emergency function to update platform fee (only owner)
     */
    function updatePlatformFee(uint256 _newFeePercent) external {
        require(msg.sender == platformOwner, "Only platform owner can update fee");
        require(_newFeePercent <= 10, "Fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
    }
}
