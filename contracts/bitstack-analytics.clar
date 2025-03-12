;; Title: Bitstack Analytics Protocol: Decentralized Data Intelligence Empowered by Stakeholder Governance
;; 
;; Summary: A groundbreaking DeFi protocol transforming raw blockchain data into actionable intelligence through
;; decentralized governance, multi-tiered staking mechanisms, and fair incentive distribution.
;;
;; Description:
;; Bitstack Analytics revolutionizes on-chain data monetization by creating a transparent ecosystem where:
;; - Analysts and users collaboratively shape protocol evolution through proposal voting
;; - Multi-tier staking rewards long-term participants with escalating benefits
;; - Dynamic reward algorithms automatically adjust based on market conditions and participation
;; - Institutional-grade analytics become accessible through decentralized community efforts
;; - Transparent governance ensures protocol decisions align with stakeholder interests

;; Core Components:
;; 1. ANALYTICS-TOKEN: Native utility token for governance, staking rewards, and protocol fees
;; 2. Tiered Staking System: Three-tier structure (Silver, Gold, Platinum) with escalating privileges
;; 3. Governance Engine: Proposal-based decision making with voting power derived from staked assets
;; 4. Adaptive Rewards: Time-locked staking bonuses and activity-based multiplier systems
;; 5. Safety Mechanisms: Emergency pause functionality and graduated cooldown periods


;; token definitions
(define-fungible-token ANALYTICS-TOKEN u0)

;; PROTOCOL CONSTANTS
(define-constant CONTRACT-OWNER tx-sender) ;; Multisig admin address
(define-constant ERR-NOT-AUTHORIZED (err u1000)) ;; Authorization error code
(define-constant ERR-INVALID-PROTOCOL (err u1001)) ;; Invalid parameter error
(define-constant ERR-INVALID-AMOUNT (err u1002)) ;; Incorrect value error
(define-constant ERR-INSUFFICIENT-STX (err u1003)) ;; Balance insufficiency
(define-constant ERR-COOLDOWN-ACTIVE (err u1004)) ;; Withdrawal timing restriction
(define-constant ERR-NO-STAKE (err u1005)) ;; Missing position error
(define-constant ERR-BELOW-MINIMUM (err u1006)) ;; Minimum threshold violation
(define-constant ERR-PAUSED (err u1007)) ;; Protocol suspension state

;; PROTOCOL STATE VARIABLES
(define-data-var contract-paused bool false) ;; Global pause switch
(define-data-var emergency-mode bool false) ;; Emergency shutdown state
(define-data-var stx-pool uint u0) ;; Total STX liquidity in protocol
(define-data-var base-reward-rate uint u500) ;; 5% base APR (100 = 1%)
(define-data-var bonus-rate uint u100) ;; 1% loyalty bonus
(define-data-var minimum-stake uint u1000000) ;; 1M microSTX minimum
(define-data-var cooldown-period uint u1440) ;; 24h cooldown (1440 blocks)
(define-data-var proposal-count uint u0) ;; Governance proposal counter

;; DATA STRUCTURES

;; Governance Proposals Registry
(define-map Proposals
    { proposal-id: uint }
    {
        creator: principal,          ;; Proposal originator
        description: (string-utf8 256), ;; UTF-8 proposal details
        start-block: uint,          ;; Voting commencement block
        end-block: uint,            ;; Voting termination block
        executed: bool,             ;; Implementation status
        votes-for: uint,             ;; Affirmative votes
        votes-against: uint,         ;; Negative votes
        minimum-votes: uint          ;; Quorum threshold
    }
)

;; User Financial Positions
(define-map UserPositions
    principal  ;; User principal
    {
        total-collateral: uint,     ;; Total deposited assets
        total-debt: uint,           ;; Outstanding obligations
        health-factor: uint,        ;; Risk ratio (collateral/debt)
        last-updated: uint,          ;; Last activity block
        stx-staked: uint,           ;; Total STX committed
        analytics-tokens: uint,     ;; ANALYTICS-TOKEN balance
        voting-power: uint,         ;; Governance influence metric
        tier-level: uint,           ;; Current privilege tier (1-3)
        rewards-multiplier: uint     ;; Active rewards multiplier
    }
)

;; Staking Position Details
(define-map StakingPositions
    principal  ;; User principal
    {
        amount: uint,               ;; STX staked amount
        start-block: uint,          ;; Position creation block
        last-claim: uint,            ;; Last rewards harvest
        lock-period: uint,           ;; Commitment duration
        cooldown-start: (optional uint), ;; Withdrawal initiation time
        accumulated-rewards: uint    ;; Pending rewards balance
    }
)

;; Tier Configuration Matrix
(define-map TierLevels
    uint  ;; Tier ID (1=Silver, 2=Gold, 3=Platinum)
    {
        minimum-stake: uint,         ;; Tier entry threshold
        reward-multiplier: uint,     ;; Base rewards multiplier
        features-enabled: (list 10 bool) ;; Tier-specific features
    }
)

;; PRIVATE UTILITIES

;; Determine user tier based on stake amount
(define-private (get-tier-info (stake-amount uint))
    (if (>= stake-amount u10000000)  ;; Platinum Tier (10M+ STX)
        {tier-level: u3, reward-multiplier: u200}
        (if (>= stake-amount u5000000) ;; Gold Tier (5M+ STX)
            {tier-level: u2, reward-multiplier: u150}
            {tier-level: u1, reward-multiplier: u100} ;; Silver Tier
        )
    )
)

;; Calculate time-lock bonus multiplier
(define-private (calculate-lock-multiplier (lock-period uint))
    (if (>= lock-period u8640)     ;; 60-day lock: 1.5x
        u150                       
        (if (>= lock-period u4320) ;; 30-day lock: 1.25x
            u125                   
            u100                   ;; No lock: 1x
        )
    )
)

