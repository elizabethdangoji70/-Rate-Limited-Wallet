(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-DAILY-LIMIT-EXCEEDED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-NOT-AUTHORIZED (err u103))
(define-constant ERR-WALLET-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-INITIALIZED (err u105))
(define-constant ERR-DELEGATION-NOT-FOUND (err u106))
(define-constant ERR-ALREADY-DELEGATED (err u107))
(define-constant ERR-CANNOT-DELEGATE-TO-SELF (err u108))
(define-constant ERR-SCHEDULE-NOT-FOUND (err u109))
(define-constant ERR-SCHEDULE-NOT-READY (err u110))
(define-constant ERR-SCHEDULE-ALREADY-EXECUTED (err u111))
(define-constant ERR-SCHEDULE-CANCELLED (err u112))
(define-constant ERR-INVALID-SCHEDULE (err u113))

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

(define-map wallet-delegations
    { owner: principal, delegate: principal }
    {
        daily-limit: uint,
        daily-spent: uint,
        last-reset-block: uint,
        granted-at: uint,
        is-active: bool
    }
)

(define-map delegation-history
    { owner: principal, delegate: principal, day: uint }
    { total-spent: uint, transaction-count: uint }
)

(define-map scheduled-withdrawals
    { owner: principal, schedule-id: uint }
    {
        recipient: principal,
        amount: uint,
        execute-at-block: uint,
        is-recurring: bool,
        interval-blocks: uint,
        max-executions: uint,
        executions-count: uint,
        is-active: bool,
        created-at: uint
    }
)

(define-map owner-schedule-counter
    { owner: principal }
    { next-id: uint }
)

(define-data-var total-wallets uint u0)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)
(define-data-var total-delegations uint u0)
(define-data-var total-schedules uint u0)

(define-private (get-current-day)
    (/ stacks-block-height BLOCKS-PER-DAY)
)

(define-private (get-next-schedule-id (owner principal))
    (let ((counter-data (default-to { next-id: u0 } (map-get? owner-schedule-counter { owner: owner }))))
        (get next-id counter-data)
    )
)

(define-private (increment-schedule-id (owner principal))
    (let ((current-id (get-next-schedule-id owner)))
        (map-set owner-schedule-counter { owner: owner } { next-id: (+ current-id u1) })
        current-id
    )
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

(define-private (should-reset-delegation-limit (delegation-data { daily-limit: uint, daily-spent: uint, last-reset-block: uint, granted-at: uint, is-active: bool }))
    (let ((current-day (get-current-day))
          (last-reset-day (/ (get last-reset-block delegation-data) BLOCKS-PER-DAY)))
        (> current-day last-reset-day)
    )
)

(define-private (reset-delegation-spending (owner principal) (delegate principal))
    (let ((delegation-key { owner: owner, delegate: delegate })
          (delegation-data (unwrap! (map-get? wallet-delegations delegation-key) ERR-DELEGATION-NOT-FOUND)))
        (map-set wallet-delegations delegation-key
            (merge delegation-data
                {
                    daily-spent: u0,
                    last-reset-block: stacks-block-height
                }
            )
        )
        (ok true)
    )
)

(define-private (record-delegation-transaction (owner principal) (delegate principal) (amount uint))
    (let ((current-day (get-current-day))
          (history-key { owner: owner, delegate: delegate, day: current-day })
          (existing-history (default-to { total-spent: u0, transaction-count: u0 }
                                       (map-get? delegation-history history-key))))
        (map-set delegation-history history-key
            {
                total-spent: (+ (get total-spent existing-history) amount),
                transaction-count: (+ (get transaction-count existing-history) u1)
            }
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
        total-delegations: (var-get total-delegations),
        total-schedules: (var-get total-schedules),
        contract-balance: (stx-get-balance (as-contract tx-sender)),
        current-block: stacks-block-height,
        current-day: (get-current-day)
    })
)

(define-public (delegate-spending (delegate principal) (daily-limit uint))
    (let ((wallet-key { owner: tx-sender })
          (delegation-key { owner: tx-sender, delegate: delegate }))
        (asserts! (is-some (map-get? wallets wallet-key)) ERR-WALLET-NOT-FOUND)
        (asserts! (> daily-limit u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq tx-sender delegate)) ERR-CANNOT-DELEGATE-TO-SELF)
        (asserts! (is-none (map-get? wallet-delegations delegation-key)) ERR-ALREADY-DELEGATED)
        (map-set wallet-delegations delegation-key
            {
                daily-limit: daily-limit,
                daily-spent: u0,
                last-reset-block: stacks-block-height,
                granted-at: stacks-block-height,
                is-active: true
            }
        )
        (var-set total-delegations (+ (var-get total-delegations) u1))
        (ok true)
    )
)

