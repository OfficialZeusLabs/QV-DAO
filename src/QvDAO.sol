// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "./interfaces/QvInterface.sol";

contract QuadraticVotingDAO {
    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        uint256 creationTimestamp; // Add a timestamp to track proposal creation time
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    QvInterface public qv;
    uint256 public votingPeriod = 7 days; // Set the voting period (adjust as needed)

    constructor(address _qvAddress) {
        qv = QvInterface(_qvAddress);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public returns (uint256 proposalId) {
        proposalId = qv.propose(targets, values, calldatas, bytes32ToString(descriptionHash));
        proposals[proposalId] = Proposal({
            targets: targets,
            values: values,
            calldatas: calldatas,
            descriptionHash: descriptionHash,
            yesVotes: 0,
            noVotes: 0,
            executed: false,
            creationTimestamp: block.timestamp
        });
    }

    function castVote(uint256 proposalId, uint8 support) public returns (uint256 balance) {
        require(!voted[proposalId][msg.sender], "Already voted");
        
        uint256 votes = qv.getVotes(msg.sender, block.timestamp);
        
        if (support == 1) {
            proposals[proposalId].yesVotes += sqrt(votes);
        } else {
            proposals[proposalId].noVotes += sqrt(votes);
        }
        
        voted[proposalId][msg.sender] = true;
        return votes;
    }

    function execute(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp > proposal.creationTimestamp + votingPeriod, "Voting period not over yet");
        require(proposal.yesVotes > proposal.noVotes, "Proposal failed");

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "Action execution failed");
        }

        proposal.executed = true;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function bytes32ToString(bytes32 data) internal pure returns (string memory) {
        bytes memory bytesData = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            bytesData[i] = data[i];
        }
        return string(bytesData);
    }
}
