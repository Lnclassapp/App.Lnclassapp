require "test_helper"

# Chantier tester-pr-en-local: db/seeds/demo/trois_etablissements.rb gives the owner three test schools to simulate on
# his machine (bin/tester-pr --demo). Played here in the transaction of the test, after the referential.
class DemoSchoolsTest < ActiveSupport::TestCase
  FILE = Rails.root.join("db/seeds/demo/trois_etablissements.rb").to_s
  LEVELS = %w[6eme 5eme 4eme 3eme 2nde 1ere tle].freeze

  def play
    Rails.application.reload_routes_unless_loaded
    capture_io { load Rails.root.join("db/seeds.rb").to_s, true }
    Rails.env = "development"
    capture_io { load FILE, true }.first
  ensure
    Rails.env = "test"
  end

  def schools = Orm::School.where("name LIKE ?", "Test — %").order(:name)

  test "it refuses to run outside development" do
    error = assert_raises(RuntimeError) { load FILE, true }

    assert_match "réservé au développement", error.message
  end

  test "three schools, three classes per level from 6ème to Tle, 35 to 45 students each, one head each" do
    output = play

    assert_equal 3, schools.count
    schools.each do |school|
      classrooms = Orm::Classroom.where(school:).includes(:level)
      assert_equal LEVELS.to_h { [ it, 3 ] }, classrooms.group_by { it.level.slug }.transform_values(&:size), school.name
      classrooms.each do |classroom|
        students = Orm::ClassroomStudent.where(classroom:, primary: true, left_at: nil)
        assert_includes 35..45, students.count, "#{school.name} · #{classroom.name}"
      end
      assert_equal 1, Orm::SchoolStaff.where(school:, position: "head").count
    end
    assert_includes output, "PIN 2468"
  end

  test "every classroom has six distinct teachers, one per subject: EDHC in the first cycle, philosophy in the second" do
    play
    common = %w[mathematiques physique-chimie svt francais histoire-geographie]
    first_cycle = %w[6eme 5eme 4eme 3eme]

    Orm::Classroom.where(school: schools).includes(:level).find_each do |classroom|
      teacher_ids = Orm::TeacherClassroom.where(classroom:).pluck(:teacher_id)
      # Each teacher's subject in this classroom: the one of their subjects in the school that the level takes.
      expected = common + [ first_cycle.include?(classroom.level.slug) ? "edhc" : "philosophie" ]
      slugs = Orm::TeacherSchoolMaterial.joins(:material).where(teacher_id: teacher_ids, school_id: classroom.school_id)
                                       .pluck("materials.slug").uniq & expected

      assert_equal 6, teacher_ids.uniq.size, classroom.name
      assert_equal expected.sort, slugs.sort, classroom.name
      teacher_ids.each { assert Orm::TeacherSchool.exists?(teacher_id: it, school_id: classroom.school_id) }
    end
    taught = Orm::TeacherClassroom.joins(classroom: :level).where(classrooms: { school_id: schools.select(:id) })
    levels_of = ->(slug) { taught.where(teacher_id: Orm::TeacherSchoolMaterial.joins(:material).where(materials: { slug: }).select(:teacher_id)).distinct.pluck("levels.slug").sort }
    assert_equal first_cycle.sort, levels_of.("edhc"), "l'EDHC au collège seulement"
    assert_equal %w[1ere 2nde tle], levels_of.("philosophie"), "la philosophie au lycée seulement"
    assert_equal "EDHC", Orm::Material.find_by!(slug: "edhc").name
  end

  test "some teachers have several subjects, others several schools, one of them three" do
    play

    teachers = Orm::TeacherSchool.where(school: schools)
    by_schools = teachers.group(:teacher_id).count
    by_subjects = Orm::TeacherSchoolMaterial.where(school: schools).group(:teacher_id, :school_id).count

    assert_operator by_subjects.count { |_, count| count >= 2 }, :>=, 6, "au moins 2 enseignants bivalents par établissement"
    assert_operator by_schools.count { |_, count| count >= 2 }, :>=, 2
    assert_includes by_schools.values, 3
    assert_equal by_schools.size, teachers.where(primary: true).count, "un établissement principal chacun"
  end

  test "the accounts it prints sign in with PIN 2468, with their role, school and classroom" do
    play
    first_school = schools.find_by!(name: "Test — Lycée Moderne Les Cocotiers")
    first_classroom = Orm::Classroom.where(school: first_school).order(:id).first
    signs_in = ->(contact, role) { Orm::User.find_by!(contact:).tap { assert_equal role, it.role, contact; assert it.authenticate_pin("2468"), contact } }

    head = signs_in.("0731000001", "school_admin")
    assert_equal first_school.id, Orm::SchoolStaff.find_by!(user: head).school_id
    teacher = signs_in.("0531000001", "teacher")
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id, school_id: first_school.id, primary: true)
    assert Orm::TeacherProfile.find_by!(user: teacher).onboarding_completed_at, "parcours d'arrivée terminé"
    student = signs_in.("0131000101", "student")
    assert_equal [ first_classroom.id, "6ème 1" ], [ Orm::ClassroomStudent.find_by!(student_id: student.id).classroom_id, first_classroom.name ]
    assert_equal [ Entities::Classroom::SchoolYear.current(Date.current) ], Orm::Classroom.where(school: schools).distinct.pluck(:school_year)
  end

  test "a school already there without the two others is refused, rather than completed" do
    play
    schools.where.not(name: "Test — Collège Le Baobab").each { |school| Orm::School.where(id: school.id).update_all(name: "Ailleurs #{school.id}") }

    error = assert_raises(RuntimeError) { play }
    assert_match "partiellement présents", error.message
  end

  test "played twice, it creates nothing more" do
    play
    counts = [ Orm::User.count, Orm::Classroom.count, Orm::TeacherClassroom.count, Orm::ClassroomStudent.count ]
    play

    assert_equal counts, [ Orm::User.count, Orm::Classroom.count, Orm::TeacherClassroom.count, Orm::ClassroomStudent.count ]
  end
end
