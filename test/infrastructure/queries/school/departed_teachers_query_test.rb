require "test_helper"

# GD-21 (ADR-0071 §4.6): « Enseignants retirés » of the direction: the open departures of its school whose teacher has
# no school since and is not anonymised, newest first, in a fixed number of queries.
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
          create_teacher_departure(teacher:, school:, detached_by: @admin, detached_at:, reinstated:)
        end
      end

      def overview(school_id: @school.id) = DepartedTeachersQuery.new.call(school_id:)

      test "GD-21 : un enseignant retiré, sa matière, la date de son retrait ; ni réintégré, ni rattaché ailleurs depuis, ni d'un autre établissement" do
        detached_at = Time.zone.local(2026, 9, 28, 10)
        awa = departed(first_name: "Awa", last_name: "Koné", material: @maths, detached_at:)
        departed(last_name: "Ailleurs").tap { Orm::TeacherSchool.create!(teacher: it, school: @other, primary: true) }
        departed(last_name: "Reintegre", reinstated: true)
        departed(last_name: "Anonyme").update!(anonymized_at: Time.current)
        departed(school: @other, last_name: "DeB")

        assert_equal DepartedTeachersQuery::Overview.new(
          school_name: "Lycée Moderne de Bouaké", school_active: true,
          teachers: [ DepartedTeachersQuery::Row.new(public_id: awa.public_id, name: "Awa Koné", material_name: "Mathématiques",
                                                     material_category: "science", detached_at:) ]
        ), overview
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
