# DATABASE_SCHEMA.md - Complete Database Design

## 🗄️ Database Overview

**Database Name**: `ligamanager`  
**DBMS**: PostgreSQL 15+  
**Multi-Tenancy Strategy**: Schema-per-Tenant  
**Character Set**: UTF-8  
**Timezone**: UTC

---

## 📊 Schema Architecture

```
ligamanager (Database)
│
├── public (Shared Schema)
│   ├── tenants
│   ├── subscriptions
│   ├── platform_users
│   └── payment_transactions
│
├── tenant_canchas_xyz (Tenant Schema #1)
│   ├── leagues
│   ├── teams
│   ├── players
│   ├── matches
│   ├── match_events
│   └── standings
│
├── tenant_complejo_abc (Tenant Schema #2)
│   ├── leagues
│   ├── teams
│   └── ... (same structure)
│
└── tenant_liga_norte (Tenant Schema #3)
    └── ... (same structure)
```

---

## 🏢 Shared Schema (public)

### Table: `tenants`

Stores field owner (customer) accounts.

```sql
CREATE TABLE public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Business Information
    tenant_key VARCHAR(50) UNIQUE NOT NULL,  -- URL-safe: 'canchas-xyz'
    schema_name VARCHAR(63) NOT NULL,        -- 'tenant_canchas_xyz'
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

-- Indexes
CREATE INDEX idx_tenants_tenant_key ON public.tenants(tenant_key);
CREATE INDEX idx_tenants_email ON public.tenants(email);
CREATE INDEX idx_tenants_subscription_status ON public.tenants(subscription_status);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenants_updated_at
BEFORE UPDATE ON public.tenants
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
```

**Sample Data:**
```sql
INSERT INTO public.tenants (tenant_key, schema_name, business_name, owner_name, email, phone, subscription_plan)
VALUES 
    ('canchas-del-norte', 'tenant_canchas_del_norte', 'Canchas del Norte', 'Juan Pérez', 'juan@example.com', '+52 55 1234 5678', 'pro'),
    ('complejo-deportivo-abc', 'tenant_complejo_deportivo_abc', 'Complejo Deportivo ABC', 'María García', 'maria@example.com', '+52 55 9876 5432', 'basic');
```

---

### Table: `subscriptions`

Tracks subscription history and billing.

```sql
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
    
    CONSTRAINT check_billing_cycle 
        CHECK (billing_cycle IN ('monthly', 'yearly')),
    CONSTRAINT check_subscription_status_sub 
        CHECK (status IN ('active', 'cancelled', 'past_due', 'unpaid'))
);

CREATE INDEX idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_next_billing_date ON public.subscriptions(next_billing_date);
```

---

### Table: `platform_users`

Users who can access tenant dashboards (admins).

```sql
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
    
    CONSTRAINT check_user_role 
        CHECK (role IN ('tenant_admin', 'platform_admin', 'tenant_viewer'))
);

CREATE INDEX idx_platform_users_email ON public.platform_users(email);
CREATE INDEX idx_platform_users_tenant_id ON public.platform_users(tenant_id);

-- Unique constraint: One admin per tenant (optional, can have multiple)
-- CREATE UNIQUE INDEX idx_one_admin_per_tenant 
--     ON public.platform_users(tenant_id) 
--     WHERE role = 'tenant_admin';
```

---

### Table: `payment_transactions`

Log of all payment attempts.

```sql
CREATE TABLE public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id),
    subscription_id UUID REFERENCES public.subscriptions(id),
    
    -- Transaction Details
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'MXN',
    payment_method VARCHAR(50) NOT NULL,
    external_transaction_id VARCHAR(100),
    
    -- Status
    status VARCHAR(30) NOT NULL,  -- 'pending', 'completed', 'failed', 'refunded'
    failure_reason TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_payment_status 
        CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
);

CREATE INDEX idx_payment_transactions_tenant_id ON public.payment_transactions(tenant_id);
CREATE INDEX idx_payment_transactions_status ON public.payment_transactions(status);
CREATE INDEX idx_payment_transactions_created_at ON public.payment_transactions(created_at DESC);
```

