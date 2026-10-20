# DOORSTEP CAR CARE — Software Requirements Specification (SRS)

**Version:** 0.1  
**Status:** Working draft. Confirmed rules are distinguished from unresolved details.  
**Product:** Society-based car-wash and car-care booking platform.

## 1. Purpose and scope

The platform will support Customer, Service Person, and Admin roles. Customers can register vehicles, verify their society association, buy a standard or custom monthly subscription, make one-time wash bookings repeatedly, create recurring schedules, and view service history. Workers manage availability and perform assigned services. Admin manages societies, verification, worker assignments, service catalog/pricing, manual payments, and operational exceptions.

This SRS describes intended behavior, not completed implementation. The repository currently has a static marketing website; backend services and database schemas are still in design.

## 2. Actors

- **Customer:** profile, vehicles, society membership request, plans, subscriptions, bookings, cancellations and service history.
- **Service Person:** weekly availability, time off, assigned bookings, service progress and completion.
- **Admin:** society and worker administration, catalog/pricing, payment verification, operational review and reassignment.
- **System processes:** rolling recurring-booking generation, booking capacity validation, worker assignment, entitlement tracking, Kafka event processing and email notifications.

## 3. Functional requirements

Requirement IDs are stable identifiers for later API, database and test traceability.

### 3.1 Identity and profiles

- FR-001: Users authenticate using either email + password or mobile number + password.
- FR-002: Each account has at least one login identifier; every provided email/mobile identifier is unique after normalization.
- FR-003: Passwords are stored as secure hashes, never plaintext.
- FR-004: Supported roles are CUSTOMER, SERVICE_PERSON and ADMIN.
- FR-005: Public registration cannot assign ADMIN or SERVICE_PERSON roles to the registrant.
- FR-006: Customer can maintain a profile and register multiple vehicles.
- FR-007: Vehicle registration number is mandatory and unique across the platform after normalization.
- FR-008: Booking operations must validate that a selected vehicle belongs to the customer.
- FR-009: Vehicle records referenced by history must be deactivated rather than hard-deleted.

### 3.2 Society and worker administration

- FR-010: Admin can create/update/activate/deactivate societies.
- FR-011: Customer selects a society during registration or onboarding and submits a membership request.
- FR-012: Society membership is manually reviewed by Admin in the initial release.
- FR-013: Customer can book only in an active service society where their membership is VERIFIED.
- FR-014: Admin can create worker profiles and assign workers to societies.
- FR-015: A worker can serve multiple societies; a society can have multiple workers.
- FR-016: Operating days and hours are configurable for each society.
- FR-017: Worker assignment and society status must be validated for each new booking.

### 3.3 Catalog and plans

- FR-018: Admin maintains a service catalog, including estimated duration, buffer rules, one-time eligibility, and custom-plan eligibility.
- FR-019: Customers can view available standard monthly plans.
- FR-020: Customers can create a custom monthly plan by selecting eligible service types and quantities within configured limits.
- FR-021: Custom-plan base price is calculated as sum(unit service rate × quantity), with Admin-configured volume discounts.
- FR-022: Backend calculates prices and never trusts a frontend-submitted total.
- FR-023: Pricing rules have effective periods and deterministic application/rounding rules.
- FR-024: Standard plan definitions are versioned; purchased terms remain snapshots.
- FR-025: Customers can book one-time washes without subscriptions and can use this option multiple times.
- FR-026: There is no separate trial-wash feature in scope.
- FR-027: One booking can contain multiple service types for the same vehicle.
- FR-028: Exact service rates, discount thresholds/stacking, buffer aggregation and incompatible service combinations are configurable/open until finalized.

### 3.4 Availability and booking capacity

