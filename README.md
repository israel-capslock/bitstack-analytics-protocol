# Bitstack Analytics Protocol - Smart Contract Documentation

## Introduction

Bitstack Analytics Protocol is a decentralized data intelligence platform that transforms raw blockchain data into institutional-grade analytics through community-governed mechanisms. This smart contract implements the core protocol logic for staking, governance, and reward distribution.

## Protocol Highlights

- **Decentralized Governance**: Stake-weighted voting system for protocol evolution
- **Tiered Staking System**: Three-tier structure with escalating privileges
- **Dynamic Rewards**: Time-locked bonuses + activity-based multipliers
- **Institutional-Grade Security**: Emergency protocols + graduated cooldowns
- **Transparent Economics**: On-chain reward calculation + real-time analytics

## Core Components

### 1. ANALYTICS-TOKEN Economy

- Native ERC-20 compatible utility token
- Functions: Governance rights, fee payments, staking collateral
- Minting: Algorithmically controlled via staking rewards

### 2. Tiered Staking Architecture

| Tier     | Minimum STX | Multiplier | Features Enabled          |
| -------- | ----------- | ---------- | ------------------------- |
| Silver   | 1M          | 1x         | Basic analytics access    |
| Gold     | 5M          | 1.5x       | Advanced metrics          |
| Platinum | 10M         | 2x         | Institutional tools + API |

### 3. Governance Engine

- Proposal lifecycle management
- Quadratic voting with stake-weighted influence
- Automated proposal execution system

### 4. Adaptive Reward System

- Base APR: 5% (adjustable via governance)
- Time-lock bonuses (up to +50%)
- Activity multipliers (up to 2x)

## Smart Contract Functions

### Staking Operations

#### `stake-stx`

```clarity
(define-public (stake-stx (amount uint) (lock-period uint))
```

- **Parameters**:
  - `amount`: STX amount in microSTX (1 STX = 1,000,000 µSTX)
  - `lock-period`: 0 (none), 4320 (30d), 8640 (60d)
- **Actions**:
  - Transfers STX to contract custody
  - Updates user tier status
  - Applies time-lock multiplier
  - Resets cooldown timer

#### `initiate-unstake`

```clarity
(define-public (initiate-unstake (amount uint))
```

- Starts 24h cooldown period
- Partial unstaking supported
- Maintains rewards eligibility during cooldown

### Governance Functions

#### `create-proposal`

```clarity
(define-public (create-proposal (description (string-utf8 256)) (voting-period uint))
```

- **Requirements**:
  - Minimum 1M voting power
  - Description: 10-256 UTF-8 characters
  - Voting period: 100-2880 blocks

#### `vote-on-proposal`

```clarity
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
```

- Vote weight = `voting-power` from UserPositions
- Votes cannot be changed once cast
- Requires active staking position

### Administrative Controls

#### Emergency Protocol

```clarity
(define-public (pause-contract))
(define-public (resume-contract))
```

- Multi-sig protected functions
- Halts all non-governance activity
- Preserves existing positions

## Reward Calculation

### Formula

```
Rewards = (Staked Amount × Base Rate × Multiplier × Blocks Staked) / 1,440,000
```

- **Base Rate**: Variable (default 5% APR)
- **Multiplier**: Tier + Time-Lock bonuses
- **Blocks**: Duration since last claim

### Example Calculation

- 10M STX staked (Platinum tier)
- 60-day time lock (1.5x)
- 30-day staking period

```
(10,000,000 × 500 × 300 × 4320) / 1,440,000 = 45,000,000 µSTX (45 STX)
```

## Security Features

### 1. Cooldown System

- 24h withdrawal delay after initiation
- Prevents flash loan attacks
- Allows system stress testing

### 2. Tiered Safeguards

```clarity
(define-map TierLevels
    uint
    {
        features-enabled: (list 10 bool)
    }
)
```

- Progressive feature unlocking
- Risk isolation between tiers
- Graduated access controls

### 3. Governance Checks

- Minimum 1M STX voting threshold
- 24h-48h voting windows
- Multi-sig execution requirements

## Error Reference

| Code     | Description             | Resolution                    |
| -------- | ----------------------- | ----------------------------- |
| ERR-1000 | Unauthorized access     | Verify sender permissions     |
| ERR-1001 | Invalid parameter       | Check input constraints       |
| ERR-1002 | Incorrect amount        | Validate quantity             |
| ERR-1003 | Insufficient balance    | Add funds to wallet           |
| ERR-1004 | Cooldown active         | Wait 24h or cancel withdrawal |
| ERR-1005 | No staking position     | Initiate stake first          |
| ERR-1006 | Below minimum threshold | Meet tier requirements        |
| ERR-1007 | Protocol paused         | Wait for admin resolution     |

## Development Guide

### Requirements

- Clarinet SDK v1.5.0+
- Node.js 18.x
- Stacks.js libraries

### Deployment Checklist

1. Verify multi-sig configuration
2. Initialize tier parameters
3. Set base reward rate
4. Deploy ANALYTICS-TOKEN contract
5. Configure governance thresholds
