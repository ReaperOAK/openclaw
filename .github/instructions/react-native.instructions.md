---
description: 'ReactJS development standards and best practices'
applyTo: '**/*.jsx, **/*.tsx, **/*.js, **/*.ts, **/*.css, **/*.scss'
---

# **React Native Architecture & Development Standards**

## **1\. Purpose & Scope**

- **Purpose**: This document establishes the non-negotiable standards for all
  React Native development within this codebase. It eliminates ambiguity,
  enforces consistency, and mandates production-grade quality from day one.
- **Scope**: Applies to all .ts, .tsx, .js, and .json files within the mobile
  repository.
- **Audience**: All developers, architects, and AI coding assistants
  contributing to this project. Compliance is mandatory.

## **2\. Core Principles**

- **Mobile-First**: Design for touch, small screens, and unstable networks.
  Desktop assumptions will be rejected.
- **Strict TypeScript**: any is forbidden. If it's not typed, it doesn't exist.
- **Expo Managed**: We use Expo Managed workflow. Ejecting or using bare
  workflow requires written justification and Principal Architect approval.
- **Functional & Declarative**: 100% Functional Components. 100% Hooks. Zero
  Class Components.
- **Performance is a Feature**: 60fps is the baseline. Janky animations or slow
  interactions are bugs.
- **Immutability**: State is immutable. Direct mutation is strictly forbidden.

## **3\. Project Structure**

The project follows a feature-based structure to ensure scalability.

src/  
├── app/ \# Expo Router file-based routing (pages/screens)  
├── components/ \# Shared, atomic UI components (Buttons, Inputs)  
│ ├── ui/ \# Generic UI kit (no business logic)  
│ └── functional/ \# Components with specific logic  
├── features/ \# Feature-specific domains (Auth, Profile, Feed)  
│ ├── auth/  
│ │ ├── components/ \# Components unique to Auth  
│ │ ├── hooks/ \# Hooks unique to Auth  
│ │ └── api.ts \# API logic unique to Auth  
├── hooks/ \# Global custom hooks (useTheme, useDebounce)  
├── context/ \# Global React Context providers  
├── services/ \# External services (API, Analytics, Storage)  
├── styles/ \# Global theme, colors, typography  
├── types/ \# Global TypeScript definitions  
├── utils/ \# Pure utility functions (date formatting, validation)  
└── constants/ \# Global config and static values

- **Forbidden**: Grouping by file type (e.g., a root controllers folder or views
  folder). Logic must sit close to the feature it serves.

## **4\. TypeScript Rules**

- **Strict Mode**: strict: true in tsconfig.json is required.
- **No any**: Use unknown if the type is truly dynamic, then type guard it.
- **Props Interfaces**: Export Props interfaces for every component.  
  // CORRECT  
  export interface ButtonProps {  
   label: string;  
   onPress: () \=\> void;  
  }

- **React.FC**: Do not use React.FC. Type props directly in the function
  argument.
- **Async Handling**: All async functions must return Promise\<void\> or
  Promise\<T\>.
- **Navigation Typing**: All navigation params must be typed via a central
  NavigationTypes.ts file. Passing untyped params is forbidden.

## **5\. Component Design Rules**

- **Functional Only**: Classes are banned.
- **Single Responsibility**: One component per file. If a file exceeds 200
  lines, extract sub-components.
- **Props**: Destructure props in the function signature.
- **Logic Extraction**: Extract complex logic (data fetching, heavy
  calculations) into custom hooks. Keep the UI layer dumb.
- **Container vs. Presentational**:
  - **Presentational**: Accepts data via props, renders UI. No API calls.
  - **Container**: Handles data fetching, state management, and passes data to
    Presentational components.
- **Memoization**: Use React.memo only when a specific performance issue is
  identified and measured.

## **6\. State Management**

- **Local State**: Use useState for UI state (toggles, form inputs) local to a
  component.
- **Server State**: Use **TanStack Query (React Query)** for all async server
  data. Do not store server data in Redux/Zustand manually.
- **Global Client State**: Use **Zustand** for global app state (User Session,
  Theme, Settings). Avoid Redux unless complex transactional state updates are
  required.
- **Context API**: Use only for static global dependency injection (Theme, Auth
  State). Avoid high-frequency updates in Context to prevent re-render cascades.
- **Forbidden**: Storing derived state (data that can be calculated from
  existing props/state) in state.

## **7\. Hooks & Side Effects**

- **Rules of Hooks**: Never call hooks inside loops, conditions, or nested
  functions.
- **useEffect Dependency Array**: Must be exhaustive. eslint-plugin-react-hooks
  must be enabled and treated as an error, not a warning.
- **Cleanup**: Always return a cleanup function in useEffect when setting up
  subscriptions, timers, or event listeners.
- **Custom Hooks**: Prefix all custom hooks with use.
- **Business Logic**: Encapsulate all business logic in custom hooks. Components
  should look like a list of hooks followed by a JSX return.

