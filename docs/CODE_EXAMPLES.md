# CODE_EXAMPLES.md - Ready-to-Use Code Templates

## 🎯 Purpose

This document contains complete, production-ready code examples you can copy directly into your project. Each example includes comments explaining key concepts.

---

## 📁 Backend Code Examples (Spring Boot)

### 1. Multi-Tenancy Configuration

#### TenantContext.java
```java
package com.ligamanager.config;

import org.springframework.stereotype.Component;

/**
 * ThreadLocal storage for current tenant ID.
 * Ensures tenant isolation across requests.
 */
@Component
public class TenantContext {
    private static final ThreadLocal<String> currentTenant = new ThreadLocal<>();
    
    /**
     * Set tenant ID for current request thread
     */
    public static void setTenantId(String tenantId) {
        currentTenant.set(tenantId);
    }
    
    /**
     * Get current tenant ID
     */
    public static String getTenantId() {
        return currentTenant.get();
    }
    
    /**
     * Clear tenant context (IMPORTANT: Prevents memory leaks)
     */
    public static void clear() {
        currentTenant.remove();
    }
}
```

#### TenantInterceptor.java
```java
package com.ligamanager.config;

import com.ligamanager.exception.UnauthorizedException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Intercepts requests to extract and set tenant context
 */
@Slf4j
@Component
public class TenantInterceptor implements HandlerInterceptor {
    
    @Override
    public boolean preHandle(HttpServletRequest request, 
                            HttpServletResponse response, 
                            Object handler) {
        
        // Extract tenant from subdomain (e.g., canchas-xyz.ligamanager.com)
        String host = request.getServerName();
        String tenantKey = extractTenantFromSubdomain(host);
        
        // Fallback: Check custom header
        if (tenantKey == null) {
            tenantKey = request.getHeader("X-Tenant-ID");
        }
        
        // Skip tenant resolution for public endpoints
        String path = request.getRequestURI();
        if (path.startsWith("/api/v1/auth") || path.startsWith("/api/v1/public")) {
            return true;
        }
        
        if (tenantKey == null) {
            log.error("Tenant not identified. Host: {}, Path: {}", host, path);
            throw new UnauthorizedException("Tenant identification failed");
        }
        
        // Set tenant in context
        TenantContext.setTenantId(tenantKey);
        log.debug("Tenant resolved: {}", tenantKey);
        
        return true;
    }
    
    @Override
    public void afterCompletion(HttpServletRequest request, 
                                HttpServletResponse response, 
                                Object handler, 
                                Exception ex) {
        // Always clear context to prevent memory leaks
        TenantContext.clear();
    }
    
    /**
     * Extract tenant key from subdomain
     * Example: canchas-xyz.ligamanager.com → canchas-xyz
     */
    private String extractTenantFromSubdomain(String host) {
        if (host == null || host.equals("localhost")) {
            return null;
        }
        
        // Remove port if present
        host = host.split(":")[0];
        
        // Extract subdomain
        String[] parts = host.split("\\.");
        if (parts.length >= 3) {
            return parts[0]; // First part is tenant key
        }
        
        return null;
    }
}
```

#### MultiTenantConnectionProvider.java
```java
package com.ligamanager.config;

import org.hibernate.cfg.AvailableSettings;
import org.hibernate.engine.jdbc.connections.spi.MultiTenantConnectionProvider;
import org.springframework.boot.autoconfigure.orm.jpa.HibernatePropertiesCustomizer;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Map;

/**
 * Provides database connections with correct schema set
 */
@Component
public class MultiTenantConnectionProvider 
    implements MultiTenantConnectionProvider<String>, HibernatePropertiesCustomizer {
    
    private final DataSource dataSource;
    
    public MultiTenantConnectionProvider(DataSource dataSource) {
        this.dataSource = dataSource;
    }
    
    @Override
    public Connection getAnyConnection() throws SQLException {
        return dataSource.getConnection();
    }
    
    @Override
    public void releaseAnyConnection(Connection connection) throws SQLException {
        connection.close();
    }
    
    @Override
    public Connection getConnection(String tenantIdentifier) throws SQLException {
        Connection connection = getAnyConnection();
        
        // Set schema for this connection
        String schemaName = "tenant_" + tenantIdentifier.replace("-", "_");
        connection.createStatement().execute("SET search_path TO " + schemaName);
        
        return connection;
    }
    
    @Override
    public void releaseConnection(String tenantIdentifier, Connection connection) 
        throws SQLException {
        // Reset to public schema before releasing
        connection.createStatement().execute("SET search_path TO public");
        connection.close();
    }
    
    @Override
    public boolean supportsAggressiveRelease() {
        return false;
    }
    
    @Override
    public boolean isUnwrappableAs(Class<?> unwrapType) {
        return false;
    }
    
    @Override
    public <T> T unwrap(Class<T> unwrapType) {
        return null;
    }
    
    @Override
    public void customize(Map<String, Object> hibernateProperties) {
        hibernateProperties.put(AvailableSettings.MULTI_TENANT_CONNECTION_PROVIDER, this);
    }
}
```

