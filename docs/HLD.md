# DOORSTEP CAR CARE — High-Level Design (HLD)

**Document status:** Working design baseline  
**Version:** 0.1  
**Status:** Architecture direction agreed; detailed contracts and production rules remain open.

## 1. Purpose

DOORSTEP CAR CARE is a society-based car-care platform. Customers can register vehicles, select standard or custom monthly plans, book one-time washes, arrange recurring bookings, and view service history. Service Persons manage availability and execute assigned jobs. Admin manages societies, verification, workers, catalog/pricing, payments, and operational exceptions.

This document describes the intended backend architecture. It is not a claim that the backend has already been implemented. The repository currently includes the static marketing website; backend development is planned.

## 2. Technology decisions

- Runtime/language: Java 21. Prefer familiar Java 7-era syntax where practical. Explain unfamiliar concepts and any use of lambdas, streams, Optional, or other modern APIs line by line.
- Framework: Spring Boot.
- Architecture: independently deployable microservices.
- Database: PostgreSQL, with a separate logical database owned by each service.
- Data access: Spring JdbcTemplate, not JPA.
- Synchronous communication: REST APIs.
- Asynchronous communication: Apache Kafka. Kafka will be learned from fundamentals during implementation.
- Security: Spring Security and JWT-based authentication/authorization.
- Frontend: React, planned after backend services and APIs.
- Containers: Docker.
- Orchestration: Kubernetes; Amazon EKS is the proposed AWS target.
- AWS direction: ECR for images, RDS for managed PostgreSQL, MSK as a managed Kafka option, plus IAM, Secrets Manager and CloudWatch as appropriate. Final AWS sizing and service selection remain open.

For local development, the separate PostgreSQL databases can run on one PostgreSQL server. Services must use restricted credentials and must not read or modify another service's tables.

## 3. Actors

### Customer
- Registers and signs in using email + password or mobile number + password.
- Selects a residential society; Admin manually verifies the association.
- Registers multiple vehicles.
- Chooses a standard subscription, builds a custom subscription, or books a one-time wash.
- Uses recurring schedules, individual bookings, or both within subscription rules.
- Views booking and service history.

### Service Person
- Manages weekly availability and future time off.
- Views assigned work.
- Starts and completes individual service items.
- Cannot update bookings not assigned to them, except through explicitly authorized workflows.

### Admin
- Manages societies, verification, worker profiles/assignments, catalog, pricing and discount rules.
- Records and verifies externally collected payments.
- Resolves cancellations, worker conflicts, reassignment and other operational exceptions.

## 4. Proposed microservices and data ownership

| Service | Responsibilities | Owned database |
|---|---|---|
| Identity / Auth | Account identifiers, credentials, roles, verification challenges, password reset, refresh-session metadata | identity_db |
| User / Profile | Customer and Service Person profiles; vehicle registration | user_profile_db |
| Society | Societies, customer memberships and verification history, worker assignments, operating hours | society_db |
| Plan / Catalog | Services, durations/buffers, standard plans, current service pricing, custom-plan limits, discount rules | catalog_db |
| Availability | Weekly worker availability, time off, availability history | availability_db |
| Booking | Bookings, booking service lines, recurring schedules/occurrences, capacity reservations, assignment and status history, outbox events | booking_db |
| Subscription | Vehicle-specific subscriptions, version snapshots, entitlements and entitlement ledger, plan-change requests, outbox events | subscription_db |
| Service Execution | Overall service execution, individual service items, execution history, outbox events | execution_db |
| Payment | Payment obligations, receipts, allocations, verification history, outbox events | payment_db |
| Notification | Notification requests, delivery attempts and templates | notification_db |

The API Gateway is infrastructure rather than a business microservice. Admin is an application role, not a separate service.

Each service owns its database. IDs referring to records in other services are stored as identifiers without cross-service foreign keys. Cross-service validation uses service APIs and/or defined events. Do not use direct cross-database table access.

## 5. Main architecture principles

- Use REST where a caller requires an immediate answer, such as slot availability validation or confirming a booking request.
- Use Kafka for asynchronous work such as notification delivery, payment-verification downstream workflows, and service-completion processing.
- A database transaction is local to one service/database. Do not assume one PostgreSQL transaction covers several microservices.
- Use explicit saga-style orchestration/compensation for workflows spanning Booking and Subscription, such as reserving an entitlement and then reserving capacity.
- Use a transactional outbox for important events that must not be lost after a database change commits.
- Kafka consumers must be idempotent when duplicate processing could cause harmful results.
- Enforce authorization in each protected service, not only at the gateway.
- Keep payment, booking, subscription, and service-execution statuses separate.
- Preserve audit history for payment verification, service progress, assignment changes, and entitlement transactions.

## 6. Customer booking flow

1. Customer selects an active, verified society, a vehicle, service type(s), and desired time.
2. Backend validates that the vehicle belongs to the customer and that the society, service, plan, and subscription eligibility are valid.
3. Availability/Booking logic evaluates worker assignments, schedules, existing bookings, service duration, buffers, and configured capacity.
4. For subscription bookings, Subscription Service reserves the applicable entitlements. For one-time bookings, no subscription entitlement is required.
5. Booking Service assigns an eligible worker, preferring the eligible worker with the lowest scheduled workload; it then reserves capacity and stores the booking transactionally.
6. The customer receives confirmation only after the required reservations succeed. If a cross-service step fails, compensate/release successful reservations and retry or reconcile failures.
7. After booking is committed, an outbox publisher sends the booking event to Kafka. Notification Service sends an email.
8. Service Person records each booked service item’s progress. Completing an item creates a reliable event; Subscription Service consumes the matching reserved entitlement exactly once.

