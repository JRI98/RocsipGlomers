# RocsipGlomers

[Gossip Glomers](https://fly.io/dist-sys/) distributed systems challenges implemented in [Roc](https://www.roc-lang.org/) and evaluated with [Maelstrom](https://github.com/jepsen-io/maelstrom).

## Setup

```bash
curl -L -O https://github.com/jepsen-io/maelstrom/releases/download/v0.2.4/maelstrom.tar.bz2
tar -xf maelstrom.tar.bz2 && rm maelstrom.tar.bz2
```

**Prerequisites**: [Roc](https://www.roc-lang.org/install) and Java 11+ (required by Maelstrom).

## Challenges

| Challenge | Workload | Command | Status |
| :--- | :--- | :--- | :---: |
| [1. Echo](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge1.roc) | `echo` | `make challenge1` | Passed |
| [2. Unique ID Generation](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge2.roc) | `unique-ids` | `make challenge2` | Passed |
| [3a. Broadcast (Single-Node)](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge3a.roc) | `broadcast` | `make challenge3a` | Passed |
| [3b. Broadcast (Multi-Node)](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge3b.roc) | `broadcast` | `make challenge3b` | Passed |
| [3c. Fault-Tolerant Broadcast](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge3c.roc) | `broadcast` (nemesis partition) | `make challenge3c` | Passed |
| [3d. Efficient Broadcast I](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge3d.roc) | `broadcast` (25 nodes, 100ms latency) | `make challenge3d` | Passed |
| [3e. Efficient Broadcast II](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge3e.roc) | `broadcast` (25 nodes, batched) | `make challenge3e` | Passed |
| [4. Grow-Only Counter](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge4.roc) | `g-counter` (nemesis partition) | `make challenge4` | Passed |
| [5a. Single-Node Kafka-Style Log](file:///Users/joaoimperadeiro/projects/GossipGlomers/roc/challenge5a.roc) | `kafka` | `make challenge5a` | Passed |

## Commands

- `make challengeXX` - Run a specific challenge
- `make all` - Run all completed challenges
- `make fmt` - Format all Roc source files
- `make serve` - Start Maelstrom web UI (`http://localhost:8080`)
