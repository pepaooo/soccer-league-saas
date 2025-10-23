# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Liga Manager** - Multi-tenant SaaS platform for soccer field owners in Mexico to manage leagues, teams, players, and matches.

- **Tech Stack**: Spring Boot 3.5.6 + Java 21 + PostgreSQL 15 + Next.js 15
- **Architecture**: Monolith with schema-per-tenant multi-tenancy
- **Build Tool**: Maven 3.9.x
- **Database**: PostgreSQL with Flyway migrations

## Common Commands

### Backend Development

```bash
# Build the project
mvn clean compile

# Run tests
mvn test

# Run single test class
mvn test -Dtest=ClassName

# Run single test method
mvn test -Dtest=ClassName#methodName

# Run application (from backend/ directory)
mvn spring-boot:run

# Package without running tests
mvn package -DskipTests

# Run integration tests
mvn verify -P integration-tests
```

### Local Development

```bash
# Start local services (PostgreSQL + Redis)
docker-compose up -d

# Stop local services
docker-compose down

# View logs
docker-compose logs -f postgres

# Access PostgreSQL
psql -U ligamanager -d ligamanager -h localhost

# Check database tables
psql -U ligamanager -d ligamanager -h localhost -c "\dt"
```

### Frontend (from ../frontend/)

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Run tests
npm test
```

## Architecture Overview

### Multi-Tenancy Strategy

This application uses **schema-per-tenant** isolation:

- **Shared Schema (`public`)**: Contains `tenants`, `subscriptions`, `platform_users` tables
- **Tenant Schemas (`tenant_*`)**: Each tenant gets an isolated schema with `leagues`, `teams`, `players`, `matches`, `match_events`, `standings`

**Tenant Resolution Flow**:
1. Request arrives with subdomain (e.g., `canchas-xyz.ligamanager.com`) or `X-Tenant-ID` header
2. `TenantInterceptor` extracts tenant key and sets in `TenantContext` (ThreadLocal)
3. `TenantIdentifierResolver` provides schema name to Hibernate
4. All JPA queries automatically target the correct tenant schema

**Important**: When creating new entities, ensure they're in the correct schema context. Platform-level entities use `@Table(schema = "public")`, tenant entities use dynamic schema resolution.

### Package Structure

```
com.ligamanager/
├── config/           # Security, multi-tenancy, AWS configs
├── domain/           # JPA entities (@Entity classes)
├── dto/              # Request/Response DTOs
├── repository/       # Spring Data JPA repositories
├── service/          # Business logic layer
├── controller/       # REST controllers (@RestController)
├── security/         # JWT, authentication, filters
├── exception/        # Custom exceptions and handlers
└── util/             # Helper classes
```

### Database Migrations

- **Tool**: Flyway (auto-runs on startup)
- **Location**: `src/main/resources/db/migration/`
- **Naming**: `V{version}__{description}.sql` (e.g., `V1__create_shared_schema.sql`)
- **Tenant Schema Template**: `V2__create_tenant_schema_template.sql` contains the template for tenant schemas (uses `__TENANT_SCHEMA__` placeholder)

**Creating New Migrations**:
1. Create `V{next_version}__description.sql` in `db/migration/`
2. For tenant tables, remember to use the schema-qualified table names or ensure proper tenant context
3. Test migration on clean database: `docker-compose down -v && docker-compose up -d`

### Authentication & Security

- **Method**: JWT (JSON Web Tokens) using JJWT library (v0.12.5)
- **Expiration**: 24 hours (configurable via `jwt.expiration` in application.yml)
- **Secret**: Configured via `JWT_SECRET` env var or application.yml
- **Public Endpoints**: `/auth/**`, `/public/**`
- **Protected Endpoints**: All others require `Authorization: Bearer {token}` header

**Adding New Protected Endpoints**:
- By default, all endpoints are protected
- To make public, add to security config allow list or use `/public/**` prefix

### API Structure

- **Base Path**: `/api/v1` (configured in `server.servlet.context-path`)
- **Response Format**: Standard wrapper with `success`, `data`, `message`, `timestamp`
- **Error Format**: Standard error object with `code`, `message`, `field`, `details`
- **Pagination**: Spring Data Pageable support on list endpoints

## Key Configuration

### Application Properties (application.yml)

```yaml
# Database connection
spring.datasource.url: jdbc:postgresql://localhost:5432/ligamanager

# Hibernate validation (use Flyway for schema changes)
spring.jpa.hibernate.ddl-auto: validate

# Flyway enabled
spring.flyway.enabled: true

# Multi-tenancy strategy
tenant.resolution-strategy: subdomain  # or header
tenant.default-schema: public
```

### Environment Variables

Required for production:
- `JWT_SECRET`: 256-bit secret key for JWT signing
- `DATABASE_URL`: PostgreSQL connection string
- `DATABASE_USERNAME`: Database user
- `DATABASE_PASSWORD`: Database password

## Important Development Notes

### Multi-Tenancy Implementation

**When writing new features**:

1. **Tenant Context**: Always verify `TenantContext` is set before accessing tenant data
2. **Schema Isolation**: Tenant entities automatically use the correct schema via Hibernate multi-tenancy
3. **Shared vs Tenant Data**:
   - Shared: Tenants, subscriptions, platform users
   - Tenant-specific: Leagues, teams, players, matches, standings

**Testing Multi-Tenancy**:
```java
// Set tenant context in tests
TenantContext.setTenantId("test-tenant");
try {
    // Your test code
} finally {
    TenantContext.clear();
}
```

### Database Schema Management

**New Tenant Provisioning Flow**:
1. Create tenant record in `public.tenants` table
2. Generate schema name: `tenant_{tenant_key}` (replace hyphens with underscores)
3. Execute tenant schema template SQL with actual schema name
4. Store schema name in tenant record

**Modifying Tenant Schema**:
- Changes must be applied to ALL existing tenant schemas
- Create migration script that loops through all `tenant_*` schemas
- Test thoroughly on a copy of production data

### Standings Calculation

Standings are **automatically updated** when match results are recorded:
- Trigger/service updates `standings` table when `matches.status` changes to `FINISHED`
- Points: Win = 3, Draw = 1, Loss = 0
- Sorting: Points DESC → Goal Difference DESC → Goals For DESC

**Recalculating Standings**:
```sql
-- If standings get out of sync, use the recalculation function
-- (needs to be implemented as a service method)
```

## Testing Guidelines

### Unit Tests

- Use JUnit 5 (`@Test`)
- Mock dependencies with Mockito (`@Mock`, `@InjectMocks`)
- Test services independently from controllers
- Location: `src/test/java/com/ligamanager/`

### Integration Tests

- Use `@SpringBootTest` for full context
- Use Testcontainers for PostgreSQL (`testcontainers:postgresql` dependency)
- Test multi-tenancy isolation
- Test API endpoints end-to-end

### Running Specific Tests

```bash
# Single test class
mvn test -Dtest=LeagueServiceTest

# Single method
mvn test -Dtest=LeagueServiceTest#shouldCreateLeague

# All tests in a package
mvn test -Dtest=com.ligamanager.service.*
```

## Common Development Patterns

### Creating a New Entity Module

1. **Entity** (`domain/`): JPA entity with proper annotations
2. **Repository** (`repository/`): Extend `JpaRepository<Entity, UUID>`
3. **DTOs** (`dto/`): Request/Response classes (use validation annotations)
4. **Service** (`service/`): Business logic, transaction management
5. **Controller** (`controller/`): REST endpoints, request/response mapping
6. **Tests**: Unit tests for service, integration tests for API

### Adding a New REST Endpoint

```java
@RestController
@RequestMapping("/api/v1/resource")
public class ResourceController {

    private final ResourceService service;

    @PostMapping
    public ResponseEntity<ApiResponse<ResourceResponse>> create(
        @Valid @RequestBody ResourceRequest request) {
        // Implementation
    }
}
```

### Exception Handling

- Custom exceptions extend `RuntimeException`
- Global exception handler with `@ControllerAdvice`
- Standard error response format maintained across all endpoints

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker-compose ps

# Restart database
docker-compose restart postgres

# View logs
docker-compose logs postgres
```

### Flyway Migration Failures

```bash
# Reset database (development only!)
docker-compose down -v
docker-compose up -d

# Check migration history
psql -U ligamanager -d ligamanager -c "SELECT * FROM flyway_schema_history;"
```

### Multi-Tenancy Issues

- Verify `TenantContext.getTenantId()` returns correct value
- Check interceptor is registering tenant correctly
- Ensure tenant schema exists: `\dn` in psql
- Verify schema name format: `tenant_{key_with_underscores}`

### Port Conflicts

```bash
# Kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Kill process on port 5432
lsof -ti:5432 | xargs kill -9
```

## Related Documentation

Full documentation available in the `docs/` directory:
- `PROJECT_SETUP.md`: Initial setup instructions
- `DATABASE_SCHEMA.md`: Complete schema reference
- `API_REFERENCE.md`: Full API documentation with examples
- `IMPLEMENTATION_ROADMAP.md`: Sprint-by-sprint implementation guide
- `QUICKSTART.md`: How to use AI coding assistants with this project

## Development Workflow

1. Start Docker services: `docker-compose up -d`
2. Run backend: `mvn spring-boot:run`
3. Access API: `http://localhost:8080/api/v1`
4. Make changes to code
5. Run tests: `mvn test`
6. Commit with descriptive messages
7. Frontend at: `http://localhost:3000` (from ../frontend/)
