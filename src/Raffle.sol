// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Raffle
 * @author Kellspell
 * @notice This contract is to create a simple Raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {

    // Errors Section
    error Raffle_NotEnoughEthSent();
    error Raffle_TranferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numParticipants,
        uint256 RaffleState
    );

    /** Type Desclaretions  */
    enum RaffleState {
        OPEN,
        CALCULATING,
        Finished
    }
     
    // State Variables
    uint256 private immutable i_entranceFee;

    //@dev Duration of the lotterry in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    // VRF Coordinator Address
    VRFCoordinatorV2Interface private i_vrfCoordinator;

    // Gas Lane 
    bytes32 private  i_gasLane;

    // SubscriptionId
    uint64 private i_subscriptionId;

    // RequestConfirmations -> here we set nthe number of conformations we expect
    uint16 private constant CONFIRMATIONS_REQUEST = 3;

    // Numbers of Words
    uint32 private constant NUM_WORDS = 1 ;

    // CallbackGasLimit
    uint32 private  i_callbackGasLimit;

    // Array bellow is to keep track of the participants , the address must be payable in order to be able  to pay the participants
    address payable[] private s_participants;

    // Picking the winner
    address private s_participantsWinner;

    // RaffleState
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEvent(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);
    

    constructor(uint256 entranceFee, uint256 interval, address VRFCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)VRFConsumerBaseV2(VRFCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(VRFCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp; 
        s_raffleState = RaffleState.OPEN;
        
        
    }

    function enterRaffle() external payable {
        //require (msg.value >= i_entranceFee, "Raffle: You must pay enough");
        // We could use the line above but the block of code below is more gas efficient
        if(msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
        revert Raffle_RaffleNotOpen();
    }
        s_participants.push(payable(msg.sender));
        emit RaffleEvent(msg.sender);

    }

    // Here we'll make a function that will use cron jobs 
    /**
    * @dev This is the function that the Chainlink Automation node call
    * to see if its time to perform an upKeep.
    * The folloewing should be true for this to return true:
    * 1. The time interval has passed between the raffle runs
    * 2. The Raffle State is OPEN
    * 3. The contract has ETH (aka, players)
    * 4. (Implicit) The subscriptionId is funded with LINK
    * @return upKeepNeeded
   */
    function checkUpKeep(bytes memory /* checkData*/) public view returns (bool upKeepNeeded, bytes memory /* performData */) {
        // 1. The time interval has passed between the raffle runs
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        // 2. The Raffle State is OPEN
        bool isOpen = RaffleState.OPEN == s_raffleState;
        // 3. The contract has ETH (aka, participants)
        bool hasBalance = address(this).balance> 0;
        bool hasPlayers = s_participants.length > 0;
        // 4. (Implicit) The subscriptionId is funded with LINK
        bool hasSubscriptionId = i_subscriptionId > 0;
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers && hasSubscriptionId);
        return (upKeepNeeded, "0x0");
    }
          

    function performUpkeep(bytes calldata /* performData */) external { 
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(
                    s_raffleState
                )
            );
        }    
    // Using the Raffle State to check if the Raffle is calculating
    s_raffleState = RaffleState.CALCULATING;
    uint256 requesId = i_vrfCoordinator.requestRandomWords(
        i_gasLane, // gas lane
        i_subscriptionId, //ID from fund with link
        CONFIRMATIONS_REQUEST, // number of confirmations
        i_callbackGasLimit, // callback gas
        NUM_WORDS // number of words
    );
    emit RequestedRaffleWinner(requesId);
    }

    function fulfillRandomWords(
        uint256 /**requestId*/,
        uint256[] memory randomWords
    )internal override {
        uint256 indexOfWinner = randomWords[0] % s_participants.length;
        address payable winner = s_participants[indexOfWinner];
        s_participantsWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = winner.call{value: address(this).balance} ("");
        if (!success) {
            revert Raffle_TranferFailed ();
    }
    emit PickedWinner(winner);
         
    }

    /** Getter Function */
    function getentranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
        
    }


    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

}