-- ==============================================================================
-- 000001_init_schema.down.sql
-- Rollback master schema
-- ==============================================================================

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS blog_posts CASCADE;
DROP TABLE IF EXISTS student_assessments CASCADE;
DROP TABLE IF EXISTS syllabus_coverage CASCADE;
DROP TABLE IF EXISTS cbc_strands CASCADE;
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS library_books CASCADE;
DROP TABLE IF EXISTS nurse_visits CASCADE;
DROP TABLE IF EXISTS payment_plans CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS fee_ledgers CASCADE;
DROP TABLE IF EXISTS fee_structure_items CASCADE;
DROP TABLE IF EXISTS fee_structures CASCADE;
DROP TABLE IF EXISTS staff_invites CASCADE;
DROP TABLE IF EXISTS biometric_templates CASCADE;
DROP TABLE IF EXISTS consents CASCADE;
DROP TABLE IF EXISTS enrolments CASCADE;
DROP TABLE IF EXISTS student_guardians CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS clubs CASCADE;
DROP TABLE IF EXISTS dormitories CASCADE;
DROP TABLE IF EXISTS classes CASCADE;
DROP TABLE IF EXISTS grade_levels CASCADE;
DROP TABLE IF EXISTS terms CASCADE;
DROP TABLE IF EXISTS academic_years CASCADE;
DROP TABLE IF EXISTS membership_badges CASCADE;
DROP TABLE IF EXISTS badge_permissions CASCADE;
DROP TABLE IF EXISTS badges CASCADE;
DROP TABLE IF EXISTS memberships CASCADE;
DROP TABLE IF EXISTS permissions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS schools CASCADE;

DROP FUNCTION IF EXISTS current_school_id();
