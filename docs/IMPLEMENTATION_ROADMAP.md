# IMPLEMENTATION_ROADMAP.md - 8-Week Sprint-by-Sprint Guide

## 🎯 Overview

This roadmap breaks down the 8-week MVP into **4 two-week sprints** with clear daily tasks, deliverables, and AI-ready prompts.

**Total Timeline**: 8 weeks (2 sprints per month)  
**Sprint Duration**: 2 weeks (10 working days)  
**Daily Commitment**: 4-6 hours  
**Final Goal**: Production-ready SaaS platform with 3-5 pilot users

**Tech Stack (2025 Modern):**
- Backend: Spring Boot 3.5.x + Java 21 + PostgreSQL 15
- Frontend: **Next.js 15** (latest stable) + TypeScript + Axios
- Deployment: AWS (EC2, RDS, S3, CloudFront)

---

## 📊 Progress Tracking

```
Week 1-2:  Sprint 1 - Foundation & Multi-Tenancy       [ ] Not Started
Week 3-4:  Sprint 2 - League & Team Management         [ ] Not Started
Week 5-6:  Sprint 3 - Match Scheduling & Results       [ ] Not Started
Week 7-8:  Sprint 4 - Standings, Payments & Launch     [ ] Not Started
```

**Instructions**: Update checkboxes as you complete each sprint!

---

## 🚀 SPRINT 1: Foundation & Multi-Tenancy (Weeks 1-2)

### 🎯 Sprint Goal
Build the core multi-tenant infrastructure and authentication system. By the end of Sprint 1, multiple field owners should be able to sign up and access their isolated data.

### 📋 Sprint Backlog

| Day | Tasks | Hours | Status |
|-----|-------|-------|--------|
| 1-2 | Project Setup + Multi-Tenancy Core | 8-10h | [ ] |
| 3-4 | Domain Entities (Shared Schema) | 8-10h | [ ] |
| 5-7 | Authentication & JWT | 12-15h | [ ] |
| 8-10 | Frontend Auth + Dashboard Layout | 12-15h | [ ] |

---

### 📅 Day 1-2: Project Setup & Multi-Tenancy Core

#### Tasks Checklist
- [ ] Complete initial project setup from PROJECT_SETUP.md
- [ ] Verify Docker Compose running (PostgreSQL + Redis)
- [ ] Create base package structure in Spring Boot
- [ ] Implement TenantContext (ThreadLocal)
- [ ] Implement TenantInterceptor (subdomain extraction)
- [ ] Implement Hibernate TenantIdentifierResolver
- [ ] Implement MultiTenantConnectionProvider
- [ ] Write unit tests for tenant resolution
- [ ] Test with multiple tenant contexts

#### Files to Create

```
backend/src/main/java/com/ligamanager/
├── config/
│   ├── TenantContext.java
│   ├── TenantInterceptor.java
│   ├── TenantIdentifierResolver.java
│   ├── MultiTenantConnectionProvider.java
│   └── WebMvcConfig.java
└── exception/
    └── UnauthorizedException.java
```

#### Prompt for AI Assistant (Cursor/Claude Code)

**Prompt 1: TenantContext.java**
```
Create a Spring Boot component class TenantContext.java that:
- Uses ThreadLocal<String> to store current tenant ID
- Has static methods: setTenantId(String), getTenantId(), and clear()
- Includes JavaDoc comments explaining tenant isolation
- Add @Component annotation
- Use proper package: com.ligamanager.config

Example usage:
TenantContext.setTenantId("canchas-xyz");
String tenant = TenantContext.getTenantId(); // returns "canchas-xyz"
TenantContext.clear(); // cleanup to prevent memory leaks
```

**Prompt 2: TenantInterceptor.java**
```
Create a Spring Boot HandlerInterceptor for multi-tenancy:

Class: com.ligamanager.config.TenantInterceptor
Implements: HandlerInterceptor

Requirements:
1. In preHandle():
   - Extract tenant from subdomain: "canchas-xyz.domain.com" → "canchas-xyz"
   - Fallback to X-Tenant-ID header if no subdomain
   - Skip tenant resolution for /api/v1/auth/** and /api/v1/public/** paths
   - Call TenantContext.setTenantId(tenantKey)
   - Throw UnauthorizedException if tenant not identified
   - Add debug logging

2. In afterCompletion():
   - Always call TenantContext.clear() to prevent memory leaks

3. Private method extractTenantFromSubdomain(String host):
   - Handle localhost (return null)
   - Remove port if present
   - Split by "." and return first part
   - Example: "canchas-xyz.ligamanager.com:8080" → "canchas-xyz"

Use @Slf4j for logging, @Component annotation.
```

**Prompt 3: Hibernate Multi-Tenancy Configuration**
```
Create Spring Boot multi-tenancy configuration for schema-per-tenant strategy:

1. TenantIdentifierResolver.java
   - Implements: CurrentTenantIdentifierResolver
   - resolveCurrentTenantIdentifier(): Get from TenantContext
   - validateExistingCurrentSessions(): return true

2. MultiTenantConnectionProvider.java
   - Implements: MultiTenantConnectionProvider<String>
   - Implements: HibernatePropertiesCustomizer
   - Constructor: inject DataSource
   - getConnection(tenantId): 
     * Get connection from DataSource
     * Execute: "SET search_path TO tenant_" + tenantId.replace("-", "_")
     * Return connection
   - releaseConnection(): Reset to public schema, then close
   - customize(): Set MULTI_TENANT_CONNECTION_PROVIDER property

3. Update application.yml with:
spring:
  jpa:
    properties:
      hibernate:
        multiTenancy: SCHEMA

Use package: com.ligamanager.config
Add proper error handling and logging.
```

**Prompt 4: Register Interceptor**
```
Create WebMvcConfig.java that registers the TenantInterceptor:

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {
    
    @Autowired
    private TenantInterceptor tenantInterceptor;
    
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(tenantInterceptor)
            .addPathPatterns("/api/v1/**")
            .excludePathPatterns("/api/v1/auth/**", "/api/v1/public/**");
    }
}

Package: com.ligamanager.config
```

#### Verification Checkpoint
```bash
# 1. Code compiles
mvn clean compile

# 2. Test tenant extraction
# Create a simple test controller:
@RestController
@RequestMapping("/api/v1/test")
public class TestController {
    @GetMapping("/tenant")
    public ResponseEntity<String> getTenant() {
        String tenant = TenantContext.getTenantId();
        return ResponseEntity.ok("Current tenant: " + tenant);
    }
}

# 3. Start application
mvn spring-boot:run

# 4. Test with header
curl -H "X-Tenant-ID: test-tenant" http://localhost:8080/api/v1/test/tenant
# Should return: Current tenant: test-tenant

# 5. Test without header (should fail)
curl http://localhost:8080/api/v1/test/tenant
# Should return: 401 Unauthorized
```

