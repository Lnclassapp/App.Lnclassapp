require "test_helper"

module Repositories
  module Catalog
    class CourseRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = CourseRepository.new
        @level = create_level
        @material = create_material
        @author = create_team_member(team_role: "content", second_factor: false)
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def course(name: "Génétique", **attributes)
        Entities::Catalog::Course.new(name:, subtitle: "Hérédité", level_id: @level.id, material_id: @material.id,
                                      author_id: @author.id, content: "<p>La <strong>méiose</strong>.</p>", **attributes)
      end

      test "crée un cours brouillon avec son contenu riche, puis le relit par slug" do
        created = @repository.create(course: course).value

        found = @repository.find_by_slug(slug: created.slug)

        assert_instance_of Entities::Catalog::Course, found
        assert_equal [ "genetique", "Génétique", "Hérédité", "draft", @level.id, @material.id, nil, @author.id ],
                     [ found.slug, found.name, found.subtitle, found.status, found.level_id, found.material_id, found.series_id, found.author_id ]
        assert_equal "<p>La <strong>méiose</strong>.</p>", found.content
        assert_equal "Orm::Course", ActionText::RichText.find_by(record_id: found.id, name: "content").record_type
        assert_nil @repository.find_by_slug(slug: "inconnu")
      end

      test "le contenu saisi est assaini à l'écriture, à la création comme à la modification" do
        forged = %(<p onclick="x()">A<script>alert(1)</script></p><action-text-attachment sgid="x"></action-text-attachment>)
        created = @repository.create(course: course(content: forged)).value

        assert_equal "<p>A</p>", created.content
        created.content = %(<a href="javascript:alert(1)">B</a>)
        @repository.update(course: created)

        assert_equal "<a>B</a>", @repository.find_by_slug(slug: created.slug).content
      end

      test "garde le slug et le statut fournis ; un cours sans contenu se relit sans contenu" do
        created = @repository.create(course: course(slug: "genetique-tle-d", status: "published", content: nil)).value

        assert_equal [ "genetique-tle-d", "published", nil ], [ created.slug, created.status, created.content ]
        assert_nil @repository.find_by_slug(slug: "genetique-tle-d").content
      end

      test "un nom déjà pris pour le même niveau, la même matière et la même série donne :conflict" do
        series = create_series
        @repository.create(course: course(series_id: series.id))

        result = @repository.create(course: course(series_id: series.id))

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
        assert @repository.create(course: course).success?
      end

      test "met à jour le cours et son contenu sans changer le slug" do
        entity = @repository.create(course: course).value
        entity.name = "Génétique humaine"
        entity.content = "<p>Nouveau</p>"
        entity.series_id = create_series.id

        updated = @repository.update(course: entity).value

        assert_equal [ "genetique", "Génétique humaine", "<p>Nouveau</p>", entity.series_id ],
                     [ updated.slug, updated.name, updated.content, updated.series_id ]
      end

      test "une mise à jour vers un nom pris donne :conflict" do
        @repository.create(course: course(name: "Mitose"))
        entity = @repository.create(course: course).value
        entity.name = "Mitose"

        assert_equal({ name: [ :taken ] }, @repository.update(course: entity).errors)
      end

      test "la première publication pose published_at, l'archivage archived_at, la republication garde la première date" do
        record = create_course(status: "draft")

        assert @repository.transition(id: record.id, to: "published", at: @at)
        assert @repository.transition(id: record.id, to: "archived", at: @at + 1.day)
        assert_equal [ "archived", @at, @at + 1.day ], record.reload.attributes.values_at("status", "published_at", "archived_at")

        @repository.transition(id: record.id, to: "published", at: @at + 2.days)

        assert_equal [ "published", @at, nil ], record.reload.attributes.values_at("status", "published_at", "archived_at")
        assert_raises(ArgumentError) { @repository.transition(id: record.id, to: "draft", at: @at) }
      end

      test "donne les clés de doublon et les slugs pris" do
        series = create_series
        record = create_course(level: @level, material: @material, series:, name: "Génétique  et Évolution")

        assert_includes @repository.existing_keys, [ "genetique et evolution", @level.id, @material.id, series.id ]
        assert_includes @repository.taken_slugs, record.slug
        assert_instance_of Set, @repository.taken_slugs
      end
    end
  end
end
