-- ============================================================
-- Resume Intelligence Pipeline — Database Schema
-- Version: 1.0
-- Schemas: resume_data, enrichment, failed_resumes
-- ============================================================

-- ============================================================
-- SCHEMA 1: Resume Data
-- Structured information extracted from parsed resumes
-- ============================================================
-- Table 1: candidates
-- Core identity table. One row per unique human being.
-- All other resume tables reference this table.
CREATE TABLE candidates(
    candidate_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(50),
    city  VARCHAR(100),
    country VARCHAR(100),
    linkedin_url TEXT,
    github_url TEXT,
    portfolio_url TEXT,
    summary TEXT,
    total_years_experience NUMERIC(4,1),
    source_platform VARCHAR(50),
    profile_headline VARCHAR(255),  
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE INDEX idx_candidates_email on candidates(email);
CREATE INDEX idx_candidates_phone on candidates(phone);


-- Table 2: education
-- One row per education entry per candidate.
-- A candidate can have multiple education records.
CREATE TABLE education(
    education_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    degree VARCHAR(255),
    institution VARCHAR(255),
    specialization VARCHAR(255),
    cgpa  NUMERIC(4,2),
    start_year   SMALLINT,
    end_year    SMALLINT
);

CREATE INDEX idx_education_candidate on education(candidate_id);

-- Table 3: experience
-- One row per job entry per candidate.
-- A candidate can have multiple experience records.
CREATE TABLE experience(
    experience_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    company VARCHAR(255),
    designation VARCHAR(255),
    location VARCHAR(255),
    client VARCHAR(255),
    start_date   DATE,
    end_date     DATE,
    is_current   BOOLEAN    NOT NULL  DEFAULT FALSE,
    description  TEXT
);
CREATE INDEX idx_experience_candidate ON experience(candidate_id);


-- Table 4: skills
-- One row per skill per candidate.
-- Source field distinguishes resume-parsed vs enrichment-added skills.
CREATE TABLE  skills(
    skill_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    skill_name VARCHAR(255) NOT NULL,
    category VARCHAR(50),
    source  VARCHAR (20) NOT NULL DEFAULT 'resume'
        CHECK (source  IN ('resume','enriched')),
    CONSTRAINT uq_candidate_skill UNIQUE (candidate_id, skill_name)

);
CREATE INDEX idx_skills_candidate on skills(candidate_id);



-- Table 5: projects
-- One row per project per candidate.
CREATE TABLE  projects(
    project_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    project_name VARCHAR(255),
    description TEXT,
    technologies TEXT[],
    github_url TEXT,
    live_url TEXT
);

CREATE INDEX idx_projects_candidate on projects(candidate_id);


-- Table 6: certificates
-- One row per certificates per candidate.
CREATE TABLE  certifications(
    certification_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    certificate_name VARCHAR(255),
    issuing_organization VARCHAR(255),
    issue_date   DATE,
    expiry_date  DATE,
    credential_url TEXT
);

CREATE INDEX idx_certifications_candidate ON certifications(candidate_id);


--Table 7: Languages
-- One row per language per candidate.
-- Proficiency is optional — resumes rarely specify it.
CREATE TABLE languages(
    language_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    language VARCHAR(100)  NOT NULL,
    proficiency VARCHAR(20)   
);
CREATE INDEX idx_languages_candidate ON languages(candidate_id);

-- ============================================================
-- SCHEMA 2: Enrichment Data
-- Information retrieved from external vendors after parsing.
-- One candidate can have multiple enrichment records across
-- different vendors or different points in time.
-- Tables: candidate_enrichments
-- ============================================================

-- Table 8: candidate_enrichments
-- One row per enrichment attempt per candidate.
-- Stores both raw API response (JSONB) and extracted key fields.
-- is_active flag distinguishes current enrichment from historical records.
-- data_source tracks which vendor provided the data.

CREATE TABLE candidate_enrichments(
    enrichment_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID     NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    -- data_source VARCHAR(50) NOT NULL  <-- Require Clarity on the need of it 
    -- CHECK (data_source IN ('people_data_labs', 'apollo', 'zoominfo', 'fullcontact'))
    raw_payload JSONB,
    current_company VARCHAR(255),
    current_title  VARCHAR(255),
    location_update VARCHAR(200),
    industry VARCHAR(100),
    years_experience SMALLINT,
    confidence_score NUMERIC(4,3),
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_enrichments_candidate on candidate_enrichments(candidate_id);
-- CREATE INDEX idx_enrichments_source on candidate_enrichments(data_so);


-- ============================================================
-- SCHEMA 3: Failed / Rejected Resumes
-- Audit trail for all resumes that could not be processed.
-- Records files that failed at any stage of the pipeline —
-- before, during, or after parsing.
-- Tables: failed_resumes
-- ============================================================

-- Table 9: failed_resumes
-- One row per failed or rejected resume file.
-- Tracks filename, source path, failure reason, and review status.
-- No foreign key to candidates — these never made it to parsing.
-- failure_reason captures the stage and type of failure.
-- status tracks whether the failure has been reviewed or resolved.

CREATE TABLE failed_resumes(
    failed_resume_id UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name  VARCHAR(255),
    file_path  TEXT,
    email      VARCHAR(255),
    failure_reason  VARCHAR (50) NOT NULL
        CHECK(failure_reason IN (
            'duplicate_file', 
            'duplicate_candidate',
            'image_only_pdf',
            'corrupted_file',
            'password_protected',
            'parse_failed',
            'unsupported_format'
        )),
    status  VARCHAR (20) NOT NULL DEFAULT 'pending_review'
        CHECK (status  IN ('pending_review', 'resolved', 'ignored')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now() 

);

CREATE INDEX idx_failed_resumes_reason ON failed_resumes(failure_reason);
