-- ============================================================================
-- V2: Tenant Schema Template
-- ============================================================================
-- IMPORTANT: This is a TEMPLATE file. Replace __TENANT_SCHEMA__ with the
-- actual schema name when provisioning a new tenant.
--
-- Example: For tenant 'canchas-xyz', replace all instances of
-- __TENANT_SCHEMA__ with 'tenant_canchas_xyz'
--
-- Tables created:
-- - leagues: Tournament/league configurations
-- - teams: Teams enrolled in leagues
-- - players: Player rosters for teams
-- - matches: Scheduled and completed matches
-- - match_events: Goals, cards, substitutions during matches
-- - standings: Auto-calculated league standings
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS __TENANT_SCHEMA__;

-- ============================================================================
-- HELPER FUNCTIONS (Tenant-specific)
-- ============================================================================

-- Function: Calculate player age from birth date
CREATE OR REPLACE FUNCTION __TENANT_SCHEMA__.calculate_age(birth_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date))::INTEGER;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION __TENANT_SCHEMA__.calculate_age IS 'Calculates age in years from birth date';

-- ============================================================================
-- TABLE: leagues
-- ============================================================================
-- Stores league/tournament configurations for a tenant
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.leagues (
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

    -- Constraints
    CONSTRAINT check_league_type
        CHECK (league_type IN ('futbol_5', 'futbol_7', 'futbol_11')),
    CONSTRAINT check_league_status
        CHECK (status IN ('draft', 'active', 'finished', 'cancelled')),
    CONSTRAINT check_dates
        CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Indexes for leagues
CREATE INDEX idx_leagues_status ON __TENANT_SCHEMA__.leagues(status);
CREATE INDEX idx_leagues_season ON __TENANT_SCHEMA__.leagues(season);

-- Unique constraint: League name per season (excluding cancelled)
CREATE UNIQUE INDEX idx_unique_league_name_season
    ON __TENANT_SCHEMA__.leagues(name, season)
    WHERE status != 'cancelled';

-- Trigger for updated_at
CREATE TRIGGER update_leagues_updated_at
BEFORE UPDATE ON __TENANT_SCHEMA__.leagues
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE __TENANT_SCHEMA__.leagues IS 'League/tournament configurations';
COMMENT ON COLUMN __TENANT_SCHEMA__.leagues.league_type IS 'Field size: futbol_5, futbol_7, or futbol_11';

-- ============================================================================
-- TABLE: teams
-- ============================================================================
-- Teams enrolled in leagues
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,

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

-- Indexes for teams
CREATE INDEX idx_teams_league_id ON __TENANT_SCHEMA__.teams(league_id);
CREATE INDEX idx_teams_name ON __TENANT_SCHEMA__.teams(name);

-- Unique constraint: Team name per league
CREATE UNIQUE INDEX idx_unique_team_name_per_league
    ON __TENANT_SCHEMA__.teams(league_id, name);

-- Trigger for updated_at
CREATE TRIGGER update_teams_updated_at
BEFORE UPDATE ON __TENANT_SCHEMA__.teams
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE __TENANT_SCHEMA__.teams IS 'Teams registered in leagues';
COMMENT ON COLUMN __TENANT_SCHEMA__.teams.logo_url IS 'S3 URL to team logo image';

-- ============================================================================
-- TABLE: players
-- ============================================================================
-- Player rosters for teams
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,

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

    -- Constraints
    CONSTRAINT check_position
        CHECK (position IN ('goalkeeper', 'defender', 'midfielder', 'forward') OR position IS NULL)
);

-- Indexes for players
CREATE INDEX idx_players_team_id ON __TENANT_SCHEMA__.players(team_id);
CREATE INDEX idx_players_name ON __TENANT_SCHEMA__.players(full_name);
CREATE INDEX idx_players_is_active ON __TENANT_SCHEMA__.players(is_active);

-- Unique constraint: Jersey number per team (only active players)
CREATE UNIQUE INDEX idx_unique_jersey_per_team
    ON __TENANT_SCHEMA__.players(team_id, jersey_number)
    WHERE is_active = TRUE AND jersey_number IS NOT NULL;