---

### 2. JWT Authentication

#### JwtTokenService.java
```java
package com.ligamanager.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * Service for generating and validating JWT tokens
 */
@Slf4j
@Service
public class JwtTokenService {
    
    private final SecretKey secretKey;
    private final long expirationMs;
    
    public JwtTokenService(
        @Value("${jwt.secret}") String secret,
        @Value("${jwt.expiration:86400000}") long expirationMs) {
        
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }
    
    /**
     * Generate JWT token with tenant and user information
     */
    public String generateToken(String tenantId, String userId, String email) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("tenantId", tenantId);
        claims.put("userId", userId);
        claims.put("email", email);
        
        Instant now = Instant.now();
        Instant expiration = now.plus(expirationMs, ChronoUnit.MILLIS);
        
        return Jwts.builder()
            .claims(claims)
            .subject(userId)
            .issuedAt(Date.from(now))
            .expiration(Date.from(expiration))
            .signWith(secretKey)
            .compact();
    }
    
    /**
     * Extract all claims from token
     */
    public Claims extractClaims(String token) {
        return Jwts.parser()
            .verifyWith(secretKey)
            .build()
            .parseSignedClaims(token)
            .getPayload();
    }
    
    /**
     * Extract tenant ID from token
     */
    public String extractTenantId(String token) {
        return extractClaims(token).get("tenantId", String.class);
    }
    
    /**
     * Extract user ID from token
     */
    public String extractUserId(String token) {
        return extractClaims(token).getSubject();
    }
    
    /**
     * Validate token
     */
    public boolean validateToken(String token) {
        try {
            Claims claims = extractClaims(token);
            return !claims.getExpiration().before(new Date());
        } catch (Exception e) {
            log.error("Invalid JWT token: {}", e.getMessage());
            return false;
        }
    }
}
```

#### JwtAuthenticationFilter.java
```java
package com.ligamanager.security;

import com.ligamanager.config.TenantContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;

/**
 * Filter to validate JWT and set authentication context
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private final JwtTokenService jwtTokenService;
    
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) 
        throws ServletException, IOException {
        
        // Extract JWT from Authorization header
        String authHeader = request.getHeader("Authorization");
        
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }
        
        String token = authHeader.substring(7);
        
        try {
            // Validate token
            if (jwtTokenService.validateToken(token)) {
                String userId = jwtTokenService.extractUserId(token);
                String tenantId = jwtTokenService.extractTenantId(token);
                
                // Set tenant context from JWT
                TenantContext.setTenantId(tenantId);
                
                // Create authentication object
                UsernamePasswordAuthenticationToken authentication = 
                    new UsernamePasswordAuthenticationToken(
                        userId, 
                        null, 
                        new ArrayList<>()
                    );
                
                authentication.setDetails(
                    new WebAuthenticationDetailsSource().buildDetails(request)
                );
                
                // Set authentication in Spring Security context
                SecurityContextHolder.getContext().setAuthentication(authentication);
                
                log.debug("JWT authenticated user: {} for tenant: {}", userId, tenantId);
            }
        } catch (Exception e) {
            log.error("JWT authentication failed: {}", e.getMessage());
        }
        
        filterChain.doFilter(request, response);
    }
}
```

---

### 3. Service Layer Example

