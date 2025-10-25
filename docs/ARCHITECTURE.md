# ARCHITECTURE.md - System Architecture Specification

## 📋 Document Information

**Project**: Liga Manager - Soccer League Management SaaS  
**Version**: 1.0 (MVP)  
**Target Market**: Mexico (Soccer Field Owners)  
**Date**: October 2025  
**Status**: Living Document

---

## 🎯 Executive Summary

### Purpose
Liga Manager is a multi-tenant SaaS platform enabling soccer field owners in Mexico to manage leagues, teams, players, schedules, and match results. The platform prioritizes **data isolation**, **scalability**, and **rapid time-to-market**.

### Key Architecture Decisions
1. **Multi-Tenancy**: Schema-per-tenant (PostgreSQL)
2. **Application Architecture**: Modular monolith (not microservices)
3. **Frontend**: Server-side rendering with Next.js 15
4. **Authentication**: Stateless JWT tokens
5. **Deployment**: Cloud-native on AWS

### Quality Attributes Priority
1. **Security** - Tenant data isolation (critical)
2. **Scalability** - Support 1,000+ tenants
3. **Performance** - <200ms API response time
4. **Availability** - 99.5% uptime
5. **Maintainability** - Easy to extend

---

## 🏗️ System Architecture Overview

### High-Level Architecture

```mermaid
C4Context
    title System Context Diagram - Liga Manager SaaS

    Person(fieldOwner, "Field Owner", "Soccer field/complex owner managing leagues")
    Person(player, "Player/Fan", "Views public schedules and standings")
    
    System(ligaManager, "Liga Manager Platform", "Multi-tenant SaaS for league management")
    
    System_Ext(stripe, "Stripe/OpenPay", "Payment processing")
    System_Ext(email, "Email Service", "Transactional emails")
    System_Ext(storage, "AWS S3", "File storage")
    
    Rel(fieldOwner, ligaManager, "Manages leagues, teams, matches", "HTTPS")
    Rel(player, ligaManager, "Views public pages", "HTTPS")
    Rel(ligaManager, stripe, "Processes payments", "API")
    Rel(ligaManager, email, "Sends notifications", "SMTP/API")
    Rel(ligaManager, storage, "Stores team logos", "S3 API")
```

### Container Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        WebApp[Web Application<br/>Next.js 15 + React 19]
        MobileWeb[Mobile Browser<br/>Responsive UI]
    end
    
    subgraph "API Gateway"
        ALB[Application Load Balancer<br/>AWS ALB]
        CDN[CloudFront CDN<br/>Static Assets]
    end
    
    subgraph "Application Layer"
        API1[API Server 1<br/>Spring Boot 3.5.6]
        API2[API Server 2<br/>Spring Boot 3.5.6]
        
        subgraph "Application Modules"
            Auth[Authentication Module]
            League[League Management]
            Team[Team Management]
            Match[Match Management]
            Standing[Standing Calculation]
            Payment[Payment Processing]
        end
    end
    
    subgraph "Data Layer"
        RDS[(PostgreSQL RDS<br/>Multi-Schema)]
        Redis[(Redis ElastiCache<br/>Session & Cache)]
        S3[S3 Bucket<br/>File Storage]
    end
    
    subgraph "External Services"
        Stripe[Stripe API]
        Email[SendGrid/SES]
    end
    
    WebApp -->|HTTPS| ALB
    MobileWeb -->|HTTPS| ALB
    CDN -->|Static Assets| S3
    
    ALB --> API1
    ALB --> API2
    
    API1 --> Auth
    API1 --> League
    API1 --> Team
    API1 --> Match
    API1 --> Standing
    API1 --> Payment
    
    Auth --> RDS
    League --> RDS
    Team --> RDS
    Match --> RDS
    Standing --> Redis
    Standing --> RDS
    
    Team --> S3
    Payment --> Stripe
    Auth --> Email
    
    style API1 fill:#4CAF50
    style API2 fill:#4CAF50
    style RDS fill:#2196F3
    style Redis fill:#FF9800
