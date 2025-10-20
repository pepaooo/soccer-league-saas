# API_REFERENCE.md - Complete API Documentation

## 🌐 Base URL & Authentication

**Production**: `https://api.yourplatform.com/v1`  
**Staging**: `https://staging-api.yourplatform.com/v1`  
**Local Dev**: `http://localhost:8080/api/v1`

### Authentication

All endpoints except `/auth/**` and `/public/**` require JWT authentication.

**Header:**
```
Authorization: Bearer {jwt_token}
X-Tenant-ID: {tenant_key}  (alternative to subdomain)
```

**Subdomain-based Tenant Resolution:**
```
https://canchas-xyz.yourplatform.com/api/v1/leagues
→ Automatically resolves to tenant: canchas-xyz
```

---

## 📍 API Endpoints

### 1. Authentication

#### POST `/auth/signup`
Create new tenant account (field owner registration).

**Request:**
```json
{
  "businessName": "Canchas del Norte",
  "ownerName": "Juan Pérez",
  "email": "juan@canchasdelnorte.com",
  "phone": "+52 55 1234 5678",
  "password": "SecurePass123!",
  "subscriptionPlan": "BASIC"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzUxMiJ9...",
    "tenant": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tenantKey": "canchas-del-norte",
      "businessName": "Canchas del Norte",
      "email": "juan@canchasdelnorte.com",
      "subscriptionPlan": "BASIC",
      "subscriptionStatus": "ACTIVE"
    },
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "juan@canchasdelnorte.com",
      "fullName": "Juan Pérez",
      "role": "TENANT_ADMIN"
    }
  },
  "message": "Account created successfully",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Errors:**
- `400` - Validation error (email format, password strength)
- `409` - Email already registered

---

#### POST `/auth/login`
Authenticate existing user.

**Request:**
```json
{
  "email": "juan@canchasdelnorte.com",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzUxMiJ9...",
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "juan@canchasdelnorte.com",
      "fullName": "Juan Pérez",
      "role": "TENANT_ADMIN",
      "tenantId": "550e8400-e29b-41d4-a716-446655440000",
      "tenantKey": "canchas-del-norte"
    }
  },
  "timestamp": "2025-01-15T10:35:00Z"
}
```

**Errors:**
- `401` - Invalid credentials
- `403` - Account suspended

---

#### GET `/auth/me`
Get current authenticated user details.

**Headers:**
```
Authorization: Bearer {token}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "email": "juan@canchasdelnorte.com",
    "fullName": "Juan Pérez",
    "role": "TENANT_ADMIN",
    "tenant": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tenantKey": "canchas-del-norte",
      "businessName": "Canchas del Norte",
      "subscriptionPlan": "BASIC",
      "subscriptionStatus": "ACTIVE"
    }
  }
}
```

---

### 2. Leagues

#### POST `/leagues`
Create a new league.

**Request:**
```json
{
  "name": "Liga Apertura 2025",
  "season": "Apertura 2025",
  "startDate": "2025-03-01",
  "endDate": "2025-06-30",
  "leagueType": "FUTBOL_7"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "770e8400-e29b-41d4-a716-446655440002",
    "name": "Liga Apertura 2025",
    "season": "Apertura 2025",
    "startDate": "2025-03-01",
    "endDate": "2025-06-30",
    "leagueType": "FUTBOL_7",
    "status": "DRAFT",
    "teamCount": 0,
    "matchCount": 0,
    "createdAt": "2025-01-15T10:40:00Z"
  }
}
```

**Validations:**
- `name`: Required, 1-150 characters
- `leagueType`: One of [FUTBOL_5, FUTBOL_7, FUTBOL_11]
- `endDate` must be after `startDate`

---

#### GET `/leagues`
List all leagues for current tenant.

**Query Parameters:**
- `status` (optional): Filter by status [DRAFT, ACTIVE, FINISHED, CANCELLED]
- `season` (optional): Filter by season name (partial match)
- `page` (default: 0): Page number
- `size` (default: 20): Items per page
- `sort` (default: createdAt,desc): Sort field and direction

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "name": "Liga Apertura 2025",
        "season": "Apertura 2025",
        "startDate": "2025-03-01",
        "endDate": "2025-06-30",
        "leagueType": "FUTBOL_7",
        "status": "ACTIVE",
        "teamCount": 8,
        "matchCount": 28,
        "createdAt": "2025-01-15T10:40:00Z"
      }
    ],
    "page": 0,
    "size": 20,
    "totalElements": 1,
    "totalPages": 1
  }
}
```