## 7. Capacity and worker assignment

- Capacity is configurable, based on actual staffing/operating rules rather than a fixed universal number of cars per slot.
- Admin configures service durations and applicable buffer rules.
- Multiple service types may be included in one booking for the same vehicle.
- Booking Service combines durations and buffer rules to determine the reservation interval; the exact buffer aggregation policy remains open.
- Prevent concurrent requests from overbooking a worker. Availability displayed earlier is not sufficient proof that a slot remains free.
- If multiple workers are eligible, choose the worker with the lowest scheduled workload; use a deterministic tie-breaker to be defined.
- Admin can reassign bookings while preserving assignment history and notifying affected parties.

## 8. Recurring bookings

- Customers can use recurring schedules and individual bookings within the same subscription entitlement limits.
- Generate occurrences on a rolling seven-day horizon.
- Each occurrence becomes its own booking when it passes validation and capacity reservation.
- If an occurrence cannot be scheduled, retain it as ACTION_REQUIRED and notify the customer. Do not silently skip or falsely confirm it.
- The customer can choose another available time. Resolving/cancelling one occurrence does not cancel the entire schedule.
- Prevent duplicate generation with a stable occurrence identity and database uniqueness.
- Generate only occurrences allowed by subscription validity and eligibility rules.

## 9. Subscription and payment rules

- A subscription is vehicle-specific in the initial release.
- Standard and custom plans are supported. Custom pricing is the sum of service rates multiplied by quantities, with Admin-configured volume discounts.
- Subscription activation requires Admin-verified, fully settled payment and does not begin before a future selected start date.
- Validity is one calendar month from the activation date, not the end of the calendar month. Month-end and expiry-boundary rules remain open.
- Unused entitlements expire at period end and do not roll over automatically.
- Track granted, reserved, consumed and expired entitlement amounts separately.
- Reserve entitlement for a confirmed subscription booking; consume it only after the corresponding service item completes. Release reservations for valid cancellations before completion.
- Upgrades are intended to take effect immediately with prorated price adjustment; downgrades take effect next renewal. Exact proration, payment adjustment and entitlement treatment remain open.
- Initial payment handling is manual (cash, UPI, bank transfer); no online payment gateway in the first release. Full payment only; no installments.
- One-time wash may be paid after service completion. Payment status remains separate from booking and execution status.
- Correct/overpaid/unpaid payment exception workflows remain to be finalized.

## 10. Service execution and notifications

- A booking may contain multiple service items. Worker can mark each item complete independently.
- Overall execution becomes COMPLETED only when all required service items are completed.
- A completed item may consume only its own subscription entitlement; incomplete items remain unresolved and their entitlements are not consumed.
- The policy for interrupted/failed items, partial refunds or rescheduling must be finalized before implementation.
- Email is the only notification channel for the initial release. SMS/WhatsApp can be added later.
- Delivery status SENT means the provider accepted the message; it does not prove the recipient read it.
- The email address requirement/verification policy for users who sign up with mobile only remains open.

## 11. Security

- Authentication Service supports email/password or mobile/password. At least one normalized identifier is required; any provided identifier must be unique.
- Store password hashes only, using Spring Security PasswordEncoder.
- JWT access tokens are validated by each protected service. Refresh-token metadata, if refresh sessions are enabled, stores token hashes rather than raw tokens.
- Public registration must not permit self-assignment of ADMIN or SERVICE_PERSON roles.
- Enforce resource ownership: customers access only their own vehicles and bookings; workers update only assigned jobs; Admin actions require explicit authorization.
- Keep secrets and credentials out of Git. Use secure configuration locally and AWS Secrets Manager or an equivalent production secret store.
- Apply least-privilege database credentials and role permissions.

## 12. Local development and deployment direction

- Local: separate Spring Boot services, PostgreSQL databases per service, and Kafka; Docker Compose can simplify integration testing.
- Containerize each service with Docker.
- Kubernetes: learn Deployments, Services, ConfigMaps, Secrets, health probes, resource limits and ingress.
- AWS target: EKS for Kubernetes, ECR for image storage, RDS for PostgreSQL, and consider MSK for managed Kafka. Final production architecture, networking, monitoring, backups, recovery, CI/CD and costs require a separate deployment design.
- Start with a learning/development setup and avoid leaving costly AWS infrastructure running unnecessarily.

## 13. Current project state

- The repository contains a static marketing website deployed from the develop branch.
- HLD/SRS and database models are design artifacts, not an implemented backend.
- An Identity / Auth PostgreSQL DDL draft is prepared but has not yet been validated against a live PostgreSQL instance.
- No backend microservices, Kafka integration, Docker deployment, Kubernetes manifests or AWS backend deployment are claimed as complete.

## 14. Next work

1. Review and finalize identity_db schema, including identifier/verification and refresh-session policy.
2. Finalize database schemas for all services and validate DDL in PostgreSQL.
3. Define REST/Kafka contracts, cross-service workflows, idempotency and compensation.
4. Implement backend services incrementally, with explanatory code walkthroughs.
5. Add automated tests, containerization, local integration and later AWS deployment.