- FR-029: Service Persons submit weekly availability, including multiple intervals when required.
- FR-030: Workers can request future time off.
- FR-031: If time off has no conflicts with confirmed bookings, it can take effect immediately.
- FR-032: If time off conflicts with confirmed bookings, the change requires conflict resolution or Admin review before application.
- FR-033: Admin can override availability operationally but must preserve and resolve affected bookings.
- FR-034: Bookable capacity is configurable based on actual staffing, worker schedules, existing reservations, society hours, service duration, buffers and operating rules.
- FR-035: Admin can configure service duration and buffer rules without code changes.
- FR-036: Booking Service validates capacity at booking time and reserves it atomically in its own database.
- FR-037: The system prevents simultaneous requests from overbooking a worker.
- FR-038: Multiple-service booking duration is calculated from the selected services and agreed buffer policy.
- FR-039: If several eligible workers are available, prefer the worker with the lowest scheduled workload; scheduled service minutes are preferred over raw booking count.
- FR-040: When workload ties, use a deterministic tie-breaker to be decided during implementation.
- FR-041: Admin can reassign workers while preserving the assignment history and notifying affected parties.

### 3.5 Booking lifecycle and cancellation

- FR-042: Booking is automatically confirmed only after request validation and all required reservations succeed.
- FR-043: Booking stores a stable customer-facing reference and the service/scheduling details agreed at confirmation.
- FR-044: Booking type distinguishes SUBSCRIPTION and ONE_TIME; source distinguishes INDIVIDUAL and RECURRING.
- FR-045: Booking, payment, subscription and service-execution statuses are independent.
- FR-046: Cancellation is permitted according to an Admin-configurable window.
- FR-047: Late cancellation is restricted and flagged for review in the initial release; automatic cancellation fees are not charged initially.
- FR-048: An accepted cancellation releases worker-capacity reservation and any applicable entitlement reservation.
- FR-049: Cancellation must be idempotent; repeated requests must not release capacity or entitlements twice.
- FR-050: A valid cancellation before service completion does not consume a wash.
- FR-051: Exact cancellation window, exceptions and late-cancellation resolution are open before implementation.

### 3.6 Recurring bookings

- FR-052: Customer can define recurring days/times, vehicle, society and service selections.
- FR-053: Generate bookings on a rolling seven-day horizon.
- FR-054: Each occurrence has a stable occurrence identity and a separate booking/status.
- FR-055: Every occurrence is checked using the same availability, worker, capacity and subscription-entitlement rules as an individual booking.
- FR-056: If an occurrence cannot be scheduled, preserve it as ACTION_REQUIRED and notify the customer.
- FR-057: Customer can choose another available slot to resolve an ACTION_REQUIRED occurrence.
- FR-058: Cancelling or rescheduling one occurrence does not cancel the whole recurring schedule.
- FR-059: Duplicate generation attempts must not create duplicate occurrence/booking records.
- FR-060: Do not generate/confirm an occurrence that relies on an expired or ineligible subscription entitlement.
- FR-061: Policy for repeated scheduling failures and exact horizon boundary behavior remains open.

### 3.7 Subscription and entitlement management

- FR-062: Customers can purchase standard and custom monthly subscriptions.
- FR-063: Each subscription is linked to one vehicle in the initial release.
- FR-064: A customer can own multiple vehicles, each with a separate subscription, entitlements and service history.
- FR-065: Subscription activates only after full payment is verified and not before its selected start date.
- FR-066: Subscription defaults to immediate start, with an optional future start date.
- FR-067: Validity is one calendar month from activation, not the end of the calendar month.
- FR-068: Month-end semantics, timezone and exact expiry boundary must be finalized before implementation.
- FR-069: Unused entitlements expire at subscription expiry and do not roll over by default.
- FR-070: Track granted, reserved, consumed and expired quantities per service type.
- FR-071: Confirmed subscription bookings reserve entitlements; completion consumes the corresponding entitlement exactly once.
- FR-072: Valid cancellation before service completion releases the entitlement reservation.
- FR-073: Subscription Service owns entitlement balances and transaction ledger; no other service updates its database.
- FR-074: Upgrades take effect immediately with a prorated adjustment; downgrades take effect at next renewal.
- FR-075: Standard and custom subscriptions use the same plan-change principles.
- FR-076: Preserve purchased plan/service quantities, price, discount and terms as immutable/versioned snapshots.
- FR-077: Proration formula, handling of already-reserved/consumed washes, and adjustments/refunds are open before implementation.

### 3.8 Service execution

