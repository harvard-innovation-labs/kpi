-- student_dim

CREATE TABLE salesforce_members_raw ( -- one row per student per term
  contact_id text,
  lab_term text,
  team_member_created date,
  term_venture_stage text,
  first_name text,
  last_name text,
  preferred_email text,
  sma_registration_email text,
  permanent_email text,
  secondary_email text,
  team text,
  account_id text,
  team_vp_cohort text,
  team_lead boolean,
  primary_industry text,
  secondary_industry text,
  harvard_school_affiliation_1 text,
  harvard_school_affiliation_2 text,
  harvard_affiliation text,
  non_harvard_affiliation text,
  harvard_affiliation_from_sso text,
  gender text,
  race_ethnicity text
);

CREATE TABLE student_dim (   -- one row per student
  contact_id text PRIMARY KEY,
  first_name text,
  last_name text,
  full_name text,
  first_team text,
  last_team text,
  preferred_email_norm text,    -- emails are normalized, so lower(trim(xx)) for easier matching
  sma_registration_email_norm text,
  permanent_email_norm text,
  secondary_email_norm text,
  gender text,
  race_ethnicity text,
  school_1 text,
  school_2 text,
  first_term text,
  last_term text,
  first_term_venture_stage text,
  last_term_venture_stage text,
  join_date date
);


-- Airtable data
--
-- try to use similar names as oncehub_bookings
CREATE TABLE airtable_bookings (
  unique_id text,

  booker text,  -- student name 
  booker_email text,  -- student email
  booker_harvard_affiliation text, -- student status, so undergrad, grad
  booker_school text,  -- primary school / college
  booker_grad_year integer,
  startup text, 	-- venture name
  startup_description text, 	-- short venture description
  question text, -- agenda 

  expert text,  	-- full_name_from_expert_from_slot 
  expert_vertical text, 	-- primary_vertical_from_expert_from_slot
  expert_school text, -- university_affiliation_from_expert_2_from_slot
  expert_type text, -- expert_type_from_expert_from_slot

  created_at timestamp without time zone,
  starting_at timestamp without time zone,
  duration integer,
  location text, 	-- virtual or in person 
  academic_year text
);
CREATE INDEX IF NOT EXISTS idx_airtable_bookings_academic_year ON airtable_bookings (academic_year);


# raw table for imports
CREATE TABLE airtable_raw (
  id int,
  slot text,
  university_affiliation_from_expert_2_from_slot text,
  expert_type_from_expert_from_slot text,
  url text,
  unique_id text,
  full_name_from_expert_from_slot text,
  primary_vertical_from_expert_from_slot text,
  location_from_slot text,
  specific_location_from_slot text,

  start_local_from_slot timestamp,
  end_local_from_slot timestamp,
  created timestamp,

  start_iso_no_tz_from_slot text,
  end_iso_no_tz_from_slot text,
  expert_from_slot text,
  expert_email_from_slots text,
  student_name text,
  student_email text,
  agenda text,
  primary_school_college text,
  which_university_or_organization_are_you_a_part_of text,
  student_status text,
  graduation_year text,
  venture_name text,
  short_venture_description text,

  num int,
  email_address_from_expert_from_slot_2 text,
  pitch_deck_or_other_materials text,
  start_iso_no_tz_from_slot_copy text,
  no_show_tracking text,
  created_2 timestamp,
  feedback text,
  send_reminder_24h text, -- might have errors
  reminder_sent text
);

 
-- student events 
create table student_events (
  event_key text primary key,
  source_system text not null,
  source_record_id text not null,
  event_type text not null,
  booker_name text,
  booker_email_norm text,
  booked_at timestamp,
  event_at timestamp,
  student_id text      -- if matched to student_dim, else could be null
)
CREATE INDEX idx_student_events_email ON student_events (booker_email_norm);
CREATE INDEX idx_student_events_student ON student_events (student_id);


CREATE INDEX IF NOT EXISTS idx_student_dim_preferred_email ON student_dim (preferred_email_norm);
CREATE INDEX IF NOT EXISTS idx_student_dim_sma_email        ON student_dim (sma_registration_email_norm);
CREATE INDEX IF NOT EXISTS idx_student_dim_permanent_email  ON student_dim (permanent_email_norm);
CREATE INDEX IF NOT EXISTS idx_student_dim_secondary_email  ON student_dim (secondary_email_norm);

CREATE INDEX IF NOT EXISTS idx_event_attendees_email ON event_attendees (lower(trim(email)));
CREATE INDEX IF NOT EXISTS idx_oncehub_bookings_email ON oncehub_bookings (lower(trim(booker_email)));
CREATE INDEX IF NOT EXISTS idx_airtable_bookings_email ON airtable_bookings (lower(trim(booker_email)));
