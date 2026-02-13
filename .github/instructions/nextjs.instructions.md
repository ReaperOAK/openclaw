---
description:
  'Best practices for building Next.js (App Router) apps with modern caching,
  tooling, and server/client boundaries (aligned with Next.js 16.1.1).'
applyTo: '**/*.tsx, **/*.ts, **/*.jsx, **/*.js, **/*.css'
---

# **Next.js Fullstack Best Practices (App Router \+ Tailwind)**

This document serves as the **single** source of truth for building
production-grade Next.js applications. It consolidates architectural standards,
strict coding rules, and performance guidelines for Next.js 16+, TypeScript, and
Tailwind CSS.

**Target Stack:** Next.js 16+ (App Router), TypeScript, Tailwind CSS, Turbopack.

## **1\. Purpose & Scope**

- **Goal:** Ensure code quality, scalability, security, and maintainability
  across the full stack.
- **Scope:** Applies to all \*\*/\*.tsx, \*\*/\*.ts, \*\*/\*.css, and config
  files.
- **Audience:** AI assistants (LLMs) and human developers.

## **2\. Project Assumptions**

- **Version:** Next.js 16.1.1 or later.
- **Router:** App Router (app/) **ONLY**. Legacy pages/ directory is
  **FORBIDDEN**.
- **Language:** TypeScript (Strict Mode) is **MANDATORY**.
- **Styling:** Tailwind CSS is **MANDATORY**.
- **Bundler:** Turbopack (default).

## **3\. Directory & Architecture Rules**

- **Root Structure:**
  - app/ — Routes, layouts, and route handlers.
  - components/ — Reusable UI components (colocated or shared).
  - lib/ — Business logic, API clients, and shared utilities.
  - hooks/ — Custom React hooks.
  - types/ — Global TypeScript definitions.
  - public/ — Static assets.
- **Colocation Strategy:**
  - **MUST** colocate components, styles, and tests near their usage when
    specific to a route/feature.
  - **SHOULD** use Feature Folders (e.g., app/dashboard/components/) for
    domain-specific logic.
- **Route Organization:**
  - **MUST** use Route Groups (group-name) to organize files without affecting
    URL paths.
  - **MUST** use Private Folders \_folder to exclude files from routing logic.
- **Naming Conventions:**
  - **Files:** PascalCase for React components/pages (e.g., UserCard.tsx,
    page.tsx).
  - **Utilities:** camelCase for hooks and logic (e.g., useAuth.ts,
    formatDate.ts).
  - **Folders:** kebab-case for route segments (e.g., user-profile/).

## **4\. Server vs Client Component Rules**

- **Default to Server Components:**
  - All components are Server Components by default.
  - **MUST** attempt to render everything on the server first.
- **Client Components:**
  - **MUST** add 'use client' at the very top of the file.
  - **SHOULD** be leaf nodes where possible.
  - **MUST NOT** import Server Components into Client Components directly (pass
    them as children props instead).
- **Strict Boundary Rules:**
  - **MUST NOT** use next/dynamic with { ssr: false } inside a Server Component.
  - **MUST** extract client-only logic (hooks, window access, event listeners)
    into a dedicated Client Component and import it.
  - **MUST** serialize props passed from Server to Client components (no
    functions or non-serializable objects).

## **5\. Data Fetching & Caching**

- **Async Request APIs (Next.js 16+):**
  - **MUST** treat cookies(), headers(), params, and searchParams as
    **Promises** in Server Components.
  - **MUST** await these APIs before usage.
- **Caching Strategy:**
  - **MUST** prefer **Cache Components** (use cache directive) over legacy
    unstable_cache.
  - **MUST** enable cacheComponents: true in next.config.
  - **SHOULD** use cacheTag for granular invalidation and cacheLife for
    time-based expiration.
- **Direct Database Access:**
  - **MUST** fetch data directly from the database in Server Components.
  - **MUST NOT** call internal API Route Handlers (e.g., fetch('/api/users'))
    from Server Components. Call the DB/service logic directly.
- **Loading States:**
  - **MUST** use Suspense boundaries for async data fetching to prevent blocking
    the entire page render.

## **6\. API & Route Handlers**

