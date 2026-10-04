require "test_helper"

# UDR-0067 §3.0, §3.4.2 : le panneau « Images du texte » de la modale montre les images que cite le texte, dans son
# ordre, chacune avec son sgid, son adresse et son texte de remplacement, reconstruites depuis le texte envoyé et
# image_alts : un re-rendu 422 garde les images et leurs textes.
module Queries
  module Communication
    class ArticleFormImagesQueryTest < ActiveSupport::TestCase
      include Rails.application.routes.url_helpers

      setup do
        @first = create_article_image(alt: "Une salle de classe")
        @second = create_article_image(fixture: "photos/photo.png")
      end

      def query(**) = ArticleFormImagesQuery.new.call(**)

      # Ce que Trix envoie : une figure dont data-trix-attachment porte le sgid posé par l'éditeur à l'envoi.
      def trix_figure(image)
        attachment = { sgid: image.attachable_sgid, contentType: image.content_type, url: blog_image_path(image.public_id) }
        %(<figure data-trix-attachment="#{ERB::Util.html_escape(attachment.to_json)}" ) +
          %(data-trix-content-type="#{image.content_type}" class="attachment attachment--preview"><img src="x"></figure>)
      end

      test "les images du texte, dans son ordre, avec sgid, adresse et texte de remplacement enregistré" do
        images = query(body: article_body_with(@second, @first), image_alts: {})

        assert_equal [ @second.public_id, @first.public_id ], images.map(&:public_id)
        assert_equal [ @second.attachable_sgid, blog_image_path(@second.public_id), nil ],
                     [ images.first.sgid, images.first.url, images.first.alt ]
        assert_equal "Une salle de classe", images.second.alt
        assert_kind_of Dtos::Communication::ArticleInput::Image, images.first
      end

      test "le texte de remplacement saisi l'emporte ; vidé, il reste vide ; absent de la saisie, l'enregistré reste" do
        images = query(body: article_body_with(@first, @second), image_alts: { @first.public_id => nil, @second.public_id => "Un tableau" })

        assert_equal [ nil, "Un tableau" ], images.map(&:alt)
        assert_equal [ "Une salle de classe", nil ], query(body: article_body_with(@first, @second)).map(&:alt)
      end

      test "le texte tel que Trix l'envoie (figures) est lu comme le texte enregistré" do
        images = query(body: "<div>Avant</div>#{trix_figure(@first)}<div>Après</div>#{trix_figure(@second)}", image_alts: {})

        assert_equal [ @first.public_id, @second.public_id ], images.map(&:public_id)
      end

      test "une image citée deux fois compte une fois ; un sgid illisible ou d'un autre modèle est ignoré" do
        user = create_user(role: "student")
        body = article_body_with(@first, @first) +
               %(<action-text-attachment sgid="faux"></action-text-attachment>) +
               %(<action-text-attachment sgid="#{user.to_sgid(for: 'attachable')}"></action-text-attachment>)

        assert_equal [ @first.public_id ], query(body:, image_alts: {}).map(&:public_id)
      end

      test "seules les images de l'article, ou à personne encore, sont montrées" do
        own = create_article(status: "draft")
        other = create_article(status: "draft")
        mine = create_article_image(article: own)
        theirs = create_article_image(article: other)
        body = article_body_with(mine, theirs, @first)

        assert_equal [ mine.public_id, @first.public_id ], query(body:, article_public_id: own.public_id).map(&:public_id)
        assert_equal [ @first.public_id ], query(body:).map(&:public_id)
      end

      test "un texte vide ou sans image : aucune image, sans requête" do
        assert_equal [], query(body: nil)
        assert_no_queries { assert_equal [], query(body: "<div>Texte seul</div>", image_alts: {}) }
      end

      test "l'adresse de la couverture, si elle est à l'article ou à personne encore ; sinon rien" do
        article = create_article(status: "draft")
        cover = create_article_image(article:)
        finder = ArticleFormImagesQuery.new

        assert_equal blog_image_path(@first.public_id), finder.cover_url(public_id: @first.public_id)
        assert_equal blog_image_path(cover.public_id), finder.cover_url(public_id: cover.public_id, article_public_id: article.public_id)
        assert_nil finder.cover_url(public_id: cover.public_id)
        assert_nil finder.cover_url(public_id: "inconnue")
        assert_nil finder.cover_url(public_id: nil)
      end
    end
  end
end
