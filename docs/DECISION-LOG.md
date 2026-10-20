# DOORSTEP CAR CARE — Architecture Decision Log

**Version:** 0.1  
**Purpose:** Record the decisions agreed during initial product/HLD/database discussions. These decisions are the current working baseline; detailed implementation contracts may refine them explicitly.

## Architecture and technology

### ADR-001 — Java and coding/learning approach
Use Java 21 runtime with Spring Boot. Prefer familiar pre-Java-8 syntax where practical; explain unfamiliar concepts, including lambdas, streams, Optional and other modern APIs, line by line when introduced. Use JdbcTemplate rather than JPA.

### ADR-002 — Microservices
Use independently deployable microservices with clear business responsibilities and service-owned data. Avoid direct database access across service boundaries.

### ADR-003 — Database per service
Each microservice owns a separate PostgreSQL database. During local development, databases may be hosted by a single PostgreSQL server/instance. Each service uses restricted credentials. References to other services' entities are identifiers; no cross-service foreign keys or direct cross-database table access.

### ADR-004 — Communication
Use REST when an immediate response is required. Use Apache Kafka for appropriate asynchronous workflows. Kafka will be learned from fundamentals during implementation. Use an outbox for important events and idempotent consumers for side effects.

### ADR-005 — Security
Use Spring Security with JWT-based authentication/authorization. Validate access tokens in each protected service and enforce resource ownership, not just broad roles. Store password hashes only; never commit credentials or secrets.

### ADR-006 — Container and cloud direction
Use Docker for container images and Kubernetes for orchestration. Target AWS, with Amazon EKS proposed for Kubernetes, ECR for images, RDS for PostgreSQL and MSK considered for managed Kafka. The exact AWS architecture, networking, sizing, costs and production controls remain to be finalized.

## Identity, user and society

### ADR-007 — Login identifier
Users can log in with either email + password or mobile number + password. An account must have at least one identifier; any supplied identifier must be unique after normalization.

### ADR-008 — Roles
Initial roles: CUSTOMER, SERVICE_PERSON and ADMIN. Public registration must not allow a user to assign ADMIN or SERVICE_PERSON to themselves.

### ADR-009 — Customer and worker profile ownership
Identity/Auth owns authentication records. User/Profile owns customer and Service Person profile details and vehicles. Society owns society membership verification and worker-to-society assignments.

### ADR-010 — Multiple vehicles
A customer may register multiple vehicles. Each vehicle has a required, unique registration number normalized before uniqueness checks. Each vehicle initially belongs to one account; shared-car access/ownership transfer is deferred. Preserve vehicle history rather than hard-delete referenced records.

### ADR-011 — Society verification
Initial release uses manual Admin verification. Customers select a society and submit a membership request. Only verified customers can book at active societies where the service is enabled. Preserve verification history and reviewer timestamps.

## Catalog, plans and pricing

### ADR-012 — Standard and custom plans
Offer standard monthly subscriptions and a custom plan builder. Admin configures eligible service types, quantity bounds, prices and rules.

### ADR-013 — Custom plan pricing
Base custom-plan price is the sum of selected service unit rates multiplied by quantities, with Admin-configured volume discounts. Backend calculates price; frontend totals are never trusted. Actual rates, discount thresholds, stacking and rounding remain open.

### ADR-014 — Repeatable one-time washes
Offer a one-time wash independent of subscription. Customer may book this option multiple times. There is no separate trial-wash feature.

### ADR-015 — Service duration and buffers
Admin configures estimated duration and buffer rules per service type. Confirmed appointments preserve scheduling snapshots so later catalog edits do not silently alter existing bookings.

### ADR-016 — Multiple services per booking
One booking can contain multiple service types for the same vehicle. Store service lines separately and calculate the combined reserved time. Exact buffer aggregation and incompatible combinations remain open.

## Booking and worker operations

### ADR-017 — Configurable capacity
Booking capacity depends on staffing, worker schedules, existing reservations, service duration/buffer, society operating hours and operating rules. No universal fixed cars-per-slot assumption.

### ADR-018 — Automatic confirmation
Booking is automatically confirmed only after backend validations and successful capacity reservation. Use concurrency-safe local database operations; if a multi-service workflow fails, release any successful reservations and reconcile retry failures. Do not report confirmed until required reservations succeed.

### ADR-019 — Automatic worker assignment
Assign an eligible worker based on society assignment, availability, duration/buffer and capacity. Prefer the eligible worker with the lowest scheduled workload, ideally measured in scheduled service minutes. Tie-breaker remains to be defined. Admin may reassign while preserving history and notifying affected parties.

