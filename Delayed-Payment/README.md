# STX Scheduler

## Smart Transaction Scheduling Protocol

STX Scheduler is a secure and efficient smart contract for the Stacks blockchain that enables future-dated financial operations. This protocol allows users to schedule STX token transfers to happen at specific block heights, with funds held securely in escrow until execution time.

## Overview

STX Scheduler provides a trustless mechanism for scheduling future payments on the Stacks blockchain. The protocol holds funds in escrow and automatically executes transfers when the specified block height is reached. This enables a wide range of use cases including recurring payments, time-locked transfers, and deferred settlements.

## Features

- **Secure Escrow**: Funds are securely held by the contract until the scheduled execution time
- **Flexible Scheduling**: Schedule payments to occur at specific future block heights
- **Optional Memos**: Include optional payment notes with each scheduled transaction
- **Cancellation Support**: Payment senders can cancel pending transfers before execution
- **Admin Oversight**: Protocol admin can intervene in case of disputes or emergencies
- **Comprehensive Validations**: Multiple security checks to ensure transaction integrity

## Functions

### Administrative Functions

#### `get-protocol-admin`
- **Type**: Read-only
- **Description**: Returns the current contract administrator address

#### `transfer-admin-rights`
- **Parameters**: 
  - `new-admin`: The principal address of the new administrator
- **Description**: Transfers administrative rights to a new principal address
- **Access**: Current admin only

### Schedule Information Functions

#### `get-schedule-counter`
- **Type**: Read-only
- **Description**: Returns the current schedule ID counter value

#### `schedule-exists?`
- **Parameters**:
  - `schedule-id`: ID of the schedule to check
- **Description**: Verifies if a schedule with the given ID exists

#### `get-payment-details`
- **Parameters**:
  - `schedule-id`: ID of the scheduled payment
- **Description**: Returns detailed information about a scheduled payment

#### `is-payment-executable?`
- **Parameters**:
  - `schedule-id`: ID of the scheduled payment
- **Description**: Checks if a payment is ready for execution based on current block height

### Payment Scheduling Functions

#### `create-scheduled-payment`
- **Parameters**:
  - `recipient-address`: Principal address of the payment recipient
  - `payment-value`: Amount of STX to transfer
  - `delay-in-blocks`: Number of blocks to wait before execution
  - `payment-memo`: Optional payment note (max 34 UTF-8 characters)
- **Description**: Creates a new scheduled payment with the specified parameters
- **Return**: Schedule ID of the created payment

### Payment Execution Functions

#### `process-scheduled-payment`
- **Parameters**:
  - `schedule-id`: ID of the scheduled payment to process
- **Description**: Executes a scheduled payment that has reached its execution time
- **Access**: Anyone can trigger execution when conditions are met

### Payment Management Functions

#### `cancel-scheduled-payment`
- **Parameters**:
  - `schedule-id`: ID of the scheduled payment to cancel
- **Description**: Cancels a scheduled payment and returns funds to the sender
- **Access**: Original sender or protocol admin

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Operation requires higher privileges |
| u101 | ERR-FUTURE-BLOCK-REQUIRED | Schedule must be set for a future block |
| u102 | ERR-BALANCE-TOO-LOW | Insufficient STX balance for operation |
| u103 | ERR-SCHEDULE-NOT-FOUND | Referenced schedule ID does not exist |
| u104 | ERR-ALREADY-PROCESSED | Payment has already been processed or canceled |
| u105 | ERR-EXECUTION-TIME-NOT-REACHED | Payment's target block height not yet reached |
| u106 | ERR-TRANSFER-FAILED | STX transfer operation failed |
| u107 | ERR-INVALID-ADDRESS | Invalid principal address provided |
| u108 | ERR-INVALID-SCHEDULE-ID | Schedule ID is out of valid range |
| u109 | ERR-SELF-TRANSFER-DISALLOWED | Cannot transfer to the same address |

## Usage Examples

### Scheduling a Payment

```clarity
;; Schedule 500 STX to be sent to recipient after 144 blocks (approx. 1 day)
(contract-call? .stx-scheduler create-scheduled-payment 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u500000000 
  u144 
  (some u"Subscription payment"))
```

### Executing a Payment

```clarity
;; Process payment with schedule ID 42 once execution time is reached
(contract-call? .stx-scheduler process-scheduled-payment u42)
```

### Canceling a Payment

```clarity
;; Cancel payment with schedule ID 42 before execution
(contract-call? .stx-scheduler cancel-scheduled-payment u42)
```

## Security Considerations

- Funds are held in the contract's escrow until execution or cancellation
- Only the original sender or protocol admin can cancel scheduled payments
- Multiple validation checks prevent common attack vectors
- Self-transfers are disallowed to prevent confusion or potential exploits
- Comprehensive error handling and status tracking prevent double-spending