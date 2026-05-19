# Finora Sprint 2 Implementation Plan: Core Transactions

This document outlines the architecture and tasks for executing **Sprint 2: Payments (P2P + QR)**. This sprint introduces the core money-movement capabilities for Finora, including sending funds via phone numbers and executing merchant payments via QR codes.

## User Review Required

> [!IMPORTANT]
> **QR Code Scanning**: We are using the `mobile_scanner` package. Testing camera functionalities typically requires a physical device. We will mock the scanner output gracefully if camera permissions fail or if run on an emulator that doesn't support the camera. Do you approve this approach?

> [!IMPORTANT]
> **Simulated Failures**: We need a way to trigger the rollback flow (SCRUM-55). I propose simulating a failure if the user attempts to send exactly `PKR 999` (simulated server error) or uses the phone number `"0000000000"`. Does this work for testing purposes?

## Proposed Changes

### 1. Backend / Service Layer (`lib/data/services/`)

Complete the stubs in `transaction_service.dart` and `payment_service.dart`.

#### [MODIFY] [transaction_service.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/data/services/transaction_service.dart)
- Implement `getTransaction(id)` to query a single record.
- Implement `createTransaction(txn)` to insert into the `transactions` table and update the `wallets` balance inside an atomic SQLite transaction. Add idempotency by checking `id`.
- Implement `rollbackTransaction(txnId)` to reverse the `amount` from the `wallets` balance and update the transaction `status` to `reversed`.

#### [MODIFY] [payment_service.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/data/services/payment_service.dart)
- Implement `sendP2P` and `payMerchant`.
- Both methods will:
  1. Fetch current wallet balance to ensure sufficient funds.
  2. Generate a UUID for the transaction.
  3. Call `TransactionService.createTransaction`.
  4. Optionally trigger simulated failures for testing (which triggers rollback).

### 2. State Management (`lib/features/payments/providers/`)

Create a dedicated provider to manage the payment state, handling inputs, validation, and invoking the `PaymentService`.

#### [NEW] [payment_provider.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/features/payments/providers/payment_provider.dart)
- Will track `recipientPhone`, `recipientName`, `merchantId`, `amount`, and `description`.
- Expose methods `initiateP2P()` and `initiateQR()`.
- Will interface directly with `PaymentService` and `WalletProvider` to ensure the dashboard reflects new balances immediately.

### 3. UI Layer (`lib/features/payments/screens/`)

Build out the screens required for sending money and scanning QR codes.

#### [NEW] [send_money_screen.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/features/payments/screens/send_money_screen.dart)
- Input field for phone number and a horizontal list/grid of mock contacts (from `SeedData.contacts`).
- Numeric input field for the amount.
- 'Continue' button leading to confirmation.

#### [NEW] [scan_qr_screen.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/features/payments/screens/scan_qr_screen.dart)
- Camera view using `mobile_scanner`.
- Parses custom scheme `finora://pay?merchant=ID&name=Name`.
- Overlays a merchant info card upon successful scan, prompting for the amount.

#### [NEW] [payment_confirmation_screen.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/features/payments/screens/payment_confirmation_screen.dart)
- Displays transaction breakdown (Recipient, Amount, Fee: Free).
- Includes our `PinPad` widget at the bottom to securely authorize the transaction using the created PIN.

#### [NEW] [payment_status_screen.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/features/payments/screens/payment_status_screen.dart)
- A dynamic screen taking a `success` boolean.
- Uses Lottie animations (or animated icons) to show Success/Failure.
- Button to view receipt (routes to `TransactionDetailScreen` from Sprint 1) or return to Dashboard.

### 4. Routing & App Configuration

#### [MODIFY] [app_router.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/core/routing/app_router.dart)
- Register routes for `/send-money`, `/scan-qr`, `/payment-confirmation`, and `/payment-status`.

#### [MODIFY] [app.dart](file:///c:/Users/Sana%20Mir/Documents/SANA_UNI/Semester8/SPM/Project/Finora-App/lib/app.dart)
- Inject `PaymentProvider` via `ChangeNotifierProvider` globally or proxy it if it needs `AuthService` access.

## Verification Plan

### Automated Tests
- I will write unit tests for `TransactionService` testing idempotency and rollback scenarios inside `test/services/transaction_service_test.dart`.

### Manual Verification
1. **P2P Flow**: Launch app, navigate to 'Send Money', pick 'Ahmed Khan', send PKR 500. Verify the amount is deducted and a receipt is generated.
2. **QR Flow**: Navigate to 'Scan QR' and manually enter amount.
3. **Simulated Failure**: Attempt to send exactly PKR 999 to trigger a simulated failure. Ensure the app reports failure and the balance does not decrease (rollback successful).
