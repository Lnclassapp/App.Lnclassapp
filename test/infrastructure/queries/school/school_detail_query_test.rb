require "test_helper"

module Queries
  module School
    class SchoolDetailQueryTest < ActiveSupport::TestCase
      YEAR = "2026-2027".freeze

      setup do
        @drena = create_drena(name: "Abidjan 1")
        @school = create_school(drena: @drena, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "public",
                                cycle: "both", status: "active")
        @sixth = create_level(name: "6ème", position: 1, cycle: "first")
        @final = create_level(name: "Tle", position: 7)
      end

      def detail(public_id: @school.public_id) = SchoolDetailQuery.new.call(public_id:, school_year: YEAR)

      test "SC-05 : l'en-tête de l'établissement, avec sa DRENA" do
        school = detail

        assert_equal [ @school.public_id, "Lycée Classique d'Abidjan", "LCA", "Abidjan 1", "public", "both", "active", YEAR ],
                     school.to_h.values_at(:public_id, :name, :sigle, :drena_name, :school_type, :cycle, :status, :school_year)
      end

      test "SC-05 : les classes de l'année, groupées par niveau dans l'ordre du référentiel, avec code, effectif et enseignants" do
        d_series = create_series(name: "D")
        a_series = create_series(name: "A1")
        tle_d10 = create_classroom(school: @school, level: @final, series: d_series, name: "Tle D 10", join_code: "kfm37",
                                   school_year: YEAR)
        create_classroom(school: @school, level: @final, series: d_series, name: "Tle D 2", join_code: nil, school_year: YEAR)
        create_classroom(school: @school, level: @final, series: a_series, name: "Tle A1 1", school_year: YEAR, status: "archived")
        sixth_one = create_classroom(school: @school, level: @sixth, name: "6ème 1", school_year: YEAR)
        create_classroom(school: @school, level: @sixth, name: "6ème 1", school_year: "2025-2026")
        create_classroom(school: create_school(drena: @drena), level: @sixth, name: "6ème 2", school_year: YEAR)

        create_student(classroom: tle_d10)
        create_student(classroom: tle_d10)
        Orm::ClassroomStudent.create!(classroom: tle_d10, student: create_student, joined_at: 1.month.ago, left_at: 1.day.ago)
        create_teacher(school: @school, first_name: "Awa", last_name: "Koné", classrooms: [ tle_d10, sixth_one ])
        create_teacher(school: @school, first_name: "Yao", last_name: "Brou", classrooms: [ tle_d10 ])

        levels = detail.levels
        assert_equal %w[6ème Tle], levels.map(&:name)
        assert_equal [ "6ème 1" ], levels.first.classrooms.map(&:name)
        assert_equal [ "Tle A1 1", "Tle D 2", "Tle D 10" ], levels.last.classrooms.map(&:name)

        row = levels.last.classrooms.last
        assert_equal SchoolDetailQuery::ClassroomRow.new(public_id: tle_d10.public_id, name: "Tle D 10", join_code_display: "KFM37",
                                                         students_count: 2, teacher_names: [ "Yao Brou", "Awa Koné" ],
                                                         status: "active"),
                     row
        assert_equal [ nil, 0, [], "active" ], levels.last.classrooms.second.to_h.values_at(:join_code_display, :students_count,
                                                                                            :teacher_names, :status)
        assert_equal "archived", levels.last.classrooms.first.status
        assert_equal 4, detail.classrooms_count
      end

      test "SC-05 : les enseignants de l'établissement, l'école principale d'abord, avec leur matière" do
        svt = create_material(name: "SVT", category: "science")
        french = create_material(name: "Français", category: "literature")
        create_teacher(school: @school, first_name: "Awa", last_name: "Koné", material: svt)
        other = create_teacher(school: create_school(drena: @drena), first_name: "Yao", last_name: "Brou", material: french)
        Orm::TeacherSchool.create!(teacher: other, school: @school, primary: false)
        create_teacher(school: create_school(drena: @drena))

        assert_equal [ SchoolDetailQuery::TeacherRow.new(name: "Awa Koné", material_name: "SVT", material_category: "science", primary: true),
                       SchoolDetailQuery::TeacherRow.new(name: "Yao Brou", material_name: "Français", material_category: "literature",
                                                         primary: false) ],
                     detail.teachers
      end

      test "un établissement sans classe ni enseignant : listes vides" do
        school = detail

        assert_equal [ [], [], 0 ], [ school.levels, school.teachers, school.classrooms_count ]
      end

      test "un établissement inconnu : nil ; « new » n'est pas un établissement" do
        assert_nil detail(public_id: "new")
        assert_nil detail(public_id: "sch-inconnue")
      end

      test "l'année par défaut est l'année scolaire en cours" do
        create_classroom(school: @school, level: @sixth, name: "6ème 3")

        assert_equal [ "6ème 3" ], SchoolDetailQuery.new.call(public_id: @school.public_id).levels.sole.classrooms.map(&:name)
      end
    end
  end
end