```

---

## 🔐 Multi-Tenancy Architecture

### Decision: Schema-per-Tenant

**Chosen Strategy**: Schema-per-tenant (PostgreSQL native schemas)

#### Comparison Matrix

| Aspect | Shared Schema | Schema-per-Tenant | Database-per-Tenant |
|--------|---------------|-------------------|---------------------|
| **Isolation** | ❌ Low (app-level) | ✅ High (DB-level) | ✅✅ Highest |
| **Scalability** | ✅✅ Best | ✅ Good | ❌ Poor |
| **Cost** | ✅✅ Lowest | ✅ Low | ❌ High |
| **Complexity** | ✅ Low | ⚠️ Medium | ❌ High |
| **Migration** | ✅ Easy | ⚠️ Medium | ❌ Hard |
| **Query Performance** | ✅ Fast | ✅ Fast | ⚠️ Varies |
| **Backup/Restore** | ⚠️ Complex | ✅ Per-tenant | ✅ Per-tenant |

**Winner for MVP**: ✅ **Schema-per-Tenant**

#### Rationale

**Why Schema-per-Tenant?**
1. **Strong Isolation**: Each tenant's data in separate PostgreSQL schema
2. **Cost-Effective**: Single database handles 1,000+ tenants
3. **Easy Compliance**: Can export/delete tenant data easily (GDPR)
4. **Simple Backups**: `pg_dump --schema=tenant_xyz`
5. **Mexico Market Fit**: Field owners typically manage 2-5 leagues (low volume per tenant)

**Why NOT Shared Schema?**
- ❌ Risk of data leakage (catastrophic for trust)
- ❌ Complex queries (WHERE tenant_id = ? everywhere)
- ❌ Hard to migrate individual tenants

**Why NOT Database-per-Tenant?**
- ❌ Too expensive (1,000 tenants = 1,000 RDS instances)
- ❌ Hard to manage (connection pooling nightmare)
- ❌ Overkill for low-volume tenants

### Schema Architecture

```mermaid
graph TB
    subgraph "PostgreSQL Database: ligamanager"
        Public[Schema: public<br/>Platform Tables]
        
        Public --> Tenants[tenants<br/>subscriptions<br/>platform_users]
        
        T1[Schema: tenant_canchas_xyz<br/>Tenant 1 Data]
        T2[Schema: tenant_complejo_abc<br/>Tenant 2 Data]
        T3[Schema: tenant_liga_norte<br/>Tenant 3 Data]
        
        T1 --> TData1[leagues<br/>teams<br/>players<br/>matches<br/>standings]
        T2 --> TData2[leagues<br/>teams<br/>players<br/>matches<br/>standings]
        T3 --> TData3[leagues<br/>teams<br/>players<br/>matches<br/>standings]
    end
    
    style Public fill:#FF6B6B
    style T1 fill:#4ECDC4
    style T2 fill:#4ECDC4
    style T3 fill:#4ECDC4
```

### Tenant Resolution Flow

```mermaid
sequenceDiagram
    participant Client
    participant ALB
    participant API
    participant TenantInterceptor
    participant TenantContext
    participant Hibernate
    participant PostgreSQL

    Client->>ALB: GET https://canchas-xyz.api.ligamanager.com/leagues
    ALB->>API: Forward request
    API->>TenantInterceptor: preHandle(request)
    
    TenantInterceptor->>TenantInterceptor: Extract subdomain: "canchas-xyz"
    TenantInterceptor->>TenantContext: setTenantId("canchas-xyz")
    TenantInterceptor-->>API: Continue
    
    API->>Hibernate: Query League
    Hibernate->>TenantContext: getTenantId()
    TenantContext-->>Hibernate: "canchas-xyz"
    
    Hibernate->>PostgreSQL: SET search_path TO tenant_canchas_xyz
    Hibernate->>PostgreSQL: SELECT * FROM leagues
    PostgreSQL-->>Hibernate: Results from tenant_canchas_xyz schema
    
    Hibernate-->>API: League objects
    API-->>Client: JSON response
    
    API->>TenantInterceptor: afterCompletion()
    TenantInterceptor->>TenantContext: clear()
    
    Note over TenantContext: ThreadLocal cleared<br/>prevents memory leaks
