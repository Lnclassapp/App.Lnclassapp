require "test_helper"

# ADR-0074 §4.1, §4.4 : une image d'article est une pièce jointe Action Text par sgid ; le texte la cite, l'éditeur
# (to_trix_html, modale de l'équipe) la montre par son adresse, la page publique la rend par un partiel du Lot D.
module Orm
  class ArticleImageTest < ActiveSupport::TestCase
    def image(**attributes)
      Orm::ArticleImage.create!(content_type: "image/webp", byte_size: 2048, width: 1600, height: 900, **attributes)
    end

    def article(**attributes)
      Orm::Article.create!(title: "Réviser le BEPC", author: create_team_member(team_role: "content", second_factor: false),
                           **attributes)
    end

    test "une image a son public_id, se cite par un sgid d'attachable et se rend par le partiel des articles" do
      picture = image

      assert_equal 14, picture.public_id.size
      assert_equal picture.public_id, picture.to_param
      assert_equal "communication/articles/body_image", picture.to_attachable_partial_path
      assert_equal picture, ActionText::Attachable.from_attachable_sgid(picture.attachable_sgid)
      assert_equal picture, Orm::ArticleImage.from_attachable_sgid(picture.attachable_sgid)
      assert_nil SignedGlobalID.parse(picture.attachable_sgid, for: "autre")
    end

    test "un article a un public_id pour l'équipe et un slug figé tiré du titre pour le public" do
      first = article(title: "Réviser le BEPC en 4 semaines")
      second = article(title: "Réviser le BEPC en 4 semaines")
      first.update!(title: "Réviser le BEPC en 5 semaines")

      assert_equal [ "reviser-le-bepc-en-4-semaines", "reviser-le-bepc-en-4-semaines-2" ], [ first.reload.slug, second.slug ]
      assert_equal first.public_id, first.to_param
      assert_equal [ "draft", "team", 0 ], [ first.status, first.signature, first.reads_count ]
    end

    test "un article tient sa couverture et ses images ; une image tient son article" do
      cover = image
      record = article(cover_image: cover)
      cover.update!(article: record)
      body_image = image(article: record, alt: "Un tableau")

      assert_equal cover, record.reload.cover_image
      assert_equal [ cover, body_image ], record.images.order(:id).to_a
      assert_equal record, body_image.article
      assert_not image.article
    end

    # Sans to_trix_content_attachment_partial_path → nil, Action Text chercherait « orm/article_images/_article_image »
    # et la modale de modification (Lot A) casserait.
    test "le texte d'un article rouvert dans l'éditeur montre ses images par leur adresse, sans partiel" do
      picture = image(alt: "Un tableau")
      record = article(body: %(<div>Avant</div><action-text-attachment sgid="#{picture.attachable_sgid}" content-type="image/webp" ) +
                             %(width="1600" height="900" caption="Au tableau"></action-text-attachment>))

      trix = Orm::Article.find(record.id).body.to_trix_html
      attributes = JSON.parse(Nokogiri::HTML5.fragment(trix).at_css("figure[data-trix-attachment]")["data-trix-attachment"])

      assert_equal({ "sgid" => picture.attachable_sgid, "contentType" => "image/webp", "url" => "/blog/images/#{picture.public_id}",
                     "width" => 1600, "height" => 900, "filesize" => 2048 }, attributes.except("caption", "filename"))
      assert_includes trix, "Au tableau"
      assert_equal [ picture ], record.body.body.attachables
    end
  end
end
