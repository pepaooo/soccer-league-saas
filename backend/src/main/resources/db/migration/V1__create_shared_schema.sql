-- ============================================================================
-- V1: Create Shared Schema (Platform-level tables)
-- ============================================================================
-- This migration creates the 'public' schema with platform-level tables:
-- - tenants: Field owner accounts
-- - subscriptions: Billing records
-- - platform_users: Admin users
-- - payment_transactions: Payment history
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS public;

-- ============================================================================
-- TRIGGER FUNCTION: Update updated_at timestamp
-- ============================================================================
-- This function is used by triggers to automatically update the updated_at
-- column whenever a row is modified
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TABLE: tenants
-- ============================================================================
-- Stores field owner (customer) accounts. Each tenant gets an isolated
-- PostgreSQL schema for their data.
-- ============================================================================

CREATE TABLE public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Business Information
    tenant_key VARCHAR(50) UNIQUE NOT NULL,  -- URL-safe: 'canchas-xyz'
    schema_name VARCHAR(63) NOT NULL,        -- PostgreSQL schema: 'tenant_canchas_xyz'
    business_name VARCHAR(200) NOT NULL,
    owner_name VARCHAR(150),

    -- Contact
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20),

    -- Subscription
    subscription_plan VARCHAR(50) NOT NULL DEFAULT 'basic',
    subscription_status VARCHAR(30) NOT NULL DEFAULT 'active',

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_tenant_key_format
        CHECK (tenant_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT check_subscription_plan
        CHECK (subscription_plan IN ('basic', 'pro', 'enterprise')),
    CONSTRAINT check_subscription_status
        CHECK (subscription_status IN ('active', 'suspended', 'cancelled', 'trial'))
);

-- Indexes for tenants
CREATE INDEX idx_tenants_tenant_key ON public.tenants(tenant_key);
CREATE INDEX idx_tenants_email ON public.tenants(email);
CREATE INDEX idx_tenants_subscription_status ON public.tenants(subscription_status);

-- Trigger for updated_at
CREATE TRIGGER update_tenants_updated_at
BEFORE UPDATE ON public.tenants
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE public.tenants IS 'Field owner accounts - each tenant gets an isolated schema';
COMMENT ON COLUMN public.tenants.tenant_key IS 'URL-safe identifier used in subdomains (e.g., canchas-xyz)';
COMMENT ON COLUMN public.tenants.schema_name IS 'PostgreSQL schema name (e.g., tenant_canchas_xyz)';

-- ============================================================================
-- TABLE: subscriptions
-- ============================================================================
-- Tracks subscription history and billing information
-- ============================================================================

CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

    -- Plan Details
    plan_name VARCHAR(50) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,  -- 'monthly', 'yearly'
    amount_cents INTEGER NOT NULL,       -- Store in cents to avoid decimals
    currency VARCHAR(3) DEFAULT 'MXN',

    -- Billing Dates
    start_date DATE NOT NULL,
    end_date DATE,
    next_billing_date DATE,

    -- Payment
    auto_renew BOOLEAN DEFAULT TRUE,
    payment_method VARCHAR(50),          -- 'stripe', 'openpay', 'mercadopago'
    external_subscription_id VARCHAR(100),  -- Stripe/OpenPay subscription ID

    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'active',

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_billing_cycle
        CHECK (billing_cycle IN ('monthly', 'yearly')),
    CONSTRAINT check_subscription_status_sub
        CHECK (status IN ('active', 'cancelled', 'past_due', 'unpaid'))
);

-- Indexes for subscriptions
CREATE INDEX idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_next_billing_date ON public.subscriptions(next_billing_date);

-- Trigger for updated_at
CREATE TRIGGER update_subscriptions_updated_at
BEFORE UPDATE ON public.subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE public.subscriptions IS 'Subscription records and billing information';
COMMENT ON COLUMN public.subscriptions.amount_cents IS 'Amount in cents to avoid floating point precision issues';

-- ============================================================================
-- TABLE: platform_users
-- ============================================================================
-- Users who can access tenant dashboards (admins)
-- ============================================================================

CREATE TABLE public.platform_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

    -- Credentials
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,  -- BCrypt hash

    -- Profile
    full_name VARCHAR(150),
    role VARCHAR(30) NOT NULL DEFAULT 'tenant_admin',

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_user_role
        CHECK (role IN ('tenant_admin', 'platform_admin', 'tenant_viewer'))
);

-- Indexes for platform_users
CREATE INDEX idx_platform_users_email ON public.platform_users(email);
CREATE INDEX idx_platform_users_tenant_id ON public.platform_users(tenant_id);

-- Trigger for updated_at
CREATE TRIGGER update_platform_users_updated_at
BEFORE UPDATE ON public.platform_users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE public.platform_users IS 'Platform users with access to tenant dashboards';
COMMENT ON COLUMN public.platform_users.password_hash IS 'BCrypt hash with cost factor 12';

-- ============================================================================
-- TABLE: payment_transactions
-- ============================================================================
-- Log of all payment attempts and results
-- ============================================================================

CREATE TABLE public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id),
    subscription_id UUID REFERENCES public.subscriptions(id),

    -- Transaction Details
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'MXN',
    payment_method VARCHAR(50) NOT NULL,
    external_transaction_id VARCHAR(100),  -- Stripe/OpenPay transaction ID

    -- Status
    status VARCHAR(30) NOT NULL,  -- 'pending', 'completed', 'failed', 'refunded'
    failure_reason TEXT,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_payment_status
        CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
);

-- Indexes for payment_transactions
CREATE INDEX idx_payment_transactions_tenant_id ON public.payment_transactions(tenant_id);
CREATE INDEX idx_payment_transactions_subscription_id ON public.payment_transactions(subscription_id);
CREATE INDEX idx_payment_transactions_status ON public.payment_transactions(status);
CREATE INDEX idx_payment_transactions_created_at ON public.payment_transactions(created_at DESC);

COMMENT ON TABLE public.payment_transactions IS 'Immutable log of all payment attempts';
COMMENT ON COLUMN public.payment_transactions.external_transaction_id IS 'Reference ID from payment gateway';

-- ============================================================================
-- FUNCTION: create_tenant_schema
-- ============================================================================
-- Creates a new tenant schema with all tables from the template
-- This function reads V2__create_tenant_schema_template.sql and executes it
-- with the actual schema name
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_tenant_schema(tenant_key_param VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    schema_name VARCHAR;
BEGIN
    -- Generate schema name (replace hyphens with underscores)
    schema_name := 'tenant_' || REPLACE(tenant_key_param, '-', '_');

    -- Validate schema name doesn't already exist
    IF EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = schema_name
    ) THEN
        RAISE EXCEPTION 'Schema % already exists', schema_name;
    END IF;

    -- Note: The actual table creation is done by executing the template SQL
    -- This function is a placeholder for the Java/service layer to coordinate
    -- tenant provisioning. The template (V2) contains all table definitions.

    RETURN schema_name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.create_tenant_schema IS 'Helper function for tenant provisioning - returns schema name';
