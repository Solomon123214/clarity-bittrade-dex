;; BitTrade DEX Contract
;; Synthetic Asset DEX with AMM functionality and multi-asset swaps

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-pool-not-found (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-path-too-long (err u104))
(define-constant err-deadline-expired (err u105))
(define-constant err-contract-paused (err u106))
(define-constant err-zero-amount (err u107))
(define-constant err-slippage-exceeded (err u108))
(define-constant err-reentrancy (err u109))

;; Data vars
(define-data-var protocol-fee-rate uint u3) ;; 0.3%
(define-data-var is-paused bool false)
(define-data-var fee-collector principal contract-owner)
(define-data-var reentrancy-guard uint u0)
(define-data-var last-event-id uint u0)

;; Pool and position maps
(define-map asset-pools
    { asset-id: uint }
    {
        liquidity: uint,
        stx-balance: uint,
        asset-balance: uint,
        total-shares: uint
    }
)

(define-map user-positions
    { user: principal, asset-id: uint }
    {
        shares: uint,
        asset-amount: uint
    }
)

;; Helper functions
(define-private (check-reentrancy)
    (begin
        (asserts! (is-eq (var-get reentrancy-guard) u0) err-reentrancy)
        (var-set reentrancy-guard u1)
        (ok true))
)

(define-private (clear-reentrancy)
    (begin
        (var-set reentrancy-guard u0)
        (ok true))
)

(define-private (validate-pool (asset-id uint))
    (match (map-get? asset-pools { asset-id: asset-id })
        pool (ok pool)
        err-pool-not-found)
)

(define-private (emit-event (event-type (string-ascii 32)) (data (string-ascii 64)))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print { 
            event-id: (var-get last-event-id), 
            type: event-type, 
            data: data,
            block: block-height 
        })
    )
)

;; Emergency functions
(define-public (emergency-withdraw (asset-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (var-get is-paused) err-contract-paused)
        (match (map-get? asset-pools { asset-id: asset-id })
            pool (begin
                (emit-event "emergency-withdraw" (concat (to-string asset-id) "-pool"))
                (ok { 
                    stx-amount: (get stx-balance pool),
                    asset-amount: (get asset-balance pool)
                }))
            err-pool-not-found)
    )
)

;; [Previous public functions remain with added reentrancy protection]

(define-public (remove-liquidity (asset-id uint) (shares uint) (min-stx uint) (min-asset uint) (deadline uint))
    (begin
        (try! (check-reentrancy))
        (asserts! (not (var-get is-paused)) err-contract-paused)
        (asserts! (unwrap! (check-deadline deadline) err-deadline-expired) err-deadline-expired)
        (let (
            (pool (unwrap! (validate-pool asset-id) err-pool-not-found))
            (user-position (unwrap! (map-get? user-positions { user: tx-sender, asset-id: asset-id }) err-insufficient-funds))
            (stx-amount (/ (* shares (get stx-balance pool)) (get total-shares pool)))
            (asset-amount (/ (* shares (get asset-balance pool)) (get total-shares pool)))
        )
        (asserts! (>= shares (get shares user-position)) err-insufficient-funds)
        (asserts! (>= stx-amount min-stx) err-invalid-params)
        (asserts! (>= asset-amount min-asset) err-invalid-params)
        
        (map-set asset-pools
            { asset-id: asset-id }
            {
                liquidity: (- (get liquidity pool) shares),
                stx-balance: (- (get stx-balance pool) stx-amount),
                asset-balance: (- (get asset-balance pool) asset-amount),
                total-shares: (- (get total-shares pool) shares)
            }
        )
        
        (map-set user-positions
            { user: tx-sender, asset-id: asset-id }
            {
                shares: (- (get shares user-position) shares),
                asset-amount: (- (get asset-amount user-position) asset-amount)
            }
        )
        (try! (clear-reentrancy))
        (emit-event "liquidity-removed" (concat (to-string asset-id) "-shares"))
        (ok { stx-amount: stx-amount, asset-amount: asset-amount })))
)