```

### Tenant Provisioning Flow

```mermaid
sequenceDiagram
    participant User as Field Owner
    participant Frontend
    participant AuthController
    participant TenantService
    participant PostgreSQL
    participant PaymentGateway

    User->>Frontend: Sign up form
    Frontend->>AuthController: POST /auth/signup
    
    AuthController->>TenantService: createTenant(data)
    
    TenantService->>TenantService: Generate unique tenantKey<br/>"canchas-xyz"
    TenantService->>PostgreSQL: INSERT INTO public.tenants
    
    TenantService->>PostgreSQL: CREATE SCHEMA tenant_canchas_xyz
    TenantService->>PostgreSQL: CREATE TABLE tenant_canchas_xyz.leagues
    TenantService->>PostgreSQL: CREATE TABLE tenant_canchas_xyz.teams
    TenantService->>PostgreSQL: ... (all tables)
    
    TenantService->>PaymentGateway: Create customer + subscription
    PaymentGateway-->>TenantService: Subscription ID
    
    TenantService->>PostgreSQL: INSERT INTO public.subscriptions
    
    TenantService-->>AuthController: Tenant created
    AuthController-->>Frontend: JWT token + tenant info
    Frontend-->>User: Redirect to dashboard
```

---

## 🔒 Security Architecture

### Authentication Flow (JWT)

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant AuthService
    participant JwtService
    participant Database
    participant Redis

    Client->>API: POST /auth/login<br/>{email, password}
    API->>AuthService: authenticate(email, password)
    
    AuthService->>Database: SELECT user WHERE email = ?
    Database-->>AuthService: User record
    
    AuthService->>AuthService: BCrypt.verify(password, hash)
    
    alt Password Valid
        AuthService->>JwtService: generateToken(userId, tenantId)
        JwtService->>JwtService: Sign with HMAC-SHA512
        JwtService-->>AuthService: JWT token
        
        AuthService->>Redis: Store session metadata (optional)
        AuthService-->>API: AuthResponse(token, user)
        API-->>Client: 200 OK + token
    else Password Invalid
        AuthService-->>API: UnauthorizedException
        API-->>Client: 401 Unauthorized
    end
    
    Note over Client: Store token in localStorage
    
    Client->>API: GET /leagues<br/>Authorization: Bearer {token}
    API->>JwtService: validateToken(token)
    JwtService->>JwtService: Verify signature + expiry
    JwtService-->>API: Valid + claims
    API->>API: Extract tenantId from claims
    API->>API: Set TenantContext
    API-->>Client: League data
```

### Security Layers

```mermaid
graph TB
    subgraph "Layer 1: Network Security"
        HTTPS[HTTPS/TLS 1.3]
        WAF[AWS WAF]
        DDoS[DDoS Protection]
    end
    
    subgraph "Layer 2: Application Security"
        JWT[JWT Authentication]
        RBAC[Role-Based Access]
        RateLimit[Rate Limiting]
        InputVal[Input Validation]
    end
    
    subgraph "Layer 3: Data Security"
        Encryption[Encryption at Rest]
        TenantIsolation[Schema Isolation]
        Backup[Encrypted Backups]
    end
    
    subgraph "Layer 4: Infrastructure Security"
        VPC[Private VPC]
        SG[Security Groups]
        IAM[IAM Roles]
        Secrets[Secrets Manager]
    end
    
    HTTPS --> JWT
    WAF --> RateLimit
    JWT --> TenantIsolation
    TenantIsolation --> VPC
    
    style HTTPS fill:#4CAF50
    style JWT fill:#4CAF50
    style TenantIsolation fill:#4CAF50
    style VPC fill:#4CAF50
```

### Authorization Model

```mermaid
erDiagram
    PLATFORM_USER ||--o{ TENANT : belongs_to
    PLATFORM_USER {
        uuid id
        string email
        string role
    }
    
    TENANT {
        uuid id
        string tenant_key
        string subscription_plan
    }
    
    ROLE {
        string name
    }
    
    PERMISSION {
        string resource
        string action
    }
    
    PLATFORM_USER ||--|| ROLE : has
    ROLE ||--o{ PERMISSION : grants
    
    ROLE ||--o{ LEAGUE_ACCESS : can_access
    LEAGUE_ACCESS ||--|| LEAGUE : references
```

**Roles:**
- `TENANT_ADMIN` - Full access to tenant's data
- `TENANT_VIEWER` - Read-only access
- `PLATFORM_ADMIN` - Anthropic admin (cross-tenant access)

---

## 💾 Data Architecture

### Entity Relationship Diagram (Complete)

