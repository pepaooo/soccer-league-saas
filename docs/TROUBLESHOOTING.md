# TROUBLESHOOTING.md - Common Issues & Solutions

## 🎯 Purpose

This guide helps you quickly resolve common problems during development and deployment.

---

## 🔍 Table of Contents

1. [Setup & Configuration Issues](#setup--configuration-issues)
2. [Multi-Tenancy Issues](#multi-tenancy-issues)
3. [Database Issues](#database-issues)
4. [Authentication Issues](#authentication-issues)
5. [API Issues](#api-issues)
6. [Frontend Issues](#frontend-issues)
7. [Deployment Issues](#deployment-issues)
8. [Performance Issues](#performance-issues)

---

## 1. Setup & Configuration Issues

### ❌ Problem: Docker containers won't start

**Symptoms:**
```bash
docker-compose up -d
# Error: port is already allocated
```

**Solution:**
```bash
# Find what's using the port
lsof -ti:5432 | xargs kill -9  # PostgreSQL
lsof -ti:6379 | xargs kill -9  # Redis

# Or change port in docker-compose.yml
services:
  postgres:
    ports:
      - "5433:5432"  # Use different host port
```

---

### ❌ Problem: Maven dependencies won't download

**Symptoms:**
```bash
mvn clean compile
# [ERROR] Failed to execute goal on project backend
```

**Solution:**
```bash
# Clear Maven cache
rm -rf ~/.m2/repository

# Force update
mvn clean install -U

# Check internet connection
ping repo.maven.apache.org

# If behind corporate proxy, configure ~/.m2/settings.xml:
<settings>
  <proxies>
    <proxy>
      <id>corporate-proxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>proxy.company.com</host>
      <port>8080</port>
    </proxy>
  </proxies>
</settings>
```

---

### ❌ Problem: Spring Boot application won't start

**Symptoms:**
```
APPLICATION FAILED TO START
***************************
Description: Failed to configure a DataSource
```

**Solution:**

1. **Check database is running:**
```bash
docker ps | grep postgres
# Should show running container

# Test connection
psql -h localhost -U ligamanager -d ligamanager
```

2. **Verify application.yml:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/ligamanager
    username: ligamanager
    password: dev_password_123
```

3. **Check logs:**
```bash
# Look for specific error
mvn spring-boot:run | grep -i error

# Common causes:
# - Wrong database password
# - Database not created
# - Port mismatch
```

---

### ❌ Problem: Next.js build fails

**Symptoms:**
```bash
npm run build
# Type error: Property 'X' does not exist
```

**Solution:**
```bash
# Clear cache (Next.js 15 uses Turbopack)
rm -rf .next
rm -rf node_modules
npm install

# Check TypeScript errors
npm run type-check

# Fix missing types
npm install --save-dev @types/node @types/react @types/react-dom

# Verify Next.js 15 is installed
cat package.json | grep '"next"'
# Should show: "next": "15.x.x"

# If still failing, check tsconfig.json:
{
  "compilerOptions": {
    "strict": false,  # Temporarily disable for debugging
    "skipLibCheck": true
  }
}

# Next.js 15 specific: Check for React 19 compatibility
npm list react
# Should show: react@19.x.x
```

---

## 2. Multi-Tenancy Issues

### ❌ Problem: Tenant context not set correctly

**Symptoms:**
```
java.lang.NullPointerException: Tenant ID is null
```

**Solution:**

1. **Verify TenantInterceptor is registered:**
```java
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new TenantInterceptor());
    }
}
```

2. **Debug tenant extraction:**
```java
@Override
public boolean preHandle(HttpServletRequest request, ...) {
    String host = request.getServerName();
    log.info("Host: {}", host);  // Add logging
    
    String tenantKey = extractTenantFromSubdomain(host);
    log.info("Extracted tenant: {}", tenantKey);  // Debug
    
    if (tenantKey == null) {
        log.error("Tenant not found. Headers: {}", 
            Collections.list(request.getHeaderNames()));
    }
    // ...
}
```

3. **Test with header instead of subdomain:**
```bash
curl -H "X-Tenant-ID: test-tenant" http://localhost:8080/api/v1/leagues
```

---

### ❌ Problem: Wrong schema being accessed

**Symptoms:**
```
ERROR: relation "leagues" does not exist
# But table exists in tenant_xyz schema
```

**Solution:**

1. **Verify search_path is set:**
```java
// In MultiTenantConnectionProvider
String schemaName = "tenant_" + tenantIdentifier.replace("-", "_");
connection.createStatement().execute("SET search_path TO " + schemaName);

// Log it
log.info("Set search_path to: {}", schemaName);
```

2. **Manually test:**
```sql
-- Connect to database
psql -h localhost -U ligamanager -d ligamanager

-- Check current schema
SHOW search_path;

-- Set manually
SET search_path TO tenant_xyz;

-- Verify table exists
\dt
SELECT * FROM leagues;
```

3. **Ensure schema exists:**
```java
// Add to TenantProvisioningService
public void verifySchemaExists(String tenantKey) {
    String schemaName = "tenant_" + tenantKey.replace("-", "_");
    
    String sql = "SELECT schema_name FROM information_schema.schemata " +
                 "WHERE schema_name = ?";
    
    boolean exists = jdbcTemplate.queryForObject(sql, 
        Boolean.class, schemaName);
    
    if (!exists) {
        throw new IllegalStateException("Schema not found: " + schemaName);
    }
}
```

---

## 3. Database Issues

### ❌ Problem: Flyway migration fails

**Symptoms:**
```
FlywayException: Validate failed: 
Migration checksum mismatch for migration V1__create_shared_schema.sql
```

**Solution:**

1. **Reset Flyway history (DEV ONLY!):**
```sql
-- Connect to database
psql -h localhost -U ligamanager -d ligamanager

-- Drop Flyway table
DROP TABLE IF EXISTS flyway_schema_history CASCADE;

-- Restart application (will re-run migrations)
```

2. **Fix migration file:**
```bash
# Don't modify existing migrations in production!
# Create new migration instead:
# V2__fix_previous_migration.sql

# For dev, can recreate:
docker-compose down -v  # Destroys all data!
docker-compose up -d
mvn spring-boot:run
```

3. **Check migration naming:**
```
✅ V1__create_tables.sql
✅ V2__add_indexes.sql
❌ v1_create_tables.sql  # Wrong: lowercase 'v'
❌ V1__create tables.sql  # Wrong: space in filename
```

---

### ❌ Problem: Database connection pool exhausted

**Symptoms:**
```
HikariPool: Connection is not available, request timed out after 30000ms
```

**Solution:**

1. **Check for connection leaks:**
```java
// Always use @Transactional
@Transactional(readOnly = true)
public List<League> getAllLeagues() {
    return leagueRepository.findAll();
}

// Close connections in finally blocks
Connection conn = null;
try {
    conn = dataSource.getConnection();
    // ...
} finally {
    if (conn != null) {
        conn.close();  // IMPORTANT
    }
}
```

2. **Increase pool size (application.yml):**
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20  # Default: 10
      connection-timeout: 60000  # 60 seconds
      idle-timeout: 600000  # 10 minutes
```

3. **Find long-running queries:**
```sql
-- PostgreSQL
SELECT 
    pid,
    now() - query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Kill long query
SELECT pg_terminate_backend(12345);  -- Replace with pid
```

---

### ❌ Problem: Slow query performance

**Symptoms:**
```
Query takes 5+ seconds to return results
```

**Solution:**

1. **Add missing indexes:**
```sql
-- Check query plan
EXPLAIN ANALYZE SELECT * FROM tenant_xyz.matches WHERE scheduled_at > NOW();

-- If "Seq Scan" appears, add index:
CREATE INDEX idx_matches_scheduled_at 
ON tenant_xyz.matches(scheduled_at);

-- Verify index is used
EXPLAIN ANALYZE SELECT * FROM tenant_xyz.matches WHERE scheduled_at > NOW();
-- Should show "Index Scan"
```

2. **Optimize N+1 queries:**
```java
// ❌ BAD: N+1 queries
List<League> leagues = leagueRepository.findAll();
for (League league : leagues) {
    league.getTeams().size();  // Lazy loading = separate query
}

// ✅ GOOD: Single query with JOIN FETCH
@Query("SELECT l FROM League l LEFT JOIN FETCH l.teams")
List<League> findAllWithTeams();
```

3. **Enable query logging:**
```yaml
# application.yml
logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

---

## 4. Authentication Issues

### ❌ Problem: JWT token not working

**Symptoms:**
```
401 Unauthorized
# Even with valid token
```

**Solution:**

1. **Verify token is being sent:**
```bash
# Check request headers
curl -v -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/api/v1/leagues
  
# Look for "Authorization: Bearer ..." in output
```

2. **Check JWT secret configuration:**
```yaml
# application.yml
jwt:
  secret: your-secret-key-must-be-at-least-256-bits-long
  expiration: 86400000  # 24 hours
```

3. **Debug token validation:**
```java
// Add logging to JwtTokenService
public boolean validateToken(String token) {
    try {
        Claims claims = extractClaims(token);
        log.info("Token valid. User: {}, Expires: {}", 
            claims.getSubject(), claims.getExpiration());
        return !claims.getExpiration().before(new Date());
    } catch (ExpiredJwtException e) {
        log.error("Token expired: {}", e.getMessage());
        return false;
    } catch (Exception e) {
        log.error("Invalid token: {}", e.getMessage());
        return false;
    }
}
```

4. **Test token manually:**
```java
// Create test endpoint (remove in production!)
@GetMapping("/debug/token")
public ResponseEntity<?> debugToken(@RequestHeader("Authorization") String auth) {
    String token = auth.substring(7);
    
    try {
        Claims claims = jwtTokenService.extractClaims(token);
        return ResponseEntity.ok(claims);
    } catch (Exception e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }
}
```

---

### ❌ Problem: Login returns 401 with correct credentials

**Symptoms:**
```bash
POST /auth/login
{
  "email": "test@example.com",
  "password": "correct_password"
}
# Returns 401
```

**Solution:**

1. **Check password hashing:**
```java
// Ensure BCrypt is used
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
}

// When creating user:
String hashedPassword = passwordEncoder.encode(plainPassword);
user.setPasswordHash(hashedPassword);

// When validating:
if (!passwordEncoder.matches(plainPassword, user.getPasswordHash())) {
    throw new UnauthorizedException("Invalid credentials");
}
```

2. **Debug AuthService:**
```java
public AuthResponse login(LoginRequest request) {
    log.info("Login attempt for: {}", request.getEmail());
    
    PlatformUser user = userRepository.findByEmail(request.getEmail())
        .orElseThrow(() -> {
            log.error("User not found: {}", request.getEmail());
            return new UnauthorizedException("Invalid credentials");
        });
    
    log.info("User found: {}", user.getId());
    
    if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
        log.error("Password mismatch for: {}", request.getEmail());
        throw new UnauthorizedException("Invalid credentials");
    }
    
    log.info("Password matched. Generating token...");
    // ...
}
```

3. **Verify user exists:**
```sql
SELECT * FROM public.platform_users WHERE email = 'test@example.com';
-- Should return one row

-- Check password hash format (should start with $2a$)
```

---

## 5. API Issues

### ❌ Problem: CORS errors in browser

**Symptoms:**
```
Access to fetch at 'http://localhost:8080/api/v1/leagues' from origin 
'http://localhost:3000' has been blocked by CORS policy
```

**Solution:**

1. **Configure CORS in Spring Boot:**
```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("http://localhost:3000", "https://app.ligamanager.com")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

2. **Or add `@CrossOrigin` to controller:**
```java
@RestController
@RequestMapping("/api/v1/leagues")
@CrossOrigin(origins = "http://localhost:3000")
public class LeagueController {
    // ...
}
```

3. **Check Security config doesn't block OPTIONS:**
```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .cors().and()  // Enable CORS
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()  // Allow preflight
            // ...
        );
    return http.build();
}
```

---

### ❌ Problem: Request validation fails

**Symptoms:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed"
  }
}
```

**Solution:**

1. **Check validation annotations:**
```java
public class LeagueRequest {
    @NotBlank(message = "Name is required")
    @Size(min = 3, max = 150, message = "Name must be 3-150 characters")
    private String name;
    
    @NotNull(message = "Start date is required")
    @FutureOrPresent(message = "Start date must be today or future")
    private LocalDate startDate;
}
```

2. **Add global exception handler:**
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse> handleValidationErrors(
        MethodArgumentNotValidException ex) {
        
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error -> 
            errors.put(error.getField(), error.getDefaultMessage())
        );
        
        return ResponseEntity.badRequest().body(
            ApiResponse.builder()
                .success(false)
                .error(ApiError.builder()
                    .code("VALIDATION_ERROR")
                    .message("Validation failed")
                    .details(errors)
                    .build())
                .build()
        );
    }
}
```

3. **Test validation:**
```bash
# Test with invalid data
curl -X POST http://localhost:8080/api/v1/leagues \
  -H "Content-Type: application/json" \
  -d '{
    "name": "",
    "startDate": "2020-01-01"
  }'
  
# Should return detailed validation errors
```

---

## 6. Frontend Issues

### ❌ Problem: API calls fail with CORS error

**Solution:** See [CORS errors](#-problem-cors-errors-in-browser) above.

---

### ❌ Problem: Environment variables not loading

**Symptoms:**
```typescript
console.log(process.env.NEXT_PUBLIC_API_URL);
// Prints: undefined
```

**Solution:**

1. **Check .env.local file exists:**
```bash
# frontend/.env.local must exist
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
```

2. **Restart dev server:**
```bash
# Environment variables only load on server start
npm run dev
```

3. **Verify prefix:**
```bash
# ❌ Wrong: Won't work in browser
API_URL=http://localhost:8080

# ✅ Correct: NEXT_PUBLIC_ prefix required
NEXT_PUBLIC_API_URL=http://localhost:8080
```

4. **Check build-time vs runtime:**
```typescript
// ✅ Available in browser
const apiUrl = process.env.NEXT_PUBLIC_API_URL;

// ❌ Server-side only (not available in client components)
const secret = process.env.API_SECRET;
```

---

### ❌ Problem: State not persisting after refresh

**Symptoms:**
```
User logs in → Refreshes page → Logged out again
```

**Solution:**

1. **Use Zustand persist middleware:**
```typescript
export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      // ... state
    }),
    {
      name: 'auth-storage',  // LocalStorage key
      partialize: (state) => ({
        user: state.user,
        token: state.token,
      }),
    }
  )
);
```

2. **Load state on app mount:**
```typescript
// app/layout.tsx
'use client';

import { useEffect } from 'react';
import { useAuthStore } from '@/store/authStore';

export default function RootLayout({ children }) {
  const loadUser = useAuthStore(state => state.loadUser);
  
  useEffect(() => {
    loadUser();  // Load from localStorage on mount
  }, []);
  
  return <html>{children}</html>;
}
```

---

## 7. Deployment Issues

### ❌ Problem: EC2 application won't start

**Symptoms:**
```bash
sudo systemctl status ligamanager
# Status: failed
```

**Solution:**

1. **Check logs:**
```bash
sudo journalctl -u ligamanager -n 100

# Common errors:
# - Java not found → Install Java 21
# - Permission denied → Check file ownership
# - Port in use → Kill conflicting process
```

2. **Verify Java installation:**
```bash
java -version
# Should show: openjdk version "21"

which java
# Should show: /usr/bin/java
```

3. **Check file permissions:**
```bash
ls -la /opt/ligamanager/
# app.jar should be readable by ec2-user

sudo chown -R ec2-user:ec2-user /opt/ligamanager
chmod 755 /opt/ligamanager/app.jar
```

4. **Test manual start:**
```bash
cd /opt/ligamanager
java -jar app.jar

# If starts successfully, issue is with systemd service
```

---

### ❌ Problem: RDS connection refused

**Symptoms:**
```
Could not connect to database: Connection refused
```

**Solution:**

1. **Check security groups:**
```bash
# EC2 security group must be allowed in RDS security group
# RDS SG Inbound Rules:
# Type: PostgreSQL, Port: 5432, Source: EC2 security group ID
```

2. **Verify RDS endpoint:**
```bash
# Check endpoint is correct in .env file
DB_HOST=ligamanager-db.xxxxxxxxx.us-east-1.rds.amazonaws.com

# Test connection from EC2
psql -h $DB_HOST -U app_role -d ligamanager

# If fails, check:
# - RDS is in same VPC as EC2
# - Public accessibility matches (usually off)
```

3. **Check RDS status:**
```bash
# AWS Console → RDS → Databases → ligamanager-db
# Status should be "Available"

# If stopped, start it
aws rds start-db-instance --db-instance-identifier ligamanager-db
```

---

## 8. Performance Issues

### ❌ Problem: Slow API responses

**Symptoms:**
```
API calls take 2-5 seconds
```

**Solution:**

1. **Add Redis caching:**
```java
@Cacheable(value = "standings", key = "#leagueId")
public List<Standing> getStandings(UUID leagueId) {
    return standingsRepository.findByLeagueId(leagueId);
}

@CacheEvict(value = "standings", key = "#leagueId")
public void invalidateStandingsCache(UUID leagueId) {
    // Called after match result recorded
}
```

2. **Optimize database queries:**
```java
// Use @EntityGraph to avoid N+1
@EntityGraph(attributePaths = {"teams", "matches"})
Optional<League> findWithTeamsAndMatchesById(UUID id);
```

3. **Enable query caching:**
```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          region.factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
```

---

### ❌ Problem: High memory usage

**Symptoms:**
```bash
# EC2 instance running out of memory
free -m
# Shows: Used: 3800MB / Total: 4096MB
```

**Solution:**

1. **Optimize JVM settings:**
```bash
# In systemd service file:
ExecStart=/usr/bin/java \
  -Xms256m \
  -Xmx1024m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -jar /opt/ligamanager/app.jar
```

2. **Find memory leaks:**
```bash
# Install and use jmap
jmap -heap <pid>

# Generate heap dump
jmap -dump:format=b,file=heap.bin <pid>

# Analyze with VisualVM or Eclipse MAT
```

3. **Monitor with CloudWatch:**
```bash
# Set up memory alarm
aws cloudwatch put-metric-alarm \
  --alarm-name high-memory \
  --metric-name MemoryUtilization \
  --threshold 80
```

---

### ❌ Problem: Next.js dev server slow (Turbopack issues)

**Symptoms:**
```bash
npm run dev
# Takes 30+ seconds to start
# Hot reload is slow
```

**Solution:**

1. **Verify Turbopack is enabled (Next.js 15 default):**
```bash
# package.json scripts should have:
"dev": "next dev --turbo"

# If not, add it
npm pkg set scripts.dev="next dev --turbo"
```

2. **Clear Turbopack cache:**
```bash
rm -rf .next
npm run dev
```

3. **Check Node.js version:**
```bash
node -v
# Should be v18.17+ or v20+

# Update if needed
nvm install 20
nvm use 20
```

4. **Reduce file watching:**
```bash
# Create .gitignore entries for large folders
node_modules/
.next/
dist/
```

---

## 🆘 Emergency Troubleshooting

### Quick Diagnostic Commands

```bash
# Check all services
docker ps                          # Docker containers
systemctl status ligamanager       # Backend service
curl http://localhost:8080/actuator/health  # Backend health
curl http://localhost:3000         # Frontend

# Check logs
sudo journalctl -u ligamanager -n 100  # Backend logs
docker logs ligamanager-db         # Database logs
npm run dev 2>&1 | tee frontend.log  # Frontend logs

# Check disk space
df -h

# Check memory
free -m

# Check network
netstat -tuln | grep -E '3000|8080|5432|6379'

# Check database
psql -h localhost -U ligamanager -d ligamanager -c "SELECT version();"
```

---

## 📚 Where to Get Help

1. **Documentation Issues**: Re-read PROJECT_SETUP.md and IMPLEMENTATION_ROADMAP.md
2. **Backend Errors**: Check Spring Boot logs, search Stack Overflow
3. **Frontend Issues**: Check Next.js 15 docs at https://nextjs.org/docs
4. **Database Problems**: Check PostgreSQL logs in Docker
5. **AI Assistant**: Ask Cursor/Claude Code with error messages
6. **Community**: 
   - Spring Boot: https://stackoverflow.com/questions/tagged/spring-boot
   - Next.js: https://github.com/vercel/next.js/discussions
   - PostgreSQL: https://stackoverflow.com/questions/tagged/postgresql

---

## ✅ Health Check Checklist

Before asking for help, verify:

- [ ] Docker containers are running (`docker ps`)
- [ ] Backend starts without errors (`mvn spring-boot:run`)
- [ ] Database is accessible (`psql -h localhost ...`)
- [ ] Frontend builds (`npm run build`)
- [ ] No port conflicts (`lsof -ti:8080`, `lsof -ti:3000`)
- [ ] Environment variables set (`.env`, `application.yml`)
- [ ] Git commits are clean (no uncommitted changes blocking you)
- [ ] You've read the error message carefully
- [ ] You've tried restarting everything

---

## 🎯 Prevention Tips

1. **Commit Often**: Small commits = easy rollback
2. **Test Locally First**: Never deploy untested code
3. **Use Branches**: `git checkout -b feature/league-crud`
4. **Read Logs**: Don't ignore warnings
5. **Keep Dependencies Updated**: `npm audit fix`, `mvn versions:display-dependency-updates`
6. **Monitor Resources**: Watch CPU/memory usage
7. **Backup Database**: Weekly backups of dev database
8. **Document Custom Changes**: Comment your code

---

*Troubleshooting Guide Last Updated: January 2025 (Next.js 15)*
