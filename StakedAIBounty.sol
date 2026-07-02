// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract StakedAIBounty {
    struct Challenge {
        address owner;
        string prompt;
        uint256 reward;
        uint256 commitDeadline;
        uint256 revealDeadline;
        bool judged;
        bool finalized;
        address winner;
        string[] answers;
        address[] participants;
        mapping(address => bytes32) commitments;
        mapping(address => bool) hasRevealed;
        mapping(address => uint256) answerIndex;
        mapping(address => uint256) stakes;
        mapping(address => bool) isParticipant;
        uint256 minStake;
    }

    struct ChallengeInfo {
        address owner;
        string prompt;
        uint256 reward;
        uint256 commitDeadline;
        uint256 revealDeadline;
        bool judged;
        bool finalized;
        address winner;
        uint256 participantCount;
        uint256 answerCount;
        uint256 minStake;
    }

    uint256 public challengeCounter;
    mapping(uint256 => Challenge) public challenges;

    event ChallengeCreated(uint256 indexed id, address indexed owner, uint256 reward);
    event CommitmentSubmitted(uint256 indexed id, address indexed participant, uint256 stake);
    event AnswerRevealed(uint256 indexed id, address indexed participant, string answer);
    event Judged(uint256 indexed id, uint256 answerCount);
    event WinnerFinalized(uint256 indexed id, address indexed winner);
    event StakeRefunded(uint256 indexed id, address indexed participant, uint256 amount);
    event StakeSlashed(uint256 indexed id, address indexed participant, uint256 amount);

    modifier challengeExists(uint256 id) {
        require(challenges[id].owner != address(0), "Challenge does not exist");
        _;
    }

    modifier onlyCommitPhase(uint256 id) {
        require(block.timestamp <= challenges[id].commitDeadline, "Commit phase ended");
        _;
    }

    modifier onlyRevealPhase(uint256 id) {
        require(block.timestamp > challenges[id].commitDeadline, "Not reveal phase");
        require(block.timestamp <= challenges[id].revealDeadline, "Reveal phase ended");
        _;
    }

    modifier onlyAfterReveal(uint256 id) {
        require(block.timestamp > challenges[id].revealDeadline, "Reveal phase not over");
        _;
    }

    modifier onlyChallengeOwner(uint256 id) {
        require(msg.sender == challenges[id].owner, "Not challenge owner");
        _;
    }

    modifier notJudged(uint256 id) {
        require(!challenges[id].judged, "Already judged");
        _;
    }

    modifier notFinalized(uint256 id) {
        require(!challenges[id].finalized, "Already finalized");
        _;
    }

    function createChallenge(
        string calldata prompt,
        uint256 commitDeadline,
        uint256 revealDuration,
        uint256 minStake
    ) external payable {
        require(msg.value > 0, "Reward must be > 0 RIT");
        require(commitDeadline > block.timestamp, "Deadline must be in future");
        require(revealDuration > 0, "Reveal duration must be > 0");
        require(minStake > 0, "Minimum stake must be > 0");

        uint256 id = challengeCounter++;
        Challenge storage c = challenges[id];
        c.owner = msg.sender;
        c.prompt = prompt;
        c.reward = msg.value;
        c.commitDeadline = commitDeadline;
        c.revealDeadline = commitDeadline + revealDuration;
        c.minStake = minStake;

        emit ChallengeCreated(id, msg.sender, msg.value);
    }

    function commitSolution(uint256 id, bytes32 commitment) external payable 
        challengeExists(id)
        onlyCommitPhase(id)
    {
        Challenge storage c = challenges[id];
        require(c.commitments[msg.sender] == 0, "Already committed");
        require(msg.value >= c.minStake, "Stake too low");

        c.commitments[msg.sender] = commitment;
        c.participants.push(msg.sender);
        c.isParticipant[msg.sender] = true;
        c.stakes[msg.sender] = msg.value;

        emit CommitmentSubmitted(id, msg.sender, msg.value);
    }

    function revealSolution(
        uint256 id,
        string calldata answer,
        bytes32 salt
    ) external 
        challengeExists(id)
        onlyRevealPhase(id)
    {
        Challenge storage c = challenges[id];
        bytes32 commitment = c.commitments[msg.sender];
        require(commitment != 0, "No commitment found");
        require(!c.hasRevealed[msg.sender], "Already revealed");

        bytes32 computed = keccak256(abi.encodePacked(answer, salt, msg.sender, id));
        require(computed == commitment, "Commitment mismatch");

        c.hasRevealed[msg.sender] = true;
        c.answerIndex[msg.sender] = c.answers.length;
        c.answers.push(answer);

        uint256 stake = c.stakes[msg.sender];
        c.stakes[msg.sender] = 0;
        payable(msg.sender).transfer(stake);
        emit StakeRefunded(id, msg.sender, stake);

        emit AnswerRevealed(id, msg.sender, answer);
    }

    function judgeAll(uint256 id, bytes calldata _llmInput) external 
        challengeExists(id)
        onlyChallengeOwner(id)
        onlyAfterReveal(id)
        notJudged(id)
    {
        Challenge storage c = challenges[id];
        require(c.answers.length > 0, "No revealed answers");

        c.judged = true;
        emit Judged(id, c.answers.length);
    }

    function finalizeWinner(uint256 id, uint256 winnerIndex) external 
        challengeExists(id)
        onlyChallengeOwner(id)
        onlyAfterReveal(id)
        notFinalized(id)
    {
        Challenge storage c = challenges[id];
        require(c.judged, "Must judge first");
        require(winnerIndex < c.answers.length, "Invalid winner index");

        c.finalized = true;
        c.winner = c.participants[winnerIndex];

        for (uint i = 0; i < c.participants.length; i++) {
            address participant = c.participants[i];
            if (participant != c.winner && c.stakes[participant] > 0) {
                uint256 slashed = c.stakes[participant];
                c.stakes[participant] = 0;
                payable(c.owner).transfer(slashed);
                emit StakeSlashed(id, participant, slashed);
            }
        }

        payable(c.winner).transfer(c.reward);

        emit WinnerFinalized(id, c.winner);
    }

    function getChallengeInfo(uint256 id) external view returns (ChallengeInfo memory) {
        Challenge storage c = challenges[id];
        return ChallengeInfo({
            owner: c.owner,
            prompt: c.prompt,
            reward: c.reward,
            commitDeadline: c.commitDeadline,
            revealDeadline: c.revealDeadline,
            judged: c.judged,
            finalized: c.finalized,
            winner: c.winner,
            participantCount: c.participants.length,
            answerCount: c.answers.length,
            minStake: c.minStake
        });
    }

    function getAnswers(uint256 id) external view returns (string[] memory) {
        require(msg.sender == challenges[id].owner || challenges[id].finalized, "Not authorized");
        return challenges[id].answers;
    }

    function hasCommitted(uint256 id, address participant) external view returns (bool) {
        return challenges[id].commitments[participant] != 0;
    }

    function hasRevealed(uint256 id, address participant) external view returns (bool) {
        return challenges[id].hasRevealed[participant];
    }
}
