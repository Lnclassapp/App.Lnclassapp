require "test_helper"
require "rake"

# Chantier acquisition-classes, lot A : `bin/rails entonnoir:classes`, l'entonnoir des classes en lecture seule, comptes uniquement
# (PRD §6, les 9 scénarios).
class EntonnoirClassesTaskTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 16, 12)

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("entonnoir:classes")
    # La base de test porte les établissements et classes du jeu de référence : retirés dans la transaction du test.
    Orm::Classroom.delete_all
    Orm::School.delete_all
    travel_to NOW
  end

  def classes
    task = Rake::Task["entonnoir:classes"]
    task.reenable
    capture_io { task.invoke }.first
  end

  def table_counts = %w[users classrooms classroom_students crm_accounts].map { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{it}") }
  def anonymize(user) = user.update_columns(anonymized_at: Time.current)
  def ticked_by(teacher) = Orm::TeacherClassroom.find_by!(teacher:).classroom

  def classroom_with(count, sessions: 0)
    create_classroom.tap do |classroom|
      students = Array.new(count) { create_student(classroom:) }
      students.first(sessions).each { create_exercise_session(student: it) }
    end
  end

  test "l'entonnoir compte chaque étage : E1 3, E2 2, E3 2, E4 1, E5 0, E6 1, bloqués 1" do
    create_teacher(school: create_school)
    create_teacher(classrooms: [ classroom_with(0) ])
    create_teacher(classrooms: [ classroom_with(5, sessions: 5) ])

    out = classes

    assert_includes out, "lecture seule"
    assert_match(/^total +3 +2 +2 +1 +0 +1 +1$/, out)
    assert_match(/^ +standard +3 +2 +2 +1 +0 +1 +1$/, out)
    assert_match(/^ +équipe +0 +0 +0 +0 +0 +0 +0$/, out)
    assert_match(/^2026-11 +3 +2 +2 +1 +0 +1 +1$/, out)
  end

  test "une classe de l'année passée ne compte pas : inscrit, pas coché" do
    school = create_school
    create_teacher(school:, classrooms: [ create_classroom(school:, school_year: "2025-2026") ])

    assert_match(/^total +1 +0 +0 +0 +0 +0 +1$/, classes)
  end

  test "les comptes anonymisés sont exclus" do
    classroom = create_classroom
    gone = create_teacher(classrooms: [ classroom ])
    ghost = create_student(classroom:)
    anonymize(gone)
    anonymize(ghost)

    out = classes

    assert_includes out, "Aucun enseignant inscrit."
    assert_match(/^avec enseignant : aucun élève$/, out)
    assert_match(/^sans enseignant : aucun élève$/, out)
  end

  test "l'indice sépare les classes vides avec ou sans devoir" do
    with_assignment = create_teacher(classrooms: [ classroom_with(0) ])
    create_assignment(by: with_assignment, classroom: ticked_by(with_assignment))
    create_teacher(classrooms: [ classroom_with(0) ])

    assert_includes classes, "classe vide avec devoir : 1 · sans devoir : 1"
  end

  test "les élèves sont répartis selon que leur classe a un enseignant" do
    create_student(classroom: create_classroom, joined_via: "standard")
    ticked = create_classroom
    create_teacher(classrooms: [ ticked ])
    create_student(classroom: ticked, joined_via: "code")

    out = classes

    assert_includes out, "sans enseignant : standard 1"
    assert_includes out, "avec enseignant : code 1"
    assert_includes out, "Médiane d'élèves par classe cochée et peuplée : 1,0"
  end

  test "les écoles du CRM sont croisées avec l'usage réel" do
    school = create_school
    Orm::CrmAccount.create!(school:, stage: "demo_done", stage_changed_at: Time.current)
    Orm::CrmInteraction.create!(school:, author: create_user(role: "team"), kind: "call", occurred_at: 2.days.ago, outcome: "positive")
    create_teacher(school:)
    create_school

    out = classes

    assert_match(/^démo faite +1 +1 +1 +0 +0$/, out)
    assert_match(/^prospect +1 +0 +0 +0 +0$/, out)
    assert_match(/^perdu +0 +0 +0 +0 +0$/, out)
    assert_includes out, "Échanges notés sur 30 jours : 1"
  end

  test "le goulot est désigné selon la règle : trois enseignants et deux écoles jointes, goulot 4" do
    3.times { create_teacher(classrooms: [ classroom_with(0) ]) }
    2.times { |i| Orm::CrmInteraction.create!(school: create_school, author: create_user(role: "team", contact: format("07%08d", i)), kind: "call", occurred_at: 1.day.ago, outcome: "neutral") }

    out = classes

    assert_includes out, "Goulot désigné : 4 (les établissements ne sont pas encore joints)"
    assert_includes out, "Limites"
    assert_includes out, "le partage d'un code n'est pas enregistré"
  end

  test "un entonnoir sain n'a aucun goulot" do
    10.times { create_teacher(classrooms: [ classroom_with(12, sessions: 5) ]) }

    assert_includes classes, "Goulot désigné : aucun (aucun seuil franchi)"
  end

  test "comptes seulement : ni nom, ni numéro, ni identifiant public" do
    classroom = create_classroom
    teacher = create_teacher(classrooms: [ classroom ], first_name: "Aïcha", last_name: "Traoré")
    student = create_student(classroom:, first_name: "Yao", last_name: "N'Guessan")
    create_assignment(by: teacher, classroom:)

    out = classes

    [ "Aïcha", "Traoré", "Yao", "N'Guessan", teacher.contact, student.contact, teacher.public_id, student.public_id, classroom.public_id,
      classroom.school.public_id, classroom.school.name, classroom.join_code, classroom.link_token ].each { assert_not_includes out, it }
  end

  test "lecture seule : une écriture dans la transaction est refusée, rien ne change" do
    create_teacher(classrooms: [ classroom_with(1) ])
    before = table_counts
    writer = ->(**) { Orm::User.update_all(first_name: "Écrit") }

    error = stub_any_instance(Queries::Classroom::ClassAdoptionQuery, :call, writer) { assert_raises(ActiveRecord::StatementInvalid) { classes } }

    assert_match(/read-only transaction/, error.message)
    assert_equal before, table_counts
  end

  test "base vide : une ligne, puis le CRM et le goulot 4" do
    out = classes

    assert_includes out, "Aucun enseignant inscrit."
    assert_includes out, "Goulot désigné : 4"
    assert_match(/^prospect +0 +0 +0 +0 +0$/, out)
    assert_includes out, "aucune classe peuplée"
  end
end