---

#### GET `/leagues/{id}`
Get league details by ID.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "770e8400-e29b-41d4-a716-446655440002",
    "name": "Liga Apertura 2025",
    "season": "Apertura 2025",
    "startDate": "2025-03-01",
    "endDate": "2025-06-30",
    "leagueType": "FUTBOL_7",
    "status": "ACTIVE",
    "teamCount": 8,
    "matchCount": 28,
    "teams": [
      {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "name": "Águilas FC",
        "logoUrl": "https://cdn.yourplatform.com/logos/aguilas.png",
        "captainName": "Carlos Mendoza"
      }
    ],
    "createdAt": "2025-01-15T10:40:00Z",
    "updatedAt": "2025-01-15T11:00:00Z"
  }
}
```

**Errors:**
- `404` - League not found
- `403` - Not authorized to access this league (wrong tenant)

---

#### PUT `/leagues/{id}`
Update league details.

**Request:**
```json
{
  "name": "Liga Apertura 2025 - Modificada",
  "startDate": "2025-03-08",
  "endDate": "2025-07-15"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "770e8400-e29b-41d4-a716-446655440002",
    "name": "Liga Apertura 2025 - Modificada",
    "startDate": "2025-03-08",
    "endDate": "2025-07-15",
    ...
  }
}
```

**Restrictions:**
- Cannot change `leagueType` after creation
- Cannot modify if status is `FINISHED`

---

#### DELETE `/leagues/{id}`
Delete (soft delete) a league.

**Response (204 No Content)**

**Errors:**
- `400` - Cannot delete league with scheduled matches
- `404` - League not found

---

### 3. Teams

#### POST `/leagues/{leagueId}/teams`
Add a team to a league.

**Request (multipart/form-data):**
```
name: "Águilas FC"
captainName: "Carlos Mendoza"
captainPhone: "+52 55 9876 5432"
logo: [file upload]
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "880e8400-e29b-41d4-a716-446655440003",
    "leagueId": "770e8400-e29b-41d4-a716-446655440002",
    "name": "Águilas FC",
    "logoUrl": "https://cdn.yourplatform.com/logos/aguilas-fc-1234.png",
    "captainName": "Carlos Mendoza",
    "captainPhone": "+52 55 9876 5432",
    "playerCount": 0,
    "createdAt": "2025-01-15T11:00:00Z"
  }
}
```

**Validations:**
- Team name must be unique within league
- Logo file: Max 2MB, formats: PNG, JPG, JPEG
- Cannot add team to `FINISHED` league

---

#### GET `/leagues/{leagueId}/teams`
List all teams in a league.

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "name": "Águilas FC",
      "logoUrl": "https://cdn.yourplatform.com/logos/aguilas-fc.png",
      "captainName": "Carlos Mendoza",
      "captainPhone": "+52 55 9876 5432",
      "playerCount": 12
    }
  ]
}
```

---

