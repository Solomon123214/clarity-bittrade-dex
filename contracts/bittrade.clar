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

;; Data vars
(define-data-var protocol-fee-rate uint u3) ;; 0.3%
(define-data-var is-paused bool false)
(define-data-var fee-collector principal contract-owner)

;; Events
(define-data-var last-event-id uint u0)

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

;; Private functions
(define-private (emit-event (event-type (string-ascii 32)) (data (string-ascii 64)))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print { event-id: (var-get last-event-id), type: event-type, data: data })
    )
)

(define-private (check-deadline (deadline uint))
    (ok (>= deadline block-height))
)

(define-private (calculate-swap-output (input-amount uint) (input-reserve uint) (output-reserve uint))
    (let (
        (input-with-fee (mul input-amount u997))
        (numerator (mul input-with-fee output-reserve))
        (denominator (add (mul input-reserve u1000) input-with-fee))
    )
    (div numerator denominator))
)

;; Admin functions
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set is-paused paused)
        (emit-event "set-paused" (if paused "true" "false"))
        (ok true))
)

(define-public (set-fee-collector (new-collector principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set fee-collector new-collector)
        (emit-event "set-fee-collector" (to-string new-collector))
        (ok true))
)

;; Public functions
(define-public (create-pool (asset-id uint) (initial-stx uint) (initial-asset uint))
    (begin
        (asserts! (not (var-get is-paused)) err-contract-paused)
        (asserts! (> initial-stx u0) err-zero-amount)
        (asserts! (> initial-asset u0) err-zero-amount)
        (let (
            (pool-exists (default-to false (map-get? asset-pools { asset-id: asset-id })))
        )
        (asserts! (not pool-exists) err-invalid-params)
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set asset-pools
            { asset-id: asset-id }
            {
                liquidity: u0,
                stx-balance: initial-stx,
                asset-balance: initial-asset,
                total-shares: u0
            }
        )
        (emit-event "pool-created" (concat (to-string asset-id) "-pool"))
        (ok true)))
)

;; ... [Previous public functions remain unchanged]

(define-public (remove-liquidity (asset-id uint) (shares uint) (min-stx uint) (min-asset uint) (deadline uint))
    (begin
        (asserts! (not (var-get is-paused)) err-contract-paused)
        (asserts! (unwrap! (check-deadline deadline) err-deadline-expired) err-deadline-expired)
        (let (
            (pool (unwrap! (map-get? asset-pools { asset-id: asset-id }) err-pool-not-found))
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
        (emit-event "liquidity-removed" (concat (to-string asset-id) "-shares"))
        (ok { stx-amount: stx-amount, asset-amount: asset-amount })))
)