### ADR-020 — Worker availability and time off
Workers submit weekly availability and may block future time off. If time off has no confirmed-booking conflicts, it can take effect immediately. If it conflicts with confirmed bookings, resolve the conflict or obtain Admin review before the change applies. Admin may override operationally, but must preserve and resolve affected bookings.

### ADR-021 — Recurring booking generation
Generate recurring bookings on a rolling seven-day horizon. Every occurrence is an independent booking with a stable occurrence identity. If an occurrence cannot be scheduled, mark it ACTION_REQUIRED and notify the customer; do not silently skip or falsely confirm it. Resolving/cancelling one occurrence does not cancel the full schedule.

### ADR-022 — Cancellation policy
Cancellation window is Admin-configurable. Accepted cancellation releases capacity and any applicable entitlement reservation. Late cancellations are restricted and flagged for review in the initial release; do not automatically charge a cancellation fee. Exact window and exceptions remain open.

## Subscription and service execution

### ADR-023 — One subscription per vehicle
Each subscription is vehicle-specific in the initial release. A customer with multiple vehicles manages separate subscriptions and entitlements for each vehicle.

### ADR-024 — Subscription start and validity
Subscription activates only after payment has been fully verified and not before its selected start date. Immediate start is the default, with a future start date option. Validity is one calendar month from activation, not end of calendar month. Month-end semantics, timezone and expiry boundary remain open.

### ADR-025 — Unused entitlement expiry
Unused washes expire at subscription period end and do not roll over automatically.

### ADR-026 — Entitlement lifecycle
Track granted, reserved, consumed and expired quantities per service type. Confirmed subscription booking reserves a wash; completion consumes it once. Valid cancellation before completion releases it. Use an entitlement ledger and idempotency to prevent duplicate deductions.

### ADR-027 — Plan changes
Upgrades take effect immediately with a prorated price adjustment; downgrades take effect at next renewal. Standard and custom subscriptions follow the same rules. Exact proration, adjustments/refunds, interaction with existing reservations and consumed entitlements remain open.

### ADR-028 — Partial service completion
Worker can mark each service item complete separately. Overall execution becomes COMPLETED only after all required items are completed. Only completed subscription service items consume their corresponding reserved entitlements. Incomplete items remain unresolved; failure/reschedule/refund rules remain open.

## Payment and notification

### ADR-029 — Manual payments
Initial release records payments collected externally (cash, UPI, bank transfer); no online payment gateway. Admin records and verifies payments.

### ADR-030 — Full payment only
Each payment obligation must be fully settled in the initial release; no partial payments/installments. Underpayment cannot settle an obligation; overpayment requires explicit exception/correction handling. Keep payment status separate from booking, subscription and execution status.

### ADR-031 — Subscription payment gating
Subscription activation requires full payment verification and the selected start date to have arrived. A verified future-dated subscription is not usable before its start date.

### ADR-032 — One-time payment timing
One-time wash can be paid after service completion. Handling of unpaid/overdue one-time washes remains to be defined.

### ADR-033 — Email notifications
Email is the only enabled notification channel in the initial release. Data model remains channel-aware for future SMS/WhatsApp. A provider accepting a message does not prove it was read. Policy for mobile-only accounts without a verified email remains open.

## Repository and delivery conventions

### ADR-034 — Backend first
Build backend and databases before the React frontend. Do not treat conceptual designs as implemented software.

### ADR-035 — Documentation baseline
Maintain HLD, SRS, decision log and SQL scripts in Git alongside the application. Finalize each schema, then validate it against PostgreSQL before implementing the associated service.

## Open decisions register

The following must be explicitly resolved before the relevant features are implemented:
- Email/mobile verification policy; email requirement for email notifications.
- Refresh-token rotation and session/logout policy.
- Exact service rates, duration defaults, buffer aggregation and allowed service combinations.
- Discount thresholds, scope, stacking and rounding.
- Exact cancellation window, late-cancellation exceptions and partial-service resolution.
- Rolling recurring horizon boundary, retry/failure policy and occurrences near subscription expiry.
- Subscription month-end/expiry timestamp/timezone semantics.
- Upgrade proration formula and treatment of old reservations/entitlements.
- Unpaid one-time wash follow-up, overpayment and payment correction process.
- Workload tie-breaker and assignment conflict resolution.
- Production AWS architecture, deployment, monitoring, backups, disaster recovery and cost controls.

