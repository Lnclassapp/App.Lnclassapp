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

  test "every classroom has six distinct teachers, one per subject, each declared in its school with that subject" do
    play

    Orm::Classroom.where(school: schools).find_each do |classroom|
      teacher_ids = Orm::TeacherClassroom.where(classroom:).pluck(:teacher_id)
      materials = Orm::TeacherSchoolMaterial.where(teacher_id: teacher_ids, school_id: classroom.school_id).pluck(:material_id)

      assert_equal 6, teacher_ids.uniq.size, classroom.name
      assert_equal Orm::Material.count, materials.uniq.size, "#{classroom.name} : les 6 matières"
      teacher_ids.each { assert Orm::TeacherSchool.exists?(teacher_id: it, school_id: classroom.school_id) }
    end
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

  test "played twice, it creates nothing more" do
    play
    counts = [ Orm::User.count, Orm::Classroom.count, Orm::TeacherClassroom.count, Orm::ClassroomStudent.count ]
    play

    assert_equal counts, [ Orm::User.count, Orm::Classroom.count, Orm::TeacherClassroom.count, Orm::ClassroomStudent.count ]
  end
end