-- Trigger for updated_at
CREATE TRIGGER update_players_updated_at
BEFORE UPDATE ON __TENANT_SCHEMA__.players
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE __TENANT_SCHEMA__.players IS 'Player rosters for teams';
COMMENT ON COLUMN __TENANT_SCHEMA__.players.jersey_number IS 'Unique per team for active players';

-- ============================================================================
-- TABLE: matches
-- ============================================================================
-- Scheduled and completed matches
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,

    -- Teams
    home_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),
    away_team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id),

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

    -- Constraints
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

-- Indexes for matches
CREATE INDEX idx_matches_league_id ON __TENANT_SCHEMA__.matches(league_id);
CREATE INDEX idx_matches_scheduled_at ON __TENANT_SCHEMA__.matches(scheduled_at);
CREATE INDEX idx_matches_home_team_id ON __TENANT_SCHEMA__.matches(home_team_id);
CREATE INDEX idx_matches_away_team_id ON __TENANT_SCHEMA__.matches(away_team_id);
CREATE INDEX idx_matches_status ON __TENANT_SCHEMA__.matches(status);

-- Composite index for team's schedule
CREATE INDEX idx_matches_team_schedule
    ON __TENANT_SCHEMA__.matches(home_team_id, scheduled_at)
    WHERE status != 'cancelled';

-- Trigger for updated_at
CREATE TRIGGER update_matches_updated_at
BEFORE UPDATE ON __TENANT_SCHEMA__.matches
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE __TENANT_SCHEMA__.matches IS 'Match schedule and results';
COMMENT ON COLUMN __TENANT_SCHEMA__.matches.status IS 'scheduled, in_progress, finished, cancelled, postponed';

-- ============================================================================
-- TABLE: match_events
-- ============================================================================
-- Events during matches (goals, cards, substitutions)
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.matches(id) ON DELETE CASCADE,
    player_id UUID REFERENCES __TENANT_SCHEMA__.players(id) ON DELETE SET NULL,

    -- Event Details
    minute INTEGER NOT NULL,          -- Match minute (0-90+)
    event_type VARCHAR(30) NOT NULL,  -- 'goal', 'yellow_card', 'red_card', 'substitution'
    description TEXT,                 -- Optional notes

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_minute_valid
        CHECK (minute >= 0 AND minute <= 120),  -- Extra time
    CONSTRAINT check_event_type
        CHECK (event_type IN ('goal', 'yellow_card', 'red_card', 'substitution', 'own_goal'))
);

-- Indexes for match_events
CREATE INDEX idx_match_events_match_id ON __TENANT_SCHEMA__.match_events(match_id);
CREATE INDEX idx_match_events_player_id ON __TENANT_SCHEMA__.match_events(player_id);
CREATE INDEX idx_match_events_type ON __TENANT_SCHEMA__.match_events(event_type);

-- Ordered by minute for timeline display
CREATE INDEX idx_match_events_timeline
    ON __TENANT_SCHEMA__.match_events(match_id, minute);

COMMENT ON TABLE __TENANT_SCHEMA__.match_events IS 'Match events (goals, cards, substitutions)';
COMMENT ON COLUMN __TENANT_SCHEMA__.match_events.minute IS 'Match minute (0-120 for extra time)';

-- ============================================================================
-- TABLE: standings
-- ============================================================================
-- Auto-calculated league standings
-- ============================================================================

CREATE TABLE __TENANT_SCHEMA__.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.leagues(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES __TENANT_SCHEMA__.teams(id) ON DELETE CASCADE,

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

    -- Constraints
    CONSTRAINT check_played_matches
        CHECK (played = won + drawn + lost),
    CONSTRAINT check_points_calculation
        CHECK (points = (won * 3) + drawn),

    -- Unique standing per team per league
    UNIQUE(league_id, team_id)
);

-- Add computed column for goal difference
ALTER TABLE __TENANT_SCHEMA__.standings
ADD COLUMN goal_difference INTEGER
GENERATED ALWAYS AS (goals_for - goals_against) STORED;

