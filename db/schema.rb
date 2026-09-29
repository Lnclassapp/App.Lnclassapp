# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_29_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "answers", force: :cascade do |t|
    t.string "content", limit: 500, null: false
    t.boolean "correct", null: false
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "position"], name: "index_answers_on_question_id_and_position", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", limit: 60, null: false
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "ip_address", limit: 45
    t.jsonb "metadata", default: {}, null: false
    t.bigint "subject_id"
    t.string "subject_type", limit: 40
    t.index ["actor_id", "created_at"], name: "index_audit_events_on_actor_id_and_created_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject_type_and_subject_id"
  end

  create_table "backup_codes", force: :cascade do |t|
    t.string "code_digest", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_backup_codes_on_user_id", where: "(used_at IS NULL)"
  end

  create_table "classroom_assignments", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "archived_by_id"
    t.bigint "assignable_id", null: false
    t.string "assignable_type", null: false
    t.datetime "assigned_at", null: false
    t.bigint "assigned_by_id", null: false
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.string "public_id", limit: 14, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_by_id"], name: "index_classroom_assignments_on_archived_by_id"
    t.index ["assignable_type", "assignable_id"], name: "idx_on_assignable_type_assignable_id_89cda988b0"
    t.index ["assigned_by_id"], name: "index_classroom_assignments_on_assigned_by_id"
    t.index ["classroom_id", "assignable_type", "assignable_id"], name: "index_classroom_assignments_one_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["classroom_id"], name: "index_classroom_assignments_on_classroom_id"
    t.index ["public_id"], name: "index_classroom_assignments_on_public_id", unique: true
    t.check_constraint "(status::text = 'archived'::text) = (archived_at IS NOT NULL)", name: "classroom_assignments_archived_at_iff_archived"
    t.check_constraint "assignable_type::text = ANY (ARRAY['Course'::character varying, 'Essential'::character varying, 'Exercise'::character varying]::text[])", name: "classroom_assignments_type_values"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "classroom_assignments_status_values"
  end

  create_table "classroom_plan_entries", force: :cascade do |t|
    t.integer "count", null: false
    t.datetime "created_at", null: false
    t.bigint "level_id", null: false
    t.string "school_type", null: false
    t.bigint "series_id"
    t.datetime "updated_at", null: false
    t.index ["school_type", "level_id", "series_id"], name: "index_classroom_plan_entries_on_pair", unique: true, where: "(series_id IS NOT NULL)"
    t.index ["school_type", "level_id"], name: "index_classroom_plan_entries_on_level", unique: true, where: "(series_id IS NULL)"
    t.index ["series_id"], name: "index_classroom_plan_entries_on_series_id"
    t.check_constraint "count >= 0 AND count <= 30", name: "classroom_plan_entries_count_range"
    t.check_constraint "school_type::text = ANY (ARRAY['public'::character varying, 'private'::character varying]::text[])", name: "classroom_plan_entries_school_type_values"
  end

  create_table "classroom_students", force: :cascade do |t|
    t.bigint "classroom_id", null: false
    t.datetime "joined_at", null: false
    t.datetime "left_at"
    t.boolean "primary", default: false, null: false
    t.bigint "student_id", null: false
    t.index ["classroom_id", "student_id"], name: "index_classroom_students_on_classroom_id_and_student_id", unique: true
    t.index ["student_id"], name: "index_classroom_students_one_active_primary", unique: true, where: "(\"primary\" AND (left_at IS NULL))"
  end

  create_table "classrooms", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "join_code", limit: 5
    t.datetime "join_code_rotated_at"
    t.bigint "level_id", null: false
    t.integer "max_students", default: 80, null: false
    t.string "name", limit: 15, null: false
    t.string "public_id", limit: 14, null: false
    t.bigint "school_id", null: false
    t.string "school_year", limit: 9, null: false
    t.bigint "series_id"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["join_code"], name: "index_classrooms_on_join_code", unique: true, where: "(join_code IS NOT NULL)"
    t.index ["level_id"], name: "index_classrooms_on_level_id"
    t.index ["public_id"], name: "index_classrooms_on_public_id", unique: true
    t.index ["school_id", "school_year", "name"], name: "index_classrooms_on_school_id_and_school_year_and_name", unique: true
    t.index ["series_id"], name: "index_classrooms_on_series_id"
    t.check_constraint "(status::text = 'archived'::text) = (archived_at IS NOT NULL)", name: "classrooms_archived_at_iff_archived"
    t.check_constraint "join_code::text ~ '^[a-hj-np-z]{3}[2-9]{2}$'::text", name: "classrooms_join_code_format"
    t.check_constraint "max_students >= 1 AND max_students <= 150", name: "classrooms_max_students_range"
    t.check_constraint "school_year::text ~ '^[0-9]{4}-[0-9]{4}$'::text AND \"right\"(school_year::text, 4)::integer = (\"left\"(school_year::text, 4)::integer + 1)", name: "classrooms_school_year_format"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "classrooms_status_values"
  end

  create_table "courses", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "level_id", null: false
    t.bigint "material_id", null: false
    t.string "name", limit: 200, null: false
    t.datetime "published_at"
    t.bigint "series_id"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "subtitle", limit: 150
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_courses_on_author_id"
    t.index ["level_id", "material_id", "name"], name: "index_courses_unique_without_series", unique: true, where: "(series_id IS NULL)"
    t.index ["level_id", "material_id", "series_id", "name"], name: "index_courses_unique_with_series", unique: true, where: "(series_id IS NOT NULL)"
    t.index ["material_id"], name: "index_courses_on_material_id"
    t.index ["series_id"], name: "index_courses_on_series_id"
    t.index ["slug"], name: "index_courses_on_slug", unique: true
    t.index ["status"], name: "index_courses_on_status"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "courses_status_values"
  end

  create_table "drenas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 80, null: false
    t.string "public_id", limit: 14, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_drenas_on_name", unique: true
    t.index ["public_id"], name: "index_drenas_on_public_id", unique: true
    t.index ["slug"], name: "index_drenas_on_slug", unique: true
  end

  create_table "essentials", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "author_id", null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 150, null: false
    t.integer "position", null: false
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "subtitle", limit: 150
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_essentials_on_author_id"
    t.index ["course_id", "name"], name: "index_essentials_on_course_id_and_name", unique: true
    t.index ["course_id", "position"], name: "index_essentials_on_course_id_and_position", unique: true
    t.index ["slug"], name: "index_essentials_on_slug", unique: true
    t.index ["status"], name: "index_essentials_on_status"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "essentials_status_values"
  end

  create_table "exercise_badges", force: :cascade do |t|
    t.datetime "awarded_at", null: false
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.bigint "exercise_session_id", null: false
    t.string "level", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_exercise_badges_on_exercise_id"
    t.index ["exercise_session_id"], name: "index_exercise_badges_on_exercise_session_id"
    t.index ["student_id", "exercise_id"], name: "index_exercise_badges_on_student_id_and_exercise_id", unique: true
    t.check_constraint "level::text = ANY (ARRAY['bronze'::character varying, 'silver'::character varying, 'gold'::character varying, 'diamond'::character varying]::text[])", name: "exercise_badges_level_values"
  end

  create_table "exercise_sessions", force: :cascade do |t|
    t.integer "answered_count", default: 0, null: false
    t.bigint "classroom_assignment_id"
    t.datetime "completed_at"
    t.integer "correct_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.string "kind", default: "standard", null: false
    t.bigint "knowledge_gap_id"
    t.integer "progress_percent", default: 0, null: false
    t.string "public_id", limit: 14, null: false
    t.integer "question_count", null: false
    t.integer "score_percent"
    t.datetime "started_at", null: false
    t.string "status", default: "started", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_assignment_id"], name: "index_exercise_sessions_on_classroom_assignment_id"
    t.index ["exercise_id"], name: "index_exercise_sessions_on_exercise_id"
    t.index ["knowledge_gap_id"], name: "index_exercise_sessions_on_knowledge_gap_id"
    t.index ["public_id"], name: "index_exercise_sessions_on_public_id", unique: true
    t.index ["student_id", "completed_at"], name: "index_exercise_sessions_on_student_id_and_completed_at"
    t.index ["student_id", "exercise_id"], name: "index_exercise_sessions_one_started", unique: true, where: "((status)::text = 'started'::text)"
    t.check_constraint "(kind::text = 'remediation'::text) = (knowledge_gap_id IS NOT NULL)", name: "exercise_sessions_remediation_iff_gap"
    t.check_constraint "kind::text = ANY (ARRAY['standard'::character varying, 'remediation'::character varying]::text[])", name: "exercise_sessions_kind_values"
    t.check_constraint "progress_percent >= 0 AND progress_percent <= 100", name: "exercise_sessions_progress_percent_range"
    t.check_constraint "question_count > 0", name: "exercise_sessions_question_count_positive"
    t.check_constraint "score_percent >= 0 AND score_percent <= 100", name: "exercise_sessions_score_percent_range"
    t.check_constraint "status::text <> 'completed'::text OR score_percent IS NOT NULL", name: "exercise_sessions_completed_has_score"
    t.check_constraint "status::text = ANY (ARRAY['started'::character varying, 'completed'::character varying, 'abandoned'::character varying]::text[])", name: "exercise_sessions_status_values"
  end

  create_table "exercises", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "essential_id", null: false
    t.string "exercise_type", default: "fixation", null: false
    t.integer "position", null: false
    t.string "public_id", limit: 14, null: false
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "title", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_exercises_on_author_id"
    t.index ["essential_id", "position"], name: "index_exercises_on_essential_id_and_position", unique: true
    t.index ["essential_id", "status"], name: "index_exercises_on_essential_id_and_status"
    t.index ["public_id"], name: "index_exercises_on_public_id", unique: true
    t.index ["status"], name: "index_exercises_on_status"
    t.check_constraint "exercise_type::text = ANY (ARRAY['fixation'::character varying, 'evaluation'::character varying]::text[])", name: "exercises_exercise_type_values"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "exercises_status_values"
  end

  create_table "import_reports", force: :cascade do |t|
    t.string "checksum_sha256", limit: 64
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.integer "error_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "format_version"
    t.jsonb "import_errors", default: [], null: false
    t.bigint "imported_by_id", null: false
    t.integer "imported_count", default: 0, null: false
    t.string "kind", null: false
    t.integer "processed_count", default: 0, null: false
    t.string "public_id", limit: 14, null: false
    t.integer "skipped_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["imported_by_id"], name: "index_import_reports_on_imported_by_id"
    t.index ["kind", "created_at"], name: "index_import_reports_on_kind_and_created_at"
    t.index ["kind"], name: "index_import_reports_one_running_per_kind", unique: true, where: "((status)::text = ANY ((ARRAY['queued'::character varying, 'validating'::character varying, 'importing'::character varying])::text[]))"
    t.index ["public_id"], name: "index_import_reports_on_public_id", unique: true
    t.check_constraint "kind::text = 'classrooms'::text OR checksum_sha256 IS NOT NULL", name: "import_reports_checksum_unless_generation"
    t.check_constraint "kind::text = ANY (ARRAY['schools'::character varying, 'course_tree'::character varying, 'essentials'::character varying, 'exercises'::character varying, 'classrooms'::character varying]::text[])", name: "import_reports_kind_values"
    t.check_constraint "status::text <> 'completed'::text OR total_count = (imported_count + skipped_count + error_count)", name: "import_reports_completed_counts_add_up"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'validating'::character varying, 'importing'::character varying, 'completed'::character varying, 'rejected'::character varying, 'failed'::character varying]::text[])", name: "import_reports_status_values"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "accepted_user_id"
    t.string "contact", limit: 10, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id"
    t.string "kind", null: false
    t.string "position"
    t.datetime "revoked_at"
    t.bigint "school_id"
    t.string "team_role"
    t.string "token_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_user_id"], name: "index_invitations_on_accepted_user_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["kind", "contact"], name: "index_invitations_one_pending", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["school_id"], name: "index_invitations_on_school_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.check_constraint "\"position\"::text = ANY (ARRAY['principal'::character varying, 'censor'::character varying, 'educator'::character varying, 'secretary'::character varying]::text[])", name: "invitations_position_values"
    t.check_constraint "contact::text ~ '^0[157][0-9]{8}$'::text", name: "invitations_contact_format"
    t.check_constraint "kind::text <> 'school_staff'::text OR school_id IS NOT NULL", name: "invitations_staff_has_school"
    t.check_constraint "kind::text <> 'team'::text OR team_role IS NOT NULL", name: "invitations_team_has_role"
    t.check_constraint "kind::text = ANY (ARRAY['team'::character varying, 'school_staff'::character varying]::text[])", name: "invitations_kind_values"
    t.check_constraint "team_role::text = ANY (ARRAY['admin'::character varying, 'content'::character varying, 'field'::character varying]::text[])", name: "invitations_team_role_values"
  end

  create_table "knowledge_gaps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "essential_id", null: false
    t.integer "failed_sessions_count", default: 1, null: false
    t.string "public_id", limit: 14, null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_session_id"
    t.bigint "source_session_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["essential_id"], name: "index_knowledge_gaps_on_essential_id"
    t.index ["public_id"], name: "index_knowledge_gaps_on_public_id", unique: true
    t.index ["resolved_by_session_id"], name: "index_knowledge_gaps_on_resolved_by_session_id"
    t.index ["source_session_id"], name: "index_knowledge_gaps_on_source_session_id"
    t.index ["student_id", "essential_id"], name: "index_knowledge_gaps_one_pending", unique: true, where: "((status)::text = 'pending'::text)"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'remediated'::character varying, 'self_corrected'::character varying]::text[])", name: "knowledge_gaps_status_values"
  end

  create_table "level_series", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "level_id", null: false
    t.bigint "series_id", null: false
    t.index ["level_id", "series_id"], name: "index_level_series_on_level_id_and_series_id", unique: true
    t.index ["series_id"], name: "index_level_series_on_series_id"
  end

  create_table "levels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cycle", null: false
    t.string "name", limit: 20, null: false
    t.integer "position", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_levels_on_name", unique: true
    t.index ["position"], name: "index_levels_on_position", unique: true
    t.index ["slug"], name: "index_levels_on_slug", unique: true
    t.check_constraint "cycle::text = ANY (ARRAY['first'::character varying, 'second'::character varying]::text[])", name: "levels_cycle_values"
  end

  create_table "login_attempts", force: :cascade do |t|
    t.string "contact", limit: 20, null: false
    t.datetime "created_at", null: false
    t.string "ip_address", limit: 45
    t.string "kind", null: false
    t.boolean "succeeded", null: false
    t.bigint "user_id"
    t.index ["contact", "created_at"], name: "index_login_attempts_on_contact_and_created_at"
    t.index ["user_id"], name: "index_login_attempts_on_user_id"
    t.check_constraint "kind::text = ANY (ARRAY['pin'::character varying, 'second_factor'::character varying]::text[])", name: "login_attempts_kind_values"
  end

  create_table "materials", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 40, null: false
    t.string "shortname", limit: 10, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_materials_on_name", unique: true
    t.index ["shortname"], name: "index_materials_on_shortname", unique: true
    t.index ["slug"], name: "index_materials_on_slug", unique: true
    t.check_constraint "category::text = ANY (ARRAY['literature'::character varying, 'science'::character varying, 'other'::character varying]::text[])", name: "materials_category_values"
  end

  create_table "pin_recovery_codes", force: :cascade do |t|
    t.string "code_digest", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.bigint "issued_by_id", null: false
    t.datetime "revoked_at"
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["issued_by_id"], name: "index_pin_recovery_codes_on_issued_by_id"
    t.index ["user_id"], name: "index_pin_recovery_codes_one_active", unique: true, where: "((used_at IS NULL) AND (revoked_at IS NULL))"
  end

  create_table "question_attempts", force: :cascade do |t|
    t.datetime "answered_at", null: false
    t.boolean "correct", null: false
    t.bigint "exercise_session_id", null: false
    t.bigint "question_id", null: false
    t.bigint "selected_answer_ids", null: false, array: true
    t.index ["exercise_session_id", "question_id"], name: "index_question_attempts_on_exercise_session_id_and_question_id", unique: true
    t.index ["question_id"], name: "index_question_attempts_on_question_id"
    t.check_constraint "cardinality(selected_answer_ids) > 0", name: "question_attempts_selected_answer_ids_present"
  end

  create_table "questions", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.text "explanation"
    t.integer "position", null: false
    t.string "question_type", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_id", "position"], name: "index_questions_on_exercise_id_and_position", unique: true
    t.check_constraint "question_type::text = ANY (ARRAY['true_false'::character varying, 'single_choice'::character varying, 'multiple_correct_2'::character varying, 'multiple_correct_3'::character varying]::text[])", name: "questions_question_type_values"
  end

  create_table "referral_shares", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_referral_shares_on_created_at"
    t.index ["user_id", "created_at"], name: "index_referral_shares_on_user_id_and_created_at"
    t.check_constraint "channel::text = ANY (ARRAY['whatsapp'::character varying, 'sms'::character varying, 'copy'::character varying, 'native'::character varying]::text[])", name: "referral_shares_channel_values"
  end

  create_table "referrals", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "referee_id", null: false
    t.bigint "referrer_id", null: false
    t.bigint "school_id", null: false
    t.string "source", null: false
    t.index ["created_at"], name: "index_referrals_on_created_at"
    t.index ["referee_id"], name: "index_referrals_on_referee_id", unique: true
    t.index ["referrer_id"], name: "index_referrals_on_referrer_id"
    t.index ["school_id"], name: "index_referrals_on_school_id"
    t.check_constraint "referrer_id <> referee_id", name: "referrals_not_self"
    t.check_constraint "source::text = ANY (ARRAY['link'::character varying, 'sponsor'::character varying]::text[])", name: "referrals_source_values"
  end

  create_table "school_join_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "decided_by_id"
    t.string "decided_via"
    t.string "public_id", limit: 14, null: false
    t.bigint "school_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "teacher_id", null: false
    t.datetime "updated_at", null: false
    t.index ["decided_by_id"], name: "index_school_join_requests_on_decided_by_id"
    t.index ["public_id"], name: "index_school_join_requests_on_public_id", unique: true
    t.index ["school_id", "status"], name: "index_school_join_requests_on_school_id_and_status"
    t.index ["teacher_id"], name: "index_school_join_requests_on_teacher_id", unique: true
    t.check_constraint "(status::text = 'pending'::text) = (decided_at IS NULL)", name: "school_join_requests_decided_iff_not_pending"
    t.check_constraint "decided_via::text = ANY (ARRAY['team'::character varying, 'sponsor'::character varying]::text[])", name: "school_join_requests_decided_via_values"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])", name: "school_join_requests_status_values"
  end

  create_table "school_staffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "invited_by_id"
    t.bigint "school_id", null: false
    t.bigint "user_id", null: false
    t.index ["invited_by_id"], name: "index_school_staffs_on_invited_by_id"
    t.index ["school_id"], name: "index_school_staffs_on_school_id"
    t.index ["user_id"], name: "index_school_staffs_on_user_id", unique: true
  end

  create_table "schools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cycle", default: "both", null: false
    t.bigint "drena_id", null: false
    t.string "name", limit: 150, null: false
    t.string "national_code", limit: 6
    t.string "public_id", limit: 14, null: false
    t.string "school_code", limit: 6, null: false
    t.datetime "school_code_rotated_at"
    t.string "school_type", null: false
    t.string "sigle", limit: 20
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["drena_id", "name"], name: "index_schools_on_drena_id_and_name", unique: true
    t.index ["drena_id"], name: "index_schools_on_drena_id"
    t.index ["national_code"], name: "index_schools_on_national_code", unique: true, where: "(national_code IS NOT NULL)"
    t.index ["public_id"], name: "index_schools_on_public_id", unique: true
    t.index ["school_code"], name: "index_schools_on_school_code", unique: true
    t.check_constraint "cycle::text = ANY (ARRAY['first'::character varying, 'both'::character varying]::text[])", name: "schools_cycle_values"
    t.check_constraint "national_code::text ~ '^[0-9]{6}$'::text", name: "schools_national_code_format"
    t.check_constraint "school_code::text ~ '^[a-hj-np-z2-9]{6}$'::text", name: "schools_school_code_format"
    t.check_constraint "school_type::text = ANY (ARRAY['public'::character varying, 'private'::character varying, 'mixed'::character varying]::text[])", name: "schools_school_type_values"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'inactive'::character varying]::text[])", name: "schools_status_values"
  end

  create_table "series", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 10, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_series_on_name", unique: true
    t.index ["slug"], name: "index_series_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", limit: 45
    t.datetime "last_seen_at", null: false
    t.datetime "second_factor_verified_at"
    t.string "token_digest", limit: 64, null: false
    t.string "user_agent", limit: 255
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "teacher_classrooms", force: :cascade do |t|
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.bigint "teacher_id", null: false
    t.index ["classroom_id"], name: "index_teacher_classrooms_on_classroom_id"
    t.index ["teacher_id", "classroom_id"], name: "index_teacher_classrooms_on_teacher_id_and_classroom_id", unique: true
  end

  create_table "teacher_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "material_id", null: false
    t.datetime "onboarding_completed_at"
    t.string "referral_token", limit: 12, default: -> { "substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 12)" }, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["material_id"], name: "index_teacher_profiles_on_material_id"
    t.index ["referral_token"], name: "index_teacher_profiles_on_referral_token", unique: true
    t.index ["user_id"], name: "index_teacher_profiles_on_user_id", unique: true
    t.check_constraint "referral_token::text ~ '^[0-9a-f]{12}$'::text", name: "teacher_profiles_referral_token_format"
  end

  create_table "teacher_schools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "primary", default: false, null: false
    t.bigint "school_id", null: false
    t.bigint "teacher_id", null: false
    t.index ["school_id"], name: "index_teacher_schools_on_school_id"
    t.index ["teacher_id", "school_id"], name: "index_teacher_schools_on_teacher_id_and_school_id", unique: true
    t.index ["teacher_id"], name: "index_teacher_schools_one_primary", unique: true, where: "\"primary\""
  end

  create_table "totp_credentials", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.bigint "last_used_step"
    t.text "secret", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_totp_credentials_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "anonymized_at"
    t.string "contact", limit: 10
    t.datetime "created_at", null: false
    t.string "first_name", limit: 80, null: false
    t.string "gender", null: false
    t.string "last_name", limit: 50, null: false
    t.string "pin_digest", null: false
    t.string "public_id", limit: 14, null: false
    t.string "role", null: false
    t.string "team_role"
    t.datetime "updated_at", null: false
    t.index ["contact"], name: "index_users_on_contact", unique: true, where: "(contact IS NOT NULL)"
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.check_constraint "(role::text = 'team'::text) = (team_role IS NOT NULL)", name: "users_team_role_iff_team"
    t.check_constraint "contact::text ~ '^0[157][0-9]{8}$'::text", name: "users_contact_format"
    t.check_constraint "gender::text = ANY (ARRAY['male'::character varying, 'female'::character varying]::text[])", name: "users_gender_values"
    t.check_constraint "role::text = ANY (ARRAY['student'::character varying, 'teacher'::character varying, 'school_admin'::character varying, 'team'::character varying]::text[])", name: "users_role_values"
    t.check_constraint "team_role::text = ANY (ARRAY['admin'::character varying, 'content'::character varying, 'field'::character varying]::text[])", name: "users_team_role_values"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "answers", "questions", on_delete: :restrict
  add_foreign_key "audit_events", "users", column: "actor_id", on_delete: :restrict
  add_foreign_key "backup_codes", "users", on_delete: :cascade
  add_foreign_key "classroom_assignments", "classrooms", on_delete: :restrict
  add_foreign_key "classroom_assignments", "users", column: "archived_by_id", on_delete: :restrict
  add_foreign_key "classroom_assignments", "users", column: "assigned_by_id", on_delete: :restrict
  add_foreign_key "classroom_plan_entries", "levels", on_delete: :restrict
  add_foreign_key "classroom_plan_entries", "series", on_delete: :restrict
  add_foreign_key "classroom_students", "classrooms", on_delete: :restrict
  add_foreign_key "classroom_students", "users", column: "student_id", on_delete: :restrict
  add_foreign_key "classrooms", "levels", on_delete: :restrict
  add_foreign_key "classrooms", "schools", on_delete: :restrict
  add_foreign_key "classrooms", "series", on_delete: :restrict
  add_foreign_key "courses", "levels", on_delete: :restrict
  add_foreign_key "courses", "materials", on_delete: :restrict
  add_foreign_key "courses", "series", on_delete: :restrict
  add_foreign_key "courses", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "essentials", "courses", on_delete: :restrict
  add_foreign_key "essentials", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "exercise_badges", "exercise_sessions", on_delete: :restrict
  add_foreign_key "exercise_badges", "exercises", on_delete: :restrict
  add_foreign_key "exercise_badges", "users", column: "student_id", on_delete: :restrict
  add_foreign_key "exercise_sessions", "classroom_assignments", on_delete: :restrict
  add_foreign_key "exercise_sessions", "exercises", on_delete: :restrict
  add_foreign_key "exercise_sessions", "knowledge_gaps", on_delete: :restrict
  add_foreign_key "exercise_sessions", "users", column: "student_id", on_delete: :restrict
  add_foreign_key "exercises", "essentials", on_delete: :restrict
  add_foreign_key "exercises", "users", column: "author_id", on_delete: :restrict
  add_foreign_key "import_reports", "users", column: "imported_by_id", on_delete: :restrict
  add_foreign_key "invitations", "schools", on_delete: :restrict
  add_foreign_key "invitations", "users", column: "accepted_user_id", on_delete: :restrict
  add_foreign_key "invitations", "users", column: "invited_by_id", on_delete: :restrict
  add_foreign_key "knowledge_gaps", "essentials", on_delete: :restrict
  add_foreign_key "knowledge_gaps", "exercise_sessions", column: "resolved_by_session_id", on_delete: :restrict
  add_foreign_key "knowledge_gaps", "exercise_sessions", column: "source_session_id", on_delete: :restrict
  add_foreign_key "knowledge_gaps", "users", column: "student_id", on_delete: :restrict
  add_foreign_key "level_series", "levels", on_delete: :restrict
  add_foreign_key "level_series", "series", on_delete: :restrict
  add_foreign_key "login_attempts", "users", on_delete: :cascade
  add_foreign_key "pin_recovery_codes", "users", column: "issued_by_id", on_delete: :restrict
  add_foreign_key "pin_recovery_codes", "users", on_delete: :cascade
  add_foreign_key "question_attempts", "exercise_sessions", on_delete: :restrict
  add_foreign_key "question_attempts", "questions", on_delete: :restrict
  add_foreign_key "questions", "exercises", on_delete: :restrict
  add_foreign_key "referral_shares", "users", on_delete: :restrict
  add_foreign_key "referrals", "schools", on_delete: :restrict
  add_foreign_key "referrals", "users", column: "referee_id", on_delete: :restrict
  add_foreign_key "referrals", "users", column: "referrer_id", on_delete: :restrict
  add_foreign_key "school_join_requests", "schools", on_delete: :restrict
  add_foreign_key "school_join_requests", "users", column: "decided_by_id", on_delete: :restrict
  add_foreign_key "school_join_requests", "users", column: "teacher_id", on_delete: :restrict
  add_foreign_key "school_staffs", "schools", on_delete: :restrict
  add_foreign_key "school_staffs", "users", column: "invited_by_id", on_delete: :restrict
  add_foreign_key "school_staffs", "users", on_delete: :restrict
  add_foreign_key "schools", "drenas", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "teacher_classrooms", "classrooms", on_delete: :restrict
  add_foreign_key "teacher_classrooms", "users", column: "teacher_id", on_delete: :restrict
  add_foreign_key "teacher_profiles", "materials", on_delete: :restrict
  add_foreign_key "teacher_profiles", "users", on_delete: :restrict
  add_foreign_key "teacher_schools", "schools", on_delete: :restrict
  add_foreign_key "teacher_schools", "users", column: "teacher_id", on_delete: :restrict
  add_foreign_key "totp_credentials", "users", on_delete: :cascade
end
