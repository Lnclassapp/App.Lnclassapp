require "test_helper"

module Queries
  module School
    class SchoolsQueryTest < ActiveSupport::TestCase
      YEAR = "2026-2027".freeze

      def query(**filters) = SchoolsQuery.new.call(school_year: YEAR, **filters)

      # 600 écoles dans 3 DRENA, insérées d'un coup : la pagination se prouve sur le volume de SC-04.
      def insert_schools(count, drenas)
        now = Time.current
        Orm::School.insert_all!(Array.new(count) do |index|
          { public_id: "sch#{format('%011d', index)}", drena_id: drenas[index % drenas.size].id, name: format("École %03d", index),
            school_type: %w[public private mixed][index % 3], cycle: "both", status: "active", created_at: now, updated_at: now,
            school_code: format("aa%04d", index).tr("01", "ab") }
        end)
      end

      test "SC-04 : 50 établissements par page, par nom, avec le total et le nombre de pages" do
        insert_schools(600, Array.new(3) { create_drena })

        first = query
        assert_equal [ 600, 1, 12 ], [ first.total_count, first.page, first.pages ]
        assert_equal 50, first.rows.size
        assert_equal [ "École 000", "École 049" ], [ first.rows.first.name, first.rows.last.name ]

        last = query(page: "12")
        assert_equal [ 12, 50, "École 550" ], [ last.page, last.rows.size, last.rows.first.name ]
      end

      test "une page hors bornes ou illisible revient dans les bornes" do
        insert_schools(60, [ create_drena ])

        assert_equal [ 2, 10 ], query(page: "99").then { [ it.page, it.rows.size ] }
        assert_equal 1, query(page: "-3").page
        assert_equal 1, query(page: "abc").page
        # A query string such as page[]=2 or page[a]=1 hands an array or a hash: page 1, never a 500.
        assert_equal 1, query(page: [ "2" ]).page
        assert_equal 1, query(page: { "a" => "1" }).page
        assert_equal 1, query(page: nil).page
      end

      test "une ligne : DRENA, type, cycle, statut, classes de l'année et enseignants" do
        drena = create_drena(name: "Abidjan 1")
        school = create_school(drena:, name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "mixed", cycle: "first",
                               status: "draft", school_code: "k7m4qz")
        create_classroom(school:, school_year: YEAR)
        create_classroom(school:, school_year: YEAR)
        create_classroom(school:, school_year: "2025-2026")
        create_teacher(school:)

        assert_equal SchoolsQuery::Row.new(public_id: school.public_id, name: "Lycée Classique d'Abidjan", sigle: "LCA",
                                           drena_public_id: drena.public_id, drena_name: "Abidjan 1", school_type: "mixed", cycle: "first", status: "draft",
                                           classrooms_count: 2, teachers_count: 1, school_code: "k7m4qz", national_code: nil),
                     query.rows.sole
      end

      test "filtres : DRENA, type, cycle, statut ; une valeur inconnue est ignorée" do
        abidjan = create_drena(name: "Abidjan 1")
        bouake = create_drena(name: "Bouaké")
        create_school(drena: abidjan, name: "A public", school_type: "public")
        create_school(drena: abidjan, name: "B privé", school_type: "private", cycle: "first")
        create_school(drena: bouake, name: "C mixte", school_type: "mixed", status: "inactive")

        names = ->(**filters) { query(**filters).rows.map(&:name) }
        assert_equal [ "A public", "B privé" ], names.call(drena: abidjan.public_id)
        assert_equal [ "C mixte" ], names.call(school_type: "mixed")
        assert_equal [ "B privé" ], names.call(cycle: "first")
        assert_equal [ "C mixte" ], names.call(status: "inactive")
        assert_equal [ "B privé" ], names.call(drena: abidjan.public_id, school_type: "private", cycle: "first", status: "active")
        assert_equal 3, query(school_type: "privée", cycle: "second", status: "fermé", drena: "").total_count
        assert_equal 0, query(drena: "drena-inconnue").total_count
      end

      test "recherche sur le nom ou le sigle, sans tenir compte de la casse ni des accents" do
        create_school(name: "Collège Moderne de Cocody", sigle: "CMC")
        create_school(name: "Lycée Classique", sigle: "LCA")
        create_school(name: "ÉCOLE PRIMAIRE 100%")

        names = ->(search) { query(search:).rows.map(&:name) }
        assert_equal [ "Collège Moderne de Cocody" ], names.call("college moderne")
        assert_equal [ "Lycée Classique" ], names.call(" lca ")
        assert_equal [ "Lycée Classique" ], names.call("LYCEE")
        assert_equal [ "ÉCOLE PRIMAIRE 100%" ], names.call("ecole")
        assert_equal [ "ÉCOLE PRIMAIRE 100%" ], names.call("100%")
        assert_empty names.call("_")
        assert_equal 3, query(search: "  ").total_count
      end

      test "CP-10 : recherche aussi sur le code national, que la ligne porte (ADR-0063)" do
        create_school(name: "Lycée Classique", national_code: "012345")
        create_school(name: "Lycée Moderne")

        assert_equal [ [ "Lycée Classique", "012345" ] ], query(search: "012345").rows.map { [ it.name, it.national_code ] }
        assert_equal [ "Lycée Classique" ], query(search: "0123").rows.map(&:name)
      end

      test "aucun établissement : une page vide" do
        page = query

        assert_equal [ [], 0, 1, 1 ], [ page.rows, page.total_count, page.page, page.pages ]
      end

      test "find : la ligne d'un établissement par son public_id, ou nil ; l'année par défaut est l'année en cours" do
        school = create_school(name: "Lycée Moderne")
        create_classroom(school:)

        row = SchoolsQuery.new.find(public_id: school.public_id)
        assert_equal [ "Lycée Moderne", 1 ], [ row.name, row.classrooms_count ]
        assert_equal 1, SchoolsQuery.new.call.rows.sole.classrooms_count
        assert_nil SchoolsQuery.new.find(public_id: "new")
      end
    end
  end
end