;; Reward calculation engine
(define-private (calculate-rewards (user principal) (blocks uint))
    (let (
        (staking-position (unwrap! (map-get? StakingPositions user) u0))
        (user-position (unwrap! (map-get? UserPositions user) u0))
        (stake-amount (get amount staking-position))
        (base-rate (var-get base-reward-rate))
        (multiplier (get rewards-multiplier user-position))
        )
        ;; Formula: (stake * rate * multiplier * blocks) / 1M
        (/ (* (* (* stake-amount base-rate) multiplier) blocks) u14400000)
    )
)

(define-private (is-valid-description (desc (string-utf8 256)))
    (and 
        (>= (len desc) u10)   ;; Minimum description length
        (<= (len desc) u256)  ;; Maximum description length
    )
)

(define-private (is-valid-lock-period (lock-period uint))
    (or 
        (is-eq lock-period u0)    ;; No lock
        (is-eq lock-period u4320) ;; 1 month
        (is-eq lock-period u8640) ;; 2 months
    )
)

(define-private (is-valid-voting-period (period uint))
    (and 
        (>= period u100)      ;; Minimum voting blocks
        (<= period u2880)     ;; Maximum voting blocks (approximately 1 day)
    )
)

;; PUBLIC INTERFACE

;; Protocol Initialization
(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Configure tier system
        (map-set TierLevels u1  ;; Silver Tier
            { minimum-stake: u1000000, reward-multiplier: u100,
              features-enabled: (list true false false false false false false false false false) })
        
        (map-set TierLevels u2  ;; Gold Tier
            { minimum-stake: u5000000, reward-multiplier: u150,
              features-enabled: (list true true true false false false false false false false) })
        
        (map-set TierLevels u3  ;; Platinum Tier
            { minimum-stake: u10000000, reward-multiplier: u200,
              features-enabled: (list true true true true true false false false false false) })
        (ok true)
    )
)

(define-public (stake-stx (amount uint) (lock-period uint))
    (let
        (
            (current-position (default-to 
                {
                    total-collateral: u0,
                    total-debt: u0,
                    health-factor: u0,
                    last-updated: u0,
                    stx-staked: u0,
                    analytics-tokens: u0,
                    voting-power: u0,
                    tier-level: u0,
                    rewards-multiplier: u100
                }
                (map-get? UserPositions tx-sender)))
        )
		;; Validations
        (asserts! (is-valid-lock-period lock-period) ERR-INVALID-PROTOCOL)
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (>= amount (var-get minimum-stake)) ERR-BELOW-MINIMUM)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Calculate tier level and multiplier
        (let
            (
                (new-total-stake (+ (get stx-staked current-position) amount))
                (tier-info (get-tier-info new-total-stake))
                (lock-multiplier (calculate-lock-multiplier lock-period))
            )
            
            ;; Update staking position
            (map-set StakingPositions
                tx-sender
                {
                    amount: amount,
                    start-block: stacks-block-height,
                    last-claim: stacks-block-height,
                    lock-period: lock-period,
                    cooldown-start: none,
                    accumulated-rewards: u0
                }
            )
            
            ;; Update user position with new tier info
            (map-set UserPositions
                tx-sender
                (merge current-position
                    {
                        stx-staked: new-total-stake,
                        tier-level: (get tier-level tier-info),
                        rewards-multiplier: (* (get reward-multiplier tier-info) lock-multiplier)
                    }
                )
            )
            
            ;; Update STX pool
            (var-set stx-pool (+ (var-get stx-pool) amount))
            (ok true)
        )
    )
)

(define-public (initiate-unstake (amount uint))
    (let
        (
            (staking-position (unwrap! (map-get? StakingPositions tx-sender) ERR-NO-STAKE))
            (current-amount (get amount staking-position))
        )
        (asserts! (>= current-amount amount) ERR-INSUFFICIENT-STX)
        (asserts! (is-none (get cooldown-start staking-position)) ERR-COOLDOWN-ACTIVE)
        
        ;; Update staking position with cooldown
        (map-set StakingPositions
            tx-sender
            (merge staking-position
                {
                    cooldown-start: (some stacks-block-height)
                }
            )
        )
        (ok true)
    )
)

(define-public (complete-unstake)
    (let
        (
            (staking-position (unwrap! (map-get? StakingPositions tx-sender) ERR-NO-STAKE))
            (cooldown-start (unwrap! (get cooldown-start staking-position) ERR-NOT-AUTHORIZED))
        )
        (asserts! (>= (- stacks-block-height cooldown-start) (var-get cooldown-period)) ERR-COOLDOWN-ACTIVE)
        
        ;; Transfer STX back to user
        (try! (as-contract (stx-transfer? (get amount staking-position) tx-sender tx-sender)))
        
        ;; Clear staking position
        (map-delete StakingPositions tx-sender)
        
        (ok true)
    )
)

;; GOVERNANCE ENGINE

;; Proposal Creation
(define-public (create-proposal (description (string-utf8 256)) (voting-period uint))
    (let
        (
            (user-position (unwrap! (map-get? UserPositions tx-sender) ERR-NOT-AUTHORIZED))
            (proposal-id (+ (var-get proposal-count) u1))
        )
        (asserts! (>= (get voting-power user-position) u1000000) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-description description) ERR-INVALID-PROTOCOL)
        (asserts! (is-valid-voting-period voting-period) ERR-INVALID-PROTOCOL)
        
        (map-set Proposals { proposal-id: proposal-id }
            {
                creator: tx-sender,
                description: description,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height voting-period),
                executed: false,
                votes-for: u0,
                votes-against: u0,
                minimum-votes: u1000000
            }
        )
        
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)