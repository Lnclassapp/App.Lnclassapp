require "test_helper"

module Repositories
  module Catalog
    class EssentialRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = EssentialRepository.new
        @course = create_course(name: "Génétique")
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      # Menace n° 15 : lock prend le verrou de la ligne, tenu jusqu'à la fin de la transaction.
      test "lock verrouille la ligne de la fiche" do
        saved = create_essential(course: @course, status: "draft")
        statements = []
        collect = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/FROM "essentials".*FOR UPDATE/m) }

        ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
          Orm::Essential.transaction { assert @repository.lock(id: saved.id) }
        end

        assert_equal 1, statements.size
      end

      test "relit une fiche par slug avec le statut du cours" do
        saved = create_essential(course: @course, name: "La mitose", status: "draft")

        found = @repository.find_by_slug(slug: saved.slug)

        assert_instance_of Entities::Catalog::Essential, found
        assert_equal [ saved.slug, "La mitose", 1, "draft", @course.id, "published" ],
                     [ found.slug, found.name, found.position, found.status, found.course_id, found.course_status ]
        assert_nil @repository.find_by_slug(slug: "inconnu")
      end

      test "la première publication pose published_at, l'archivage archived_at, la republication garde la première date" do
        record = create_essential(course: @course, status: "draft")

        assert @repository.transition(id: record.id, to: "published", at: @at)
        assert @repository.transition(id: record.id, to: "archived", at: @at + 1.day)
        assert_equal [ "archived", @at, @at + 1.day ], record.reload.attributes.values_at("status", "published_at", "archived_at")

        @repository.transition(id: record.id, to: "published", at: @at + 2.days)

        assert_equal [ "published", @at, nil ], record.reload.attributes.values_at("status", "published_at", "archived_at")
        assert_raises(ArgumentError) { @repository.transition(id: record.id, to: "draft", at: @at) }
      end

      test "donne les clés de doublon des cours demandés ou de tous, la position suivante et les slugs pris" do
        other_course = create_course
        mine = create_essential(course: @course, name: "La  Mitose")
        create_essential(course: other_course, name: "Ailleurs")

        assert_equal Set[[ @course.id, "la mitose" ]], @repository.existing_keys(course_ids: [ @course.id ])
        assert @repository.existing_keys.superset?(Set[[ @course.id, "la mitose" ], [ other_course.id, "ailleurs" ]])
        assert_equal({ "la mitose" => mine.id }, @repository.ids_by_name(course_id: @course.id))
        assert_equal [ mine.name ], @repository.names(course_id: @course.id)
        assert_equal 2, @repository.next_position(course_id: @course.id)
        assert_equal 1, @repository.next_position(course_id: create_course.id)
        assert_includes @repository.taken_slugs, mine.slug
      end

      # ADR-0035, amendement du 2026-10-01 (« Tout publier ») : les fiches brouillons du cours seules, dans son ordre.
      test "draft_slugs liste les fiches brouillons du cours, dans l'ordre du cours, sans les publiées, archivées ni d'autres cours" do
        second = create_essential(course: @course, name: "Seconde", status: "draft", position: 2)
        first = create_essential(course: @course, name: "Première", status: "draft", position: 1)
        create_essential(course: @course, status: "published")
        create_essential(course: @course, status: "archived")
        create_essential(course: create_course, status: "draft")

        assert_equal [ first.slug, second.slug ], @repository.draft_slugs(course_id: @course.id)
      end
    end
  end
end