#### GET `/teams/{id}`
Get team details including roster.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "880e8400-e29b-41d4-a716-446655440003",
    "name": "Águilas FC",
    "logoUrl": "https://cdn.yourplatform.com/logos/aguilas-fc.png",
    "captainName": "Carlos Mendoza",
    "captainPhone": "+52 55 9876 5432",
    "league": {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "name": "Liga Apertura 2025"
    },
    "players": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440004",
        "fullName": "Miguel Ángel Hernández",
        "position": "FORWARD",
        "jerseyNumber": "10",
        "age": 25,
        "isActive": true
      }
    ],
    "statistics": {
      "matchesPlayed": 5,
      "wins": 3,
      "draws": 1,
      "losses": 1,
      "goalsFor": 12,
      "goalsAgainst": 7
    }
  }
}
```

---

#### PUT `/teams/{id}`
Update team details.

**Request:**
```json
{
  "name": "Águilas FC Renovadas",
  "captainName": "Roberto García",
  "captainPhone": "+52 55 1111 2222"
}
```

---

#### DELETE `/teams/{id}`
Remove team from league.

**Response (204 No Content)**

**Errors:**
- `400` - Cannot delete team with scheduled matches

---

#### POST `/teams/{id}/logo`
Upload team logo (separate endpoint for logo-only updates).

**Request (multipart/form-data):**
```
logo: [file upload]
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "logoUrl": "https://cdn.yourplatform.com/logos/aguilas-fc-5678.png"
  }
}
```

---

### 4. Players

#### POST `/teams/{teamId}/players`
Add a player to a team.

**Request:**
```json
{
  "fullName": "Miguel Ángel Hernández",
  "birthDate": "1999-05-15",
  "position": "FORWARD",
  "jerseyNumber": "10"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "990e8400-e29b-41d4-a716-446655440004",
    "teamId": "880e8400-e29b-41d4-a716-446655440003",
    "fullName": "Miguel Ángel Hernández",
    "birthDate": "1999-05-15",
    "age": 25,
    "position": "FORWARD",
    "jerseyNumber": "10",
    "isActive": true,
    "createdAt": "2025-01-15T11:15:00Z"
  }
}
```

**Validations:**
- Jersey number must be unique within team
- Position: One of [GOALKEEPER, DEFENDER, MIDFIELDER, FORWARD]
- Age calculated from birthDate

---

#### GET `/teams/{teamId}/players`
List all players in a team.

**Query Parameters:**
- `isActive` (default: true): Filter by active status
- `position`: Filter by position

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "990e8400-e29b-41d4-a716-446655440004",
      "fullName": "Miguel Ángel Hernández",
      "position": "FORWARD",
      "jerseyNumber": "10",
      "age": 25,
      "isActive": true
    }
  ]
}
```

---

#### GET `/players/{id}`
Get player details.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "990e8400-e29b-41d4-a716-446655440004",
    "fullName": "Miguel Ángel Hernández",
    "birthDate": "1999-05-15",
    "age": 25,
    "position": "FORWARD",
    "jerseyNumber": "10",
    "isActive": true,
    "team": {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "name": "Águilas FC"
    },
    "statistics": {
      "matchesPlayed": 5,
      "goals": 8,
      "assists": 3,
      "yellowCards": 1,
      "redCards": 0
    }
  }
}
```

---

#### PUT `/players/{id}`
Update player details.

**Request:**
```json
{
  "jerseyNumber": "7",
  "position": "MIDFIELDER"
}
```

---

#### DELETE `/players/{id}`
Remove player (soft delete - sets isActive=false).

**Response (204 No Content)**

---

### 5. Matches

#### POST `/leagues/{leagueId}/matches/generate`
Auto-generate round-robin match schedule.

**Request:**
```json
{
  "startDate": "2025-03-01",
  "matchTime": "19:00",
  "fieldNames": ["Cancha 1", "Cancha 2", "Cancha Principal"],
  "playDays": ["SATURDAY", "SUNDAY"],
  "matchesPerDay": 3
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "matchesCreated": 28,
    "rounds": 7,
    "firstMatchDate": "2025-03-01T19:00:00Z",
    "lastMatchDate": "2025-04-12T19:00:00Z",
    "matches": [
      {
        "id": "aa0e8400-e29b-41d4-a716-446655440005",
        "homeTeam": {
          "id": "880e8400-e29b-41d4-a716-446655440003",
          "name": "Águilas FC"
        },
        "awayTeam": {
          "id": "bb0e8400-e29b-41d4-a716-446655440006",
          "name": "Tigres Unidos"
        },
        "scheduledAt": "2025-03-01T19:00:00Z",
        "fieldName": "Cancha 1",
        "status": "SCHEDULED"
      }
    ]
  },
  "message": "Schedule generated successfully"
}
```

**Validations:**
- League must have at least 2 teams
- Will overwrite existing SCHEDULED matches (confirmation required)

---

#### GET `/leagues/{leagueId}/matches`
List matches in a league.

**Query Parameters:**
- `status`: Filter by [SCHEDULED, IN_PROGRESS, FINISHED, CANCELLED]
- `teamId`: Filter matches for specific team
- `startDate`: Filter from date (ISO format)
- `endDate`: Filter to date
- `page`, `size`, `sort`

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": "aa0e8400-e29b-41d4-a716-446655440005",
        "homeTeam": {
          "id": "880e8400-e29b-41d4-a716-446655440003",
          "name": "Águilas FC",
          "logoUrl": "..."
        },
        "awayTeam": {
          "id": "bb0e8400-e29b-41d4-a716-446655440006",
          "name": "Tigres Unidos",
          "logoUrl": "..."
        },
        "scheduledAt": "2025-03-01T19:00:00Z",
        "fieldName": "Cancha 1",
        "homeScore": 3,
        "awayScore": 2,
        "status": "FINISHED",
        "result": "3-2"
      }
    ],
    "page": 0,
    "totalElements": 28
  }
}
```

