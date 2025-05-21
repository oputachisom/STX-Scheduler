;; STX Scheduler - Smart Transaction Scheduling Protocol
;; 
;; This contract enables secure future-dated financial operations on the Stacks blockchain.
;; Users can schedule STX transfers to happen at specific block heights, with the funds
;; securely held in escrow until execution time. The protocol provides transaction
;; management functions including scheduling, cancellation, and execution mechanisms
;; with comprehensive security validations.

;; Constants

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-FUTURE-BLOCK-REQUIRED (err u101))
(define-constant ERR-BALANCE-TOO-LOW (err u102))
(define-constant ERR-SCHEDULE-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-PROCESSED (err u104))
(define-constant ERR-EXECUTION-TIME-NOT-REACHED (err u105))
(define-constant ERR-TRANSFER-FAILED (err u106))
(define-constant ERR-INVALID-ADDRESS (err u107))
(define-constant ERR-INVALID-SCHEDULE-ID (err u108))
(define-constant ERR-SELF-TRANSFER-DISALLOWED (err u109))

;; Data Structures

;; Contract administrator
(define-data-var protocol-admin principal tx-sender)

;; Structure for scheduled payment data
(define-map scheduled-payments
  { schedule-id: uint }
  {
    payment-sender: principal,
    payment-recipient: principal,
    payment-amount: uint,
    payment-note: (optional (string-utf8 34)),
    target-block-height: uint,
    payment-status: bool
  }
)

;; Schedule ID counter
(define-data-var schedule-id-counter uint u0)

;; Administrative Functions

;; Get the current contract administrator
(define-read-only (get-protocol-admin)
  (var-get protocol-admin)
)

;; Change the contract administrator
(define-public (transfer-admin-rights (new-admin principal))
  (begin
    ;; Ensure only current admin can transfer rights
    (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate the new admin address
    (asserts! (is-some (to-consensus-buff? new-admin)) ERR-INVALID-ADDRESS)
    (asserts! (not (is-eq new-admin tx-sender)) ERR-SELF-TRANSFER-DISALLOWED)
    
    ;; Set the new admin
    (var-set protocol-admin new-admin)
    (ok true)
  )
)

;; Schedule Information Functions

;; Get the current schedule counter value
(define-read-only (get-schedule-counter)
  (var-get schedule-id-counter)
)

;; Check if a schedule exists
(define-read-only (schedule-exists? (schedule-id uint))
  (is-some (map-get? scheduled-payments { schedule-id: schedule-id }))
)

;; Get detailed information about a scheduled payment
(define-read-only (get-payment-details (schedule-id uint))
  (match (map-get? scheduled-payments { schedule-id: schedule-id })
    payment-data (ok payment-data)
    ERR-SCHEDULE-NOT-FOUND
  )
)

;; Check if a scheduled payment is ready for execution
(define-read-only (is-payment-executable? (schedule-id uint))
  (match (map-get? scheduled-payments { schedule-id: schedule-id })
    payment-data (and 
                   (not (get payment-status payment-data))
                   (>= block-height (get target-block-height payment-data))
                 )
    false
  )
)

;; Payment Scheduling Functions

;; Create a new scheduled payment
(define-public (create-scheduled-payment 
                (recipient-address principal) 
                (payment-value uint) 
                (delay-in-blocks uint) 
                (payment-memo (optional (string-utf8 34))))
  (let 
    (
      (initiator tx-sender)
      (current-schedule-id (var-get schedule-id-counter))
      (execution-block-height (+ block-height delay-in-blocks))
      (verified-memo (if (is-some payment-memo) payment-memo none))
    )
    
    ;; Validate recipient address
    (asserts! (is-some (to-consensus-buff? recipient-address)) ERR-INVALID-ADDRESS)
    (asserts! (not (is-eq recipient-address initiator)) ERR-SELF-TRANSFER-DISALLOWED)
    
    ;; Validate schedule parameters
    (asserts! (> delay-in-blocks u0) ERR-FUTURE-BLOCK-REQUIRED)
    (asserts! (>= (stx-get-balance initiator) payment-value) ERR-BALANCE-TOO-LOW)
    
    ;; Hold funds in contract
    (try! (stx-transfer? payment-value initiator (as-contract tx-sender)))
    
    ;; Record the scheduled payment
    (map-set scheduled-payments
      { schedule-id: current-schedule-id }
      {
        payment-sender: initiator,
        payment-recipient: recipient-address,
        payment-amount: payment-value,
        payment-note: verified-memo,
        target-block-height: execution-block-height,
        payment-status: false
      }
    )
    
    ;; Update schedule counter
    (var-set schedule-id-counter (+ current-schedule-id u1))
    
    ;; Return the created schedule ID
    (ok current-schedule-id)
  )
)

;; Payment Execution Functions

;; Process a scheduled payment that has reached its execution time
(define-public (process-scheduled-payment (schedule-id uint))
  (begin
    ;; Validate schedule ID
    (asserts! (< schedule-id (var-get schedule-id-counter)) ERR-INVALID-SCHEDULE-ID)
    
    (let 
      (
        (payment-record (unwrap! (map-get? scheduled-payments { schedule-id: schedule-id }) ERR-SCHEDULE-NOT-FOUND))
        (source-address (get payment-sender payment-record))
        (destination-address (get payment-recipient payment-record))
        (transfer-amount (get payment-amount payment-record))
        (is-processed (get payment-status payment-record))
        (execution-height (get target-block-height payment-record))
      )
      
      ;; Validate execution conditions
      (asserts! (not is-processed) ERR-ALREADY-PROCESSED)
      (asserts! (>= block-height execution-height) ERR-EXECUTION-TIME-NOT-REACHED)
      
      ;; Execute the payment
      (try! (as-contract (stx-transfer? transfer-amount tx-sender destination-address)))
      
      ;; Update payment status
      (map-set scheduled-payments
        { schedule-id: schedule-id }
        (merge payment-record { payment-status: true })
      )
      
      (ok true)
    )
  )
)

;; Payment Management Functions

;; Cancel a scheduled payment and return funds to sender
(define-public (cancel-scheduled-payment (schedule-id uint))
  (begin
    ;; Validate schedule ID
    (asserts! (< schedule-id (var-get schedule-id-counter)) ERR-INVALID-SCHEDULE-ID)
    
    (let 
      (
        (payment-record (unwrap! (map-get? scheduled-payments { schedule-id: schedule-id }) ERR-SCHEDULE-NOT-FOUND))
        (source-address (get payment-sender payment-record))
        (transfer-amount (get payment-amount payment-record))
        (is-processed (get payment-status payment-record))
      )
      
      ;; Validate cancellation conditions
      (asserts! (not is-processed) ERR-ALREADY-PROCESSED)
      (asserts! (or 
                 (is-eq tx-sender source-address)
                 (is-eq tx-sender (var-get protocol-admin))
                ) 
                ERR-UNAUTHORIZED-ACCESS)
      
      ;; Return funds to original sender
      (try! (as-contract (stx-transfer? transfer-amount tx-sender source-address)))
      
      ;; Mark as processed to prevent double-spending
      (map-set scheduled-payments
        { schedule-id: schedule-id }
        (merge payment-record { payment-status: true })
      )
      
      (ok true)
    )
  )
)

;; Contract Initialization

;; Set initial contract state
(begin
  (var-set protocol-admin tx-sender)
)