-- NOTE: This is a TEMPLATE. Replace __TENANT_SCHEMA__ with actual schema name
-- when provisioning new tenant (e.g., tenant_canchas_xyz)

CREATE SCHEMA IF NOT EXISTS __TENANT_SCHEMA__;

-- Leagues
CREATE TABLE __TENANT_SCHEMA__.leagues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    season VARCHAR(50),
    start_date DATE,
    end_date DATE,
    league_type VARCHAR(50) NOT NULL DEFAULT 'FUTBOL_7',
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Teams
CREATE TABLE __TENANT_SCHEMA__.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    logo_url TEXT,
    captain_name VARCHAR(150),
    captain_phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Players
CREATE TABLE __TENANT_SCHEMA__.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,
    birth_date DATE,
    position VARCHAR(30),
    jersey_number VARCHAR(3),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Matches
CREATE TABLE __TENANT_SCHEMA__.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    home_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),
    away_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),
    scheduled_at TIMESTAMP NOT NULL,
    field_name VARCHAR(100),
    home_score INTEGER,
    away_score INTEGER,
    status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_different_teams CHECK (home_team_id != away_team_id)
);

-- Match Events
CREATE TABLE __TENANT_SCHEMA__.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.matches(id) ON DELETE CASCADE,
    player_id UUID REFERENCES __TENANT_SCHEMA__.players(id) ON DELETE SET NULL,
    minute INTEGER NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Standings
CREATE TABLE __TENANT_SCHEMA__.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,
    played INTEGER DEFAULT 0,
    won INTEGER DEFAULT 0,
    drawn INTEGER DEFAULT 0,
    lost INTEGER DEFAULT 0,
    goals_for INTEGER DEFAULT 0,
    goals_against INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(league_id, team_id)
);

-- Indexes for performance
CREATE INDEX idx_teams_league_id ON __TENANT_SCHEMA__.teams(league_id);
CREATE INDEX idx_players_team_id ON __TENANT_SCHEMA__.players(team_id);
CREATE INDEX idx_matches_league_id ON __TENANT_SCHEMA__.matches(league_id);
CREATE INDEX idx_matches_scheduled_at ON __TENANT_SCHEMA__.matches(scheduled_at);
CREATE INDEX idx_match_events_match_id ON __TENANT_SCHEMA__.match_events(match_id);
CREATE INDEX idx_standings_league_id ON __TENANT_SCHEMA__.standings(league_id);
CREATE INDEX idx_standings_points ON __TENANT_SCHEMA__.standings(points DESC);