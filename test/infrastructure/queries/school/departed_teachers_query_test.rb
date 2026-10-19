require "test_helper"

# GD-21 (ADR-0071 §4.6), ME-21 (ADR-0094): « Enseignants retirés » of the direction: the open departures of its school
# whose teacher is not attached to it again and is not anonymised, newest first, in a fixed number of queries.
module Queries
  module School
    class DepartedTeachersQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Moderne de Bouaké")
        @other = create_school(name: "Lycée Classique d'Abidjan")
        @admin = create_school_admin(school: @school)
        @maths = create_material(name: "Mathématiques", category: "science")
      end

      def departed(school: @school, detached_at: 2.days.ago, reinstated: false, **attributes)
        create_teacher(school: nil, **attributes).tap do |teacher|
          # ADR-0103 §4.1 : sa liste de cet établissement survit au retrait.
          set_teacher_materials(teacher, school, [ teacher.teacher_profile.material ])
          create_teacher_departure(teacher:, school:, detached_by: @admin, detached_at:, reinstated:)
        end
      end

      def overview(school_id: @school.id) = DepartedTeachersQuery.new.call(school_id:)

      # ME-21 (ADR-0094 §4.6, UDR-0100 §3.3): a teacher who has joined another school since is listed too, with nothing
      # of that school; one attached again to THIS school is not.
      test "GD-21, ME-21 : retirés, rattachés ailleurs depuis ou non ; ni réintégrés, ni revenus, ni anonymisés, ni d'un autre établissement" do
        detached_at = Time.zone.local(2026, 9, 28, 10)
        awa = departed(first_name: "Awa", last_name: "Koné", material: @maths, detached_at:)
        elsewhere = departed(first_name: "Yao", last_name: "Ailleurs", material: @maths, detached_at: detached_at - 1.day)
                    .tap { Orm::TeacherSchool.create!(teacher: it, school: @other, primary: true) }
        departed(last_name: "Revenu").tap { Orm::TeacherSchool.create!(teacher: it, school: @school, primary: true) }
        departed(last_name: "Reintegre", reinstated: true)
        departed(last_name: "Anonyme").update!(anonymized_at: Time.current)
        departed(school: @other, last_name: "DeB")

        result = overview
        assert_equal [ [ awa.public_id, "Awa Koné", detached_at ], [ elsewhere.public_id, "Yao Ailleurs", detached_at - 1.day ] ],
                     result.teachers.map { [ it.public_id, it.name, it.detached_at ] }
        assert_equal [ [ "Mathématiques" ], [ "Mathématiques" ] ], result.teachers.map { it.materials.map(&:name) }
        assert_equal [ "Lycée Moderne de Bouaké", true ], [ result.school_name, result.school_active ]
      end

      test "du plus récent au plus ancien ; sans retrait, une liste vide ; l'établissement inactif est dit" do
        departed(last_name: "Ancien", detached_at: 5.days.ago)
        departed(last_name: "Recent", detached_at: 1.day.ago)

        assert_equal [ "Recent", "Ancien" ], overview.teachers.map { it.name.split.last }
        @other.update!(status: "inactive")
        assert_equal [ "Lycée Classique d'Abidjan", false, [] ], overview(school_id: @other.id).deconstruct
      end

      test "nombre de requêtes fixe, quel que soit le nombre d'enseignants retirés" do
        departed
        single = count_queries { overview }
        2.times { departed }

        assert_equal single, count_queries { assert_equal 3, overview.teachers.size }
        assert_equal 2, single
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