#### LeagueService.java
```java
package com.ligamanager.service;

import com.ligamanager.domain.League;
import com.ligamanager.dto.LeagueRequest;
import com.ligamanager.dto.LeagueResponse;
import com.ligamanager.exception.DuplicateResourceException;
import com.ligamanager.exception.ResourceNotFoundException;
import com.ligamanager.repository.LeagueRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Business logic for league management
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LeagueService {
    
    private final LeagueRepository leagueRepository;
    
    /**
     * Create a new league
     */
    @Transactional
    public LeagueResponse createLeague(LeagueRequest request) {
        log.info("Creating league: {}", request.getName());
        
        // Validate: Check for duplicate name in same season
        if (leagueRepository.existsByNameAndSeason(request.getName(), request.getSeason())) {
            throw new DuplicateResourceException(
                "League with name '" + request.getName() + 
                "' already exists in season " + request.getSeason()
            );
        }
        
        // Create entity
        League league = League.builder()
            .name(request.getName())
            .season(request.getSeason())
            .startDate(request.getStartDate())
            .endDate(request.getEndDate())
            .leagueType(LeagueType.valueOf(request.getLeagueType()))
            .status(LeagueStatus.DRAFT)
            .build();
        
        // Save
        league = leagueRepository.save(league);
        
        log.info("League created with ID: {}", league.getId());
        return mapToResponse(league);
    }
    
    /**
     * Get all leagues
     */
    @Transactional(readOnly = true)
    public List<LeagueResponse> getAllLeagues() {
        return leagueRepository.findAll().stream()
            .map(this::mapToResponse)
            .collect(Collectors.toList());
    }
    
    /**
     * Get league by ID
     */
    @Transactional(readOnly = true)
    public LeagueResponse getLeagueById(UUID id) {
        League league = leagueRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("League not found"));
        
        return mapToResponse(league);
    }
    
    /**
     * Update league
     */
    @Transactional
    public LeagueResponse updateLeague(UUID id, LeagueRequest request) {
        League league = leagueRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("League not found"));
        
        // Validate: Cannot modify finished league
        if (league.getStatus() == LeagueStatus.FINISHED) {
            throw new IllegalStateException("Cannot modify finished league");
        }
        
        // Update fields
        league.setName(request.getName());
        league.setSeason(request.getSeason());
        league.setStartDate(request.getStartDate());
        league.setEndDate(request.getEndDate());
        
        league = leagueRepository.save(league);
        
        log.info("League updated: {}", id);
        return mapToResponse(league);
    }
    
    /**
     * Delete league (soft delete)
     */
    @Transactional
    public void deleteLeague(UUID id) {
        League league = leagueRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("League not found"));
        
        // Validate: Cannot delete league with scheduled matches
        if (league.getMatches() != null && !league.getMatches().isEmpty()) {
            throw new IllegalStateException(
                "Cannot delete league with scheduled matches. Cancel matches first."
            );
        }
        
        // Soft delete: Set status to CANCELLED
        league.setStatus(LeagueStatus.CANCELLED);
        leagueRepository.save(league);
        
        log.info("League deleted: {}", id);
    }
    
    /**
     * Map entity to response DTO
     */
    private LeagueResponse mapToResponse(League league) {
        return LeagueResponse.builder()
            .id(league.getId())
            .name(league.getName())
            .season(league.getSeason())
            .startDate(league.getStartDate())
            .endDate(league.getEndDate())
            .leagueType(league.getLeagueType().name())
            .status(league.getStatus().name())
            .teamCount(league.getTeams() != null ? league.getTeams().size() : 0)
            .matchCount(league.getMatches() != null ? league.getMatches().size() : 0)
            .createdAt(league.getCreatedAt())
            .build();
    }
}
```

---

### 4. Controller Example