---

## ⚽ Tenant Schema Template

Each tenant gets an identical schema structure. Replace `__SCHEMA__` with actual schema name.

### Table: `leagues`

```sql
CREATE TABLE __SCHEMA__.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- League Info
    name VARCHAR(150) NOT NULL,
    season VARCHAR(50),               -- 'Apertura 2025', 'Clausura 2025'
    
    -- Dates
    start_date DATE,
    end_date DATE,
    
    -- Configuration
    league_type VARCHAR(50) NOT NULL DEFAULT 'futbol_7',
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_league_type 
        CHECK (league_type IN ('futbol_5', 'futbol_7', 'futbol_11')),
    CONSTRAINT check_league_status 
        CHECK (status IN ('draft', 'active', 'finished', 'cancelled')),
    CONSTRAINT check_dates 
        CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_leagues_status ON __SCHEMA__.leagues(status);
CREATE INDEX idx_leagues_season ON __SCHEMA__.leagues(season);

-- Unique constraint: League name per season
CREATE UNIQUE INDEX idx_unique_league_name_season 
    ON __SCHEMA__.leagues(name, season) 
    WHERE status != 'cancelled';
```

---

### Table: `teams`

```sql
CREATE TABLE __SCHEMA__.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __SCHEMA__.leagues(id) ON DELETE CASCADE,
    
    -- Team Info
    name VARCHAR(150) NOT NULL,
    logo_url TEXT,
    
    -- Captain/Contact
    captain_name VARCHAR(150),
    captain_phone VARCHAR(20),
    captain_email VARCHAR(150),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_teams_league_id ON __SCHEMA__.teams(league_id);
CREATE INDEX idx_teams_name ON __SCHEMA__.teams(name);

-- Unique constraint: Team name per league
CREATE UNIQUE INDEX idx_unique_team_name_per_league 
    ON __SCHEMA__.teams(league_id, name);
```

---

### Table: `players`

```sql
CREATE TABLE __SCHEMA__.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES __SCHEMA__.teams(id) ON DELETE CASCADE,
    
    -- Player Info
    full_name VARCHAR(150) NOT NULL,
    birth_date DATE,
    
    -- Position
    position VARCHAR(30),             -- 'goalkeeper', 'defender', 'midfielder', 'forward'
    jersey_number VARCHAR(3),         -- '10', '7', '1'
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_position 
        CHECK (position IN ('goalkeeper', 'defender', 'midfielder', 'forward') OR position IS NULL)
);

CREATE INDEX idx_players_team_id ON __SCHEMA__.players(team_id);
CREATE INDEX idx_players_name ON __SCHEMA__.players(full_name);
CREATE INDEX idx_players_is_active ON __SCHEMA__.players(is_active);

-- Unique constraint: Jersey number per team (only active players)
CREATE UNIQUE INDEX idx_unique_jersey_per_team 
    ON __SCHEMA__.players(team_id, jersey_number) 
    WHERE is_active = TRUE AND jersey_number IS NOT NULL;

-- Function to calculate age
CREATE OR REPLACE FUNCTION __SCHEMA__.calculate_age(birth_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date))::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

---

### Table: `matches`

```sql
CREATE TABLE __SCHEMA__.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __SCHEMA__.leagues(id) ON DELETE CASCADE,
    
    -- Teams
    home_team_id UUID NOT NULL REFERENCES __SCHEMA__.teams(id),
    away_team_id UUID NOT NULL REFERENCES __SCHEMA__.teams(id),
    
    -- Schedule
    scheduled_at TIMESTAMP NOT NULL,
    field_name VARCHAR(100),          -- 'Cancha 1', 'Cancha Principal'
    
    -- Result
    home_score INTEGER,
    away_score INTEGER,
    
    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'scheduled',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_different_teams 
        CHECK (home_team_id != away_team_id),
    CONSTRAINT check_scores_non_negative 
        CHECK (
            (home_score IS NULL OR home_score >= 0) AND 
            (away_score IS NULL OR away_score >= 0)
        ),
    CONSTRAINT check_match_status 
        CHECK (status IN ('scheduled', 'in_progress', 'finished', 'cancelled', 'postponed'))
);