#### Git Commit
```bash
git add .
git commit -m "feat: implement multi-tenancy infrastructure

- Add TenantContext for ThreadLocal storage
- Add TenantInterceptor for subdomain/header extraction
- Configure Hibernate schema-per-tenant
- Add WebMvcConfig to register interceptor
- Add basic tests"
```

---

### 📅 Day 3-4: Domain Entities (Shared Schema)

#### Tasks Checklist
- [ ] Create Tenant entity (shared schema)
- [ ] Create Subscription entity
- [ ] Create PlatformUser entity
- [ ] Create repositories for shared entities
- [ ] Create Flyway migration V1__create_shared_schema.sql
- [ ] Test database connection and migrations
- [ ] Create enum types (SubscriptionPlan, SubscriptionStatus, UserRole)
- [ ] Write repository tests

#### Files to Create

```
backend/src/main/java/com/ligamanager/
├── domain/
│   ├── Tenant.java
│   ├── Subscription.java
│   ├── PlatformUser.java
│   └── enums/
│       ├── SubscriptionPlan.java
│       ├── SubscriptionStatus.java
│       └── UserRole.java
├── repository/
│   ├── TenantRepository.java
│   ├── SubscriptionRepository.java
│   └── PlatformUserRepository.java
└── resources/
    └── db/migration/
        └── V1__create_shared_schema.sql
```

#### Prompt for AI Assistant

**Prompt 1: Shared Schema Entities**
```
Create JPA entities for the shared platform schema (public):

1. Tenant.java (com.ligamanager.domain)
Fields:
- UUID id (primary key, auto-generated)
- String tenantKey (unique, e.g., "canchas-xyz")
- String schemaName (e.g., "tenant_canchas_xyz")
- String businessName (required, max 200 chars)
- String ownerName (max 150 chars)
- String email (unique, required, max 150 chars)
- String phone (max 20 chars)
- SubscriptionPlan subscriptionPlan (enum, default BASIC)
- SubscriptionStatus subscriptionStatus (enum, default ACTIVE)
- LocalDateTime createdAt (@CreationTimestamp)
- LocalDateTime updatedAt (@UpdateTimestamp)

Annotations:
- @Entity
- @Table(name = "tenants", schema = "public")
- @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor (Lombok)
- Validation: @NotNull, @NotBlank, @Email where appropriate

2. Subscription.java
Fields:
- UUID id
- ManyToOne Tenant tenant (@JoinColumn, cascade, fetch LAZY)
- String planName (required)
- String billingCycle (MONTHLY, YEARLY)
- Integer amountCents (store in cents)
- String currency (default "MXN")
- LocalDate startDate (required)
- LocalDate endDate
- LocalDate nextBillingDate
- Boolean autoRenew (default true)
- String paymentMethod (STRIPE, OPENPAY)
- String externalSubscriptionId
- SubscriptionStatus status (default ACTIVE)
- LocalDateTime createdAt, updatedAt

3. PlatformUser.java
Fields:
- UUID id
- ManyToOne Tenant tenant
- String email (unique, required)
- String passwordHash (BCrypt, required)
- String fullName
- UserRole role (enum, default TENANT_ADMIN)
- Boolean isActive (default true)
- LocalDateTime lastLoginAt
- LocalDateTime createdAt, updatedAt

All entities should use @Table(schema = "public") since they're shared.
```

**Prompt 2: Enums**
```
Create enum classes in com.ligamanager.domain.enums:

1. SubscriptionPlan.java
public enum SubscriptionPlan {
    BASIC,
    PRO,
    ENTERPRISE
}

2. SubscriptionStatus.java
public enum SubscriptionStatus {
    ACTIVE,
    SUSPENDED,
    CANCELLED,
    TRIAL
}

3. UserRole.java
public enum UserRole {
    TENANT_ADMIN,
    PLATFORM_ADMIN,
    TENANT_VIEWER
}
```

**Prompt 3: Repositories**
```
Create Spring Data JPA repositories in com.ligamanager.repository:

1. TenantRepository extends JpaRepository<Tenant, UUID>
Custom queries:
- Optional<Tenant> findByTenantKey(String tenantKey);
- Optional<Tenant> findByEmail(String email);
- boolean existsByTenantKey(String tenantKey);
- boolean existsByEmail(String email);
- List<Tenant> findBySubscriptionStatus(SubscriptionStatus status);

2. SubscriptionRepository extends JpaRepository<Subscription, UUID>
Custom queries:
- List<Subscription> findByTenantId(UUID tenantId);
- List<Subscription> findByNextBillingDateBefore(LocalDate date);
- Optional<Subscription> findByTenantIdAndStatus(UUID tenantId, SubscriptionStatus status);

3. PlatformUserRepository extends JpaRepository<PlatformUser, UUID>
Custom queries:
- Optional<PlatformUser> findByEmail(String email);
- List<PlatformUser> findByTenantId(UUID tenantId);
- boolean existsByEmail(String email);

Add @Repository annotation to each.
```

**Prompt 4: Flyway Migration**
```
Create SQL migration file: src/main/resources/db/migration/V1__create_shared_schema.sql

Content:
1. CREATE SCHEMA IF NOT EXISTS public;

2. CREATE TABLE public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_key VARCHAR(50) UNIQUE NOT NULL,
    schema_name VARCHAR(63) NOT NULL,
    business_name VARCHAR(200) NOT NULL,
    owner_name VARCHAR(150),
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(20),
    subscription_plan VARCHAR(50) NOT NULL DEFAULT 'BASIC',
    subscription_status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_tenant_key_format CHECK (tenant_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT check_subscription_plan CHECK (subscription_plan IN ('BASIC', 'PRO', 'ENTERPRISE')),
    CONSTRAINT check_subscription_status CHECK (subscription_status IN ('ACTIVE', 'SUSPENDED', 'CANCELLED', 'TRIAL'))
);

3. CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    plan_name VARCHAR(50) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'MXN',
    start_date DATE NOT NULL,
    end_date DATE,
    next_billing_date DATE,
    auto_renew BOOLEAN DEFAULT TRUE,
    payment_method VARCHAR(50),
    external_subscription_id VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_billing_cycle CHECK (billing_cycle IN ('MONTHLY', 'YEARLY'))
);

4. CREATE TABLE public.platform_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150),
    role VARCHAR(30) NOT NULL DEFAULT 'TENANT_ADMIN',
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT check_user_role CHECK (role IN ('TENANT_ADMIN', 'PLATFORM_ADMIN', 'TENANT_VIEWER'))
);

5. Add indexes:
CREATE INDEX idx_tenants_tenant_key ON public.tenants(tenant_key);
CREATE INDEX idx_tenants_email ON public.tenants(email);
CREATE INDEX idx_subscriptions_tenant_id ON public.subscriptions(tenant_id);
CREATE INDEX idx_platform_users_email ON public.platform_users(email);
CREATE INDEX idx_platform_users_tenant_id ON public.platform_users(tenant_id);

6. Create trigger for updated_at:
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON public.tenants
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_platform_users_updated_at BEFORE UPDATE ON public.platform_users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Verification Checkpoint
```bash
# 1. Compile
mvn clean compile

