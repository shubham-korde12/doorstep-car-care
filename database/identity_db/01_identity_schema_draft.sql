-- DOORSTEP CAR CARE
-- Database: identity_db
-- Purpose: Identity, account authentication, roles, and security-token metadata.
-- PostgreSQL: gen_random_uuid() is available in modern PostgreSQL versions.
-- Run this script while connected to identity_db using a database administrator account.
-- This is a draft. Review application policies before production use.
-- Do not place database passwords, JWT signing secrets, or application credentials in this file.

BEGIN;

CREATE TABLE identity_accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- An account must have at least one login identifier.
    -- The application should trim and normalize identifiers before storing them.
    email VARCHAR(254),
    phone_number VARCHAR(20),

    -- Store a strong password hash produced by Spring Security's PasswordEncoder.
    -- Never store the raw password.
    password_hash VARCHAR(255) NOT NULL,

    account_status VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION'
        CHECK (account_status IN (
            'PENDING_VERIFICATION',
            'ACTIVE',
            'LOCKED',
            'DISABLED'
        )),

    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,

    failed_login_count INTEGER NOT NULL DEFAULT 0
        CHECK (failed_login_count >= 0),
    locked_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_identity_account_has_login_identifier
        CHECK (email IS NOT NULL OR phone_number IS NOT NULL),

    CONSTRAINT ck_identity_email_not_blank
        CHECK (email IS NULL OR (email <> '' AND email = BTRIM(email))),

    CONSTRAINT ck_identity_phone_not_blank
        CHECK (phone_number IS NULL OR
               (phone_number <> '' AND phone_number = BTRIM(phone_number))),

    CONSTRAINT ck_identity_email_verification_requires_email
        CHECK (email IS NOT NULL OR email_verified = FALSE),

    CONSTRAINT ck_identity_phone_verification_requires_phone
        CHECK (phone_number IS NOT NULL OR phone_verified = FALSE)
);

-- Email login is case-insensitive for uniqueness.
CREATE UNIQUE INDEX ux_identity_accounts_email_lower
    ON identity_accounts (LOWER(email))
    WHERE email IS NOT NULL;

-- Store phone numbers in one canonical format (recommended: E.164) in application code.
CREATE UNIQUE INDEX ux_identity_accounts_phone_number
    ON identity_accounts (phone_number)
    WHERE phone_number IS NOT NULL;

CREATE INDEX ix_identity_accounts_status
    ON identity_accounts (account_status);

CREATE TABLE roles (
    role_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_code VARCHAR(30) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    description VARCHAR(250),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_roles_code_not_blank
        CHECK (role_code <> '' AND role_code = BTRIM(role_code))
);

INSERT INTO roles (role_code, display_name, description)
VALUES
    ('CUSTOMER', 'Customer', 'Customer-facing application access'),
    ('SERVICE_PERSON', 'Service Person', 'Worker-facing service operations'),
    ('ADMIN', 'Administrator', 'Administrative access to authorized operations')
ON CONFLICT (role_code) DO NOTHING;

CREATE TABLE account_roles (
    account_id UUID NOT NULL
        REFERENCES identity_accounts (account_id) ON DELETE CASCADE,
    role_id SMALLINT NOT NULL
        REFERENCES roles (role_id) ON DELETE RESTRICT,
    assigned_by_account_id UUID
        REFERENCES identity_accounts (account_id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_account_roles PRIMARY KEY (account_id, role_id)
);

CREATE INDEX ix_account_roles_role_id
    ON account_roles (role_id);

-- Only token hashes are stored here, never raw refresh tokens.
-- The application must rotate refresh tokens and revoke them on logout/reuse detection.
CREATE TABLE refresh_tokens (
    refresh_token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL
        REFERENCES identity_accounts (account_id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    token_family_id UUID NOT NULL DEFAULT gen_random_uuid(),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revoked_reason VARCHAR(100),
    replaced_by_token_id UUID
        REFERENCES refresh_tokens (refresh_token_id) ON DELETE SET NULL,

    CONSTRAINT ck_refresh_token_expiry
        CHECK (expires_at > issued_at)
);

CREATE INDEX ix_refresh_tokens_account_expiry
    ON refresh_tokens (account_id, expires_at);

CREATE INDEX ix_refresh_tokens_active_by_family
    ON refresh_tokens (token_family_id, expires_at)
    WHERE revoked_at IS NULL;

-- Password-reset secrets are hashed and single-use.
CREATE TABLE password_reset_tokens (
    reset_token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL
        REFERENCES identity_accounts (account_id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,

    CONSTRAINT ck_password_reset_token_expiry
        CHECK (expires_at > created_at)
);

CREATE INDEX ix_password_reset_tokens_account_expiry
    ON password_reset_tokens (account_id, expires_at);

-- Supports verification workflows for email/mobile identifiers.
-- Exact policy (which identifiers must be verified and when) remains a business decision.
CREATE TABLE identity_verification_challenges (
    verification_challenge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL
        REFERENCES identity_accounts (account_id) ON DELETE CASCADE,
    challenge_type VARCHAR(30) NOT NULL
        CHECK (challenge_type IN ('EMAIL_VERIFICATION', 'PHONE_VERIFICATION')),
    destination_snapshot VARCHAR(254) NOT NULL,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    attempt_count INTEGER NOT NULL DEFAULT 0
        CHECK (attempt_count >= 0),

    CONSTRAINT ck_verification_challenge_expiry
        CHECK (expires_at > created_at)
);

CREATE INDEX ix_verification_challenges_account_type
    ON identity_verification_challenges (account_id, challenge_type, expires_at);

COMMENT ON TABLE identity_accounts IS
    'Identity and login account data. User profile, vehicle, society, booking, and subscription data belong to other services.';
COMMENT ON COLUMN identity_accounts.phone_number IS
    'Normalize to a canonical international format in application code before storage.';
COMMENT ON COLUMN identity_accounts.password_hash IS
    'Store only a secure password hash produced by Spring Security PasswordEncoder.';
COMMENT ON TABLE account_roles IS
    'Role assignments. Public registration must never permit self-assignment of ADMIN or SERVICE_PERSON.';
COMMENT ON TABLE refresh_tokens IS
    'Stores refresh-token hashes and revocation metadata; raw refresh tokens must never be stored.';
COMMENT ON TABLE password_reset_tokens IS
    'Stores hashed, expiring, single-use password-reset tokens.';
COMMENT ON TABLE identity_verification_challenges IS
    'Supports email/phone verification. Activation policy and delivery flow must be defined before production.';

COMMIT;