#### LeagueController.java
```java
package com.ligamanager.controller;

import com.ligamanager.dto.ApiResponse;
import com.ligamanager.dto.LeagueRequest;
import com.ligamanager.dto.LeagueResponse;
import com.ligamanager.service.LeagueService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * REST API endpoints for league management
 */
@Slf4j
@RestController
@RequestMapping("/api/v1/leagues")
@RequiredArgsConstructor
public class LeagueController {
    
    private final LeagueService leagueService;
    
    /**
     * Create new league
     * POST /api/v1/leagues
     */
    @PostMapping
    public ResponseEntity<ApiResponse<LeagueResponse>> createLeague(
        @Valid @RequestBody LeagueRequest request) {
        
        log.info("API: Create league - {}", request.getName());
        
        LeagueResponse response = leagueService.createLeague(request);
        
        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.<LeagueResponse>builder()
                .success(true)
                .data(response)
                .message("League created successfully")
                .timestamp(Instant.now())
                .build());
    }
    
    /**
     * Get all leagues
     * GET /api/v1/leagues
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<LeagueResponse>>> getAllLeagues() {
        log.info("API: Get all leagues");
        
        List<LeagueResponse> leagues = leagueService.getAllLeagues();
        
        return ResponseEntity.ok(
            ApiResponse.<List<LeagueResponse>>builder()
                .success(true)
                .data(leagues)
                .timestamp(Instant.now())
                .build()
        );
    }
    
    /**
     * Get league by ID
     * GET /api/v1/leagues/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<LeagueResponse>> getLeagueById(
        @PathVariable UUID id) {
        
        log.info("API: Get league - {}", id);
        
        LeagueResponse league = leagueService.getLeagueById(id);
        
        return ResponseEntity.ok(
            ApiResponse.<LeagueResponse>builder()
                .success(true)
                .data(league)
                .timestamp(Instant.now())
                .build()
        );
    }
    
    /**
     * Update league
     * PUT /api/v1/leagues/{id}
     */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<LeagueResponse>> updateLeague(
        @PathVariable UUID id,
        @Valid @RequestBody LeagueRequest request) {
        
        log.info("API: Update league - {}", id);
        
        LeagueResponse response = leagueService.updateLeague(id, request);
        
        return ResponseEntity.ok(
            ApiResponse.<LeagueResponse>builder()
                .success(true)
                .data(response)
                .message("League updated successfully")
                .timestamp(Instant.now())
                .build()
        );
    }
    
    /**
     * Delete league
     * DELETE /api/v1/leagues/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteLeague(@PathVariable UUID id) {
        log.info("API: Delete league - {}", id);
        
        leagueService.deleteLeague(id);
        
        return ResponseEntity.ok(
            ApiResponse.<Void>builder()
                .success(true)
                .message("League deleted successfully")
                .timestamp(Instant.now())
                .build()
        );
    }
}
```

---

## 🎨 Frontend Code Examples (Next.js + React)

### 5. API Client

#### lib/api.ts
```typescript
import axios, { AxiosInstance, AxiosError } from 'axios';

/**
 * Axios client configured for API communication
 * Compatible with Next.js 15 and React 19
 */
class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api/v1',
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor: Add auth token
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor: Handle errors
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        if (error.response?.status === 401) {
          // Unauthorized: Clear token and redirect to login
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  // HTTP Methods
  async get<T>(url: string, config?: any) {
    const response = await this.client.get<ApiResponse<T>>(url, config);
    return response.data;
  }

  async post<T>(url: string, data?: any, config?: any) {
    const response = await this.client.post<ApiResponse<T>>(url, data, config);
    return response.data;
  }

  async put<T>(url: string, data?: any, config?: any) {
    const response = await this.client.put<ApiResponse<T>>(url, data, config);
    return response.data;
  }

  async delete<T>(url: string, config?: any) {
    const response = await this.client.delete<ApiResponse<T>>(url, config);
    return response.data;
  }
}

// Types
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  timestamp: string;
}

export interface ApiError {
  code: string;
  message: string;
  field?: string;
}

// Export singleton instance
export const api = new ApiClient();
```

---

### 6. Authentication Store (Zustand)