- **Location:** app/api/ for public-facing API endpoints.
- **Structure:**
  - **MUST** use Route Handlers (route.ts) with standard HTTP verbs (GET, POST,
    etc.).
  - **MUST** use NextRequest and NextResponse for advanced control, or standard
    Web Request/Response for portability.
- **Validation:**
  - **MUST** validate **ALL** incoming data (params, body) using **Zod**.
  - **MUST** sanitize inputs to prevent injection attacks.
- **Dynamic Segments:**
  - **MUST** use \[param\] syntax for dynamic paths.

## **7\. Styling & Tailwind Rules**

- **Engine:** Tailwind CSS.
- **Best Practices:**
  - **MUST** use strict utility classes. Avoid arbitrary values (w-\[123px\])
    unless absolutely necessary.
  - **SHOULD** use clsx or tailwind-merge for conditional class composition.
  - **MUST** maintain responsive design (mobile-first: base \-\> sm \-\> md \-\>
    lg).
  - **MUST** support Dark Mode via Tailwind's dark: variant.
- **Container Queries:**
  - **SHOULD** use container queries (@tailwindcss/container-queries) for
    component-level responsiveness instead of relying solely on viewport media
    queries.

## **8\. State Management Rules**

- **Server State:** Use React Server Components and use cache.
- **URL State:**
  - **MUST** use URL Search Params for bookmarkable/shareable UI state (filters,
    pagination, tabs).
- **Client State:**
  - **SHOULD** use useState/useReducer for local interaction.
  - **SHOULD** use Context sparingly (only for truly global state like Themes or
    Auth).
- **Mutations:**
  - **MUST** use **Server Actions** for mutations (form submissions, data
    updates).
  - **MUST** use updateTag or revalidateTag within Server Actions to refresh
    data.

## **9\. Performance Rules**

- **Images & Fonts:**
  - **MUST** use next/image with proper sizing and next/font for automatic
    optimization.
  - **MUST NOT** use standard \<img\> tags for local assets.
- **Code Splitting:**
  - **SHOULD** rely on automatic route-based splitting.
  - **SHOULD** lazy load heavy Client Components using next/dynamic (only within
    Client contexts if needed).
- **Core Web Vitals:**
  - **MUST** optimize for LCP (Largest Contentful Paint) by prioritizing
    critical images/text.
  - **MUST** avoid CLS (Cumulative Layout Shift) by defining dimensions for
    media containers.

## **10\. Security Rules**

- **Input Validation:**
  - **MUST** validate inputs on the Server (Zod) regardless of client-side
    validation.
- **Authentication:**
  - **MUST** implement authentication checks in Middleware AND Server
    Components/Actions.
  - **MUST NOT** trust client-side user data.
- **Environment Variables:**
  - **MUST** store secrets in .env.local.
  - **MUST** prefix public variables with NEXT_PUBLIC\_.
  - **MUST NOT** commit .env files to version control.

## **11\. Tooling, Linting & Testing**

- **Linting:**
  - **MUST** use eslint with the official Next.js config.
  - **MUST** run ESLint via CLI in CI/CD.
- **TypeScript:**
  - **MUST** use strict: true in tsconfig.json.
  - **MUST** avoid any type; use unknown or specific interfaces.
  - **SHOULD** use typedRoutes (experimental/stable) for type-safe routing.
- **Testing:**
  - **SHOULD** write unit tests for shared utilities and complex components
    (Jest/Vitest).
  - **SHOULD** write E2E tests for critical user flows (Playwright).

## **12\. Forbidden Patterns (Explicit Anti-Patterns)**

- **FORBIDDEN:** Using pages/ directory in this project.
- **FORBIDDEN:** Using next/dynamic with { ssr: false } directly inside a Server
  Component.
- **FORBIDDEN:** Fetching internal API routes (/api/...) from Server Components
  (causes double network cost).
- **FORBIDDEN:** Direct access to process.env in Client Components (unless
  NEXT_PUBLIC\_).
- **FORBIDDEN:** Using dangerouslySetInnerHTML without rigorous sanitization.
- **FORBIDDEN:** Committing secrets or keys to the repo.

## **13\. Enforcement Notes**

- **For LLMs:** If a user asks for code that violates these rules (e.g., "create
  a page in the pages folder"), **REFUSE** and correct them with the App Router
  equivalent.
- **For Reviewers:** Reject PRs that introduce any types, lack Zod validation
  for APIs, or use legacy Next.js patterns