---

#### GET `/matches/{id}`
Get match details with events.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "aa0e8400-e29b-41d4-a716-446655440005",
    "league": {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "name": "Liga Apertura 2025"
    },
    "homeTeam": {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "name": "Águilas FC"
    },
    "awayTeam": {
      "id": "bb0e8400-e29b-41d4-a716-446655440006",
      "name": "Tigres Unidos"
    },
    "scheduledAt": "2025-03-01T19:00:00Z",
    "fieldName": "Cancha 1",
    "homeScore": 3,
    "awayScore": 2,
    "status": "FINISHED",
    "events": [
      {
        "id": "cc0e8400-e29b-41d4-a716-446655440007",
        "minute": 15,
        "eventType": "GOAL",
        "player": {
          "id": "990e8400-e29b-41d4-a716-446655440004",
          "fullName": "Miguel Ángel Hernández",
          "jerseyNumber": "10"
        },
        "description": "Gol de cabeza tras centro desde la derecha"
      }
    ]
  }
}
```

---

#### PUT `/matches/{id}/result`
Record match result.

**Request:**
```json
{
  "homeScore": 3,
  "awayScore": 2
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "aa0e8400-e29b-41d4-a716-446655440005",
    "homeScore": 3,
    "awayScore": 2,
    "status": "FINISHED",
    "result": "3-2"
  },
  "message": "Match result recorded. Standings updated."
}
```

**Side Effects:**
- Automatically updates league standings
- Invalidates standings cache
- Cannot modify finished match (must use separate "edit result" endpoint)

---

#### POST `/matches/{id}/events`
Add match event (goal, card, substitution).

**Request:**
```json
{
  "playerId": "990e8400-e29b-41d4-a716-446655440004",
  "minute": 15,
  "eventType": "GOAL",
  "description": "Gol de cabeza tras centro desde la derecha"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "cc0e8400-e29b-41d4-a716-446655440007",
    "matchId": "aa0e8400-e29b-41d4-a716-446655440005",
    "player": {
      "id": "990e8400-e29b-41d4-a716-446655440004",
      "fullName": "Miguel Ángel Hernández"
    },
    "minute": 15,
    "eventType": "GOAL",
    "description": "Gol de cabeza tras centro desde la derecha"
  }
}
```

**Event Types:**
- `GOAL`: Goal scored
- `YELLOW_CARD`: Yellow card issued
- `RED_CARD`: Red card issued
- `SUBSTITUTION`: Player substitution

---

### 6. Standings

#### GET `/leagues/{leagueId}/standings`
Get current league standings.

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "position": 1,
      "team": {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "name": "Águilas FC",
        "logoUrl": "..."
      },
      "played": 7,
      "won": 5,
      "drawn": 1,
      "lost": 1,
      "goalsFor": 18,
      "goalsAgainst": 9,
      "goalDifference": 9,
      "points": 16
    }
  ],
  "lastUpdated": "2025-03-15T20:30:00Z"
}
```

**Sorting:**
1. Points (descending)
2. Goal Difference (descending)
3. Goals For (descending)
4. Head-to-head record (if tied)

---