CREATE INDEX idx_matches_league_id ON __SCHEMA__.matches(league_id);
CREATE INDEX idx_matches_scheduled_at ON __SCHEMA__.matches(scheduled_at);
CREATE INDEX idx_matches_home_team_id ON __SCHEMA__.matches(home_team_id);
CREATE INDEX idx_matches_away_team_id ON __SCHEMA__.matches(away_team_id);
CREATE INDEX idx_matches_status ON __SCHEMA__.matches(status);

-- Composite index for team's schedule
CREATE INDEX idx_matches_team_schedule 
    ON __SCHEMA__.matches(home_team_id, scheduled_at) 
    WHERE status != 'cancelled';
```

---

### Table: `match_events`

```sql
CREATE TABLE __SCHEMA__.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES __SCHEMA__.matches(id) ON DELETE CASCADE,
    player_id UUID REFERENCES __SCHEMA__.players(id) ON DELETE SET NULL,
    
    -- Event Details
    minute INTEGER NOT NULL,          -- Match minute (0-90+)
    event_type VARCHAR(30) NOT NULL,  -- 'goal', 'yellow_card', 'red_card', 'substitution'
    description TEXT,                 -- Optional notes
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_minute_valid 
        CHECK (minute >= 0 AND minute <= 120),  -- Extra time
    CONSTRAINT check_event_type 
        CHECK (event_type IN ('goal', 'yellow_card', 'red_card', 'substitution', 'own_goal'))
);

CREATE INDEX idx_match_events_match_id ON __SCHEMA__.match_events(match_id);
CREATE INDEX idx_match_events_player_id ON __SCHEMA__.match_events(player_id);
CREATE INDEX idx_match_events_type ON __SCHEMA__.match_events(event_type);

-- Ordered by minute for timeline display
CREATE INDEX idx_match_events_timeline 
    ON __SCHEMA__.match_events(match_id, minute);
```

---

### Table: `standings`

```sql
CREATE TABLE __SCHEMA__.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __SCHEMA__.leagues(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES __SCHEMA__.teams(id) ON DELETE CASCADE,
    
    -- Match Statistics
    played INTEGER DEFAULT 0 NOT NULL,
    won INTEGER DEFAULT 0 NOT NULL,
    drawn INTEGER DEFAULT 0 NOT NULL,
    lost INTEGER DEFAULT 0 NOT NULL,
    
    -- Goals
    goals_for INTEGER DEFAULT 0 NOT NULL,
    goals_against INTEGER DEFAULT 0 NOT NULL,
    
    -- Points (3 for win, 1 for draw, 0 for loss)
    points INTEGER DEFAULT 0 NOT NULL,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT check_played_matches 
        CHECK (played = won + drawn + lost),
    CONSTRAINT check_points_calculation 
        CHECK (points = (won * 3) + drawn),
    
    -- Unique standing per team per league
    UNIQUE(league_id, team_id)
);

CREATE INDEX idx_standings_league_id ON __SCHEMA__.standings(league_id);
CREATE INDEX idx_standings_points ON __SCHEMA__.standings(points DESC);

-- Composite index for standings table sort
CREATE INDEX idx_standings_sort 
    ON __SCHEMA__.standings(league_id, points DESC, goals_for DESC, goals_against ASC);