# 2. Start application (will run Flyway migrations)
mvn spring-boot:run

# 3. Check migration applied
psql -h localhost -U ligamanager -d ligamanager -c "\dt public.*"
# Should show: tenants, subscriptions, platform_users, flyway_schema_history

# 4. Insert test data
psql -h localhost -U ligamanager -d ligamanager << EOF
INSERT INTO public.tenants (tenant_key, schema_name, business_name, email, subscription_plan)
VALUES ('test-tenant', 'tenant_test_tenant', 'Test Canchas', 'test@example.com', 'BASIC');

SELECT * FROM public.tenants;
EOF

# 5. Test repository
# Create simple test in TenantRepositoryTest.java
@SpringBootTest
@Testcontainers
class TenantRepositoryTest {
    @Autowired
    private TenantRepository tenantRepository;
    
    @Test
    void shouldFindTenantByKey() {
        Tenant tenant = Tenant.builder()
            .tenantKey("test-key")
            .schemaName("tenant_test_key")
            .businessName("Test")
            .email("test@test.com")
            .build();
        
        tenantRepository.save(tenant);
        
        Optional<Tenant> found = tenantRepository.findByTenantKey("test-key");
        assertThat(found).isPresent();
        assertThat(found.get().getBusinessName()).isEqualTo("Test");
    }
}
```

#### Git Commit
```bash
git add .
git commit -m "feat: add shared schema entities and migration

- Create Tenant, Subscription, PlatformUser entities
- Add enums for SubscriptionPlan, Status, UserRole
- Create Spring Data repositories
- Add Flyway migration V1 for shared schema
- Add indexes and triggers for updated_at"
```

---

### 📅 Day 5-7: Authentication & JWT

#### Tasks Checklist
- [ ] Implement JWT token service (generation + validation)
- [ ] Create authentication controller (signup, login, me)
- [ ] Implement Spring Security configuration
- [ ] Create DTO classes for auth requests/responses
- [ ] Add password encryption (BCrypt)
- [ ] Implement tenant provisioning service
- [ ] Create V2 migration (tenant schema template)
- [ ] Write integration tests for auth flow
- [ ] Test full signup → login → access protected endpoint

#### Files to Create

```
backend/src/main/java/com/ligamanager/
├── security/
│   ├── JwtTokenService.java
│   ├── JwtAuthenticationFilter.java
│   ├── SecurityConfig.java
│   └── PasswordEncoderConfig.java
├── controller/
│   └── AuthController.java
├── service/
│   ├── AuthService.java
│   └── TenantProvisioningService.java
├── dto/
│   ├── SignupRequest.java
│   ├── LoginRequest.java
│   ├── AuthResponse.java
│   └── ApiResponse.java
└── resources/db/migration/
    └── V2__create_tenant_schema_template.sql
```

#### Prompt for AI Assistant

**Prompt 1: JWT Token Service**
```
Create JwtTokenService.java (com.ligamanager.security):

Use io.jsonwebtoken (JJWT) library version 0.12.x with the new API.

Requirements:
1. Constructor injection:
   - @Value("${jwt.secret}") String secret
   - @Value("${jwt.expiration:86400000}") long expirationMs
   - Create SecretKey using: Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8))

2. generateToken(String tenantId, String userId, String email) → String
   - Create claims Map with: tenantId, userId, email
   - Set subject = userId
   - Set issuedAt = now
   - Set expiration = now + expirationMs
   - Use Jwts.builder().claims().subject().issuedAt().expiration().signWith(secretKey).compact()

3. extractClaims(String token) → Claims
   - Use: Jwts.parser().verifyWith(secretKey).build().parseSignedClaims(token).getPayload()

4. extractTenantId(String token) → String
   - Get "tenantId" claim

5. extractUserId(String token) → String
   - Get subject

6. validateToken(String token) → boolean
   - Try to extract claims
   - Check expiration not before now
   - Catch and log exceptions
   - Return false if invalid

Use @Service, @Slf4j annotations.
Add JavaDoc comments.
```

**Prompt 2: JWT Authentication Filter**
```
Create JwtAuthenticationFilter.java (com.ligamanager.security):

Extends: OncePerRequestFilter

Requirements:
1. Constructor: inject JwtTokenService

2. doFilterInternal():
   - Extract token from "Authorization: Bearer {token}" header
   - If no header or doesn't start with "Bearer ", continue filter chain
   - Validate token using jwtTokenService.validateToken()
   - If valid:
     * Extract userId and tenantId from token
     * Set TenantContext.setTenantId(tenantId)
     * Create UsernamePasswordAuthenticationToken with userId
     * Set authentication in SecurityContextHolder
     * Log success
   - Catch exceptions and log errors
   - Continue filter chain

Use @Component, @RequiredArgsConstructor, @Slf4j.
```

**Prompt 3: Security Configuration**
```
Create SecurityConfig.java (com.ligamanager.security):

Requirements:
1. Inject JwtAuthenticationFilter

