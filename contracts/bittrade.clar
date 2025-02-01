;; BitTrade DEX Contract
;; Synthetic Asset DEX with AMM functionality and multi-asset swaps

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-pool-not-found (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-path-too-long (err u104))

;; Data vars
(define-data-var protocol-fee-rate uint u3) ;; 0.3%
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
(define-private (calculate-swap-output (input-amount uint) (input-reserve uint) (output-reserve uint))
    (let (
        (input-with-fee (mul input-amount u997))
        (numerator (mul input-with-fee output-reserve))
        (denominator (add (mul input-reserve u1000) input-with-fee))
    )
    (div numerator denominator))
)

(define-private (execute-swap-step (input-amount uint) (input-id uint) (output-id uint))
    (let (
        (input-pool (unwrap! (map-get? asset-pools { asset-id: input-id }) err-pool-not-found))
        (output-pool (unwrap! (map-get? asset-pools { asset-id: output-id }) err-pool-not-found))
        (output-amount (calculate-swap-output 
            input-amount
            (get stx-balance input-pool)
            (get asset-balance output-pool)
        ))
    )
    (begin
        (map-set asset-pools
            { asset-id: input-id }
            {
                liquidity: (get liquidity input-pool),
                stx-balance: (+ (get stx-balance input-pool) input-amount),
                asset-balance: (get asset-balance input-pool),
                total-shares: (get total-shares input-pool)
            }
        )
        (map-set asset-pools
            { asset-id: output-id }
            {
                liquidity: (get liquidity output-pool),
                stx-balance: (get stx-balance output-pool),
                asset-balance: (- (get asset-balance output-pool) output-amount),
                total-shares: (get total-shares output-pool)
            }
        )
        (ok output-amount))
    )
)

;; Public functions
(define-public (create-pool (asset-id uint) (initial-stx uint) (initial-asset uint))
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
    (ok true))
)

(define-public (add-liquidity (asset-id uint) (stx-amount uint) (min-asset-amount uint))
    (let (
        (pool (unwrap! (map-get? asset-pools { asset-id: asset-id }) err-pool-not-found))
        (asset-amount (/ (* stx-amount (get asset-balance pool)) (get stx-balance pool)))
        (shares-to-mint (/ (* stx-amount (get total-shares pool)) (get stx-balance pool)))
    )
    (asserts! (>= asset-amount min-asset-amount) err-invalid-params)
    
    (map-set asset-pools
        { asset-id: asset-id }
        {
            liquidity: (+ (get liquidity pool) shares-to-mint),
            stx-balance: (+ (get stx-balance pool) stx-amount),
            asset-balance: (+ (get asset-balance pool) asset-amount),
            total-shares: (+ (get total-shares pool) shares-to-mint)
        }
    )
    
    (map-set user-positions
        { user: tx-sender, asset-id: asset-id }
        {
            shares: (+ (default-to u0 (get shares (map-get? user-positions { user: tx-sender, asset-id: asset-id }))) shares-to-mint),
            asset-amount: asset-amount
        }
    )
    (ok shares-to-mint))
)

(define-public (swap-stx-to-asset (asset-id uint) (stx-amount uint) (min-asset-out uint))
    (let (
        (pool (unwrap! (map-get? asset-pools { asset-id: asset-id }) err-pool-not-found))
        (asset-out (calculate-swap-output 
            stx-amount 
            (get stx-balance pool)
            (get asset-balance pool)
        ))
    )
    (asserts! (>= asset-out min-asset-out) err-invalid-params)
    
    (map-set asset-pools
        { asset-id: asset-id }
        {
            liquidity: (get liquidity pool),
            stx-balance: (+ (get stx-balance pool) stx-amount),
            asset-balance: (- (get asset-balance pool) asset-out),
            total-shares: (get total-shares pool)
        }
    )
    (ok asset-out))
)

(define-public (multi-asset-swap (path (list 5 uint)) (input-amount uint) (min-output-amount uint))
    (let (
        (path-len (len path))
    )
    (asserts! (> path-len u1) err-invalid-params)
    (asserts! (<= path-len u5) err-path-too-long)
    
    (fold execute-swap-step path input-amount))
)

;; Read only functions
(define-read-only (get-pool-info (asset-id uint))
    (map-get? asset-pools { asset-id: asset-id })
)

(define-read-only (get-user-position (user principal) (asset-id uint))
    (map-get? user-positions { user: user, asset-id: asset-id })
)

(define-read-only (get-optimal-swap-path (input-id uint) (output-id uint))
    (list input-id output-id)
)