## **8\. Styling & Theming**

- **Engine**: Use **NativeWind** (Tailwind CSS for Native) or **Restyle**. Plain
  StyleSheet.create is reserved for complex, dynamic animations only.
- **Theming**: All colors, spacing, and fonts must come from a central theme
  object. Hardcoded values (magic numbers/strings) are forbidden.
  - _Bad_: padding: 10, color: '\#F00'
  - _Good_: p-2.5 (NativeWind) or spacing.m, colors.error (Restyle)
- **Dark Mode**: All styles must support dark mode via the theming engine.
- **Text**: Use a standardized \<Typography\> or \<Text\> component that
  enforces font family and scaling. Never use raw \<Text\> with inline styles.

## **9\. Navigation**

- **Library**: **Expo Router** is the standard.
- **Type Safety**: Use strictly typed routes.
- **Deep Linking**: All screens must be accessible via deep links defined in the
  navigation config.
- **Structure**:
  - **Stacks**: For linear flows (e.g., Checkout).
  - **Tabs**: For main application sections.
  - **Modals**: For temporary interactions (filters, creation flows).

## **10\. Networking & API Layer**

- **Client**: Use axios or fetch wrapped in a custom apiClient instance.
- **Abstraction**: Components never call fetch directly. They call hook wrappers
  (e.g., useGetUser()) which call services (e.g., UserService.get()).
- **Error Handling**: The API layer must normalize errors into a standard format
  before throwing.
- **Auth Tokens**: Handle token injection and refresh automatically via axios
  interceptors.
- **Retries**: Idempotent GET requests should auto-retry on network failure
  (handled by React Query).

## **11\. Performance Rules**

- **Lists**: Always use FlashList (Shopify) instead of FlatList for lists with
  \>20 items.
- **Images**: Use expo-image for all images. Standard \<Image\> is deprecated.
- **Anonymous Functions**: Avoid passing inline arrow functions to list items
  (causes re-renders). Use useCallback.
- **Heavy Computation**: Run expensive synchronous tasks on a separate thread
  using react-native-worklets-core or similar if blocking the JS thread.
- **Render Cycles**: Use strict dependency arrays. Monitor render counts during
  development.

## **12\. Error Handling & Resilience**

- **Error Boundaries**: Wrap the entire app and critical features in
  \<ErrorBoundary\>.
- **Fallbacks**: UI must degrade gracefully. Show "Tap to Retry" buttons for
  failed queries.
- **Logging**: Log non-fatal errors to Sentry/Bugsnag. Console logs are for
  development only and must be stripped in production.
- **Silent Failures**: Never swallow errors in catch blocks without logging or
  user feedback.

## **13\. Testing Strategy**

- **Unit Tests**: Test logic hooks and pure utility functions using Jest.
- **Integration Tests**: Test critical user flows (Auth, Checkout) using React
  Native Testing Library.
- **Snapshot Testing**: Forbidden. It creates noise and high maintenance costs.
- **E2E**: Use **Maestro** for critical path end-to-end testing.
- **Mocking**: Mock all network requests. Tests must run offline.

## **14\. Security Rules**

- **Secrets**: NEVER commit API keys or secrets to Git. Use .env files and
  expo-secure-store.
- **Storage**: Never store sensitive data (tokens, PII) in AsyncStorage. Use
  expo-secure-store.
- **Biometrics**: Use expo-local-authentication for sensitive actions.
- **SSL Pinning**: Required for high-security applications (FinTech/Health).

## **15\. Linting, Formatting & Git Discipline**

- **Linter**: ESLint with standard or airbnb config, plus prettier.
- **Pre-commit**: husky hook must run lint and type-check before commit.
- **Commits**: Conventional Commits format is mandatory.
  - feat: add login screen
  - fix: resolve crash on logout
- **Formatting**: Prettier on save is mandatory. Code structure arguments are
  invalid; Prettier is the judge.

## **16\. Anti-Patterns (Explicitly Forbidden)**

- ❌ Using require() for images (use import).
- ❌ Inline styles for anything other than dynamic values (e.g., animation
  interpolation).
- ❌ Prop drilling \> 2 levels (use Composition or Context).
- ❌ Mutating state directly (state.value \= 5).
- ❌ Using libraries that require react-native link (we are in Expo Managed).
- ❌ Leaving console.log in production code.
- ❌ "God components" (\> 300 lines).

## **17\. PR & Code Review Checklist**

- \[ \] Code builds and runs on both iOS and Android simulators.
- \[ \] No any types remain.
- \[ \] No ESLint warnings.
- \[ \] Unit tests added/updated for new logic.
- \[ \] Accessibility labels added to interactive elements.
- \[ \] Imports are sorted and unused imports removed.
- \[ \] Complex logic is explained in JSDoc comments.