#### store/authStore.ts
```typescript
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { api } from '@/lib/api';

interface User {
  id: string;
  email: string;
  fullName: string;
  role: string;
  tenantId: string;
  tenantKey: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  
  // Actions
  login: (email: string, password: string) => Promise<void>;
  signup: (data: SignupData) => Promise<void>;
  logout: () => void;
  loadUser: () => Promise<void>;
  clearError: () => void;
}

interface SignupData {
  businessName: string;
  ownerName: string;
  email: string;
  phone: string;
  password: string;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      login: async (email, password) => {
        set({ isLoading: true, error: null });
        
        try {
          const response = await api.post<{ token: string; user: User }>(
            '/auth/login',
            { email, password }
          );
          
          const { token, user } = response.data;
          
          // Store in localStorage
          localStorage.setItem('token', token);
          localStorage.setItem('user', JSON.stringify(user));
          
          set({
            token,
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error: any) {
          const message = error.response?.data?.error?.message || 'Login failed';
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      signup: async (data) => {
        set({ isLoading: true, error: null });
        
        try {
          const response = await api.post<{ token: string; user: User; tenant: any }>(
            '/auth/signup',
            data
          );
          
          const { token, user } = response.data;
          
          localStorage.setItem('token', token);
          localStorage.setItem('user', JSON.stringify(user));
          
          set({
            token,
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error: any) {
          const message = error.response?.data?.error?.message || 'Signup failed';
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      logout: () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        
        set({
          user: null,
          token: null,
          isAuthenticated: false,
        });
        
        // Redirect to login
        window.location.href = '/login';
      },

      loadUser: async () => {
        const token = localStorage.getItem('token');
        
        if (!token) {
          set({ isAuthenticated: false });
          return;
        }
        
        try {
          const response = await api.get<User>('/auth/me');
          
          set({
            user: response.data,
            token,
            isAuthenticated: true,
          });
        } catch (error) {
          // Token invalid, clear auth
          get().logout();
        }
      },

      clearError: () => set({ error: null }),
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
```

---

### 7. Login Form Component

#### components/auth/LoginForm.tsx
```typescript
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/authStore';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Alert } from '@/components/ui/Alert';
import { Mail, Lock, Loader2 } from 'lucide-react';

export function LoginForm() {
  const router = useRouter();
  const { login, isLoading, error, clearError } = useAuthStore();
  
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    clearError();
    
    try {
      await login(email, password);
      router.push('/dashboard');
    } catch (error) {
      // Error is handled by store
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <Alert variant="destructive">
          {error}
        </Alert>
      )}
      
      <div>
        <label htmlFor="email" className="block text-sm font-medium mb-1">
          Email
        </label>
        <div className="relative">
          <Mail className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
          <Input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="juan@example.com"
            className="pl-10"
            required
          />
        </div>
      </div>
      
      <div>
        <label htmlFor="password" className="block text-sm font-medium mb-1">
          Contraseña
        </label>
        <div className="relative">
          <Lock className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
          <Input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            className="pl-10"
            required
          />
        </div>
      </div>
      
      <Button
        type="submit"
        className="w-full"
        disabled={isLoading}
      >
        {isLoading ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Iniciando sesión...
          </>
        ) : (
          'Iniciar Sesión'
        )}
      </Button>
      
      <p className="text-center text-sm text-gray-600">
        ¿No tienes cuenta?{' '}
        <a href="/signup" className="font-medium text-blue-600 hover:underline">
          Regístrate aquí
        </a>
      </p>
    </form>
  );
}
```

---

### 8. Protected Route Middleware

#### middleware.ts
```typescript
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

/**
 * Middleware to protect routes requiring authentication
 * Next.js 15 compatible with improved performance
 */
export function middleware(request: NextRequest) {
  const token = request.cookies.get('token')?.value;
  const pathname = request.nextUrl.pathname;

  // Public routes (no auth required)
  const publicRoutes = ['/login', '/signup', '/'];
  const isPublicRoute = publicRoutes.some(route => pathname.startsWith(route));

  // Dashboard routes (auth required)
  const isDashboardRoute = pathname.startsWith('/dashboard');

  // Redirect to login if accessing dashboard without token
  if (isDashboardRoute && !token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Redirect to dashboard if accessing auth pages while logged in
  if (isPublicRoute && token && pathname !== '/') {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/login',
    '/signup',
  ],
};
```

---

### 9. Standings Table Component

