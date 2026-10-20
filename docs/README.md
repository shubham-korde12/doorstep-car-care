# Project Documentation

This folder contains the current design baseline for DOORSTEP CAR CARE.

## Documents

- [High-Level Design (HLD)](HLD.md) — system architecture, actors, microservices, data ownership, communication principles, security and deployment direction.
- [Software Requirements Specification (SRS)](SRS.md) — functional and non-functional requirements with traceable requirement IDs.
- [Architecture Decision Log](DECISION-LOG.md) — recorded decisions and open items.

## Database scripts

- [Identity/Auth schema draft](../database/identity_db/01_identity_schema_draft.sql) — initial PostgreSQL DDL draft for identity, roles, token metadata and verification challenges.

## Status and caveats

These documents record the current working design from project planning discussions. They are not proof that the backend has been implemented. The Identity/Auth SQL has not yet been executed against PostgreSQL; it requires review and validation before being treated as finalized.

Open business and implementation decisions are explicitly listed in the design documents. Keep these documents updated when decisions change.