```mermaid
erDiagram
    %% Shared Schema (public)
    TENANT ||--o{ SUBSCRIPTION : has
    TENANT ||--o{ PLATFORM_USER : employs
    SUBSCRIPTION ||--o{ PAYMENT_TRANSACTION : records
    
    %% Tenant Schema
    LEAGUE ||--o{ TEAM : contains
    LEAGUE ||--o{ MATCH : schedules
    LEAGUE ||--o{ STANDING : calculates
    
    TEAM ||--o{ PLAYER : has
    TEAM ||--|| STANDING : reflects
    
    MATCH }o--|| TEAM : home_team
    MATCH }o--|| TEAM : away_team
    MATCH ||--o{ MATCH_EVENT : records
    
    PLAYER ||--o{ MATCH_EVENT : participates_in
    
    TENANT {
        uuid id PK
        string tenant_key UK
        string schema_name
        string business_name
        string email UK
        string subscription_plan
        string subscription_status
    }
    
    LEAGUE {
        uuid id PK
        string name
        string season
        date start_date
        date end_date
        string league_type
        string status
    }
    
    TEAM {
        uuid id PK
        uuid league_id FK
        string name
        string logo_url
        string captain_name
        string captain_phone
    }
    
    PLAYER {
        uuid id PK
        uuid team_id FK
        string full_name
        date birth_date
        string position
        string jersey_number
        boolean is_active
    }
    
    MATCH {
        uuid id PK
        uuid league_id FK
        uuid home_team_id FK
        uuid away_team_id FK
        timestamp scheduled_at
        string field_name
        integer home_score
        integer away_score
        string status
    }
    
    MATCH_EVENT {
        uuid id PK
        uuid match_id FK
        uuid player_id FK
        integer minute
        string event_type
        string description
    }
    
    STANDING {
        uuid id PK
        uuid league_id FK
        uuid team_id FK
        integer played
        integer won
        integer drawn
        integer lost
        integer goals_for
        integer goals_against
        integer points
    }
```

### Data Flow Architecture

```mermaid
graph LR
    subgraph "Write Path (Hot)"
        Client1[Client] -->|"`POST /matches/{id}/result`"| API1[API Server]
        API1 -->|Write| PG[(PostgreSQL)]
        API1 -->|Invalidate Cache| Redis[(Redis)]
        API1 -->|Calculate| StandingService[Standing Service]
        StandingService -->|Update| PG
        StandingService -->|Warm Cache| Redis
    end
    
    subgraph "Read Path (Cached)"
        Client2[Client] -->|GET /standings| API2[API Server]
        API2 -->|Check Cache| Redis
        Redis -->|Cache Hit| API2
        Redis -->|Cache Miss| PG
        PG -->|Store in Cache| Redis
        API2 --> Client2
    end
    
    style Redis fill:#FF9800
    style PG fill:#2196F3
```

### Caching Strategy

| Data Type | Cache? | TTL | Invalidation |
|-----------|--------|-----|--------------|
| **Standings** | ✅ Yes | 5 min | On match result |
| **Match Schedule** | ✅ Yes | 1 hour | On schedule change |
| **Team Roster** | ✅ Yes | 30 min | On player add/remove |
| **League List** | ✅ Yes | 10 min | On league CRUD |
| **Match Results** | ❌ No | - | Always fresh |
| **User Sessions** | ✅ Yes | 24 hours | On logout |

**Cache Keys Pattern:**
```
standings:{league_id}
matches:{league_id}:upcoming
teams:{league_id}
session:{user_id}
```

---

## 🚀 Deployment Architecture (AWS)

### Production Environment

```mermaid
graph TB
    subgraph "Route 53 DNS"
        DNS[ligamanager.com]
    end
    
    subgraph "CloudFront CDN"
        CF[CloudFront Distribution]
    end
    
    subgraph "S3 Static Hosting"
        S3Frontend[S3: Frontend Assets<br/>Next.js Static Export]
    end
    
    subgraph "Application Load Balancer"
        ALB[ALB<br/>api.ligamanager.com<br/>*.api.ligamanager.com]
    end
    
    subgraph "Auto Scaling Group"
        EC2_1[EC2: Spring Boot<br/>t3.medium]
        EC2_2[EC2: Spring Boot<br/>t3.medium]
    end
    
    subgraph "Data Tier"
        RDS[(RDS PostgreSQL<br/>Multi-AZ<br/>db.t3.small)]
        Redis[(ElastiCache Redis<br/>t3.micro)]
        S3Uploads[S3: User Uploads<br/>Team Logos]
    end
    
    subgraph "Monitoring & Logs"
        CloudWatch[CloudWatch Logs & Metrics]
        Sentry[Sentry<br/>Error Tracking]
    end
    
    DNS --> CF
    DNS --> ALB
    CF --> S3Frontend
    
    ALB --> EC2_1
    ALB --> EC2_2
    
    EC2_1 --> RDS
    EC2_1 --> Redis
    EC2_1 --> S3Uploads
    
    EC2_2 --> RDS
    EC2_2 --> Redis
    EC2_2 --> S3Uploads
    
    EC2_1 --> CloudWatch
    EC2_2 --> CloudWatch
    EC2_1 --> Sentry
    EC2_2 --> Sentry
    
    style RDS fill:#2196F3
    style Redis fill:#FF9800
    style EC2_1 fill:#4CAF50
    style EC2_2 fill:#4CAF50
```

