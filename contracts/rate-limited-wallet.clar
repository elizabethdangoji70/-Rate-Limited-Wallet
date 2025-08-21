(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-DAILY-LIMIT-EXCEEDED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-NOT-AUTHORIZED (err u103))
(define-constant ERR-WALLET-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-INITIALIZED (err u105))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant BLOCKS-PER-DAY u144)

(define-map wallets 
    { owner: principal } 
    { 
        balance: uint,
        daily-limit: uint,
        daily-spent: uint,
        last-reset-block: uint,
        created-at: uint
    }
)

(define-map wallet-history
    { owner: principal, day: uint }
    { total-spent: uint, transaction-count: uint }
)

(define-map daily-transactions
    { owner: principal, day: uint, tx-id: uint }
    { 
        amount: uint,
        stacks-block-height: uint,
        tx-type: (string-ascii 10)
    }
)

(define-data-var total-wallets uint u0)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)

(define-private (get-current-day)
    (/ stacks-block-height BLOCKS-PER-DAY)
)

(define-private (should-reset-daily-limit (wallet-data { balance: uint, daily-limit: uint, daily-spent: uint, last-reset-block: uint, created-at: uint }))
    (let ((current-day (get-current-day))
          (last-reset-day (/ (get last-reset-block wallet-data) BLOCKS-PER-DAY)))
        (> current-day last-reset-day)
    )
)

(define-private (reset-daily-spending (owner principal))
    (let ((wallet-data (unwrap! (map-get? wallets { owner: owner }) ERR-WALLET-NOT-FOUND)))
        (map-set wallets { owner: owner }
            (merge wallet-data 
                { 
                    daily-spent: u0,
                    last-reset-block: stacks-block-height
                }
            )
        )
        (ok true)
    )
)

(define-private (record-transaction (owner principal) (amount uint) (tx-type (string-ascii 10)))
    (let ((current-day (get-current-day))
          (history-key { owner: owner, day: current-day })
          (existing-history (default-to { total-spent: u0, transaction-count: u0 } 
                                       (map-get? wallet-history history-key)))
          (tx-count (get transaction-count existing-history)))
        (map-set wallet-history history-key
            {
                total-spent: (+ (get total-spent existing-history) amount),
                transaction-count: (+ tx-count u1)
            }
        )
        (map-set daily-transactions 
            { owner: owner, day: current-day, tx-id: tx-count }
            {
                amount: amount,
                stacks-block-height: stacks-block-height,
                tx-type: tx-type
            }
        )
        (ok true)
    )
)

(define-public (create-wallet (daily-limit uint))
    (let ((wallet-key { owner: tx-sender }))
        (asserts! (> daily-limit u0) ERR-INVALID-AMOUNT)
        (asserts! (is-none (map-get? wallets wallet-key)) ERR-ALREADY-INITIALIZED)
        (map-set wallets wallet-key
            {
                balance: u0,
                daily-limit: daily-limit,
                daily-spent: u0,
                last-reset-block: stacks-block-height,
                created-at: stacks-block-height
            }
        )
        (var-set total-wallets (+ (var-get total-wallets) u1))
        (ok true)
    )
)

(define-public (deposit (amount uint))
    (let ((wallet-key { owner: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set wallets wallet-key
            (merge wallet-data { balance: (+ (get balance wallet-data) amount) })
        )
        (unwrap-panic (record-transaction tx-sender amount "deposit"))
        (var-set total-deposits (+ (var-get total-deposits) amount))
        (ok amount)
    )
)

(define-public (withdraw (amount uint))
    (let ((wallet-key { owner: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (get balance wallet-data) amount) ERR-INSUFFICIENT-BALANCE)
        
        (let ((updated-wallet (if (should-reset-daily-limit wallet-data)
                                 (begin 
                                     (unwrap-panic (reset-daily-spending tx-sender))
                                     (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND))
                                 wallet-data)))
            (asserts! (<= (+ (get daily-spent updated-wallet) amount) (get daily-limit updated-wallet)) 
                     ERR-DAILY-LIMIT-EXCEEDED)
            (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
            (map-set wallets wallet-key
                (merge updated-wallet 
                    { 
                        balance: (- (get balance updated-wallet) amount),
                        daily-spent: (+ (get daily-spent updated-wallet) amount)
                    }
                )
            )
            (unwrap-panic (record-transaction tx-sender amount "withdraw"))
            (var-set total-withdrawals (+ (var-get total-withdrawals) amount))
            (ok amount)
        )
    )
)

(define-public (update-daily-limit (new-limit uint))
    (let ((wallet-key { owner: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND)))
        (asserts! (> new-limit u0) ERR-INVALID-AMOUNT)
        (map-set wallets wallet-key
            (merge wallet-data { daily-limit: new-limit })
        )
        (ok new-limit)
    )
)

(define-public (emergency-withdraw)
    (let ((wallet-key { owner: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND))
          (balance (get balance wallet-data)))
        (asserts! (> balance u0) ERR-INSUFFICIENT-BALANCE)
        (try! (as-contract (stx-transfer? balance tx-sender tx-sender)))
        (map-set wallets wallet-key
            (merge wallet-data { balance: u0, daily-spent: u0 })
        )
        (unwrap-panic (record-transaction tx-sender balance "emergency"))
        (ok balance)
    )
)

(define-read-only (get-wallet-info (owner principal))
    (let ((wallet-data (unwrap! (map-get? wallets { owner: owner }) ERR-WALLET-NOT-FOUND)))
        (let ((updated-wallet (if (should-reset-daily-limit wallet-data)
                                 (merge wallet-data { daily-spent: u0, last-reset-block: stacks-block-height })
                                 wallet-data)))
            (ok {
                balance: (get balance updated-wallet),
                daily-limit: (get daily-limit updated-wallet),
                daily-spent: (get daily-spent updated-wallet),
                remaining-daily: (- (get daily-limit updated-wallet) (get daily-spent updated-wallet)),
                last-reset-block: (get last-reset-block updated-wallet),
                created-at: (get created-at updated-wallet),
                current-day: (get-current-day),
                blocks-until-reset: (- (+ (* (get-current-day) BLOCKS-PER-DAY) BLOCKS-PER-DAY) stacks-block-height)
            })
        )
    )
)

(define-read-only (get-daily-history (owner principal) (day uint))
    (map-get? wallet-history { owner: owner, day: day })
)

(define-read-only (get-transaction-details (owner principal) (day uint) (tx-id uint))
    (map-get? daily-transactions { owner: owner, day: day, tx-id: tx-id })
)

(define-read-only (get-contract-stats)
    (ok {
        total-wallets: (var-get total-wallets),
        total-deposits: (var-get total-deposits),
        total-withdrawals: (var-get total-withdrawals),
        contract-balance: (stx-get-balance (as-contract tx-sender)),
        current-block: stacks-block-height,
        current-day: (get-current-day)
    })
)

(define-read-only (check-withdrawal-allowed (owner principal) (amount uint))
    (match (map-get? wallets { owner: owner })
        wallet-data
        (let ((updated-wallet (if (should-reset-daily-limit wallet-data)
                                 (merge wallet-data { daily-spent: u0 })
                                 wallet-data)))
            (ok {
                sufficient-balance: (>= (get balance updated-wallet) amount),
                within-daily-limit: (<= (+ (get daily-spent updated-wallet) amount) (get daily-limit updated-wallet)),
                current-balance: (get balance updated-wallet),
                daily-spent: (get daily-spent updated-wallet),
                daily-limit: (get daily-limit updated-wallet)
            })
        )
        ERR-WALLET-NOT-FOUND
    )
)