- FR-078: Service Person can view assigned jobs and start the execution.
- FR-079: One execution record contains individual items corresponding to booking service lines.
- FR-080: Worker can mark each service item completed independently.
- FR-081: Overall execution becomes COMPLETED only when all required service items are completed.
- FR-082: Only completed subscription service items trigger consumption of their corresponding reserved entitlement.
- FR-083: Duplicate service-completion events must not double-consume an entitlement.
- FR-084: Preserve execution progress, timestamps, worker identity and status history.
- FR-085: Policy for interrupted/failed service items and partial refund/reschedule/entitlement resolution remains open.

### 3.9 Payments

- FR-086: Initial release uses manual payment recording; no online payment gateway.
- FR-087: Admin records and verifies cash, UPI, bank-transfer or other approved external payments.
- FR-088: Full payment is required to settle each obligation; partial payments/installments are not supported initially.
- FR-089: Subscription activates only after the full purchase amount is verified and the selected start date is reached.
- FR-090: One-time washes can be paid after service completion.
- FR-091: An underpayment is not a paid obligation; an overpayment requires explicit exception/correction workflow.
- FR-092: Prevent duplicate allocations and preserve payment verification/correction history.
- FR-093: Payment events are published reliably; payment status must not directly mutate other services' databases.
- FR-094: Overdue unpaid one-time washes and subscription-change payment adjustments need defined operational rules.

### 3.10 Notifications

- FR-095: Email is the only enabled notification channel for the initial release.
- FR-096: Support notifications for booking confirmation/cancellation, ACTION_REQUIRED recurring occurrences, payment updates, subscription updates and service completion.
- FR-097: Notification Service consumes events and does not query other services' databases.
- FR-098: Keep notification request, attempt and provider result history.
- FR-099: Retry temporary failures with bounded, configurable retries; deduplicate repeated source events.
- FR-100: A provider accepting an email does not prove it was read.
- FR-101: Define how mobile-only accounts supply/verify an email address before relying on email notification.

## 4. Non-functional requirements

- Security: JWT authentication, role/resource authorization, secure password hashing, least privilege and secrets outside source control.
- Data integrity: database constraints, transactions and concurrency control for bookings and entitlement changes.
- Reliability: transactional outbox for important events, idempotent consumers and explicit compensation/reconciliation for cross-service failures.
- Auditability: preserve payment, entitlement, booking, service-execution, verification and assignment history.
- Maintainability: clear service ownership, restricted database credentials and versioned contracts.
- Performance: establish measurable latency/throughput objectives before production.
- Availability/recovery: define AWS backup, restore, monitoring and recovery requirements before production.
- Cost control: avoid leaving unnecessary EKS/RDS/MSK resources running during learning.

## 5. Proposed status values (not yet implementation contracts)

- Booking: PENDING/CONFIRMATION_IN_PROGRESS, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, ACTION_REQUIRED, NO_SHOW (final mapping to be designed).
- Recurring occurrence: PLANNED, BOOKED, ACTION_REQUIRED, CANCELLED, RESCHEDULED (final mapping to be designed).
- Subscription: PENDING_PAYMENT, SCHEDULED, ACTIVE, EXPIRED, CANCELLED, plus change/renewal states as required.
- Payment: RECORDED/PENDING_VERIFICATION, VERIFIED, REJECTED, VOIDED; obligations OPEN, PAID, CANCELLED (final mapping to be designed).
- Service item: NOT_STARTED, IN_PROGRESS, COMPLETED, INTERRUPTED/CANCELLED (final mapping to be designed).

## 6. Acceptance approach

For every requirement, later tests should cover:
1. Successful expected path.
2. Invalid input and authorization failure.
3. Concurrent requests where capacity or entitlement could be exceeded.
4. Retry/duplicate event behavior.
5. Cross-service partial failure and compensation.
6. Audit/history correctness.
7. Date/time boundaries, especially subscription expiry and recurring generation.

## 7. Out of scope for initial release

- Online payment gateway.
- Trial wash as a separate offering.
- SMS and WhatsApp notifications.
- Shared/multi-vehicle subscriptions.
- Automated invitation-code society verification.
- Final AWS production deployment details, until application/container and operational requirements are validated.