### Infrastructure as Code (Planned)

```yaml
Infrastructure:
  Provider: AWS
  Region: us-east-1 (primary)
  
  Compute:
    - Type: EC2 Auto Scaling
    - Instance: t3.medium (2 vCPU, 4GB RAM)
    - Min: 1, Desired: 2, Max: 5
    - AMI: Amazon Linux 2023
    
  Database:
    - Type: RDS PostgreSQL 15
    - Instance: db.t3.small (2 vCPU, 2GB RAM)
    - Storage: 100GB SSD (auto-scaling to 1TB)
    - Multi-AZ: Yes (HA)
    - Backup: 7-day retention
    
  Cache:
    - Type: ElastiCache Redis 7
    - Instance: cache.t3.micro (0.5GB)
    - Replication: No (for MVP)
    
  Storage:
    - S3 Buckets:
      * Frontend: ligamanager-frontend
      * Uploads: ligamanager-uploads
      * Backups: ligamanager-backups
    
  Networking:
    - VPC: Custom VPC with public/private subnets
    - Load Balancer: Application Load Balancer
    - CDN: CloudFront (frontend assets)
    
  Security:
    - SSL/TLS: ACM Certificates
    - WAF: AWS WAF (rate limiting, SQL injection protection)
    - Secrets: AWS Secrets Manager
```

---

## 🎨 Application Architecture

### Layered Architecture (Backend)

```mermaid
graph TB
    subgraph "Presentation Layer"
        RestAPI[REST Controllers<br/>@RestController]
        DTOs[Request/Response DTOs<br/>@Valid]
    end
    
    subgraph "Application Layer"
        Services[Business Services<br/>@Service @Transactional]
        Mappers[Entity-DTO Mappers]
    end
    
    subgraph "Domain Layer"
        Entities[JPA Entities<br/>@Entity]
        BusinessLogic[Domain Logic<br/>Validation, Calculations]
    end
    
    subgraph "Infrastructure Layer"
        Repositories[Spring Data Repos<br/>@Repository]
        Config[Configuration<br/>Security, Multi-tenancy]
        External[External Services<br/>Stripe, S3, Email]
    end
    
    RestAPI --> DTOs
    DTOs --> Services
    Services --> Mappers
    Mappers --> Entities
    Services --> BusinessLogic
    BusinessLogic --> Repositories
    Repositories --> Config
    Services --> External
    
    style RestAPI fill:#4CAF50
    style Services fill:#2196F3
    style Entities fill:#FF9800
    style Repositories fill:#9C27B0
```

### Module Structure (Frontend - Next.js 15)

```mermaid
graph TB
    subgraph "App Router (Next.js 15)"
        Pages[Pages<br/>app/]
        
        subgraph "Route Groups"
            Auth["(auth)/login, /signup"]
            Dashboard["(dashboard)/leagues, /teams"]
            Public["(public)/standings"]
        end
    end
    
    subgraph "Components"
        UI[UI Components<br/>Button, Input, Card]
        Feature[Feature Components<br/>LeagueCard, TeamRoster]
        Layout[Layout Components<br/>Header, Sidebar]
    end
    
    subgraph "State Management"
        Zustand[Zustand Stores<br/>authStore, leagueStore]
        ReactQuery[TanStack Query<br/>Data Fetching & Cache]
    end
    
    subgraph "Services"
        API[API Client<br/>Axios + Interceptors]
        Utils[Utilities<br/>Formatters, Validators]
    end
    
    Pages --> Auth
    Pages --> Dashboard
    Pages --> Public
    
    Auth --> UI
    Dashboard --> Feature
    Feature --> UI
    
    Feature --> Zustand
    Feature --> ReactQuery
    
    ReactQuery --> API
    API --> Utils
    
    style Pages fill:#61DAFB
    style Zustand fill:#FF9800
    style API fill:#4CAF50
```