(define-public (revoke-delegation (delegate principal))
    (let ((delegation-key { owner: tx-sender, delegate: delegate })
          (delegation-data (unwrap! (map-get? wallet-delegations delegation-key) ERR-DELEGATION-NOT-FOUND)))
        (map-set wallet-delegations delegation-key
            (merge delegation-data { is-active: false })
        )
        (ok true)
    )
)

(define-public (delegated-withdraw (owner principal) (amount uint))
    (let ((wallet-key { owner: owner })
          (delegation-key { owner: owner, delegate: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND))
          (delegation-data (unwrap! (map-get? wallet-delegations delegation-key) ERR-DELEGATION-NOT-FOUND)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (get is-active delegation-data) ERR-NOT-AUTHORIZED)
        (asserts! (>= (get balance wallet-data) amount) ERR-INSUFFICIENT-BALANCE)
        
        (let ((updated-delegation (if (should-reset-delegation-limit delegation-data)
                                    (begin
                                        (unwrap-panic (reset-delegation-spending owner tx-sender))
                                        (unwrap! (map-get? wallet-delegations delegation-key) ERR-DELEGATION-NOT-FOUND))
                                    delegation-data)))
            (asserts! (<= (+ (get daily-spent updated-delegation) amount) (get daily-limit updated-delegation))
                     ERR-DAILY-LIMIT-EXCEEDED)
            (try! (as-contract (stx-transfer? amount owner tx-sender)))
            (map-set wallets wallet-key
                (merge wallet-data { balance: (- (get balance wallet-data) amount) })
            )
            (map-set wallet-delegations delegation-key
                (merge updated-delegation { daily-spent: (+ (get daily-spent updated-delegation) amount) })
            )
            (unwrap-panic (record-delegation-transaction owner tx-sender amount))
            (unwrap-panic (record-transaction owner amount "delegated"))
            (var-set total-withdrawals (+ (var-get total-withdrawals) amount))
            (ok amount)
        )
    )
)

(define-read-only (get-delegation-info (owner principal) (delegate principal))
    (let ((delegation-data (unwrap! (map-get? wallet-delegations { owner: owner, delegate: delegate }) ERR-DELEGATION-NOT-FOUND)))
        (let ((updated-delegation (if (should-reset-delegation-limit delegation-data)
                                    (merge delegation-data { daily-spent: u0, last-reset-block: stacks-block-height })
                                    delegation-data)))
            (ok {
                daily-limit: (get daily-limit updated-delegation),
                daily-spent: (get daily-spent updated-delegation),
                remaining-daily: (- (get daily-limit updated-delegation) (get daily-spent updated-delegation)),
                granted-at: (get granted-at updated-delegation),
                is-active: (get is-active updated-delegation),
                current-day: (get-current-day)
            })
        )
    )
)

(define-read-only (get-delegation-history (owner principal) (delegate principal) (day uint))
    (map-get? delegation-history { owner: owner, delegate: delegate, day: day })
)

(define-public (schedule-withdrawal (recipient principal) (amount uint) (execute-at-block uint) (is-recurring bool) (interval-blocks uint) (max-executions uint))
    (let ((wallet-key { owner: tx-sender })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND))
          (schedule-id (increment-schedule-id tx-sender))
          (schedule-key { owner: tx-sender, schedule-id: schedule-id }))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> execute-at-block stacks-block-height) ERR-INVALID-SCHEDULE)
        (asserts! (>= (get balance wallet-data) amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (or (not is-recurring) (and (> interval-blocks u0) (> max-executions u0))) ERR-INVALID-SCHEDULE)
        (map-set scheduled-withdrawals schedule-key
            {
                recipient: recipient,
                amount: amount,
                execute-at-block: execute-at-block,
                is-recurring: is-recurring,
                interval-blocks: interval-blocks,
                max-executions: max-executions,
                executions-count: u0,
                is-active: true,
                created-at: stacks-block-height
            }
        )
        (var-set total-schedules (+ (var-get total-schedules) u1))
        (ok schedule-id)
    )
)

