require "test_helper"

module Repositories
  module Catalog
    class EssentialRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = EssentialRepository.new
        @course = create_course(name: "Génétique")
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def essential(name: "La mitose", course: @course, **attributes)
        Entities::Catalog::Essential.new(course_id: course.id, name:, subtitle: "Division", author_id: course.author_id,
                                         content: "<p>Deux cellules filles.</p>", **attributes)
      end

      test "crée une fiche brouillon en fin de cours, puis la relit par slug avec le statut du cours" do
        create_essential(course: @course)

        created = @repository.create(essential: essential).value
        found = @repository.find_by_slug(slug: created.slug)

        assert_instance_of Entities::Catalog::Essential, found
        assert_equal [ "genetique-la-mitose", "La mitose", "Division", 2, "draft", @course.id, "published" ],
                     [ found.slug, found.name, found.subtitle, found.position, found.status, found.course_id, found.course_status ]
        assert_equal "<p>Deux cellules filles.</p>", found.content
        assert_nil @repository.find_by_slug(slug: "inconnu")
      end

      test "le contenu saisi est assaini à l'écriture" do
        created = @repository.create(essential: essential(content: %(<p onclick="x()">A<script>alert(1)</script></p>))).value

        assert_equal "<p>A</p>", @repository.find_by_slug(slug: created.slug).content
      end

      test "garde le slug, la position et le statut fournis ; une fiche sans contenu se relit sans contenu" do
        created = @repository.create(essential: essential(slug: "mitose", position: 7, status: "published", content: nil)).value

        assert_equal [ "mitose", 7, "published", nil ], [ created.slug, created.position, created.status, created.content ]
      end

      test "un nom déjà pris dans le cours donne :conflict, pas dans un autre cours" do
        @repository.create(essential: essential)

        assert_equal({ name: [ :taken ] }, @repository.create(essential: essential).errors)
        assert @repository.create(essential: essential(course: create_course)).success?
      end

      test "met à jour la fiche et son contenu sans changer le slug ni la position" do
        entity = @repository.create(essential: essential).value
        entity.name = "La méiose"
        entity.content = "<p>Quatre cellules.</p>"

        updated = @repository.update(essential: entity).value

        assert_equal [ "genetique-la-mitose", "La méiose", "<p>Quatre cellules.</p>", 1 ],
                     [ updated.slug, updated.name, updated.content, updated.position ]

        other = @repository.create(essential: essential(name: "Autre")).value
        other.name = "La méiose"

        assert_equal :conflict, @repository.update(essential: other).code
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