-- Virtual column for goal difference
ALTER TABLE __SCHEMA__.standings 
ADD COLUMN goal_difference INTEGER GENERATED ALWAYS AS (goals_for - goals_against) STORED;
```

---

## 🔧 Useful Functions & Procedures

### Function: Create Tenant Schema

```sql
CREATE OR REPLACE FUNCTION public.create_tenant_schema(tenant_key VARCHAR)
RETURNS VOID AS $$
DECLARE
    schema_name VARCHAR;
    sql_template TEXT;
BEGIN
    -- Generate schema name
    schema_name := 'tenant_' || REPLACE(tenant_key, '-', '_');
    
    -- Create schema
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', schema_name);
    
    -- Read template SQL and execute (simplified version)
    -- In production, read from file or use Flyway migration
    
    -- Create leagues table
    EXECUTE format('
        CREATE TABLE %I.leagues (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name VARCHAR(150) NOT NULL,
            season VARCHAR(50),
            start_date DATE,
            end_date DATE,
            league_type VARCHAR(50) NOT NULL DEFAULT ''futbol_7'',
            status VARCHAR(30) NOT NULL DEFAULT ''draft'',
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        )', schema_name);
    
    -- Create other tables (teams, players, matches, etc.)
    -- ... (repeat for each table)
    
    RAISE NOTICE 'Tenant schema % created successfully', schema_name;
END;
$$ LANGUAGE plpgsql;

-- Usage
SELECT public.create_tenant_schema('canchas-del-norte');
```

---

### Function: Update Standings After Match

```sql
CREATE OR REPLACE FUNCTION __SCHEMA__.update_standings_after_match(match_id_param UUID)
RETURNS VOID AS $$
DECLARE
    match_record RECORD;
    home_points INTEGER;
    away_points INTEGER;
BEGIN
    -- Get match details
    SELECT * INTO match_record
    FROM __SCHEMA__.matches
    WHERE id = match_id_param AND status = 'finished';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Match not found or not finished';
    END IF;
    
    -- Calculate points
    IF match_record.home_score > match_record.away_score THEN
        home_points := 3;
        away_points := 0;
    ELSIF match_record.home_score < match_record.away_score THEN
        home_points := 0;
        away_points := 3;
    ELSE
        home_points := 1;
        away_points := 1;
    END IF;
    
    -- Update home team standing
    INSERT INTO __SCHEMA__.standings (league_id, team_id, played, won, drawn, lost, goals_for, goals_against, points)
    VALUES (
        match_record.league_id,
        match_record.home_team_id,
        1,
        CASE WHEN home_points = 3 THEN 1 ELSE 0 END,
        CASE WHEN home_points = 1 THEN 1 ELSE 0 END,
        CASE WHEN home_points = 0 THEN 1 ELSE 0 END,
        match_record.home_score,
        match_record.away_score,
        home_points
    )
    ON CONFLICT (league_id, team_id) DO UPDATE SET
        played = standings.played + 1,
        won = standings.won + CASE WHEN home_points = 3 THEN 1 ELSE 0 END,
        drawn = standings.drawn + CASE WHEN home_points = 1 THEN 1 ELSE 0 END,
        lost = standings.lost + CASE WHEN home_points = 0 THEN 1 ELSE 0 END,
        goals_for = standings.goals_for + match_record.home_score,
        goals_against = standings.goals_against + match_record.away_score,
        points = standings.points + home_points,
        updated_at = NOW();
    
    -- Update away team standing (similar logic)
    INSERT INTO __SCHEMA__.standings (league_id, team_id, played, won, drawn, lost, goals_for, goals_against, points)
    VALUES (
        match_record.league_id,
        match_record.away_team_id,
        1,
        CASE WHEN away_points = 3 THEN 1 ELSE 0 END,
        CASE WHEN away_points = 1 THEN 1 ELSE 0 END,
        CASE WHEN away_points = 0 THEN 1 ELSE 0 END,
        match_record.away_score,
        match_record.home_score,
        away_points
    )
    ON CONFLICT (league_id, team_id) DO UPDATE SET
        played = standings.played + 1,
        won = standings.won + CASE WHEN away_points = 3 THEN 1 ELSE 0 END,
        drawn = standings.drawn + CASE WHEN away_points = 1 THEN 1 ELSE 0 END,
        lost = standings.lost + CASE WHEN away_points = 0 THEN 1 ELSE 0 END,
        goals_for = standings.goals_for + match_record.away_score,
        goals_against = standings.goals_against + match_record.home_score,
        points = standings.points + away_points,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

---

## 📊 Common Queries

### Get League Standings (Sorted)

```sql
SELECT 
    ROW_NUMBER() OVER (ORDER BY s.points DESC, s.goal_difference DESC, s.goals_for DESC) AS position,
    t.name AS team_name,
    t.logo_url,
    s.played,
    s.won,
    s.drawn,
    s.lost,
    s.goals_for,
    s.goals_against,
    s.goal_difference,
    s.points
FROM __SCHEMA__.standings s
JOIN __SCHEMA__.teams t ON s.team_id = t.id
WHERE s.league_id = :league_id
ORDER BY s.points DESC, s.goal_difference DESC, s.goals_for DESC;
```

---

### Get Top Scorers

```sql
SELECT 
    p.id,
    p.full_name,
    p.jersey_number,
    t.name AS team_name,
    COUNT(me.id) AS goals
FROM __SCHEMA__.match_events me
JOIN __SCHEMA__.players p ON me.player_id = p.id
JOIN __SCHEMA__.teams t ON p.team_id = t.id
JOIN __SCHEMA__.matches m ON me.match_id = m.id
WHERE m.league_id = :league_id
  AND me.event_type = 'goal'
  AND m.status = 'finished'
GROUP BY p.id, p.full_name, p.jersey_number, t.name
ORDER BY goals DESC
LIMIT 10;
```

---

### Get Team's Upcoming Matches

```sql
SELECT 
    m.id,
    m.scheduled_at,
    m.field_name,
    CASE 
        WHEN m.home_team_id = :team_id THEN 'HOME'
        ELSE 'AWAY'
    END AS location,
    CASE 
        WHEN m.home_team_id = :team_id THEN away.name
        ELSE home.name
    END AS opponent_name,
    CASE 
        WHEN m.home_team_id = :team_id THEN away.logo_url
        ELSE home.logo_url
    END AS opponent_logo,
    m.status
FROM __SCHEMA__.matches m
JOIN __SCHEMA__.teams home ON m.home_team_id = home.id
JOIN __SCHEMA__.teams away ON m.away_team_id = away.id
WHERE (m.home_team_id = :team_id OR m.away_team_id = :team_id)
  AND m.status IN ('scheduled', 'in_progress')
  AND m.scheduled_at >= NOW()
ORDER BY m.scheduled_at ASC
LIMIT 5;
```

---

### Get Match Timeline (Events)

```sql
SELECT 
    me.minute,
    me.event_type,
    p.full_name AS player_name,
    p.jersey_number,
    t.name AS team_name,
    me.description
FROM __SCHEMA__.match_events me
JOIN __SCHEMA__.players p ON me.player_id = p.id
JOIN __SCHEMA__.teams t ON p.team_id = t.id
WHERE me.match_id = :match_id
ORDER BY me.minute ASC, me.created_at ASC;
```

---

## 🔐 Security & Permissions

### Row-Level Security (RLS) - Optional

If you want database-level tenant isolation:

```sql
-- Enable RLS on tenant tables
ALTER TABLE __SCHEMA__.leagues ENABLE ROW LEVEL SECURITY;

-- Create policy (example for application role)
CREATE POLICY tenant_isolation ON __SCHEMA__.leagues
    FOR ALL
    TO app_role
    USING (true);  -- Application handles tenant filtering
```

**Note**: For schema-per-tenant, RLS is optional since schemas are already isolated.

---

### Database Roles

```sql
-- Application role (used by Spring Boot)
CREATE ROLE app_role WITH LOGIN PASSWORD 'secure_password_here';

-- Grant schema creation permission (for tenant provisioning)
GRANT CREATE ON DATABASE ligamanager TO app_role;

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_role;

-- Grant usage on tenant schemas (dynamically after creation)
-- GRANT USAGE ON SCHEMA tenant_xyz TO app_role;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant_xyz TO app_role;
```

---

## 📈 Performance Optimization

### Recommended Indexes

Already included in table definitions above, but summary:

**Shared Schema:**
- `tenants.tenant_key`, `tenants.email` → Lookups
- `subscriptions.tenant_id`, `subscriptions.next_billing_date` → Billing jobs
- `platform_users.email`, `platform_users.tenant_id` → Authentication

**Tenant Schema:**
- `teams.league_id` → League queries
- `players.team_id`, `players.name` → Roster queries
- `matches.scheduled_at`, `matches.league_id` → Calendar views
- `standings.league_id, points DESC` → Standings table

### Partitioning (Future Optimization)

For very large tenants (10,000+ matches), consider partitioning:

```sql
-- Partition matches by year
CREATE TABLE __SCHEMA__.matches_2025 PARTITION OF __SCHEMA__.matches
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE __SCHEMA__.matches_2026 PARTITION OF __SCHEMA__.matches
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
```

---

## 🧹 Maintenance Tasks

### Weekly Vacuum

```sql
-- Run weekly
VACUUM ANALYZE public.tenants;
VACUUM ANALYZE tenant_xyz.matches;
```

### Archive Old Data

```sql
-- Archive finished leagues older than 2 years
UPDATE __SCHEMA__.leagues 
SET status = 'archived' 
WHERE status = 'finished' 
  AND end_date < NOW() - INTERVAL '2 years';
```

### Monitor Schema Count

```sql
-- Check number of tenant schemas
SELECT COUNT(*) AS tenant_count
FROM information_schema.schemata
WHERE schema_name LIKE 'tenant_%';
```

---

## 🔍 Troubleshooting Queries

### Find Orphaned Data

```sql
-- Teams without league (shouldn't happen due to FK)
SELECT t.id, t.name
FROM __SCHEMA__.teams t
LEFT JOIN __SCHEMA__.leagues l ON t.league_id = l.id
WHERE l.id IS NULL;
```

### Verify Standings Accuracy

```sql
-- Compare calculated vs stored standings
WITH calculated AS (
    SELECT 
        m.league_id,
        m.home_team_id AS team_id,
        COUNT(*) AS played,
        SUM(CASE WHEN m.home_score > m.away_score THEN 1 ELSE 0 END) AS won,
        SUM(CASE WHEN m.home_score = m.away_score THEN 1 ELSE 0 END) AS drawn,
        SUM(CASE WHEN m.home_score < m.away_score THEN 1 ELSE 0 END) AS lost,
        SUM(m.home_score) AS goals_for,
        SUM(m.away_score) AS goals_against,
        SUM(CASE 
            WHEN m.home_score > m.away_score THEN 3
            WHEN m.home_score = m.away_score THEN 1
            ELSE 0
        END) AS points
    FROM __SCHEMA__.matches m
    WHERE m.status = 'finished'
    GROUP BY m.league_id, m.home_team_id
)
SELECT 
    c.team_id,
    c.points AS calculated_points,
    s.points AS stored_points,
    c.points - s.points AS difference
FROM calculated c
JOIN __SCHEMA__.standings s ON c.league_id = s.league_id AND c.team_id = s.team_id
WHERE c.points != s.points;
```

---

## 📚 Schema Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-15 | Initial schema design |
| 1.1 | 2025-02-01 | Added `goal_difference` computed column |
| 1.2 | 2025-03-01 | Added `payment_transactions` table |

---

*Last Updated: January 2025*
