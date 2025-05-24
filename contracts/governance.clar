;; Governance Protocol Contract
;; Handles parameter adjustments and protocol governance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u401))
(define-constant ERR_VOTING_ENDED (err u402))
(define-constant ERR_ALREADY_VOTED (err u403))

;; Data vars
(define-data-var proposal-counter uint u0)
(define-data-var voting-period uint u1440) ;; ~10 days in blocks
(define-data-var quorum-threshold uint u1000) ;; Minimum votes needed

;; Data maps
(define-map proposals uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  proposer: principal,
  start-block: uint,
  end-block: uint,
  yes-votes: uint,
  no-votes: uint,
  executed: bool
})

(define-map votes {proposal-id: uint, voter: principal} bool)
(define-map voting-power principal uint)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-voting-power (user principal))
  (default-to u0 (map-get? voting-power user))
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
  (default-to false (map-get? votes {proposal-id: proposal-id, voter: voter}))
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (current-block block-height)
      (end-block (get end-block proposal))
      (yes-votes (get yes-votes proposal))
      (no-votes (get no-votes proposal))
      (total-votes (+ yes-votes no-votes))
    )
      {
        active: (< current-block end-block),
        passed: (and (>= current-block end-block) (> yes-votes no-votes) (>= total-votes (var-get quorum-threshold))),
        executed: (get executed proposal)
      }
    )
    {active: false, passed: false, executed: false}
  )
)

;; Public functions
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (start-block block-height)
    (end-block (+ block-height (var-get voting-period)))
  )
    (asserts! (> (get-voting-power tx-sender) u0) ERR_UNAUTHORIZED)

    (map-set proposals proposal-id {
      title: title,
      description: description,
      proposer: tx-sender,
      start-block: start-block,
      end-block: end-block,
      yes-votes: u0,
      no-votes: u0,
      executed: false
    })

    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (let (
    (voter-power (get-voting-power tx-sender))
    (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (> voter-power u0) ERR_UNAUTHORIZED)
    (asserts! (< block-height (get end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (not (has-voted proposal-id tx-sender)) ERR_ALREADY_VOTED)

    (map-set votes {proposal-id: proposal-id, voter: tx-sender} true)

    (if support
      (map-set proposals proposal-id (merge proposal {yes-votes: (+ (get yes-votes proposal) voter-power)}))
      (map-set proposals proposal-id (merge proposal {no-votes: (+ (get no-votes proposal) voter-power)}))
    )

    (ok true)
  )
)

(define-public (set-voting-power (user principal) (power uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set voting-power user power)
    (ok power)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (>= block-height (get end-block proposal)) ERR_VOTING_ENDED)
    (asserts! (not (get executed proposal)) ERR_UNAUTHORIZED)

    (map-set proposals proposal-id (merge proposal {executed: true}))
    (ok true)
  )
)