---

## 🔄 API Design Principles

### RESTful API Architecture

```mermaid
graph LR
    subgraph "API Design"
        Resources[Resource-Oriented<br/>/leagues, /teams]
        HTTP[HTTP Verbs<br/>GET, POST, PUT, DELETE]
        Status[Status Codes<br/>200, 201, 400, 401, 404]
        HATEOAS[HATEOAS Links<br/>Optional]
    end
    
    subgraph "Response Format"
        Wrapper[ApiResponse Wrapper]
        Data[Data Payload]
        Metadata[Metadata<br/>timestamp, requestId]
        Error[Error Details]
    end
    
    subgraph "API Versioning"
        URLVersion[URL Versioning<br/>/api/v1/]
        HeaderVersion[Header Versioning<br/>Future: Accept: v2]
    end
    
    Resources --> Wrapper
    HTTP --> Status
    Wrapper --> Data
    Wrapper --> Metadata
    Wrapper --> Error
    
    style Wrapper fill:#4CAF50
```

### API Response Structure

```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Liga Apertura 2025",
    "teams": [...]
  },
  "meta": {
    "timestamp": "2025-01-15T10:30:00Z",
    "requestId": "abc123",
    "pagination": {
      "page": 1,
      "size": 20,
      "total": 45
    }
  }
}
```

---

## 📈 Scalability Strategy

### Scaling Dimensions

```mermaid
graph TB
    subgraph "Horizontal Scaling"
        EC2_1[API Server 1]
        EC2_2[API Server 2]
        EC2_N[API Server N]
        ALB[Load Balancer]
        
        ALB --> EC2_1
        ALB --> EC2_2
        ALB --> EC2_N
    end
    
    subgraph "Vertical Scaling"
        T3Small[t3.small<br/>2 vCPU, 2GB]
        T3Medium[t3.medium<br/>2 vCPU, 4GB]
        T3Large[t3.large<br/>2 vCPU, 8GB]
        
        T3Small -->|Upgrade| T3Medium
        T3Medium -->|Upgrade| T3Large
    end
    
    subgraph "Database Scaling"
        Master[(RDS Master<br/>Write)]
        Replica1[(Read Replica 1<br/>Read)]
        Replica2[(Read Replica 2<br/>Read)]
        
        Master -->|Replicate| Replica1
        Master -->|Replicate| Replica2
    end
    
    subgraph "Caching Layer"
        Redis1[(Redis Primary)]
        Redis2[(Redis Replica)]
        
        Redis1 -->|Replicate| Redis2
    end
    
    EC2_1 --> Master
    EC2_1 --> Replica1
    EC2_1 --> Redis1
    
    style EC2_1 fill:#4CAF50
    style Master fill:#2196F3
    style Redis1 fill:#FF9800
```

### Growth Milestones

| Tenants | Users | Architecture | Estimated Cost |
|---------|-------|--------------|----------------|
| **0-100** | <1K | 1 EC2 + RDS t3.small | $150/month |
| **100-500** | 1K-5K | 2 EC2 + RDS t3.medium + Read Replica | $450/month |
| **500-2K** | 5K-20K | 3-5 EC2 + RDS t3.large + 2 Replicas | $1,200/month |
| **2K-10K** | 20K-100K | Microservices consideration | $5,000+/month |

---

## 🔮 Evolution Strategy

### Phase 1: MVP (Months 0-3) - CURRENT

```
Architecture: Modular Monolith
Focus: Time to market, validation
Features: Core league management
Deployment: Single region (us-east-1)
```

### Phase 2: Growth (Months 4-12)

```
Architecture: Monolith + Background Jobs
Additions:
  - Celery/SQS for async tasks
  - Read replicas for reporting
  - CDN for all static assets
  - Mobile app (React Native)
Features:
  - Advanced statistics
  - Tournament brackets
  - Payment splitting (teams pay)
  - Email notifications
```

### Phase 3: Scale (Year 2)

```
Architecture: Selective Microservices
Decompose:
  - Payment Service (isolated, PCI compliance)
  - Notification Service (email, SMS, push)
  - Reporting Service (analytics, exports)
Additions:
  - Multi-region deployment (us-east-1, sa-east-1)
  - GraphQL for mobile clients
  - Real-time match updates (WebSocket)
```