-- Indexes for standings
CREATE INDEX idx_standings_league_id ON __TENANT_SCHEMA__.standings(league_id);
CREATE INDEX idx_standings_points ON __TENANT_SCHEMA__.standings(points DESC);

-- Composite index for standings table sort (optimizes ORDER BY)
CREATE INDEX idx_standings_sort
    ON __TENANT_SCHEMA__.standings(league_id, points DESC, goal_difference DESC, goals_for DESC);

-- Trigger for updated_at
CREATE TRIGGER update_standings_updated_at
BEFORE UPDATE ON __TENANT_SCHEMA__.standings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE __TENANT_SCHEMA__.standings IS 'Auto-calculated league standings';
COMMENT ON COLUMN __TENANT_SCHEMA__.standings.goal_difference IS 'Computed: goals_for - goals_against';

-- ============================================================================
-- FUNCTION: update_standings_after_match
-- ============================================================================
-- Automatically updates standings when a match is finished
-- This function should be called by the application service layer when
-- a match result is recorded
-- ============================================================================

CREATE OR REPLACE FUNCTION __TENANT_SCHEMA__.update_standings_after_match(match_id_param UUID)
RETURNS VOID AS $$
DECLARE
    match_record RECORD;
    home_points INTEGER;
    away_points INTEGER;
BEGIN
    -- Get match details
    SELECT * INTO match_record
    FROM __TENANT_SCHEMA__.matches
    WHERE id = match_id_param AND status = 'finished';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Match not found or not finished: %', match_id_param;
    END IF;

    -- Validate scores are not null for finished match
    IF match_record.home_score IS NULL OR match_record.away_score IS NULL THEN
        RAISE EXCEPTION 'Match % is finished but scores are null', match_id_param;
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
    INSERT INTO __TENANT_SCHEMA__.standings (league_id, team_id, played, won, drawn, lost, goals_for, goals_against, points)
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
        played = __TENANT_SCHEMA__.standings.played + 1,
        won = __TENANT_SCHEMA__.standings.won + CASE WHEN home_points = 3 THEN 1 ELSE 0 END,
        drawn = __TENANT_SCHEMA__.standings.drawn + CASE WHEN home_points = 1 THEN 1 ELSE 0 END,
        lost = __TENANT_SCHEMA__.standings.lost + CASE WHEN home_points = 0 THEN 1 ELSE 0 END,
        goals_for = __TENANT_SCHEMA__.standings.goals_for + match_record.home_score,
        goals_against = __TENANT_SCHEMA__.standings.goals_against + match_record.away_score,
        points = __TENANT_SCHEMA__.standings.points + home_points,
        updated_at = NOW();

    -- Update away team standing
    INSERT INTO __TENANT_SCHEMA__.standings (league_id, team_id, played, won, drawn, lost, goals_for, goals_against, points)
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
        played = __TENANT_SCHEMA__.standings.played + 1,
        won = __TENANT_SCHEMA__.standings.won + CASE WHEN away_points = 3 THEN 1 ELSE 0 END,
        drawn = __TENANT_SCHEMA__.standings.drawn + CASE WHEN away_points = 1 THEN 1 ELSE 0 END,
        lost = __TENANT_SCHEMA__.standings.lost + CASE WHEN away_points = 0 THEN 1 ELSE 0 END,
        goals_for = __TENANT_SCHEMA__.standings.goals_for + match_record.away_score,
        goals_against = __TENANT_SCHEMA__.standings.goals_against + match_record.home_score,
        points = __TENANT_SCHEMA__.standings.points + away_points,
        updated_at = NOW();

    RAISE NOTICE 'Standings updated for match %', match_id_param;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION __TENANT_SCHEMA__.update_standings_after_match IS 'Updates standings when match finishes (call from service layer)';

-- ============================================================================
-- END OF TENANT SCHEMA TEMPLATE
-- ============================================================================
-- Remember to replace __TENANT_SCHEMA__ with actual schema name when provisioning
-- Example: tenant_canchas_xyz, tenant_complejo_abc, etc.
-- ============================================================================
