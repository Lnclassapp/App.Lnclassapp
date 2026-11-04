require "test_helper"

module Repositories
  module Catalog
    # ADR-0123 §8 : sur Develop, le référentiel manquant est créé ; rien d'existant n'est modifié ni supprimé.
    class ReferentialCompleterTest < ActiveSupport::TestCase
      def complete = ReferentialCompleter.new.complete

      test "on an empty referential it creates the base: levels, series, level/series pairs and materials, and says what" do
        created = complete

        assert_equal %w[6ème 5ème 4ème 3ème 2nde 1ère Tle], created.fetch(:levels)
        assert_equal %w[A C A1 A2 D], created.fetch(:series)
        assert_equal 10, created.fetch(:pairs).size
        assert_includes created.fetch(:pairs), "Tle C"
        assert_equal 7, created.fetch(:materials).size
        assert_equal [ "other", Repositories::Catalog::ProgramOrder.rank("edhc") ], Orm::Material.find_by!(slug: "edhc").then { [ it.category, it.position ] }
        assert_equal 41, created.fetch(:drenas).size
        assert_equal Orm::ClassroomPlanEntry.count, created.fetch(:plan_entries).size
        assert_operator Orm::ClassroomPlanEntry.count, :>, 0
        assert_equal [ 7, "second" ], Orm::Level.find_by!(slug: "tle").then { [ it.position, it.cycle ] }
        assert_equal Repositories::Catalog::ProgramOrder.rank("philosophie"), Orm::Material.find_by!(slug: "philosophie").position
        assert_empty created.fetch(:conflicts)
      end

      test "run again it creates nothing" do
        complete

        assert_no_difference [ "Orm::Level.count", "Orm::Series.count", "Orm::LevelSeries.count", "Orm::Material.count", "Orm::Drena.count",
                               "Orm::ClassroomPlanEntry.count" ] do
          assert(complete.values.all?(&:empty?))
        end
      end

      test "an existing level, series or material is found by its slug and left exactly as it is" do
        level = create_level(name: "Tle", position: 2, cycle: "second")
        material = create_material(name: "Mathématiques", shortname: "Mat", category: "other")
        before = [ level.reload.attributes, material.reload.attributes ]

        created = complete

        assert_not_includes created.fetch(:levels), "Tle"
        assert_not_includes created.fetch(:materials), "Mathématiques"
        assert_equal before, [ level.reload.attributes, material.reload.attributes ]
        assert Orm::LevelSeries.exists?(level:, series: Orm::Series.find_by!(slug: "c"))
      end

      test "a position already held takes the next free one; a name or short name already held by another record is a conflict, never an error" do
        create_level(name: "Terminale", position: 6, cycle: "second")
        create_material(name: "Maths appliquées", shortname: "Maths", category: "science")

        created = complete

        assert_equal [ 6, 7, 8 ], [ "terminale", "1ere", "tle" ].map { Orm::Level.find_by!(slug: it).position }
        assert_equal [ "1ère (position 7)", "Tle (position 8)" ], created.fetch(:levels).last(2)
        assert_includes created.fetch(:conflicts), "matière Mathématiques"
        assert_not Orm::Material.exists?(slug: "mathematiques")
        assert_equal 6, created.fetch(:materials).size
      end
      test "a level or a series whose name is held under another slug is a conflict, and its pairs are skipped" do
        create_level(name: "Terminale", cycle: "second").update_columns(name: "Tle")
        create_series(name: "X").update_columns(name: "C")

        created = complete

        assert_equal [ "niveau Tle", "série C" ], created.fetch(:conflicts)
        assert_not(created.fetch(:pairs).any? { it.start_with?("Tle") || it.end_with?(" C") })
        assert_includes created.fetch(:pairs), "1ère A1"
      end
      test "an interrupted step keeps what was already created, says why, and the next steps are still tried" do
        created = stub_any_instance(Orm::Material.singleton_class, :exists?, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "coupée" }) { complete }

        assert_equal 7, created.fetch(:levels).size
        assert_equal [ "matières (ActiveRecord::ConnectionNotEstablished : coupée)" ], created.fetch(:interruptions)
        assert_empty created.fetch(:conflicts)
        assert_equal 41, created.fetch(:drenas).size
      end

      test "a barème that fails or cannot be loaded writes no entry, says so, and the DRENA are still created" do
        require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s
        [ [ PG::ConnectionBad, "coupée" ], [ LoadError, "migration absente" ] ].each do |error, message|
          Orm::Drena.delete_all
          created = stub_any_instance(FillClassroomPlanEntries.singleton_class, :fill, ->(*) { raise error, message }) { complete }

          assert_equal [ [], 41, [ "barème (#{error} : #{message})" ] ],
                       [ created.fetch(:plan_entries), created.fetch(:drenas).size, created.fetch(:interruptions) ]
          assert_equal 0, Orm::ClassroomPlanEntry.count
        end
      end

      test "an unreadable DRENA list is an interruption, not an error" do
        created = ReferentialCompleter.new(drenas: Rails.root.join("tmp/absent-drenas.yml")).complete

        assert_equal [ "DRENA (Errno::ENOENT)" ], created.fetch(:interruptions).map { it.sub(/ : .*\)\z/, ")") }
        assert_operator created.fetch(:plan_entries).size, :>, 0
      end
      test "a barème entry and a DRENA already there are kept as they are; only the missing ones are added" do
        complete
        entry = Orm::ClassroomPlanEntry.where(series_id: nil).first
        entry.update_columns(count: 0)
        Orm::ClassroomPlanEntry.where.not(id: entry.id).first.delete
        drena = Orm::Drena.find_by!(slug: "drena-abidjan-1")
        drena.update_columns(name: "Abidjan Un")
        Orm::Drena.find_by!(slug: "drena-aboisso").delete

        created = complete

        assert_equal [ 0, "Abidjan Un" ], [ entry.reload.count, drena.reload.name ]
        assert_equal 1, created.fetch(:plan_entries).size
        assert_equal [ "Aboisso" ], created.fetch(:drenas)
      end
    end
  end
end
