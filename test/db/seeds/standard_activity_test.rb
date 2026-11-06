require "test_helper"

# ADR standard-de-test §4 point 2 et « Tranché » 6 : un trimestre d'activité déterministe, joué par les use cases à une
# horloge simulée. Ici, sur une activité réduite (STANDARD_ACTIVITY_SIZE=reduite : 3 semaines, 2 classes par établissement,
# 3 élèves par classe) : l'empreinte des totaux vaut une valeur attendue, la même à deux dates de chargement ; rejoué, le
# jeu ne double rien ; l'élève sans activité et la classe vide restent à zéro ; le trimestre se termine la veille.
# La valeur attendue change à chaque évolution légitime d'un calcul (notes, lacunes, badges, devoirs) : on la met à jour sciemment.
class StandardActivityTest < ActiveSupport::TestCase
  EXPECTED_FINGERPRINT = "8645917579".freeze
  # 27 leçons : toute la 1ère et la 3ème du manifeste, de quoi activer des classes du lycée et du collège.
  LESSONS = 27
  SEEDS = Rails.root.join("db/seeds")
  KEYS = %w[STANDARD_LESSONS_LIMIT STANDARD_ACTIVITY_SIZE STANDARD_QUIET].freeze

  setup do
    @set = Entities::Catalog::StandardTestSet.new(YAML.load_file(SEEDS.join("standard/jeu.yml")))
    @identity = Entities::School::FictitiousIdentity.new(YAML.load_file(SEEDS.join("standard/noms.yml")))
    %w[catalog school].each { load SEEDS.join("#{it}.rb").to_s, true }
    @previous = ENV.values_at(*KEYS)
    ENV.update("STANDARD_LESSONS_LIMIT" => LESSONS.to_s, "STANDARD_ACTIVITY_SIZE" => "reduite", "STANDARD_QUIET" => "1")
    capture_io { load SEEDS.join("standard.rb").to_s, true }
  end

  teardown { KEYS.zip(@previous) { |key, value| ENV[key] = value } }

  def play_activity
    out, = capture_io { load SEEDS.join("standard/activite.rb").to_s, true }
    out[/empreinte des totaux : (\h+)/, 1]
  end

  # Le jeu chargé à un instant donné, puis effacé : on compare les empreintes sans que l'une pollue l'autre.
  def fingerprint_at(time)
    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      travel_to(time) { result = play_activity }
      raise ActiveRecord::Rollback
    end
    result
  end

  def schools = Orm::School.where(name: @set.schools.map { @identity.school_name(it.key) })
  def students_of_standard = Orm::ClassroomStudent.where(classroom_id: Orm::Classroom.where(school: schools)).select(:student_id)
  def sessions = Orm::ExerciseSession.where(student_id: students_of_standard)
  def totals = [ sessions.count, sessions.where(status: "completed").sum(:score_percent), Orm::ClassroomAssignment.count, Orm::KnowledgeGap.count,
                 Orm::ExerciseBadge.count, Orm::Message.count ]

  test "the fingerprint is the expected one, the same on every date once the window is full, and it depends on the weeks before" do
    # Mardi, samedi et jeudi de septembre (3 semaines depuis la rentrée) : la fenêtre pleine glisse, ses chiffres ne bougent pas.
    tuesday = fingerprint_at(Time.zone.local(2026, 11, 3, 10))
    saturday = fingerprint_at(Time.zone.local(2026, 12, 12, 15))
    thursday = fingerprint_at(Time.zone.local(2026, 9, 24, 9))

    assert_equal [ tuesday, tuesday ], [ saturday, thursday ]
    assert_equal EXPECTED_FINGERPRINT, tuesday
    # Fenêtre raccourcie par la rentrée (2 semaines) : l'empreinte dépend alors du nombre de semaines, que la commande affiche.
    assert_not_equal tuesday, fingerprint_at(Time.zone.local(2026, 9, 15, 9))
  end

  test "a second pass duplicates nothing, nothing starts before the rentree, arrivals are dated, the idle student and the empty class stay at zero" do
    rentree = Time.zone.local(2026, 9, 1)
    travel_to(Time.zone.local(2026, 9, 15, 10)) do
      out, = capture_io { load SEEDS.join("standard/activite.rb").to_s, true }
      first = out[/empreinte des totaux : (\h+)/, 1]
      assert_match "(2 semaines", out, "la fenêtre raccourcie par la rentrée est annoncée"
      before = totals
      assert_operator before.first, :>, 0, "l'activité réduite doit produire des séances"

      assert_equal first, play_activity
      assert_equal before, totals

      last = [ sessions.maximum(:completed_at), Orm::ClassroomAssignment.maximum(:assigned_at) ].max
      assert_equal Date.new(2026, 9, 14), last.to_date, "le trimestre se termine la veille du chargement"
      assert_operator Orm::ClassroomAssignment.minimum(:assigned_at), :>=, rentree, "jamais avant la rentrée"
      assert_operator sessions.minimum(:started_at), :>=, rentree, "jamais avant la rentrée"
      assert_operator Orm::ClassroomAssignment.maximum(:due_on), :>, Date.new(2026, 9, 15), "des devoirs à venir"

      classrooms = Orm::Classroom.where(school: schools)
      memberships = Orm::ClassroomStudent.where(classroom: classrooms)
      recent = memberships.where("joined_at > ?", rentree)
      assert_includes 6..9, recent.count, "2 ou 3 élèves récents par établissement, pas toute la population"
      assert memberships.pluck(:joined_at).all? { it >= rentree - 5.days }, "les autres sont arrivés à la rentrée moins 2 à 5 jours"
      assert_equal 0, Orm::ExerciseSession.where(student_id: recent.select(:student_id)).count, "un élève récent n'a pas encore travaillé"
      assert Orm::TeacherSchool.where(school: schools).all? { it.created_at < rentree }, "les enseignants arrivent avant la rentrée"
      assert Orm::TeacherClassroom.where(classroom: classrooms).all? { it.created_at < rentree }

      idle = Orm::User.find_by!(contact: contact_of_first_student(@set.cases.student_without_activity))
      assert_equal 0, Orm::ExerciseSession.where(student: idle).count
      assert_equal 0, Orm::ClassroomAssignment.where(classroom_id: classroom_of(@set.cases.student_without_activity)).count

      empty = classroom_of(@set.cases.empty_classroom)
      assert_equal 0, Orm::ClassroomStudent.where(classroom_id: empty).count
      assert_equal 0, Orm::ClassroomAssignment.where(classroom_id: empty).count
    end
  end

  private

  def classroom_of(reference)
    school_key, key = reference.split("/")
    spec = @set.classrooms.find { it.school == school_key && it.key == key }
    Orm::Classroom.find_by!(school: Orm::School.find_by!(name: @identity.school_name(school_key)), level: Orm::Level.find_by!(slug: spec.level),
                            series: spec.series && Orm::Series.find_by!(slug: spec.series)).id
  end

  def contact_of_first_student(reference)
    Orm::ClassroomStudent.where(classroom_id: classroom_of(reference)).joins(:student).order("users.contact").first.student.contact
  end
end
