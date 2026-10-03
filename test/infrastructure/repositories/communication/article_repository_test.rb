require "test_helper"

# ADR-0073 §4.1 à §4.7 : l'adaptateur des articles. Le slug naît du titre et ne bouge plus (BL-10) ; enregistrer assainit
# le texte (BL-16), rattache la couverture et les images citées, supprime celles qui ne le sont plus ; une remise en ligne
# garde sa date (BL-11) ; une lecture est un seul UPDATE, sans effet sur un brouillon ni sur updated_at (BL-17).
module Repositories
  module Communication
    class ArticleRepositoryTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        @repository = ArticleRepository.new
        @author = create_team_member(team_role: "content", second_factor: false)
        @at = Time.zone.local(2026, 10, 5, 9, 30)
      end

      def input(**attributes)
        Dtos::Communication::ArticleInput.new(title: "Réviser le BEPC en 4 semaines", excerpt: "Un plan semaine par semaine.",
                                              body: "<div>Commencez par les maths.</div>", signature: "team", **attributes)
      end

      def create(**attributes) = @repository.create(dto: input(**attributes), author_id: @author.id, at: @at).value

      def cited_ids(article) = Orm::Article.find(article.id).body.body.attachables.map(&:id)

      # Orm::HasFrozenSlug lit Orm::Article.exists? pour trouver un slug libre : on simule une création concurrente.
      def with_exists(implementation)
        Orm::Article.define_singleton_method(:exists?, &implementation)
        yield
      ensure
        Orm::Article.singleton_class.remove_method(:exists?)
      end

      test "BL-10 : un brouillon naît avec un slug tiré du titre ; deux titres identiques donnent -2 ; le slug ne bouge plus" do
        first = create
        second = create

        assert_equal [ "reviser-le-bepc-en-4-semaines", "reviser-le-bepc-en-4-semaines-2" ], [ first.slug, second.slug ]
        assert_equal [ "draft", "team", @author.id, 0, @at, @at, nil ],
                     [ first.status, first.signature, first.author_id, first.reads_count, first.created_at, first.updated_at, first.published_at ]
        assert_equal 14, first.public_id.size

        updated = @repository.update(id: first.id, dto: input(title: "Réviser le BAC"), at: @at + 1.day).value

        assert_equal [ "Réviser le BAC", "reviser-le-bepc-en-4-semaines", "draft", @at + 1.day ],
                     [ updated.title, updated.slug, updated.status, updated.updated_at ]
      end

      # ADR-0029 : deux créations simultanées lisent le même slug libre ; l'index unique refuse la seconde, qui réessaie.
      test "BL-10 : une collision de slug concurrente régénère le slug et réessaie une fois" do
        create
        free_once = true
        article = with_exists(->(*args, **options) { free_once ? (free_once = false) : Orm::Article.where(*args, **options).any? }) do
          create
        end

        assert_equal "reviser-le-bepc-en-4-semaines-2", article.slug
        assert_equal 2, Orm::Article.count
      end

      test "une seconde collision de slug concurrente rend :conflict (base: write_failed), jamais un 500 ; rien n'est écrit" do
        create

        result = with_exists(->(*, **) { false }) { @repository.create(dto: input, author_id: @author.id, at: @at) }

        assert_equal :conflict, result.code
        assert_equal({ base: [ :write_failed ] }, result.errors)
        assert_equal 1, Orm::Article.count
      end

      test "la violation d'un autre index unique (public_id) n'est pas une collision de slug : elle remonte, sans nouvel essai" do
        taken = create.public_id
        lookups = 0
        SecureRandom.singleton_class.alias_method :original_base58, :base58
        SecureRandom.define_singleton_method(:base58) { |*| taken }

        error = assert_raises(ActiveRecord::RecordNotUnique) do
          with_exists(->(*args, **options) { (lookups += 1) && Orm::Article.where(*args, **options).any? }) { create }
        end

        assert_includes error.message, "index_articles_on_public_id"
        assert_equal 2, lookups, "un seul calcul du slug (-2), pas de second essai"
        assert_equal 1, Orm::Article.count
      ensure
        SecureRandom.singleton_class.alias_method :base58, :original_base58
        SecureRandom.singleton_class.remove_method :original_base58
      end

      test "une collision de slug sur un article déjà enregistré n'est pas réessayée : le slug figé n'est jamais recalculé" do
        first = create
        second = create
        Orm::Article.define_singleton_method(:find) { |id| super(id).tap { it.slug = first.slug } }

        error = assert_raises(ActiveRecord::RecordNotUnique) { @repository.update(id: second.id, dto: input(title: "Autre"), at: @at) }

        assert_includes error.message, "index_articles_on_slug"
      ensure
        Orm::Article.singleton_class.remove_method(:find)
      end

      test "BL-16 : le texte est assaini à l'écriture ; un h1 devient un h2 ; une image d'un autre article part" do
        foreign = create_article_image(article: create_article)
        user = %(<action-text-attachment sgid="#{@author.to_sgid(expires_in: nil, for: 'attachable')}"></action-text-attachment>)
        body = %(<h1>Semaine 1</h1><div onclick="x()">Texte<script>alert(1)</script></div><a href="javascript:x()">lien</a>) +
               user + article_body_with(foreign, text: "fin")

        article = create(body:)

        assert_equal %(<h2>Semaine 1</h2><div>Texte</div><a>lien</a><div>fin</div>), article.body
        assert_equal [], article.images
      end

      test "une pièce jointe dont le sgid ne se vérifie pas : :invalid sur le texte, aucune image n'est détruite ni rattachée" do
        first = create_article_image
        second = create_article_image
        article = create(body: article_body_with(first, second))
        tampered = article_body_with(first) + %(<action-text-attachment sgid="#{second.attachable_sgid}x" content-type="image/jpeg">) +
                   "</action-text-attachment>"

        [ -> { @repository.update(id: article.id, dto: input(body: tampered), at: @at + 1.day) },
          -> { @repository.create(dto: input(body: %(<action-text-attachment sgid="faux"></action-text-attachment>)), author_id: @author.id, at: @at) } ]
          .each do |save|
          result = save.call

          assert_equal :invalid, result.code
          assert_equal({ body: [ :image_unreadable ] }, result.errors)
        end
        assert_equal [ article.id, article.id ], [ first.reload.article_id, second.reload.article_id ]
        assert_equal [ first.id, second.id ], cited_ids(article)
        assert_equal 1, Orm::Article.count
      end

      test "créer rattache la couverture et les images citées, avec leurs textes de remplacement, dans l'ordre du texte" do
        cover = create_article_image
        first = create_article_image
        second = create_article_image(fixture: "photos/photo.png")
        # Trix envoie des figures : Action Text les canonise en pièces jointes avant l'assainissement.
        figure = %(<figure data-trix-attachment="#{ERB::Util.html_escape({ sgid: second.attachable_sgid, contentType: 'image/png',
                                                                            url: 'https://ailleurs.test/x.png', width: 64, height: 48 }.to_json)}"></figure>)

        article = create(body: article_body_with(first, text: "Avant") + figure, cover_public_id: cover.public_id,
                         cover_alt: "Des élèves", image_alts: { first.public_id => "Un cahier" })

        assert_equal [ [ first.public_id, "Un cahier" ], [ second.public_id, nil ] ], article.images.map { [ it.public_id, it.alt ] }
        assert_equal Entities::Communication::ArticleImage.new(public_id: cover.public_id, id: cover.id, article_id: article.id,
                                                               content_type: "image/jpeg", byte_size: cover.byte_size, width: 64, height: 48),
                     article.cover
        assert_equal "Des élèves", article.cover_alt
        assert_equal [ article.id ] * 3, [ cover, first, second ].map { it.reload.article_id }
        assert_equal [ first.id, second.id ], cited_ids(article)
        assert_not_includes article.body, "ailleurs.test"
        found = @repository.find_by_public_id(public_id: article.public_id)
        assert_equal [ article.images, article.cover, article.body ], [ found.images, found.cover, found.body ]
      end

      test "une couverture inconnue ou d'un autre article est refusée ; rien n'est écrit" do
        foreign = create_article_image(article: create_article)

        [ "inconnu0000000", foreign.public_id ].each do |cover_public_id|
          result = @repository.create(dto: input(cover_public_id:), author_id: @author.id, at: @at)

          assert_equal [ :invalid, { cover_public_id: [ :invalid ] } ], [ result.code, result.errors ], cover_public_id
        end
        assert_equal 1, Orm::Article.count
      end

      test "modifier supprime une image retirée du texte et l'ancienne couverture, jamais une image citée ; le fichier part après" do
        kept, removed, old_cover, new_cover = Array.new(4) { create_article_image }
        article = create(body: article_body_with(kept, removed), cover_public_id: old_cover.public_id)
        blob = removed.file.blob

        result = perform_enqueued_jobs do
          @repository.update(id: article.id, dto: input(body: article_body_with(kept), cover_public_id: new_cover.public_id,
                                                         image_alts: { kept.public_id => "Gardée" }), at: @at)
        end

        assert_equal [ kept.id, new_cover.id ].sort, Orm::ArticleImage.where(article_id: article.id).pluck(:id).sort
        assert_not Orm::ArticleImage.exists?(removed.id)
        assert_not Orm::ArticleImage.exists?(old_cover.id)
        assert_not ActiveStorage::Blob.exists?(blob.id)
        assert_equal [ [ kept.public_id, "Gardée" ] ], result.value.images.map { [ it.public_id, it.alt ] }
        assert_equal new_cover.public_id, result.value.cover.public_id
      end

      test "modifier sans couverture la retire ; une couverture d'un autre article est refusée sans rien changer" do
        cover = create_article_image
        article = create(cover_public_id: cover.public_id, cover_alt: "Couverture")
        foreign = create_article_image(article: create_article)

        refused = @repository.update(id: article.id, dto: input(title: "Autre", cover_public_id: foreign.public_id), at: @at)

        assert_equal :invalid, refused.code
        assert_equal [ "Réviser le BEPC en 4 semaines", cover.id ], Orm::Article.find(article.id).then { [ it.title, it.cover_image_id ] }

        updated = @repository.update(id: article.id, dto: input(cover_alt: "Couverture"), at: @at).value

        assert_nil updated.cover
        assert_not Orm::ArticleImage.exists?(cover.id)
      end

      test "une image envoyée pour l'article mais pas encore citée reste rattachable ; celle d'un autre article non" do
        article = create
        own = create_article_image(article: Orm::Article.find(article.id))
        orphan = create_article_image

        updated = @repository.update(id: article.id, dto: input(body: article_body_with(own, orphan)), at: @at).value

        assert_equal [ own.public_id, orphan.public_id ], updated.images.map(&:public_id)
      end

      test "une image prise par un autre article entre l'assainissement et le rattachement : :conflict, rien n'est écrit" do
        image = create_article_image
        other = create_article
        sanitizer = Repositories::Shared::RichTextSanitizer
        original = sanitizer.method(:call)
        sanitizer.define_singleton_method(:call) do |html, **options|
          image.update_columns(article_id: other.id)
          original.call(html, **options)
        end

        # Dans la transaction du use case (Repositories::Shared::Transaction#call), comme en production.
        result = Repositories::Shared::Transaction.new.call do
          @repository.create(dto: input(body: article_body_with(image), image_alts: { image.public_id => "Carte" }),
                             author_id: @author.id, at: @at)
        end

        assert_equal [ :conflict, { base: [ :write_failed ] } ], [ result.code, result.errors ]
        # La prise simulée passe par la même connexion : l'annulation l'emporte avec le reste. Rien n'est à l'article neuf.
        assert_equal [ nil, nil ], [ image.reload.article_id, image.alt ]
        assert_equal [ other.id ], Orm::Article.ids
      ensure
        sanitizer.define_singleton_method(:call, original)
      end

      test "un texte de remplacement absent de la saisie est gardé, vidé il s'efface ; une image citée deux fois compte une fois" do
        first, second = Array.new(2) { create_article_image }
        article = create(body: article_body_with(first, second, first),
                         image_alts: { first.public_id => "Un cahier", second.public_id => "Un tableau" })

        assert_equal [ first.public_id, second.public_id ], article.images.map(&:public_id)

        updated = @repository.update(id: article.id, dto: input(body: article_body_with(first, second),
                                                                 image_alts: { second.public_id => " " }), at: @at).value

        assert_equal [ "Un cahier", nil ], updated.images.map(&:alt)
      end

      # Seul cet adaptateur écrit un texte : une ligne qui citerait l'image d'un autre article ne la lui prête pas.
      test "les images d'un article sont les siennes, dans l'ordre de son texte" do
        foreign = create_article_image(article: create_article)
        own = create_article_image
        article = create_article(body: article_body_with(foreign, own))

        assert_equal [ own.public_id ], @repository.find_by_public_id(public_id: article.public_id).images.map(&:public_id)
      end

      test "find_by_public_id lit tout état ; nil pour un article inconnu" do
        archived = create_article(status: "archived", signature: "author", title: "Ancien")

        found = @repository.find_by_public_id(public_id: archived.public_id)

        assert_equal [ archived.id, "archived", "author", "Ancien", archived.slug, archived.archived_at, nil, [] ],
                     [ found.id, found.status, found.signature, found.title, found.slug, found.archived_at, found.cover, found.images ]
        assert found.archived?
        assert_nil @repository.find_by_public_id(public_id: "inconnu0000000")
      end

      test "BL-11 : publier pose la date la première fois ; archiver puis remettre en ligne la garde" do
        article = create

        assert @repository.transition(id: article.id, to: "published", at: @at)
        assert @repository.transition(id: article.id, to: "archived", at: @at + 1.day)
        archived = @repository.find_by_public_id(public_id: article.public_id)

        assert_equal [ "archived", @at, @at + 1.day, @at + 1.day ], [ archived.status, archived.published_at, archived.archived_at, archived.updated_at ]

        @repository.transition(id: article.id, to: "published", at: @at + 2.days)
        republished = @repository.find_by_public_id(public_id: article.public_id)

        assert_equal [ "published", @at, nil ], [ republished.status, republished.published_at, republished.archived_at ]
        assert_raises(ArgumentError) { @repository.transition(id: article.id, to: "draft", at: @at) }
      end

      test "une transition déjà faite par un geste concurrent : false, rien n'est réécrit" do
        article = create

        assert @repository.transition(id: article.id, to: "published", at: @at)
        assert_not @repository.transition(id: article.id, to: "published", at: @at + 1.hour)
        assert @repository.transition(id: article.id, to: "archived", at: @at + 1.day)
        assert_not @repository.transition(id: article.id, to: "archived", at: @at + 2.days)

        found = Orm::Article.find(article.id)
        assert_equal [ "archived", @at, @at + 1.day, @at + 1.day ], [ found.status, found.published_at, found.archived_at, found.updated_at ]
      end

      test "BL-17 : une lecture est un seul UPDATE, sans effet sur updated_at ; un brouillon ou un archivé n'est pas compté" do
        published = create_article(updated_at: 2.days.ago)
        draft = create_article(status: "draft")
        archived = create_article(status: "archived")

        assert_queries_count(1) { assert @repository.increment_reads(article_id: published.id) }
        @repository.increment_reads(article_id: published.id)

        assert_equal [ 2, published.updated_at ], published.reload.then { [ it.reads_count, it.updated_at ] }
        assert_not @repository.increment_reads(article_id: draft.id)
        assert_not @repository.increment_reads(article_id: archived.id)
        assert_equal [ 0, 0 ], [ draft.reload.reads_count, archived.reload.reads_count ]
      end
    end
  end
end
