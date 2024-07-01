// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WebSkey is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    uint256 public nextTokenId;

    struct Player {
        string username;
        uint256 highScore;
        mapping(uint256 => bool) unlockedItems;
        uint256[] unlockedItemIds;
    }

    mapping(address => Player) private players;
    address[] private playerAddresses;

    struct LeaderboardEntry {
        address player;
        uint256 highScore;
    }

    LeaderboardEntry[] private leaderboard;

    event HighScoreUpdated(address indexed player, uint256 highScore);
    event ItemUnlocked(address indexed player, uint256 itemId);
    event PlayerRegistered(address indexed player, string username);
    event RewardClaimed(address indexed player, uint256 amount);
    event NFTMinted(address indexed player, uint256 tokenId, string tokenURI);

    constructor() ERC721("WebSkeyNFT", "WSNFT") {}

    function registerPlayer(string calldata _username) external {
        require(bytes(players[msg.sender].username).length == 0, "Player already registered");
        players[msg.sender].username = _username;
        playerAddresses.push(msg.sender);
        emit PlayerRegistered(msg.sender, _username);
    }

    function updateHighScore(uint256 _score) external {
        require(bytes(players[msg.sender].username).length != 0, "Player not registered");
        require(_score > players[msg.sender].highScore, "New score must be higher than the current high score");
        players[msg.sender].highScore = _score;
        _updateLeaderboard(msg.sender, _score);
        emit HighScoreUpdated(msg.sender, _score);
    }

    function getHighScore(address _player) external view returns (uint256) {
        return players[_player].highScore;
    }

    function unlockItem(uint256 _itemId, string memory _tokenURI) external {
        require(bytes(players[msg.sender].username).length != 0, "Player not registered");
        require(!players[msg.sender].unlockedItems[_itemId], "Item already unlocked");
        players[msg.sender].unlockedItems[_itemId] = true;
        players[msg.sender].unlockedItemIds.push(_itemId);
        uint256 newItemId = _mintNFT(msg.sender, _tokenURI);
        emit ItemUnlocked(msg.sender, _itemId);
    }

    function isItemUnlocked(address _player, uint256 _itemId) external view returns (bool) {
        return players[_player].unlockedItems[_itemId];
    }

    function getUnlockedItems(address _player) external view returns (uint256[] memory) {
        return players[_player].unlockedItemIds;
    }

    function claimReward() external {
        require(bytes(players[msg.sender].username).length != 0, "Player not registered");
        uint256 reward = _calculateReward(players[msg.sender].highScore);
        require(reward > 0, "No reward available");
        payable(msg.sender).transfer(reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function _calculateReward(uint256 _highScore) internal pure returns (uint256) {
        // Implement a reward calculation logic based on the high score
        // Example: 1 ether for every 1000 points
        return (_highScore / 1000) * 1 ether;
    }

    function _updateLeaderboard(address _player, uint256 _score) internal {
        bool updated = false;
        for (uint256 i = 0; i < leaderboard.length; i++) {
            if (leaderboard[i].player == _player) {
                leaderboard[i].highScore = _score;
                updated = true;
                break;
            }
        }
        if (!updated) {
            leaderboard.push(LeaderboardEntry({player: _player, highScore: _score}));
        }
        _sortLeaderboard();
    }

    function _sortLeaderboard() internal {
        for (uint256 i = 0; i < leaderboard.length; i++) {
            for (uint256 j = i + 1; j < leaderboard.length; j++) {
                if (leaderboard[j].highScore > leaderboard[i].highScore) {
                    LeaderboardEntry memory temp = leaderboard[i];
                    leaderboard[i] = leaderboard[j];
                    leaderboard[j] = temp;
                }
            }
        }
    }

    function getLeaderboard() external view returns (LeaderboardEntry[] memory) {
        return leaderboard;
    }

    function resetPlayerData(address _player) external onlyOwner {
        delete players[_player];
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}

    function _mintNFT(address _player, string memory _tokenURI) internal returns (uint256) {
        uint256 tokenId = nextTokenId;
        _mint(_player, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        nextTokenId = nextTokenId.add(1);
        emit NFTMinted(_player, tokenId, _tokenURI);
        return tokenId;
    }

    // Override supportsInterface to handle multiple inheritance
    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage) returns (bool) {
        return ERC721URIStorage.supportsInterface(interfaceId);
    }
}

