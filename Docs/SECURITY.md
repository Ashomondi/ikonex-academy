# SECURITY.md

Consent, encryption, retention, and AI-data-boundary rules. This project
handles children's personal data — including biometric and health data —
under Kenya's Data Protection Act, 2019. This file is not legal advice; have
a Kenyan data protection lawyer or the ODPC review the platform before
processing real student data at scale. Primary sources: the Act itself, the
Data Protection (General) Regulations, 2021, and the ODPC's 2026 Guidance
Notes on Cross-Border Data Transfers — read those directly rather than
relying only on this summary.

## Data categories and how they're treated

| Category | Examples in this system | Rule |
|---|---|---|
| Sensitive personal data | biometric templates, health/nurse records | Extra processing grounds required (Act Part V); strict access control; never sent to the AI service in raw form |
| Personal data (general) | name, DOB, admission number, results | Standard processing rules: lawful, purpose-limited, accurate, not kept longer than needed |
| Financial data | fee balances, payment history | Standard rules, plus signatory approval for anything that moves money |
| Aggregate/derived data | class means, subject means | Not linked to individual students when shown outside the owning class teacher |

## Consent

- **Children's data requires parental/guardian consent.** Record consent per
  student, per purpose (`consents` table: e.g. `biometric_attendance`,
  `photo`, `sms`), with a timestamp and a way to revoke it.
- **Always offer a non-biometric alternative** for attendance and any other
  process that currently defaults to biometrics, for a guardian who declines.
- **Consent is purpose-specific.** Data collected for attendance isn't reused
  for something else (e.g. marketing, a different module) without fresh
  consent.
- **Parents can see what's held and withdraw consent** — this is the planned
  "consent centre" feature (see `REQUIREMENTS.md`, Platform foundation).

## Biometric data

- **Store encrypted templates only. Never store the raw fingerprint image.**
  Discard the raw scan immediately after the template is generated.
- **Per-school encryption keys**, envelope-encrypted via a key management
  service. Templates live in their own table (`biometric_templates`) with
  more restricted access than the rest of the schema.
- **Delete on exit.** When a student leaves the school, their biometric
  templates are deleted, not just marked inactive.
- **Audit every read** of the biometric table.

## Health data (nurse records)

- **Full clinical detail is restricted to the nurse role.**
- **Class teacher notification is a flag, not a copy of the record** — e.g.
  "visited the sickbay, advised rest," never symptoms or diagnosis.
- **Parent-facing SMS follows the same rule**: confirms a visit happened,
  not clinical detail (see `REQUIREMENTS.md`, Nurse module).
- Health data is never sent to the AI service as free text; if the AI ever
  needs to summarise nurse trends for reporting, it works from pre-aggregated,
  de-identified counts, not individual records.

## AI service data boundary

This is the section most specific to this project's AI features — see also
`API_CONTRACTS.md` for how it's enforced technically.

1. **The AI service is self-hosted, in Kenya**, and has no direct database
   access (enforced at the API layer, not just by convention).
2. **It receives only what a specific, permission-checked endpoint returns**
   — e.g. a parent-assistant query about a fee balance gets the balance, not
   the student's full record.
3. **It never receives raw biometric or nurse-record data.**
4. **It never originates a fact.** Fee balances, attendance, and results come
   from the database; the model's job is language (phrasing, translation,
   mapping natural language to CBC strands), never invention.
5. **Every AI-initiated action is logged**: what was asked, what data was
   read, what action (if any) was taken, and by which AI feature.
6. **A human approves anything sent to a parent or written to a permanent
   record** — report comments, blog posts, plain-language explanations — the
   AI drafts, a teacher/patron/bursar confirms.
7. **Payments: the AI proposes, a human confirms.** The AI service can
   initiate an STK push only after the parent has explicitly confirmed the
   child and amount in the conversation; it never sends money without that
   confirmation, and it never initiates supplier payments at all — those go
   through the bursar signatory workflow.

## Cross-border transfer

- **Default assumption: student and staff personal data stays hosted in
  Kenya.** This is both a compliance position and a product claim (see the
  bootcamp application materials), so don't add a dependency that silently
  routes personal data through a foreign service.
- If a foreign service is ever genuinely needed (e.g. a third-party API with
  no Kenyan equivalent), check Sections 48–50 of the Act first: transfers
  outside Kenya require proof of appropriate safeguards to the Data
  Commissioner, and for sensitive personal data, case law (Federation of
  Kenya Employers v. Ministry of Foreign Affairs, 2023) confirms the
  Commissioner must be informed and satisfied the transfer meets the
  statutory requirements before it happens — this is not just a consent
  question.
- Remote access to Kenyan personal data from outside Kenya, and hosting it on
  a server abroad, both count as a "transfer" under the ODPC's 2026 guidance
  — not only a literal file copy.

## Retention

> Fill in per data category once policy is set: how long results, attendance,
> financial records, and consent records are kept after a student leaves,
> and the deletion process.

## Breach response

- Data controllers must report a breach to the ODPC within 72 hours, and to
  affected data subjects without undue delay.
- `TODO`: define the internal breach process (who's notified internally,
  how a breach is confirmed, who contacts the ODPC) before handling real
  student data.

## Registration

- Acting as a data controller or processor without registering with the ODPC
  is an offence under the Act. Confirm registration status before
  processing real student data — this is a business/legal task, not a
  coding task, but it blocks going live.