### Phase 4: Enterprise (Year 3+)

```
Architecture: Event-Driven Microservices
Patterns:
  - CQRS (Command Query Responsibility Segregation)
  - Event sourcing for match events
  - Saga pattern for distributed transactions
Features:
  - White-label solution
  - API marketplace for third-party integrations
  - AI-powered schedule optimization
  - Live streaming integration
```

### Migration Path: Monolith → Microservices

```mermaid
graph TB
    subgraph "Phase 1: Monolith"
        Mono[Monolith<br/>All Features]
    end
    
    subgraph "Phase 2: Strangler Fig Pattern"
        Mono2[Core Monolith]
        Payment[Payment<br/>Microservice]
        Notification[Notification<br/>Microservice]
        
        Mono2 -.->|Extract| Payment
        Mono2 -.->|Extract| Notification
    end
    
    subgraph "Phase 3: Distributed System"
        Gateway[API Gateway]
        League[League<br/>Service]
        Team[Team<br/>Service]
        Match[Match<br/>Service]
        Pay[Payment<br/>Service]
        Notify[Notification<br/>Service]
        
        Gateway --> League
        Gateway --> Team
        Gateway --> Match
        Gateway --> Pay
        Gateway --> Notify
    end
    
    Mono --> Mono2
    Mono2 --> Gateway
    
    style Mono fill:#FF6B6B
    style Gateway fill:#4ECDC4
```

---

## 🏆 Quality Attributes

### Performance Targets

| Metric | Target | Measured By |
|--------|--------|-------------|
| **API Response Time** | <200ms (P95) | CloudWatch |
| **Page Load Time** | <2 seconds | Lighthouse |
| **Database Query** | <50ms (P95) | pg_stat_statements |
| **Cache Hit Ratio** | >80% | Redis INFO stats |
| **Error Rate** | <0.1% | Sentry |

### Availability Targets

```
SLA: 99.5% uptime (monthly)
Allowed downtime: 3.6 hours/month

Components:
- ALB: 99.99% (AWS SLA)
- EC2 (Multi-AZ): 99.95%
- RDS (Multi-AZ): 99.95%
- Redis (no replica): 99.9%
- S3: 99.99%

Calculated availability: 99.5%
```

### Security Checklist

- [x] HTTPS everywhere (TLS 1.3)
- [x] JWT with HMAC-SHA512
- [x] Password hashing (BCrypt, cost=12)
- [x] SQL injection prevention (parameterized queries)
- [x] XSS prevention (React auto-escaping)
- [x] CSRF protection (JWT stateless, no cookies)
- [x] Rate limiting (100 req/min per tenant)
- [x] Input validation (Jakarta Bean Validation)
- [x] Tenant isolation (schema-level)
- [x] Secrets management (AWS Secrets Manager)
- [ ] Penetration testing (before public launch)
- [ ] Security audit (OWASP Top 10)

---

## 📐 Design Patterns Used

### Backend Patterns

| Pattern | Usage | Example |
|---------|-------|---------|
| **Repository** | Data access abstraction | `LeagueRepository` |
| **Service Layer** | Business logic encapsulation | `LeagueService` |
| **DTO** | Data transfer between layers | `LeagueRequest`, `LeagueResponse` |
| **Strategy** | Payment processing | `StripePayment`, `OpenPayPayment` |
| **Template Method** | Tenant provisioning | `TenantProvisioningTemplate` |
| **Observer** | Match events → Standings update | Spring Events |
| **Singleton** | TenantContext, API clients | Spring @Bean |
| **Factory** | Entity creation | Builders via Lombok |

### Frontend Patterns

| Pattern | Usage | Example |
|---------|-------|---------|
| **Container/Presentational** | Component organization | `LeagueListContainer` + `LeagueCard` |
| **Custom Hooks** | Reusable logic | `useAuth`, `useLeagues` |
| **Render Props** | Component composition | `<Modal render={...}>` |
| **Compound Components** | Related components | `<Form><Form.Input></Form>` |
| **Provider Pattern** | State sharing | Zustand stores |

---

## 🧪 Testing Strategy

### Test Pyramid