#### GET `/leagues/{leagueId}/statistics`
Get league statistics (top scorers, etc.).

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "topScorers": [
      {
        "player": {
          "id": "990e8400-e29b-41d4-a716-446655440004",
          "fullName": "Miguel Ángel Hernández",
          "jerseyNumber": "10"
        },
        "team": {
          "id": "880e8400-e29b-41d4-a716-446655440003",
          "name": "Águilas FC"
        },
        "goals": 12
      }
    ],
    "topAssists": [...],
    "disciplinaryRecords": {
      "mostYellowCards": [...],
      "mostRedCards": [...]
    },
    "teamStatistics": {
      "mostGoalsScored": {...},
      "bestDefense": {...}
    }
  }
}
```

---

### 7. Public Endpoints (No Authentication)

#### GET `/public/leagues/{id}/standings`
Public standings page.

**Response:** Same as authenticated standings endpoint

**Use Case:** Shareable link for fans/players to view standings

---

#### GET `/public/leagues/{id}/schedule`
Public schedule page.

**Response:** List of upcoming and past matches

---

#### GET `/public/teams/{id}`
Public team page with roster.

**Response:** Team details and player list

---

## 🚨 Error Responses

### Standard Error Format

```json
{
  "success": false,
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "League with ID 123 not found",
    "field": "leagueId",
    "details": {}
  },
  "timestamp": "2025-01-15T12:00:00Z",
  "path": "/api/v1/leagues/123"
}
```

### HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Successful GET/PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Validation error |
| 401 | Unauthorized | Missing/invalid JWT |
| 403 | Forbidden | Wrong tenant/insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource (email exists) |
| 422 | Unprocessable Entity | Business logic error |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 502 | Bad Gateway | Upstream service failure |

### Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Input validation failed |
| `RESOURCE_NOT_FOUND` | Requested resource doesn't exist |
| `DUPLICATE_RESOURCE` | Resource already exists (unique constraint) |
| `UNAUTHORIZED` | Authentication required |
| `FORBIDDEN` | Insufficient permissions |
| `TENANT_NOT_FOUND` | Tenant not identified |
| `SUBSCRIPTION_INACTIVE` | Tenant subscription suspended |
| `FEATURE_NOT_AVAILABLE` | Feature not included in plan |
| `BUSINESS_RULE_VIOLATION` | Business logic constraint violated |
| `INTERNAL_ERROR` | Unexpected server error |

---

## 📊 Rate Limiting

**Limits per tenant:**
- 100 requests per minute (authenticated)
- 20 requests per minute (public endpoints)

**Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642248000
```

**Rate Limit Exceeded Response (429):**
```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again in 30 seconds.",
    "retryAfter": 30
  }
}
```

---

## 🔄 Pagination

All list endpoints support pagination.

**Request:**
```
GET /api/v1/leagues?page=0&size=20&sort=createdAt,desc
```

**Response:**
```json
{
  "content": [...],
  "page": 0,
  "size": 20,
  "totalElements": 45,
  "totalPages": 3,
  "first": true,
  "last": false
}
```

---

## 🧪 Testing the API

### Using cURL

```bash
# Signup
curl -X POST http://localhost:8080/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "businessName": "Test Canchas",
    "ownerName": "Test User",
    "email": "test@example.com",
    "password": "Test123!",
    "phone": "+52 55 1234 5678"
  }'

# Login (save token)
TOKEN=$(curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}' \
  | jq -r '.data.token')

# Create League
curl -X POST http://localhost:8080/api/v1/leagues \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Liga Test",
    "season": "Apertura 2025",
    "leagueType": "FUTBOL_7"
  }'
```

### Using Postman

**Import Collection:**
Download the Postman collection from: `/docs/postman-collection.json`

**Environment Variables:**
- `baseUrl`: http://localhost:8080/api/v1
- `token`: {{token}} (auto-populated from login)

---

## 📚 Additional Resources

- **Swagger UI**: http://localhost:8080/api/v1/swagger-ui.html
- **OpenAPI Spec**: http://localhost:8080/api/v1/v3/api-docs
- **Health Check**: http://localhost:8080/api/v1/actuator/health

---

*Last Updated: January 2025*