(define-public (execute-scheduled-withdrawal (owner principal) (schedule-id uint))
    (let ((schedule-key { owner: owner, schedule-id: schedule-id })
          (schedule-data (unwrap! (map-get? scheduled-withdrawals schedule-key) ERR-SCHEDULE-NOT-FOUND))
          (wallet-key { owner: owner })
          (wallet-data (unwrap! (map-get? wallets wallet-key) ERR-WALLET-NOT-FOUND)))
        (asserts! (get is-active schedule-data) ERR-SCHEDULE-CANCELLED)
        (asserts! (>= stacks-block-height (get execute-at-block schedule-data)) ERR-SCHEDULE-NOT-READY)
        (asserts! (>= (get balance wallet-data) (get amount schedule-data)) ERR-INSUFFICIENT-BALANCE)
        
        (try! (as-contract (stx-transfer? (get amount schedule-data) owner (get recipient schedule-data))))
        (map-set wallets wallet-key
            (merge wallet-data { balance: (- (get balance wallet-data) (get amount schedule-data)) })
        )
        (unwrap-panic (record-transaction owner (get amount schedule-data) "scheduled"))
        (var-set total-withdrawals (+ (var-get total-withdrawals) (get amount schedule-data)))
        
        (let ((new-executions (+ (get executions-count schedule-data) u1)))
            (if (get is-recurring schedule-data)
                (if (< new-executions (get max-executions schedule-data))
                    (map-set scheduled-withdrawals schedule-key
                        (merge schedule-data
                            {
                                executions-count: new-executions,
                                execute-at-block: (+ (get execute-at-block schedule-data) (get interval-blocks schedule-data))
                            }
                        )
                    )
                    (map-set scheduled-withdrawals schedule-key
                        (merge schedule-data
                            {
                                executions-count: new-executions,
                                is-active: false
                            }
                        )
                    )
                )
                (map-set scheduled-withdrawals schedule-key
                    (merge schedule-data
                        {
                            executions-count: new-executions,
                            is-active: false
                        }
                    )
                )
            )
        )
        (ok (get amount schedule-data))
    )
)

(define-public (cancel-scheduled-withdrawal (schedule-id uint))
    (let ((schedule-key { owner: tx-sender, schedule-id: schedule-id })
          (schedule-data (unwrap! (map-get? scheduled-withdrawals schedule-key) ERR-SCHEDULE-NOT-FOUND)))
        (asserts! (get is-active schedule-data) ERR-SCHEDULE-CANCELLED)
        (map-set scheduled-withdrawals schedule-key
            (merge schedule-data { is-active: false })
        )
        (ok true)
    )
)

(define-read-only (get-schedule-info (owner principal) (schedule-id uint))
    (match (map-get? scheduled-withdrawals { owner: owner, schedule-id: schedule-id })
        schedule-data
        (ok {
            recipient: (get recipient schedule-data),
            amount: (get amount schedule-data),
            execute-at-block: (get execute-at-block schedule-data),
            is-recurring: (get is-recurring schedule-data),
            interval-blocks: (get interval-blocks schedule-data),
            max-executions: (get max-executions schedule-data),
            executions-count: (get executions-count schedule-data),
            is-active: (get is-active schedule-data),
            created-at: (get created-at schedule-data),
            is-ready: (>= stacks-block-height (get execute-at-block schedule-data)),
            blocks-until-execution: (if (>= stacks-block-height (get execute-at-block schedule-data))
                                       u0
                                       (- (get execute-at-block schedule-data) stacks-block-height))
        })
        ERR-SCHEDULE-NOT-FOUND
    )
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
