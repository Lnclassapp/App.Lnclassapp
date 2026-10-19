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

      # ADR-0105 : une image de fiche est une pièce jointe Action Text de son contenu, par sgid.
      def attachment(image)
        %(<action-text-attachment sgid="#{image.attachable_sgid}" content-type="#{image.content_type}" ) +
          %(width="#{image.width}" height="#{image.height}"></action-text-attachment>)
      end

      def with_alts(entity, alts)
        entity.images = alts.map { |public_id, alt| Entities::Shared::ContentImage.new(public_id:, alt:) }
        entity
      end

      test "ADR-0105 : les images citées sont rattachées avec leur texte de remplacement, dans l'ordre du texte" do
        first = create_essential_image
        second = create_essential_image(fixture: "photos/photo.png")
        content = "<p>Avant</p>#{attachment(second)}<p>Entre</p>#{attachment(first)}"

        created = @repository.create(essential: with_alts(essential(content:), first.public_id => "Une pile")).value

        assert_equal [ created.id ] * 2, [ first.reload.essential_id, second.reload.essential_id ]
        assert_equal [ [ second.public_id, nil ], [ first.public_id, "Une pile" ] ], created.images.map { [ it.public_id, it.alt ] }
        assert_includes created.content, second.attachable_sgid
        assert_equal created.images.map(&:public_id), @repository.find_by_slug(slug: created.slug).images.map(&:public_id)
      end

      test "ADR-0105 : une image retirée du texte est supprimée avec son fichier, et le journal le dit" do
        kept = create_essential_image
        dropped = create_essential_image
        created = @repository.create(essential: essential(content: attachment(kept) + attachment(dropped))).value

        created.content = attachment(kept)
        logs = capture_log { @updated = @repository.update(essential: with_alts(created, kept.public_id => "Gardée")).value }

        assert_equal [ kept.public_id ], @updated.images.map(&:public_id)
        assert_equal "Gardée", kept.reload.alt
        assert_not Orm::EssentialImage.exists?(dropped.id)
        assert_includes logs, "[EssentialRepository] images supprimées ids=[#{dropped.id}] public_ids=[\"#{dropped.public_id}\"]"
      end

      # Le modèle de la pièce jointe compte, pas seulement l'identifiant : l'image d'un article n'est pas une image de fiche,
      # même si une ligne de ce numéro existait. L'assainir la retirerait sans rien dire : le texte est refusé.
      test "ADR-0105 : une pièce jointe qui n'est pas une image de fiche (image d'article, de question) refuse le texte" do
        kept = create_essential_image
        created = @repository.create(essential: essential(content: attachment(kept))).value
        article = create_article_image
        question = create_question_image

        [ article, question ].each do |foreign|
          sgid = foreign.to_sgid(expires_in: nil, for: ActionText::Attachable::LOCATOR_NAME)
          created.content = attachment(kept) + %(<action-text-attachment sgid="#{sgid}" content-type="image/jpeg"></action-text-attachment>)
          result = @repository.update(essential: created)

          assert_equal [ :invalid, { content: [ :image_unavailable ] } ], [ result.code, result.errors ]
          assert_equal created.id, kept.reload.essential_id
        end
        assert_equal [ :invalid, { content: [ :image_unavailable ] } ],
                     @repository.create(essential: essential(content: attachment(create_article_image))).then { [ it.code, it.errors ] }
      end

      test "ADR-0105 : une image d'une autre fiche ou purgée refuse le texte au lieu d'être retirée sans rien dire" do
        image = create_essential_image
        created = @repository.create(essential: essential(content: attachment(image))).value
        other = create_essential_image(essential: create_essential)
        purged = create_essential_image.tap(&:destroy!)

        [ other, purged ].each do |unavailable|
          created.content = attachment(image) + attachment(unavailable)
          result = @repository.update(essential: created)

          assert_equal [ :invalid, { content: [ :image_unavailable ] } ], [ result.code, result.errors ]
        end
        assert_equal created.id, image.reload.essential_id
        assert_not_equal created.id, other.reload.essential_id
        assert_equal [ image.public_id ], @repository.find_by_slug(slug: created.slug).images.map(&:public_id)
      end

      test "ADR-0105 : un texte de remplacement absent de la saisie est gardé ; vidé, il s'efface" do
        image = create_essential_image
        created = @repository.create(essential: with_alts(essential(content: attachment(image)), image.public_id => "Une pile")).value

        @repository.update(essential: with_alts(created, {}))
        assert_equal "Une pile", image.reload.alt
        @repository.update(essential: with_alts(created, image.public_id => nil))
        assert_nil image.reload.alt
      end

      test "ADR-0105 : un sgid illisible refuse le texte, rien n'est écrit, aucune image n'est détruite" do
        image = create_essential_image
        created = @repository.create(essential: essential(content: attachment(image))).value
        created.content = %(<action-text-attachment sgid="altere"></action-text-attachment>)

        assert_equal({ content: [ :invalid ] }, @repository.update(essential: created).errors)
        assert_equal created.id, image.reload.essential_id
        assert_includes @repository.find_by_slug(slug: created.slug).content, image.attachable_sgid
      end

      test "ADR-0105 : une image citée prise entre-temps par une autre fiche fait échouer l'écriture, rien n'est écrit" do
        image = create_essential_image
        other = create_essential
        @repository.define_singleton_method(:sanitized_content) do |canonical, record|
          super(canonical, record).tap { image.update_columns(essential_id: other.id) }
        end

        result = @repository.create(essential: essential(content: attachment(image)))

        assert_equal [ :conflict, { base: [ :write_failed ] } ], [ result.code, result.errors ]
        assert_equal [ other.id ], Orm::Essential.ids
      end

      test "ADR-0105 : les figures de Trix envoyées par l'éditeur deviennent des pièces jointes" do
        image = create_essential_image
        figure = %(<figure data-trix-attachment="#{ERB::Util.html_escape({ sgid: image.attachable_sgid, contentType: image.content_type }.to_json)}"></figure>)

        created = @repository.create(essential: essential(content: "<div>Texte#{figure}</div>")).value

        assert_equal [ image.public_id ], created.images.map(&:public_id)
      end
    end
  end
end
