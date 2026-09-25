require "test_helper"

# Every Orm:: model maps its table as-is (ADR-0027, ADR-0036). One graph through all
# the V1 tables proves the associations; the repositories (Lot 0.5) cover the rest.
class Orm::ModelsTest < ActiveSupport::TestCase
  MODELS = Dir[Rails.root.join("app/infrastructure/orm/*.rb")].map { |file| "Orm::#{File.basename(file, '.rb').camelize}".constantize }
                                                               .select { |model| model < ApplicationRecord }

  # Tables whose rows are student production: no association may destroy them (ADR-0036).
  STUDENT_PRODUCTION = %w[exercise_sessions question_attempts exercise_badges knowledge_gaps
                          classroom_students classroom_assignments].freeze

  def user(role, contact, **attributes)
    Orm::User.create!(last_name: "Koné", first_name: "Awa", contact:, gender: "female", role:, pin: "1234", **attributes)
  end

  def graph
    @graph ||= begin
      team = user("team", "0700000001", team_role: "admin")
      teacher = user("teacher", "0500000001")
      student = user("student", "0100000001")
      material = Orm::Material.create!(name: "Mathématiques", shortname: "Maths", category: "science")
      level = Orm::Level.create!(name: "Tle", position: 7, cycle: "second")
      series = Orm::Series.create!(name: "D")
      Orm::LevelSeries.create!(level:, series:)
      school = Orm::School.create!(drena: Orm::Drena.create!(name: "Abidjan 1"), name: "Lycée Classique", school_type: "mixed")
      classroom = Orm::Classroom.create!(school:, level:, series:, name: "Tle D 1", school_year: "2026-2027", join_code: "abc23")
      course = Orm::Course.create!(name: "Nombres complexes", level:, series:, material:, author: team)
      essential = Orm::Essential.create!(course:, name: "Forme algébrique", position: 1, author: team)
      exercise = Orm::Exercise.create!(essential:, title: "Calculer un module", position: 1, author: team)
      question = Orm::Question.create!(exercise:, position: 1, content: "Vrai ou faux ?", question_type: "true_false")
      answers = [ [ 2, "Faux", false ], [ 1, "Vrai", true ] ].map { |position, content, correct| Orm::Answer.create!(question:, position:, content:, correct:) }
      assignment = Orm::ClassroomAssignment.create!(classroom:, assignable_type: "Exercise", assignable_id: exercise.id,
                                                    assigned_by: teacher, assigned_at: Time.current)
      session = Orm::ExerciseSession.create!(student:, exercise:, question_count: 1, started_at: Time.current, classroom_assignment: assignment)

      { team:, teacher:, student:, material:, level:, series:, school:, classroom:, course:, essential:, exercise:,
        question:, answers:, assignment:, session: }
    end
  end

  test "every V1 table has its Orm model with an explicit table name" do
    assert_equal 30, MODELS.size
    MODELS.each { |model| assert model.table_name.present? && model.table_exists?, model.name }
  end

  test "every association resolves to an Orm model and states its class name" do
    MODELS.each do |model|
      model.reflect_on_all_associations.reject { |reflection| reflection.name.to_s.end_with?("_attachment", "_blob") }.each do |reflection|
        assert reflection.options[:class_name].to_s.start_with?("Orm::"), "#{model.name}##{reflection.name}"
        assert reflection.klass < ApplicationRecord, "#{model.name}##{reflection.name}"
      end
    end
  end

  test "no association destroys the production of students" do
    MODELS.flat_map(&:reflect_on_all_associations).select { |reflection| reflection.klass.table_name.in?(STUDENT_PRODUCTION) }.each do |reflection|
      assert_not_includes %i[destroy delete_all destroy_async], reflection.options[:dependent], "#{reflection.active_record.name}##{reflection.name}"
    end
  end

  test "a parent with dependent rows refuses its own deletion" do
    exercise = graph[:exercise]

    assert_not exercise.destroy
    assert exercise.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
  end

  test "the whole pedagogical loop is navigable through the associations" do
    graph => { team:, teacher:, student:, level:, series:, school:, classroom:, course:, essential:, exercise:, question:, session: }
    Orm::TeacherProfile.create!(user: teacher, material: graph[:material])
    Orm::TeacherSchool.create!(teacher:, school:, primary: true)
    Orm::TeacherClassroom.create!(teacher:, classroom:)
    Orm::ClassroomStudent.create!(classroom:, student:, primary: true, joined_at: Time.current)
    gap = Orm::KnowledgeGap.create!(student:, essential:, source_session: session)
    Orm::ExerciseBadge.create!(student:, exercise:, exercise_session: session, level: "bronze", awarded_at: Time.current)

    assert_equal [ series ], level.series.to_a
    assert_equal [ level ], series.levels.to_a
    assert_equal course, essential.course
    assert_equal [ "Vrai", "Faux" ], exercise.questions.first.answers.map(&:content)
    assert_equal graph[:assignment], session.classroom_assignment
    assert_equal gap.public_id, gap.to_param
    assert_equal teacher.teacher_profile.material, graph[:material]
    assert_equal [ teacher ], school.teacher_schools.map(&:teacher)
    assert_equal [ student ], classroom.classroom_students.map(&:student)
    assert_equal [ teacher ], classroom.teacher_classrooms.map(&:teacher)
    assert_equal team, course.author
    assert_equal question, question.answers.first.question
  end

  test "a question attempt is immutable once recorded" do
    attempt = Orm::QuestionAttempt.create!(exercise_session: graph[:session], question: graph[:question],
                                           selected_answer_ids: [ graph[:answers].last.id ], correct: true, answered_at: Time.current)

    assert_equal [ graph[:answers].last.id ], attempt.reload.selected_answer_ids
    assert_raises(ActiveRecord::ReadOnlyRecord) { attempt.update!(correct: false) }
  end

  test "an audit event is append-only" do
    event = Orm::AuditEvent.create!(actor: graph[:team], action: "school.changed", subject_type: "School",
                                    subject_id: graph[:school].id, metadata: { "field" => "name" })

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "login.locked") }
  end

  test "the TOTP secret is encrypted at rest" do
    credential = Orm::TotpCredential.create!(user: graph[:team], secret: "JBSWY3DPEHPK3PXP")

    assert_equal "JBSWY3DPEHPK3PXP", credential.reload.secret
    assert_not_includes Orm::TotpCredential.connection.select_value("SELECT secret FROM totp_credentials"), "JBSWY3DPEHPK3PXP"
    assert_equal credential, graph[:team].totp_credential
  end

  test "identity technical rows belong to their account" do
    team = graph[:team]
    Orm::Session.create!(user: team, token_digest: "a" * 64, created_at: Time.current, last_seen_at: Time.current)
    Orm::LoginAttempt.create!(contact: "0700000001", user: team, succeeded: true, kind: "pin")
    Orm::BackupCode.create!(user: team, code_digest: "b" * 64)
    recovery = Orm::PinRecoveryCode.create!(user: graph[:student], issued_by: graph[:teacher], code_digest: "c" * 64,
                                            expires_at: 15.minutes.from_now)
    invitation = Orm::Invitation.create!(kind: "school_staff", contact: "0700000009", school: graph[:school], position: "principal",
                                         invited_by: team, token_digest: "d" * 64, expires_at: 72.hours.from_now)

    assert_equal 1, team.sessions.count
    assert_equal graph[:teacher], recovery.issued_by
    assert_equal graph[:school], invitation.school
  end

  test "an import report keeps its source file on Active Storage" do
    report = Orm::ImportReport.create!(kind: "schools", checksum_sha256: "e" * 64,
                                       imported_by: graph[:team])
    report.source.attach(io: StringIO.new("{}"), filename: "ecoles.json", content_type: "application/json")

    assert report.reload.source.attached?
    assert_equal({ "status" => "queued", "import_errors" => [] }, report.attributes.slice("status", "import_errors"))
  end
end