```mermaid
graph TB
    subgraph "Test Pyramid"
        E2E[E2E Tests<br/>Playwright<br/>5% - 10 tests]
        Integration[Integration Tests<br/>Testcontainers<br/>20% - 50 tests]
        Unit[Unit Tests<br/>JUnit + Mockito<br/>70% - 200 tests]
    end
    
    E2E --> Integration
    Integration --> Unit
    
    style E2E fill:#FF6B6B
    style Integration fill:#FFA500
    style Unit fill:#4CAF50
```

### Coverage Targets

- **Backend**: 70%+ overall, 90%+ for service layer
- **Frontend**: 60%+ overall, 80%+ for business logic
- **Critical Paths**: 100% (authentication, payment, standings calculation)

---

## 🚨 Risk & Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Schema explosion** | Medium | High | Monitor schema count, archive inactive tenants |
| **Connection pool exhaustion** | Medium | High | HikariCP tuning, connection monitoring |
| **Data loss** | Low | Critical | Daily backups, Multi-AZ RDS, test restores |
| **Performance degradation** | Medium | Medium | Redis caching, query optimization, indexing |
| **Security breach** | Low | Critical | Penetration testing, OWASP compliance, encryption |

---

## 📚 Architecture Decision Records (ADRs)

### ADR-001: Schema-per-Tenant Multi-Tenancy

**Status**: Accepted  
**Date**: 2025-01-15  
**Context**: Need to isolate tenant data securely while remaining cost-effective  
**Decision**: Use PostgreSQL schema-per-tenant  
**Consequences**: 
- ✅ Strong isolation
- ✅ Cost-effective for 1,000+ tenants
- ⚠️ Complex backup/restore per tenant
- ⚠️ Schema limit: ~50,000 (PostgreSQL)

### ADR-002: Modular Monolith over Microservices

**Status**: Accepted  
**Date**: 2025-01-15  
**Context**: Building MVP with limited resources, need fast iteration  
**Decision**: Start with modular monolith, extract microservices later  
**Consequences**:
- ✅ Faster development
- ✅ Simpler deployment
- ✅ Easier debugging
- ⚠️ Harder to scale specific components
- ⚠️ Requires discipline to maintain modularity

### ADR-003: Next.js 15 for Frontend

**Status**: Accepted  
**Date**: 2025-01-15  
**Context**: Need SSR for SEO, fast development, modern tooling  
**Decision**: Use Next.js 15 (latest stable) with App Router  
**Consequences**:
- ✅ Excellent developer experience (Turbopack)
- ✅ Server-side rendering for public pages
- ✅ React 19 features
- ⚠️ Learning curve for App Router
- ⚠️ Need to ensure library compatibility with React 19

### ADR-004: JWT Stateless Authentication

**Status**: Accepted  
**Date**: 2025-01-15  
**Context**: Need scalable authentication for distributed API servers  
**Decision**: Use JWT tokens (stateless) instead of server sessions  
**Consequences**:
- ✅ Scales horizontally (no shared session state)
- ✅ Works with load balancers
- ✅ Mobile-friendly
- ⚠️ Cannot revoke tokens before expiry (workaround: short expiry + refresh tokens)
- ⚠️ Larger payload than session ID

---

## 📖 References & Further Reading

### Internal Documentation
- [PROJECT_SETUP.md](./PROJECT_SETUP.md) - Setup instructions
- [IMPLEMENTATION_ROADMAP.md](./IMPLEMENTATION_ROADMAP.md) - Sprint guide
- [API_REFERENCE.md](./API_REFERENCE.md) - API documentation
- [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) - Database design

### External Resources
- [Spring Boot Multi-Tenancy](https://www.baeldung.com/hibernate-5-multitenancy)
- [Next.js 15 Documentation](https://nextjs.org/docs)
- [PostgreSQL Schema Documentation](https://www.postgresql.org/docs/15/ddl-schemas.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

## 📝 Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-15 | Initial architecture specification |

---

## ✅ Review Checklist

Before making architectural changes, review:

- [ ] Does this change align with quality attributes (security, scalability)?
- [ ] Have we documented the decision (ADR)?
- [ ] Does this affect tenant isolation?
- [ ] Is this change backwards compatible?
- [ ] Have we updated diagrams?
- [ ] Have we considered the scaling implications?
- [ ] Does this require infrastructure changes?

---

*Architecture Specification - Version 1.0*  
*Last Updated: January 2025*  
*Status: Living Document - Update as system evolves*
