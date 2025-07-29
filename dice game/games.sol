// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CasinoDice
 * @dev A decentralized casino dice game smart contract
 * @author Your Name
 */
contract CasinoDice {
    address public owner;
    uint256 public houseEdge = 2; // 2% house edge
    uint256 public minBet = 0.01 ether;
    uint256 public maxBet = 1 ether;
    uint256 private nonce;
    
    struct Game {
        address player;
        uint256 betAmount;
        uint256 prediction;
        uint256 result;
        bool isWinner;
        uint256 payout;
        uint256 timestamp;
    }
    
    mapping(address => uint256) public playerBalance;
    mapping(address => Game[]) public playerGames;
    Game[] public allGames;
    
    event GamePlayed(
        address indexed player,
        uint256 betAmount,
        uint256 prediction,
        uint256 result,
        bool isWinner,
        uint256 payout,
        uint256 timestamp
    );
    
    event Deposit(address indexed player, uint256 amount);
    event Withdrawal(address indexed player, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validBet(uint256 _betAmount) {
        require(_betAmount >= minBet && _betAmount <= maxBet, "Invalid bet amount");
        require(playerBalance[msg.sender] >= _betAmount, "Insufficient balance");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Allows players to deposit ETH to their casino balance
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        playerBalance[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Allows players to withdraw their balance
     * @param _amount Amount to withdraw in wei
     */
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(playerBalance[msg.sender] >= _amount, "Insufficient balance");
        require(address(this).balance >= _amount, "Contract has insufficient funds");
        
        playerBalance[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }
    
    /**
     * @dev Main dice game function - players predict if dice roll will be higher than their prediction
     * @param _prediction Player's prediction (1-5, where they win if dice roll is higher)
     * @param _betAmount Amount to bet in wei
     */
    function playDice(uint256 _prediction, uint256 _betAmount) 
        external 
        validBet(_betAmount) 
        returns (uint256 result, bool isWinner, uint256 payout) 
    {
        require(_prediction >= 1 && _prediction <= 5, "Prediction must be between 1 and 5");
        
        // Deduct bet from player balance
        playerBalance[msg.sender] -= _betAmount;
        
        // Generate pseudo-random number (1-6)
        result = _generateRandomNumber() % 6 + 1;
        
        // Check if player wins (dice result > prediction)
        isWinner = result > _prediction;
        
        // Calculate payout
        if (isWinner) {
            // Payout based on probability and house edge
            uint256 winChance = (6 - _prediction) * 100 / 6; // Winning percentage
            uint256 multiplier = (10000 - houseEdge * 100) / winChance; // Adjusted for house edge
            payout = (_betAmount * multiplier) / 100;
            playerBalance[msg.sender] += payout;
        } else {
            payout = 0;
        }
        
        // Record the game
        Game memory newGame = Game({
            player: msg.sender,
            betAmount: _betAmount,
            prediction: _prediction,
            result: result,
            isWinner: isWinner,
            payout: payout,
            timestamp: block.timestamp
        });
        
        playerGames[msg.sender].push(newGame);
        allGames.push(newGame);
        
        emit GamePlayed(msg.sender, _betAmount, _prediction, result, isWinner, payout, block.timestamp);
        
        return (result, isWinner, payout);
    }
    
    /**
     * @dev Get player's game history
     * @param _player Address of the player
     * @return Array of games played by the player
     */
    function getPlayerGames(address _player) external view returns (Game[] memory) {
        return playerGames[_player];
    }
    
    /**
     * @dev Get contract statistics
     * @return totalGames Total number of games played
     * @return contractBalance Current contract balance
     * @return totalPlayers Number of unique players
     */
    function getContractStats() external view returns (
        uint256 totalGames,
        uint256 contractBalance,
        uint256 totalPlayers
    ) {
        totalGames = allGames.length;
        contractBalance = address(this).balance;
        
        // Count unique players (simplified version)
        totalPlayers = 0;
        address[] memory uniquePlayers = new address[](allGames.length);
        
        for (uint256 i = 0; i < allGames.length; i++) {
            bool isNewPlayer = true;
            for (uint256 j = 0; j < totalPlayers; j++) {
                if (uniquePlayers[j] == allGames[i].player) {
                    isNewPlayer = false;
                    break;
                }
            }
            if (isNewPlayer) {
                uniquePlayers[totalPlayers] = allGames[i].player;
                totalPlayers++;
            }
        }
    }
    
    /**
     * @dev Generate pseudo-random number (Note: Not truly random, suitable for demo purposes only)
     * @return Random number
     */
    function _generateRandomNumber() private returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            nonce
        )));
    }
    
    // Owner functions
    function setHouseEdge(uint256 _houseEdge) external onlyOwner {
        require(_houseEdge <= 10, "House edge cannot exceed 10%");
        houseEdge = _houseEdge;
    }
    
    function setBetLimits(uint256 _minBet, uint256 _maxBet) external onlyOwner {
        require(_minBet < _maxBet, "Min bet must be less than max bet");
        minBet = _minBet;
        maxBet = _maxBet;
    }
    
    function ownerWithdraw(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        payable(owner).transfer(_amount);
    }
    
    // Fallback function to receive ETH
    receive() external payable {
        playerBalance[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
