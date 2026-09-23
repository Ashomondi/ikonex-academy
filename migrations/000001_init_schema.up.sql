-- ==============================================================================
-- 000001_init_schema.up.sql
-- Ikonex Academy - Master PostgreSQL Schema with Row-Level Security (RLS)
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Function to return current tenant school_id from session context
CREATE OR REPLACE FUNCTION current_school_id() RETURNS uuid AS $$
    SELECT NULLIF(current_setting('app.school_id', true), '')::uuid;
$$ LANGUAGE sql STABLE;

-- ------------------------------------------------------------------------------
-- Global Tables (Non-Tenant Scoped)
-- ------------------------------------------------------------------------------

CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    county VARCHAR(100),
    logo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    national_id VARCHAR(50),
    email VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    description TEXT
);

-- ------------------------------------------------------------------------------
-- Tenant Tables (Isolated via school_id and RLS)
-- ------------------------------------------------------------------------------

CREATE TABLE memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL, -- e.g. principal, deputy, teacher, bursar, nurse, librarian, dean_of_studies, parent
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, user_id, role)
);

CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    scope_type VARCHAR(50) NOT NULL DEFAULT 'none', -- none, class, club, term, window
    description TEXT,
    UNIQUE (school_id, slug)
);

CREATE TABLE badge_permissions (
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (badge_id, permission_id)
);

CREATE TABLE membership_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    membership_id UUID NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    scope_id UUID, -- class_id, club_id, etc.
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    year INT NOT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, year)
);

CREATE TABLE terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
    term_number INT NOT NULL CHECK (term_number BETWEEN 1 AND 3),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (school_id, academic_year_id, term_number)
);

CREATE TABLE grade_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    number INT NOT NULL CHECK (number BETWEEN 7 AND 12), -- Kenya CBC Junior (7-9) & Senior (10-12)
    phase VARCHAR(20) NOT NULL CHECK (phase IN ('junior', 'senior')),
    name VARCHAR(50) NOT NULL,
    UNIQUE (school_id, number)
);

CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id) ON DELETE RESTRICT,
    stream_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, grade_level_id, stream_name)
);

CREATE TABLE dormitories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(20) NOT NULL,
    capacity INT NOT NULL DEFAULT 0
);

CREATE TABLE clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    admission_number VARCHAR(100) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    dob DATE NOT NULL,
    gender VARCHAR(20) NOT NULL,
    current_class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
    current_dormitory_id UUID REFERENCES dormitories(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, admission_number)
);

CREATE TABLE student_guardians (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_fee_payer BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, student_id, user_id)
);

CREATE TABLE enrolments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id) ON DELETE RESTRICT,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, student_id, academic_year_id)
);

CREATE TABLE consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    guardian_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    purpose VARCHAR(50) NOT NULL CHECK (purpose IN ('biometric_attendance', 'photo', 'sms')),
    granted BOOLEAN NOT NULL DEFAULT FALSE,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE TABLE biometric_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    template_data BYTEA NOT NULL, -- Raw images never stored, encrypted templates only
    algorithm VARCHAR(50) NOT NULL,
    key_version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, student_id)
);

CREATE TABLE staff_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    role VARCHAR(50) NOT NULL,
    qr_token VARCHAR(255) UNIQUE NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id) ON DELETE RESTRICT,
    term_id UUID NOT NULL REFERENCES terms(id) ON DELETE RESTRICT,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, academic_year_id, grade_level_id, term_id)
);

CREATE TABLE fee_structure_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL REFERENCES fee_structures(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    is_compulsory BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE fee_ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    term_id UUID NOT NULL REFERENCES terms(id) ON DELETE RESTRICT,
    opening_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    billed_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, student_id, academic_year_id, term_id)
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL,
    transaction_ref VARCHAR(100) UNIQUE NOT NULL,
    provider VARCHAR(50) NOT NULL, -- mpesa_stk, mpesa_c2b, bank
    amount NUMERIC(12, 2) NOT NULL,
    payer_phone VARCHAR(20),
    payer_name VARCHAR(255),
    matched_status VARCHAR(50) NOT NULL DEFAULT 'unmatched', -- unmatched, matched, ai_suggested
    matched_by UUID REFERENCES users(id),
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_payload JSONB
);

CREATE TABLE payment_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    guardian_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    pledged_amount NUMERIC(12, 2) NOT NULL,
    pledge_frequency VARCHAR(50) NOT NULL DEFAULT 'monthly',
    next_due_date DATE NOT NULL,
    default_count INT NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);

CREATE TABLE nurse_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    visit_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    clinical_notes TEXT NOT NULL, -- Strictly restricted to nurse role; never shared with teachers
    recommendation TEXT,
    notified_class_teacher BOOLEAN NOT NULL DEFAULT FALSE,
    logged_by UUID NOT NULL REFERENCES users(id)
);

CREATE TABLE library_books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    isbn VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1
);

CREATE TABLE book_loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES library_books(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    borrowed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date DATE NOT NULL,
    returned_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'borrowed'
);

CREATE TABLE cbc_strands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    grade_level_id UUID NOT NULL REFERENCES grade_levels(id) ON DELETE CASCADE,
    subject VARCHAR(100) NOT NULL,
    strand_name VARCHAR(255) NOT NULL,
    sub_strand_name VARCHAR(255) NOT NULL,
    learning_outcomes TEXT
);

CREATE TABLE syllabus_coverage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    strand_id UUID NOT NULL REFERENCES cbc_strands(id) ON DELETE CASCADE,
    teacher_user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(50) NOT NULL DEFAULT 'in_progress',
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (school_id, class_id, strand_id)
);

CREATE TABLE student_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    term_id UUID NOT NULL REFERENCES terms(id) ON DELETE RESTRICT,
    strand_id UUID NOT NULL REFERENCES cbc_strands(id) ON DELETE CASCADE,
    performance_level VARCHAR(10) NOT NULL CHECK (performance_level IN ('EE', 'ME', 'AE', 'BE')), -- CBC
    teacher_comments TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE blog_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    club_id UUID REFERENCES clubs(id) ON DELETE SET NULL,
    author_membership_id UUID NOT NULL REFERENCES memberships(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    safety_checked BOOLEAN NOT NULL DEFAULT FALSE,
    safety_flags JSONB,
    patron_reviewed_by UUID REFERENCES users(id),
    published_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'draft'
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(100),
    ip_address VARCHAR(50),
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- Row-Level Security (RLS) Configuration on all tenant-owned tables
-- ------------------------------------------------------------------------------

DO $$
DECLARE
    tbl TEXT;
    tenant_tables TEXT[] := ARRAY[
        'memberships', 'badges', 'academic_years', 'terms', 'grade_levels',
        'classes', 'dormitories', 'clubs', 'students', 'student_guardians',
        'enrolments', 'consents', 'biometric_templates', 'staff_invites',
        'fee_structures', 'fee_ledgers', 'payments', 'payment_plans',
        'nurse_visits', 'library_books', 'book_loans', 'cbc_strands',
        'syllabus_coverage', 'student_assessments', 'blog_posts'
    ];
BEGIN
    FOREACH tbl IN ARRAY tenant_tables LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', tbl);
        EXECUTE format('CREATE POLICY %I_tenant_isolation ON %I FOR ALL USING (school_id = current_school_id()) WITH CHECK (school_id = current_school_id());', tbl, tbl);
    END LOOP;
END $$;