2. @Bean SecurityFilterChain filterChain(HttpSecurity http):
   - Disable CSRF (JWT is stateless)
   - Session management: STATELESS
   - Authorize requests:
     * Permit: /api/v1/auth/**, /api/v1/public/**, /actuator/health
     * Require authentication: /api/v1/**
   - Add JwtAuthenticationFilter before UsernamePasswordAuthenticationFilter
   - Configure CORS (allow localhost:3000)

3. @Bean PasswordEncoder:
   - Return new BCryptPasswordEncoder()

Use @Configuration, @EnableWebSecurity.
Add CORS configuration for frontend development.
```

**Prompt 4: Auth Service**
```
Create AuthService.java (com.ligamanager.service):

Inject:
- TenantRepository, PlatformUserRepository, SubscriptionRepository
- TenantProvisioningService
- JwtTokenService
- PasswordEncoder

Methods:

1. signup(SignupRequest request) → AuthResponse:
   - Validate email not already registered (throw DuplicateResourceException)
   - Generate unique tenantKey from businessName (lowercase, replace spaces with -)
   - Check tenantKey doesn't exist (add number suffix if needed)
   - Create Tenant entity:
     * Set tenantKey, schemaName = "tenant_" + tenantKey.replace("-", "_")
     * Set businessName, ownerName, email, phone
     * Set subscriptionPlan = BASIC, subscriptionStatus = TRIAL
   - Save tenant
   - Call tenantProvisioningService.createTenantSchema(tenantKey)
   - Create PlatformUser:
     * Set tenant, email, passwordHash = passwordEncoder.encode(password)
     * Set fullName, role = TENANT_ADMIN, isActive = true
   - Save user
   - Create default Subscription:
     * Set tenant, planName = "Basic", billingCycle = MONTHLY
     * Set amountCents = 59900 (599 MXN), currency = MXN
     * Set startDate = now, nextBillingDate = now + 7 days (trial)
     * Set status = ACTIVE, autoRenew = true
   - Save subscription
   - Generate JWT token
   - Return AuthResponse with token, user info, tenant info

2. login(LoginRequest request) → AuthResponse:
   - Find user by email (throw UnauthorizedException if not found)
   - Validate password using passwordEncoder.matches()
   - Throw UnauthorizedException if password wrong
   - Update lastLoginAt
   - Generate JWT token
   - Return AuthResponse

3. getCurrentUser(String userId) → User:
   - Find user by ID
   - Return user info

Use @Service, @Transactional, @Slf4j.
Add proper error handling and logging.
```

**Prompt 5: Tenant Provisioning Service**
```
Create TenantProvisioningService.java (com.ligamanager.service):

Inject: JdbcTemplate

Method: createTenantSchema(String tenantKey) → void

Requirements:
1. Generate schemaName = "tenant_" + tenantKey.replace("-", "_")
2. Execute SQL: CREATE SCHEMA IF NOT EXISTS {schemaName}
3. Read tenant schema template from V2__create_tenant_schema_template.sql
4. Replace all occurrences of "__TENANT_SCHEMA__" with actual schemaName
5. Execute the modified SQL to create all tables
6. Handle exceptions (log and rethrow)
7. Log success

Use @Service, @Slf4j.

Note: For MVP, you can hardcode the table creation SQL in the method.
For production, read from classpath resource.
```

**Prompt 6: DTOs**
```
Create DTO classes in com.ligamanager.dto:

1. SignupRequest:
   - String businessName (@NotBlank, @Size(min=3, max=200))
   - String ownerName (@Size(max=150))
   - String email (@NotBlank, @Email)
   - String phone
   - String password (@NotBlank, @Size(min=8))
   - String subscriptionPlan (optional, default BASIC)

2. LoginRequest:
   - String email (@NotBlank, @Email)
   - String password (@NotBlank)

3. AuthResponse:
   - String token
   - UserInfo user (nested class)
   - TenantInfo tenant (nested class)

4. ApiResponse<T>:
   - Boolean success
   - T data
   - String message
   - Instant timestamp
   - ApiError error (for failures)

5. ApiError:
   - String code
   - String message
   - String field
   - Map<String, Object> details

Use @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor (Lombok).
Add validation annotations from jakarta.validation.constraints.
```

**Prompt 7: Auth Controller**
```
Create AuthController.java (com.ligamanager.controller):

Inject: AuthService

Endpoints:

1. POST /api/v1/auth/signup (@RequestBody @Valid SignupRequest)
   - Call authService.signup()
   - Return ApiResponse<AuthResponse> with status 201 CREATED
   - Catch DuplicateResourceException → 409 CONFLICT

2. POST /api/v1/auth/login (@RequestBody @Valid LoginRequest)
   - Call authService.login()
   - Return ApiResponse<AuthResponse> with status 200 OK
   - Catch UnauthorizedException → 401 UNAUTHORIZED

3. GET /api/v1/auth/me (requires authentication)
   - Get userId from SecurityContextHolder
   - Call authService.getCurrentUser(userId)
   - Return ApiResponse<User>

Use @RestController, @RequestMapping("/api/v1/auth"), @RequiredArgsConstructor, @Slf4j.
Add @CrossOrigin(origins = "http://localhost:3000") for CORS during development.
```

**Prompt 8: Tenant Schema Template Migration**
```
Create V2__create_tenant_schema_template.sql in src/main/resources/db/migration:

This is a COMMENT-ONLY migration. The actual table creation happens via
TenantProvisioningService when tenants sign up.

Content:
-- This migration documents the tenant schema structure
-- Actual schemas are created dynamically via TenantProvisioningService

-- Template structure (applied to each tenant schema):
-- 
-- Tables:
-- - leagues (id, name, season, start_date, end_date, league_type, status)
-- - teams (id, league_id, name, logo_url, captain_name, captain_phone)
-- - players (id, team_id, full_name, birth_date, position, jersey_number, is_active)
-- - matches (id, league_id, home_team_id, away_team_id, scheduled_at, field_name, home_score, away_score, status)
-- - match_events (id, match_id, player_id, minute, event_type, description)
-- - standings (id, league_id, team_id, played, won, drawn, lost, goals_for, goals_against, points)
--
-- See TenantProvisioningService for actual implementation
```

#### Verification Checkpoint
```bash
# 1. Start application
mvn spring-boot:run

# 2. Test Signup
curl -X POST http://localhost:8080/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "businessName": "Canchas Test",
    "ownerName": "Juan Test",
    "email": "juan@test.com",
    "phone": "+52 55 1234 5678",
    "password": "Test123456"
  }'

# Should return 201 with JWT token

# 3. Verify tenant schema created
psql -h localhost -U ligamanager -d ligamanager -c "\dn"
# Should show: tenant_canchas_test

# 4. Test Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "juan@test.com",
    "password": "Test123456"
  }'

# Should return 200 with JWT token

# 5. Save token and test protected endpoint
TOKEN="<paste_token_here>"

curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/v1/auth/me

# Should return user info

# 6. Test invalid token
curl -H "Authorization: Bearer invalid_token" \
  http://localhost:8080/api/v1/auth/me

# Should return 401
```

#### Git Commit
```bash
git add .
git commit -m "feat: implement JWT authentication

- Add JwtTokenService for token generation/validation
- Add JwtAuthenticationFilter for request authentication
- Configure Spring Security with JWT
- Implement signup and login flows
- Add TenantProvisioningService for schema creation
- Create auth DTOs and controller
- Add V2 migration for tenant schema template"
```

---

### 📅 Day 8-10: Frontend Authentication & Dashboard Layout

#### Tasks Checklist
- [ ] Create Next.js authentication pages (signup, login)
- [ ] Implement API client with Axios interceptors
- [ ] Create auth store with Zustand (persist to localStorage)
- [ ] Protect dashboard routes with middleware
- [ ] Create dashboard layout (header, sidebar, navigation)
- [ ] Add loading states and error handling
- [ ] Implement logout functionality
- [ ] Test full auth flow in browser
- [ ] Make UI mobile-responsive

#### Files to Create

```
frontend/src/
├── app/
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   ├── signup/page.tsx
│   │   └── layout.tsx
│   ├── (dashboard)/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── leagues/page.tsx (placeholder)
│   └── middleware.ts
├── components/
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Card.tsx
│   │   └── Alert.tsx
│   ├── auth/
│   │   ├── SignupForm.tsx
│   │   └── LoginForm.tsx
│   └── layout/
│       ├── Header.tsx
│       ├── Sidebar.tsx
│       └── DashboardLayout.tsx
├── lib/
│   ├── api.ts
│   ├── auth.ts
│   └── constants.ts
├── hooks/
│   └── useAuth.ts
├── store/
│   └── authStore.ts
└── types/
    └── index.ts
```

#### Prompt for AI Assistant

**Prompt 1: API Client**
```
Create lib/api.ts for API communication:

Use Axios to create a configured client:

1. Create class ApiClient:
   - baseURL from process.env.NEXT_PUBLIC_API_URL
   - timeout: 30000
   - headers: Content-Type: application/json

2. Request interceptor:
   - Get token from localStorage.getItem('token')
   - If token exists, add Authorization: Bearer {token} header
   - Return config

3. Response interceptor:
   - Handle 401: Clear localStorage, redirect to /login
   - Return response on success
   - Reject with error on failure

4. HTTP methods:
   - async get<T>(url, config?) → ApiResponse<T>
   - async post<T>(url, data?, config?) → ApiResponse<T>
   - async put<T>(url, data?, config?) → ApiResponse<T>
   - async delete<T>(url, config?) → ApiResponse<T>

5. Export types:
   - interface ApiResponse<T> { success: boolean; data: T; message?: string; timestamp: string }
   - interface ApiError { code: string; message: string; field?: string }

6. Export singleton: export const api = new ApiClient();

Use TypeScript with proper typing.
```

**Prompt 2: Auth Store (Zustand)**
```
Create store/authStore.ts using Zustand with persist middleware:

Interface AuthState:
- user: User | null
- token: string | null
- isAuthenticated: boolean
- isLoading: boolean
- error: string | null

Actions:
- login(email: string, password: string) → Promise<void>
  * Set isLoading = true
  * Call api.post('/auth/login', { email, password })
  * Store token and user in localStorage
  * Update state
  * Handle errors

- signup(data: SignupData) → Promise<void>
  * Similar to login
  * Call api.post('/auth/signup', data)

- logout() → void
  * Clear localStorage (token, user)
  * Reset state
  * Redirect to /login

- loadUser() → Promise<void>
  * Check if token exists in localStorage
  * If yes, call api.get('/auth/me')
  * Update user state
  * If fails, logout

- clearError() → void
  * Set error = null

Use Zustand persist middleware to save user and token to localStorage.

Export: export const useAuthStore = create<AuthState>()(persist(...));

TypeScript with proper types for User, SignupData.
```

**Prompt 3: Login Page**
```
Create app/(auth)/login/page.tsx:

"use client" component that:
1. Uses useAuthStore for login, isLoading, error
2. Uses useState for email and password
3. Form with:
   - Email input (with Mail icon from lucide-react)
   - Password input (with Lock icon)
   - Submit button (shows Loader2 icon when loading)
   - Link to /signup
4. Handles form submit:
   - e.preventDefault()
   - clearError()
   - await login(email, password)
   - router.push('/dashboard') on success
5. Shows error Alert if error exists
6. Mobile responsive with Tailwind CSS
7. Use shadcn/ui style components

Clean, modern design. Spanish labels ("Email", "Contraseña", "Iniciar Sesión").
```

**Prompt 4: Signup Page**
```
Create app/(auth)/signup/page.tsx:

Similar to login page but with fields:
- Business Name (Nombre del Negocio)
- Owner Name (Nombre del Dueño)
- Email
- Phone (Teléfono)
- Password (Contraseña)
- Confirm Password (Confirmar Contraseña)

Validation:
- All fields required except Owner Name
- Password minimum 8 characters
- Passwords must match

Use react-hook-form + zod for validation.

On success: router.push('/dashboard')

Spanish UI. Clean design. Mobile responsive.
```

**Prompt 5: Protected Route Middleware**
```
Create middleware.ts at project root:

Use Next.js 15 middleware to protect routes:

1. Check if token exists in cookies or localStorage (via request headers)
2. Public routes: /, /login, /signup, /public/*
3. Protected routes: /dashboard/*
4. If accessing /dashboard without token: redirect to /login
5. If accessing /login or /signup with token: redirect to /dashboard

Export config with matcher for routes to protect.

Use Next.js 15 App Router syntax with improved middleware API.
Handle both cookie-based and header-based authentication.
```

**Prompt 6: Dashboard Layout**
```
Create app/(dashboard)/layout.tsx:

"use client" component with:
1. Check authentication on mount (useAuthStore.loadUser())
2. If not authenticated: redirect to /login
3. Layout structure:
   - Header (top, fixed)
     * Logo
     * User dropdown menu (logout button)
   - Sidebar (left, collapsible on mobile)
     * Navigation links:
       - Dashboard (/)
       - Leagues (/leagues)
       - Teams (/teams)
       - Matches (/matches)
       - Settings (/settings)
   - Main content area (children)

4. Mobile responsive:
   - Sidebar collapses to hamburger menu on small screens
   - Use Tailwind CSS breakpoints

5. Use lucide-react icons for navigation

Clean, modern design. Light theme. Tailwind CSS.
```

**Prompt 7: UI Components**
```
Create basic UI components in components/ui/ using Tailwind CSS:

1. Button.tsx:
   - Props: children, onClick, disabled, variant (primary, secondary, outline), className
   - Styles: Tailwind with hover states
   - Support loading state

2. Input.tsx:
   - Props: type, placeholder, value, onChange, className, required, disabled
   - Styles: Border, focus ring, padding

3. Card.tsx:
   - Props: children, className, title
   - Styles: White background, shadow, rounded, padding

4. Alert.tsx:
   - Props: children, variant (info, success, error, warning)
   - Color-coded backgrounds
   - Icon based on variant

Use TypeScript. Export as named exports. 
Make accessible (proper ARIA labels).
```

#### Verification Checkpoint
```bash
# 1. Start frontend
cd frontend
npm run dev

# 2. Open browser: http://localhost:3000

# 3. Test Signup Flow:
# - Navigate to /signup
# - Fill form with test data
# - Submit
# - Should redirect to /dashboard
# - Check localStorage has token and user

# 4. Refresh page:
# - Should stay logged in
# - Dashboard should load

# 5. Test Logout:
# - Click user dropdown
# - Click logout
# - Should clear localStorage
# - Should redirect to /login

# 6. Test Login:
# - Go to /login
# - Enter credentials from signup
# - Should login and redirect to /dashboard

# 7. Test Protected Routes:
# - Logout
# - Try to access /dashboard directly
# - Should redirect to /login

# 8. Mobile Responsiveness:
# - Open DevTools
# - Switch to mobile view (375px width)
# - Sidebar should collapse
# - Forms should be readable
```

#### Git Commit
```bash
git add .
git commit -m "feat: implement frontend authentication

- Create login and signup pages
- Add API client with Axios
- Implement auth store with Zustand + persist
- Add protected route middleware
- Create dashboard layout with header and sidebar
- Build reusable UI components (Button, Input, Card, Alert)
- Make fully responsive for mobile"
```

---

### 🎉 Sprint 1 Complete! Definition of Done

**Checklist:**
- [ ] Multi-tenancy works: Each tenant has isolated schema
- [ ] Authentication works: Signup, login, logout functional
- [ ] Database migrations applied successfully
- [ ] Backend API endpoints tested (Postman/cURL)
- [ ] Frontend auth flow works end-to-end
- [ ] Dashboard layout renders correctly
- [ ] Protected routes redirect properly
- [ ] Code committed to Git with meaningful messages
- [ ] No critical bugs or console errors
- [ ] Can create 2+ test tenants with separate schemas

**Metrics:**
- ✅ Backend endpoints: 4 (signup, login, logout, me)
- ✅ Database schemas: 2+ (public + test tenants)
- ✅ Frontend pages: 3 (signup, login, dashboard)
- ✅ Lines of code: ~2,500-3,500
- ✅ Tests passing: Unit + Integration

**Next Sprint Preview:**
Sprint 2 focuses on League and Team management - the core features field owners need daily.

---

## 🚀 SPRINT 2: League & Team Management (Weeks 3-4)

### 🎯 Sprint Goal
Enable field owners to create leagues, add teams, manage player rosters, and upload team logos. By end of Sprint 2, users should be able to fully set up their leagues.

### 📋 Sprint Backlog

| Day | Tasks | Hours | Status |
|-----|-------|-------|--------|
| 11-12 | League Domain & API | 8-10h | [ ] |
| 13-15 | Team & Player Domain & API | 12-15h | [ ] |
| 16-18 | Frontend League & Team UI | 12-15h | [ ] |

---

### 📅 Day 11-12: League Domain & API

#### Tasks Checklist
- [ ] Create League entity (tenant schema)
- [ ] Create LeagueRepository with custom queries
- [ ] Implement LeagueService (CRUD + business logic)
- [ ] Create LeagueController (REST endpoints)
- [ ] Create League DTOs (Request/Response)
- [ ] Add validation rules
- [ ] Write unit tests for LeagueService
- [ ] Test API endpoints with Postman

#### Prompt for AI Assistant

```
Task: Create complete League management module for multi-tenant SaaS

1. League Entity (com.ligamanager.domain.League):
   - UUID id
   - String name (required, max 150 chars, @NotBlank)
   - String season (e.g., "Apertura 2025", max 50 chars)
   - LocalDate startDate
   - LocalDate endDate
   - LeagueType leagueType (enum: FUTBOL_5, FUTBOL_7, FUTBOL_11)
   - LeagueStatus status (enum: DRAFT, ACTIVE, FINISHED, CANCELLED)
   - OneToMany List<Team> teams (cascade ALL, orphanRemoval, lazy fetch)
   - OneToMany List<Match> matches (cascade ALL, lazy fetch)
   - LocalDateTime createdAt (@CreationTimestamp)
   - LocalDateTime updatedAt (@UpdateTimestamp)
   
   IMPORTANT: Do NOT use @Table(schema = "...") - this is tenant-scoped
   Add constraint: end_date must be after start_date
   Use Lombok: @Data, @Builder, @NoArgsConstructor, @AllArgsConstructor, @Entity

2. LeagueRepository (com.ligamanager.repository.LeagueRepository):
   extends JpaRepository<League, UUID>
   
   Custom queries:
   - List<League> findByStatus(LeagueStatus status);
   - List<League> findBySeasonContainingIgnoreCase(String season);
   - long countByStatus(LeagueStatus status);
   - boolean existsByNameAndSeason(String name, String season);
   - @Query with JOIN FETCH for teams and matches

3. LeagueService (com.ligamanager.service.LeagueService):
   
   Methods:
   - createLeague(LeagueRequest) → LeagueResponse
     * Validate: name + season unique per tenant
     * Throw DuplicateResourceException if exists
     * Create league with status = DRAFT
     * Save and return response
   
   - updateLeague(UUID id, LeagueRequest) → LeagueResponse
     * Find by ID or throw ResourceNotFoundException
     * Validate: Cannot modify if status = FINISHED
     * Update fields
     * Save and return
   
   - deleteLeague(UUID id) → void
     * Soft delete: Set status = CANCELLED
     * Validate: No active matches (check matches list)
     * If has matches, throw IllegalStateException
   
   - getLeagueById(UUID id) → LeagueResponse
   - getAllLeagues() → List<LeagueResponse>
   - getLeaguesByStatus(LeagueStatus) → List<LeagueResponse>
   
   Use @Service, @Transactional, @Slf4j, @RequiredArgsConstructor
   Add logging for all operations
   Private method: mapToResponse(League) → LeagueResponse

4. LeagueController (com.ligamanager.controller.LeagueController):
   
   Endpoints:
   - POST /api/v1/leagues → createLeague (@Valid @RequestBody)
   - GET /api/v1/leagues → getAllLeagues (with optional ?status= filter)
   - GET /api/v1/leagues/{id} → getLeagueById (@PathVariable UUID)
   - PUT /api/v1/leagues/{id} → updateLeague (@PathVariable, @Valid @RequestBody)
   - DELETE /api/v1/leagues/{id} → deleteLeague (@PathVariable)
   
   Return ApiResponse<T> wrapper for all endpoints
   Use @RestController, @RequestMapping("/api/v1/leagues")
   Add @RequiredArgsConstructor, @Slf4j
   Handle exceptions with proper HTTP status codes

5. DTOs (com.ligamanager.dto):
   
   LeagueRequest:
   - String name (@NotBlank, @Size(min=3, max=150))
   - String season (@Size(max=50))
   - LocalDate startDate
   - LocalDate endDate (@Future optional)
   - String leagueType (@NotNull, @Pattern for enum values)
   
   LeagueResponse:
   - UUID id
   - String name, season
   - LocalDate startDate, endDate
   - String leagueType, status
   - Integer teamCount, matchCount
   - LocalDateTime createdAt, updatedAt
   
   Use @Data, @Builder, validation annotations

6. Unit Tests (LeagueServiceTest):
   - testCreateLeague_WithValidData_Success
   - testCreateLeague_DuplicateName_ThrowsException
   - testUpdateLeague_Success
   - testDeleteLeague_WithMatches_ThrowsException
   
   Use @ExtendWith(MockitoExtension.class)
   Mock LeagueRepository
   Use AssertJ assertions

Generate complete, production-ready code with error handling, logging, and JavaDoc.
```

#### Git Commit
```bash
git add .
git commit -m "feat: implement league management module

- Add League entity with enums (LeagueType, LeagueStatus)
- Create LeagueRepository with custom queries
- Implement LeagueService with full CRUD
- Add LeagueController with REST endpoints
- Create League DTOs with validation
- Add unit tests for service layer"
```

---

### 📅 Day 13-15: Team & Player Domain & API

#### Tasks Checklist
- [ ] Create Team entity (with league relationship)
- [ ] Create Player entity (with team relationship)
- [ ] Implement file upload for team logos (local storage)
- [ ] Create Team and Player repositories
- [ ] Implement TeamService and PlayerService
- [ ] Create controllers with multipart upload support
- [ ] Write integration tests
- [ ] Test file upload with Postman

#### Prompt for AI Assistant

```
Task: Create Team and Player management modules with file upload

1. Team Entity (com.ligamanager.domain.Team):
   - UUID id
   - ManyToOne League league (required, @JoinColumn, fetch LAZY)
   - String name (required, @NotBlank, max 150)
   - String logoUrl (nullable, stores file path)
   - String captainName (max 150)
   - String captainPhone (max 20)
   - String captainEmail (@Email, max 150)
   - OneToMany List<Player> players (cascade ALL, orphanRemoval)
   - LocalDateTime createdAt, updatedAt
   
   Unique constraint: (league_id, name) - team name must be unique per league
   Use @Entity, Lombok annotations

2. Player Entity (com.ligamanager.domain.Player):
   - UUID id
   - ManyToOne Team team (required, fetch LAZY)
   - String fullName (required, max 150)
   - LocalDate birthDate (nullable)
   - Position position (enum: GOALKEEPER, DEFENDER, MIDFIELDER, FORWARD)
   - String jerseyNumber (max 3 chars, e.g., "10")
   - Boolean isActive (default true)
   - LocalDateTime createdAt, updatedAt
   
   Unique constraint: (team_id, jersey_number) for active players
   Method: getAge() → calculate from birthDate
   Use @Entity, Lombok annotations

3. FileStorageService (com.ligamanager.service.FileStorageService):
   
   Methods:
   - saveFile(MultipartFile file, String category) → String filePath
     * Validate: file not empty, size < 2MB, type is image (PNG, JPG, JPEG)
     * Generate unique filename: UUID + original extension
     * Create directory: uploads/{category}/ if not exists
     * Save file to disk
     * Return relative path: /uploads/{category}/{filename}
   
   - deleteFile(String filePath) → void
     * Delete file from disk
     * Log if file doesn't exist
   
   - getFileUrl(String filePath) → String
     * Return: NEXT_PUBLIC_API_URL + filePath
   
   Use @Service, @Value for upload directory path

4. TeamService (com.ligamanager.service.TeamService):
   
   Methods:
   - createTeam(UUID leagueId, TeamRequest) → TeamResponse
     * Validate: league exists and status != FINISHED
     * Validate: team name unique within league
     * Create team
     * Save and return
   
   - uploadTeamLogo(UUID teamId, MultipartFile file) → String logoUrl
     * Find team or throw exception
     * Delete old logo if exists
     * Save new file using FileStorageService
     * Update team.logoUrl
     * Return new URL
   
   - updateTeam(UUID teamId, TeamRequest) → TeamResponse
   - deleteTeam(UUID teamId) → void (check for scheduled matches first)
   - getTeamById(UUID teamId) → TeamResponse
   - getTeamsByLeague(UUID leagueId) → List<TeamResponse>
   
   Use @Service, @Transactional, @Slf4j

5. PlayerService (com.ligamanager.service.PlayerService):
   
   Methods:
   - addPlayer(UUID teamId, PlayerRequest) → PlayerResponse
     * Validate: team exists
     * Validate: jersey number unique within team (for active players)
     * Create player
     * Save and return
   
   - updatePlayer(UUID playerId, PlayerRequest) → PlayerResponse
   - removePlayer(UUID playerId) → void (soft delete: isActive = false)
   - getPlayerById(UUID playerId) → PlayerResponse
   - getPlayersByTeam(UUID teamId, Boolean isActive) → List<PlayerResponse>
   
   Use @Service, @Transactional

6. Controllers:
   
   TeamController (com.ligamanager.controller.TeamController):
   - POST /api/v1/leagues/{leagueId}/teams → createTeam
   - GET /api/v1/leagues/{leagueId}/teams → getTeamsByLeague
   - GET /api/v1/teams/{id} → getTeamById
   - PUT /api/v1/teams/{id} → updateTeam
   - DELETE /api/v1/teams/{id} → deleteTeam
   - POST /api/v1/teams/{id}/logo → uploadLogo (@RequestParam("file") MultipartFile)
   
   PlayerController (com.ligamanager.controller.PlayerController):
   - POST /api/v1/teams/{teamId}/players → addPlayer
   - GET /api/v1/teams/{teamId}/players → getPlayersByTeam (optional ?isActive=)
   - GET /api/v1/players/{id} → getPlayerById
   - PUT /api/v1/players/{id} → updatePlayer
   - DELETE /api/v1/players/{id} → removePlayer
   
   Use @RestController, multipart/form-data for file uploads

7. Static File Serving Configuration:
   
   Add to WebMvcConfig:
   @Override
   public void addResourceHandlers(ResourceHandlerRegistry registry) {
       registry.addResourceHandler("/uploads/**")
           .addResourceLocations("file:uploads/");
   }

Generate complete code with DTOs, validation, error handling, and integration tests.
```

#### Git Commit
```bash
git add .
git commit -m "feat: add team and player management with file upload

- Create Team and Player entities with relationships
- Add FileStorageService for logo uploads
- Implement TeamService and PlayerService
- Add controllers with multipart support
- Configure static file serving
- Add integration tests
- Support unique constraints (team name, jersey number)"
```

---

### 📅 Day 16-18: Frontend League & Team UI

#### Tasks Checklist
- [ ] Create league list page with card grid
- [ ] Add league creation modal/form
- [ ] Create league detail page with tabs
- [ ] Implement team management UI (add/edit/delete)
- [ ] Add team logo upload with preview
- [ ] Create player roster table with actions
- [ ] Add player form (modal)
- [ ] Implement data tables with sorting/filtering
- [ ] Add loading states and error handling
- [ ] Make fully responsive

#### Prompt for AI Assistant

```
Task: Create comprehensive frontend for League and Team management

1. League List Page (app/(dashboard)/leagues/page.tsx):
   - "use client" component
   - Fetch leagues using API client on mount
   - Display as card grid (3 columns on desktop, 1 on mobile)
   - Each card shows:
     * League name (title)
     * Season badge
     * Date range
     * Team count
     * Status badge (color-coded)
     * View button
   - "Create League" button (opens modal)
   - Filter dropdown: All / Active / Draft / Finished
   - Empty state: "No leagues yet. Create your first league!"
   - Loading state: Skeleton cards
   - Error state: Alert with retry button
   
   Use Tailwind CSS, lucide-react icons

2. League Form Modal (components/leagues/LeagueFormModal.tsx):
   - Form fields:
     * Name (text input, required)
     * Season (text input, placeholder: "Apertura 2025")
     * Start Date (date picker)
     * End Date (date picker, must be after start)
     * League Type (select dropdown: Fútbol 5, Fútbol 7, Fútbol 11)
   - Use react-hook-form + zod validation
   - Submit → POST /api/v1/leagues
   - Show success toast on creation
   - Close modal and refresh list
   - Error handling with inline messages
   
   Use shadcn/ui Dialog component or custom modal

3. League Detail Page (app/(dashboard)/leagues/[id]/page.tsx):
   - Fetch league details + teams on mount
   - Header section:
     * League name (editable inline or edit button)
     * Season, dates, type, status
     * Edit and Delete buttons (with confirmation)
   - Tabs:
     * Teams (default)
     * Schedule (placeholder for Sprint 3)
     * Standings (placeholder for Sprint 4)
     * Settings
   - Teams tab:
     * Grid of team cards (logo, name, captain, player count)
     * "Add Team" button → Opens team form modal
   
   Dynamic route with useParams()

4. Team Form Modal (components/teams/TeamFormModal.tsx):
   - Form fields:
     * Team Name (required)
     * Captain Name
     * Captain Phone
     * Logo Upload (click to upload or drag & drop)
   - File upload:
     * Preview uploaded image before submit
     * Max 2MB, PNG/JPG only
     * Show error if invalid file
   - Submit → POST /api/v1/leagues/{id}/teams (multipart/form-data)
   - Handle FormData:
     ```typescript
     const formData = new FormData();
     formData.append('name', teamData.name);
     formData.append('captainName', teamData.captainName);
     formData.append('logo', logoFile);
     ```
   - Success: Close modal, refresh teams
   
   Use react-dropzone for file upload

5. Team Detail/Roster Page (app/(dashboard)/teams/[id]/page.tsx):
   - Header:
     * Team logo (large)
     * Team name
     * Captain info
     * League breadcrumb
   - Player roster table:
     * Columns: Jersey #, Name, Position, Age, Actions (Edit/Remove)
     * Sortable by: name, jersey number
     * Search/filter by name
     * Highlight active players
     * Strikethrough inactive players
   - "Add Player" button
   - Bulk actions: Import CSV (future), Export roster
   
   Use shadcn/ui Table or custom table component

6. Player Form Modal (components/players/PlayerFormModal.tsx):
   - Form fields:
     * Full Name (required)
     * Birth Date (date picker)
     * Position (select: Goalkeeper, Defender, Midfielder, Forward)
     * Jersey Number (max 3 chars, e.g., "10")
   - Validation:
     * Jersey number must be unique within team
     * Show age calculated from birth date
   - Submit → POST /api/v1/teams/{id}/players
   
   Use react-hook-form

7. Shared UI Components:
   - components/ui/Table.tsx: Reusable table with sorting
   - components/ui/Modal.tsx: Generic modal wrapper
   - components/ui/FileUpload.tsx: Drag & drop file upload
   - components/ui/DatePicker.tsx: Date selection
   - components/ui/Select.tsx: Dropdown select
   - components/ui/Badge.tsx: Status badges
   - components/ui/Toast.tsx: Success/error notifications
   
   Use shadcn/ui components or build custom with Tailwind

8. API Hooks (hooks/useLeagues.ts, hooks/useTeams.ts):
   - Use React Query (TanStack Query) for data fetching:
     * useLeagues() → Query leagues with caching
     * useLeague(id) → Query single league
     * useCreateLeague() → Mutation with optimistic updates
     * useTeams(leagueId) → Query teams
     * useCreateTeam() → Mutation
   - Auto-refetch on window focus
   - Cache invalidation after mutations
   
   Install: npm install @tanstack/react-query

Generate complete, production-ready React components with TypeScript.
Use modern hooks patterns. Add PropTypes or TypeScript interfaces.
Make fully accessible (ARIA labels). Mobile-first responsive design.
```

#### Verification Checkpoint
```bash
# 1. Start backend and frontend
# Terminal 1:
cd backend
mvn spring-boot:run

# Terminal 2:
cd frontend
npm run dev

# 2. Open browser: http://localhost:3000

# 3. Test Flow:
# - Login with test account
# - Navigate to Leagues page
# - Click "Create League"
# - Fill form: "Liga Test Apertura 2025"
# - Submit → Should see new league card

# 4. Click on league card:
# - Should open league detail page
# - Click "Add Team"
# - Fill form: "Águilas FC"
# - Upload logo (use any image)
# - Submit → Should see team card

# 5. Click on team card:
# - Should open team detail page
# - Click "Add Player"
# - Fill form: "Miguel Hernández", Position: Forward, Jersey: "10"
# - Submit → Should see player in table

# 6. Mobile Test:
# - Open DevTools
# - Switch to iPhone 12 (390px)
# - All layouts should be readable
# - Sidebar should collapse
# - Cards should stack vertically

# 7. Check Console:
# - No errors
# - API calls succeed (200 OK)
# - Images load correctly
```

#### Git Commit
```bash
git add .
git commit -m "feat: complete league and team management UI

- Add league list page with card grid and filters
- Create league and team form modals
- Implement league detail page with tabs
- Add team roster page with player table
- Support file upload for team logos
- Use React Query for data fetching and caching
- Add loading, error, and empty states
- Full mobile responsive design
- Add reusable UI components (Table, Modal, FileUpload)"
```

---

### 🎉 Sprint 2 Complete! Definition of Done

**Checklist:**
- [ ] League CRUD fully functional (API + UI)
- [ ] Team CRUD with logo upload working
- [ ] Player roster management complete
- [ ] Data persists in tenant-specific schemas
- [ ] Unit and integration tests passing
- [ ] Frontend mobile responsive
- [ ] Error handling and loading states implemented
- [ ] Can create league → add teams → add players end-to-end
- [ ] Team logos display correctly
- [ ] All Git commits meaningful and organized

**Metrics:**
- ✅ Backend endpoints: 12+ (leagues, teams, players, file upload)
- ✅ Database tables: 3 (leagues, teams, players per tenant schema)
- ✅ Frontend pages: 5 (league list, league detail, team detail, forms)
- ✅ Lines of code: ~3,500-4,500
- ✅ File upload working (multipart/form-data)

**Next Sprint Preview:**
Sprint 3 implements automated match scheduling with round-robin algorithm and match result recording.

---

## 🚀 SPRINT 3 & 4 Coming Next...

The complete roadmap continues with:
- **Sprint 3 (Weeks 5-6)**: Match scheduling, calendar view, result recording
- **Sprint 4 (Weeks 7-8)**: Standings calculation, payments, public pages, production deployment

Would you like me to continue generating Sprint 3 and Sprint 4 details now?

---

## 📝 Notes

- **Daily stand-up**: Review previous day's work, plan today's tasks, note blockers
- **Update PROGRESS.md**: Check off completed tasks daily
- **Git commits**: Small, frequent commits with descriptive messages
- **Testing**: Don't skip tests - they catch bugs early
- **Ask for help**: Use AI assistants when stuck

**Remember**: You're building an MVP. Focus on core features. Polish comes later.

---

*Roadmap Last Updated: January 2025*