#### components/standings/StandingsTable.tsx
```typescript
'use client';

import { Table } from '@/components/ui/Table';
import { Trophy, TrendingUp, TrendingDown } from 'lucide-react';

interface Standing {
  position: number;
  team: {
    id: string;
    name: string;
    logoUrl?: string;
  };
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDifference: number;
  points: number;
}

interface StandingsTableProps {
  standings: Standing[];
}

export function StandingsTable({ standings }: StandingsTableProps) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className="bg-gray-50 sticky top-0">
          <tr>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
              Pos
            </th>
            <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
              Equipo
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              PJ
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              PG
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              PE
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              PP
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              GF
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              GC
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase">
              DG
            </th>
            <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase font-bold">
              Pts
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200">
          {standings.map((standing) => (
            <tr
              key={standing.team.id}
              className={`hover:bg-gray-50 ${
                standing.position <= 3 ? 'bg-green-50' : ''
              }`}
            >
              <td className="px-4 py-3 whitespace-nowrap text-sm font-medium">
                <div className="flex items-center gap-2">
                  {standing.position}
                  {standing.position === 1 && (
                    <Trophy className="h-4 w-4 text-yellow-500" />
                  )}
                  {standing.position === 2 && (
                    <Trophy className="h-4 w-4 text-gray-400" />
                  )}
                  {standing.position === 3 && (
                    <Trophy className="h-4 w-4 text-orange-600" />
                  )}
                </div>
              </td>
              <td className="px-4 py-3 whitespace-nowrap">
                <div className="flex items-center gap-3">
                  {standing.team.logoUrl && (
                    <img
                      src={standing.team.logoUrl}
                      alt={standing.team.name}
                      className="h-8 w-8 rounded-full object-cover"
                    />
                  )}
                  <span className="font-medium">{standing.team.name}</span>
                </div>
              </td>
              <td className="px-4 py-3 text-center text-sm text-gray-600">
                {standing.played}
              </td>
              <td className="px-4 py-3 text-center text-sm text-green-600 font-medium">
                {standing.won}
              </td>
              <td className="px-4 py-3 text-center text-sm text-yellow-600">
                {standing.drawn}
              </td>
              <td className="px-4 py-3 text-center text-sm text-red-600">
                {standing.lost}
              </td>
              <td className="px-4 py-3 text-center text-sm text-gray-600">
                {standing.goalsFor}
              </td>
              <td className="px-4 py-3 text-center text-sm text-gray-600">
                {standing.goalsAgainst}
              </td>
              <td className="px-4 py-3 text-center text-sm">
                <span
                  className={`font-medium ${
                    standing.goalDifference > 0
                      ? 'text-green-600'
                      : standing.goalDifference < 0
                      ? 'text-red-600'
                      : 'text-gray-600'
                  }`}
                >
                  {standing.goalDifference > 0 && '+'}
                  {standing.goalDifference}
                </span>
              </td>
              <td className="px-4 py-3 text-center text-sm font-bold">
                {standing.points}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

## 🧪 Test Examples

### 10. Service Unit Test

#### LeagueServiceTest.java
```java
package com.ligamanager.service;

import com.ligamanager.domain.League;
import com.ligamanager.dto.LeagueRequest;
import com.ligamanager.exception.DuplicateResourceException;
import com.ligamanager.repository.LeagueRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LeagueServiceTest {
    
    @Mock
    private LeagueRepository leagueRepository;
    
    @InjectMocks
    private LeagueService leagueService;
    
    private LeagueRequest validRequest;
    
    @BeforeEach
    void setUp() {
        validRequest = LeagueRequest.builder()
            .name("Liga Test")
            .season("Apertura 2025")
            .startDate(LocalDate.of(2025, 3, 1))
            .endDate(LocalDate.of(2025, 6, 30))
            .leagueType("FUTBOL_7")
            .build();
    }
    
    @Test
    void createLeague_WithValidData_ShouldReturnLeagueResponse() {
        // Given
        when(leagueRepository.existsByNameAndSeason(anyString(), anyString()))
            .thenReturn(false);
        
        when(leagueRepository.save(any(League.class)))
            .thenAnswer(invocation -> {
                League league = invocation.getArgument(0);
                league.setId(UUID.randomUUID());
                return league;
            });
        
        // When
        var response = leagueService.createLeague(validRequest);
        
        // Then
        assertThat(response).isNotNull();
        assertThat(response.getName()).isEqualTo("Liga Test");
        assertThat(response.getStatus()).isEqualTo("DRAFT");
        
        verify(leagueRepository, times(1)).save(any(League.class));
    }
    
    @Test
    void createLeague_WithDuplicateName_ShouldThrowException() {
        // Given
        when(leagueRepository.existsByNameAndSeason(anyString(), anyString()))
            .thenReturn(true);
        
        // When & Then
        assertThatThrownBy(() -> leagueService.createLeague(validRequest))
            .isInstanceOf(DuplicateResourceException.class)
            .hasMessageContaining("already exists");
        
        verify(leagueRepository, never()).save(any());
    }
}
```

---

*This document provides production-ready code examples. Copy, adapt, and use them in your project!*

**Last Updated**: January 2025
