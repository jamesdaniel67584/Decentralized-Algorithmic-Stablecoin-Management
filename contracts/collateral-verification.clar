;; Collateral Verification Contract
;; Validates and manages backing assets for the stablecoin

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u101))
(define-constant ERR_INVALID_ASSET (err u102))

;; Data maps
(define-map collateral-assets principal uint)
(define-map asset-prices principal uint)
(define-map user-collateral principal uint)

;; Data vars
(define-data-var total-collateral uint u0)
(define-data-var collateral-ratio uint u150) ;; 150% collateralization ratio

;; Read-only functions
(define-read-only (get-collateral-balance (user principal))
  (default-to u0 (map-get? user-collateral user))
)

(define-read-only (get-asset-price (asset principal))
  (default-to u0 (map-get? asset-prices asset))
)

(define-read-only (get-total-collateral)
  (var-get total-collateral)
)

(define-read-only (calculate-collateral-value (amount uint) (asset principal))
  (let ((price (get-asset-price asset)))
    (* amount price)
  )
)

;; Public functions
(define-public (add-collateral (amount uint) (asset principal))
  (let (
    (current-balance (get-collateral-balance tx-sender))
    (asset-price (get-asset-price asset))
  )
    (asserts! (> asset-price u0) ERR_INVALID_ASSET)
    (asserts! (> amount u0) ERR_INSUFFICIENT_COLLATERAL)

    (map-set user-collateral tx-sender (+ current-balance amount))
    (var-set total-collateral (+ (var-get total-collateral) amount))
    (ok amount)
  )
)

(define-public (remove-collateral (amount uint))
  (let ((current-balance (get-collateral-balance tx-sender)))
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_COLLATERAL)

    (map-set user-collateral tx-sender (- current-balance amount))
    (var-set total-collateral (- (var-get total-collateral) amount))
    (ok amount)
  )
)

(define-public (set-asset-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set asset-prices asset price)
    (ok true)
  )
)

(define-public (verify-collateral-ratio (user principal) (debt-amount uint))
  (let (
    (collateral-balance (get-collateral-balance user))
    (required-collateral (/ (* debt-amount (var-get collateral-ratio)) u100))
  )
    (ok (>= collateral-balance required-collateral))
  )
)
