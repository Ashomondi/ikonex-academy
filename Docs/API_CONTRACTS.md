# API_CONTRACTS.md

How the frontend, Go backend, and AI service agree on interfaces. Update this
as real endpoints are built — this is meant to track actual contracts, not
aspirational ones. Once the project has a real number of endpoints, consider
generating this from an OpenAPI spec instead of maintaining it by hand.

## Auth model

- Every authenticated request carries the caller's identity (user + active
  membership) and resolves to a `school_id`.
- The Go backend sets `app.school_id` for the request's database transaction
  so RLS does the enforcement — see `ARCHITECTURE.md`.
- Every endpoint declares which permission(s) it requires. A request without
  the right permission (via the caller's badges) is rejected before it
  reaches any handler logic — not filtered afterwards.
- Parent-facing endpoints additionally scope to "children this parent is a
  guardian of" — never just "this school."

## Rule: the AI service never touches the database directly

The AI service (Python/FastAPI) has no direct database credentials. It:

1. Receives a request already carrying the caller's identity and permission
   context (forwarded by the Go backend, not re-derived by the AI service).
2. Calls specific, permission-checked Go endpoints to fetch facts (fee
   balance, attendance record, syllabus status, etc.).
3. Uses the model only to phrase, translate, summarise, or map — never to
   originate a fact that should come from the database.
4. Any action with a real-world effect (starting an STK push, updating
   syllabus coverage, posting a reminder) calls a Go endpoint to perform it;
   the AI service does not write to storage on its own.

This is the enforcement point for "AI never invents a fee balance" and "AI
never handles money directly" from `CLAUDE.md` and `SECURITY.md`.

## Endpoint groups (fill in as built)

> Each group below should end up as a real section with method, path,
> request/response shape, and required permission. Skeleton only for now.

### Auth & onboarding
- `POST /auth/otp/request`, `POST /auth/otp/verify`
- `POST /staff-invites` (permission: `staff.invites.create`)
- `POST /staff-applications/{id}/review` (permission:
  `staff.applications.review`)
- `POST /students/admit` (permission: `students.admit`)

### Academics
- `GET /classes/{id}/roster` (permission: `class.students.view`)
- `GET /classes/{id}/stats` (permission: `class.stats.view` — means only, no
  names)
- `POST /syllabus/coverage` — called by AI service after mapping a teacher's
  natural-language input to CBC strands/sub-strands
- `GET /students/{id}/performance-history` (parent/teacher, scoped)

### Fees & payments
- `GET /students/{id}/fee-balance` (parent-scoped, or bursar)
- `POST /payments/stk-push` — AI service calls this after confirming child +
  amount with the parent; never initiates without that confirmation step
- `GET /payments/unmatched` (bursar) — feeds the AI reconciliation feature
- `POST /payments/{id}/match` (bursar confirms an AI-suggested match)
- `POST /payment-plans/{id}/reminder-check` — AI service reads pledge vs.
  actual payments and arrears, triggers a reminder job (does not send
  directly — enqueues via the notification system)

### Notifications
- `POST /notifications/send` (internal use by jobs, not directly callable by
  AI service without going through a job)

### AI-service-facing (internal only — never exposed to frontend directly)
- `POST /internal/ai/parent-query` — resolves a parent's natural-language
  question by calling the appropriate read endpoints above
- `POST /internal/ai/blog-safety-check` — checks a draft post for children's
  personal details before a patron publishes

## Response conventions

> Fill in once decided: error shape, pagination style, date/time format
> (recommend ISO 8601, always with the school's timezone made explicit),
> versioning approach.

## What's not yet decided

- Whether the AI service authenticates to the Go backend with a service
  token plus the forwarded user context, or some other scheme — needs a
  decision before Release 1 AI features are built.
- Rate limiting for AI-facing endpoints (a parent-assistant loop must not be
  able to hammer fee-balance lookups).
