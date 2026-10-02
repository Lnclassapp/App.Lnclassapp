require "test_helper"

# ADR-0065 §4, UDR-0052 (DS-06, DS-10): the teachers of the direction's school, their subject and their classes.
module Queries
  module School
    class SchoolTeachersQueryTest < ActiveSupport::TestCase
      YEAR = "2026-2027".freeze

      setup do
        @school = create_school(name: "Lycée Moderne de Bouaké")
        @second = create_level(name: "2nde", position: 5)
        @final = create_level(name: "Tle", position: 7)
        @maths = create_material(name: "Mathématiques", category: "science")
      end

      def overview(school_id: @school.id) = SchoolTeachersQuery.new.call(school_id:, school_year: YEAR)

      test "DS-06 : un enseignant de l'établissement, avec sa matière et ses classes, niveau puis nom" do
        tle = create_classroom(school: @school, level: @final, name: "Tle D 2", school_year: YEAR)
        second = create_classroom(school: @school, level: @second, name: "2nde C 1", school_year: YEAR)
        awa = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", material: @maths, classrooms: [ tle, second ])

        assert_equal SchoolTeachersQuery::Overview.new(
          school_name: "Lycée Moderne de Bouaké",
          teachers: [ SchoolTeachersQuery::TeacherRow.new(public_id: awa.public_id, first_name: "Awa", name: "Awa Koné",
                                                          material_name: "Mathématiques",
                                                          material_category: "science", classroom_names: [ "2nde C 1", "Tle D 2" ]) ]
        ), overview
      end

      test "DS-06 : enseignants de l'établissement, principal ou non, par nom ; ni anonymisé, ni en attente, ni d'ailleurs" do
        create_teacher(school: @school, first_name: "Yao", last_name: "Brou")
        secondary = create_teacher(school: create_school, first_name: "Awa", last_name: "Koné")
        Orm::TeacherSchool.create!(teacher: secondary, school: @school, primary: false)
        create_teacher(school: @school, last_name: "Anonyme").update!(anonymized_at: Time.current)
        create_join_request(school: @school, teacher: create_teacher(school: nil, last_name: "Attente"))
        create_teacher(school: create_school, last_name: "Ailleurs")

        assert_equal [ "Yao Brou", "Awa Koné" ], overview.teachers.map(&:name)
        assert_equal [ [], [] ], overview.teachers.map(&:classroom_names)
      end

      test "classes d'un enseignant : actives, de l'année, de cet établissement seulement (DS-10)" do
        other_school = create_school
        classrooms = [
          create_classroom(school: @school, level: @second, name: "2nde C 1", school_year: YEAR),
          create_classroom(school: @school, level: @second, name: "2nde C 2", school_year: YEAR, status: "archived"),
          create_classroom(school: @school, level: @second, name: "2nde C 3", school_year: "2025-2026"),
          create_classroom(school: other_school, level: @second, name: "2nde A 1", school_year: YEAR)
        ]
        teacher = create_teacher(school: @school, classrooms:)
        Orm::TeacherSchool.create!(teacher:, school: other_school, primary: false)

        assert_equal [ [ "2nde C 1" ] ], overview.teachers.map(&:classroom_names)
        assert_equal [ [ "2nde A 1" ] ], overview(school_id: other_school.id).teachers.map(&:classroom_names)
      end

      test "GD-14 (ADR-0071 §4.6, UDR-0056 §3.3) : chaque ligne porte le public_id et le prénom, pour « Retirer »" do
        yao = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")
        awa = create_teacher(school: @school, first_name: "Awa", last_name: "Koné")

        assert_equal [ [ yao.public_id, "Yao", "Yao Brou" ], [ awa.public_id, "Awa", "Awa Koné" ] ],
                     overview.teachers.map { [ it.public_id, it.first_name, it.name ] }
      end

      test "un établissement sans enseignant : liste vide" do
        create_teacher(school: create_school)

        assert_equal SchoolTeachersQuery::Overview.new(school_name: "Lycée Moderne de Bouaké", teachers: []), overview
      end

      test "nombre de requêtes fixe, quel que soit le nombre d'enseignants et de classes" do
        seed = -> { create_teacher(school: @school, classrooms: [ create_classroom(school: @school, level: @second, school_year: YEAR) ]) }
        seed.call
        single = count_queries { overview }
        2.times { seed.call }

        assert_equal single, count_queries { assert_equal 3, overview.teachers.size }
        assert_equal 3, single
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
