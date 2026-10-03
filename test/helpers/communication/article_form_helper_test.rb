require "test_helper"

# UDR-0065 §3.4.4 : les données de l'éditeur du blog (#article_editor), lues par le contrôleur rich-text-editor en mode
# images : plafonds lus dans Entities::Communication::ArticleImage, jamais recopiés ; messages rédigés par le serveur.
module Communication
  class ArticleFormHelperTest < ActionView::TestCase
    include Rails.application.routes.url_helpers

    IMAGE = Entities::Communication::ArticleImage

    test "article_editor_data : mode images, adresse d'envoi, formats, plafonds et textes de la barre d'outils" do
      data = article_editor_data(upload_url: "/teams/blog/images?article=abcdefghijkmno")

      assert_equal %w[rich-text-editor-lang-value rich-text-editor-attachments-value rich-text-editor-upload-url-value
                      rich-text-editor-accept-value rich-text-editor-max-bytes-value rich-text-editor-max-side-value
                      rich-text-editor-max-count-value rich-text-editor-messages-value], data.keys
      assert data["rich-text-editor-attachments-value"]
      assert_equal "/teams/blog/images?article=abcdefghijkmno", data["rich-text-editor-upload-url-value"]
      assert_equal %w[image/jpeg image/png image/webp], JSON.parse(data["rich-text-editor-accept-value"])
      assert_equal [ IMAGE::MAX_BYTES, IMAGE::MAX_SIDE, IMAGE::MAX_PER_ARTICLE ],
                   data.values_at("rich-text-editor-max-bytes-value", "rich-text-editor-max-side-value",
                                  "rich-text-editor-max-count-value")
      lang = JSON.parse(data["rich-text-editor-lang-value"])
      assert_equal [ "Gras", "Ajoutez une légende…" ], lang.values_at("bold", "captionPlaceholder")
    end

    test "les messages : plafonds interpolés par le serveur (« 1 Mo », 10), jetons du navigateur laissés intacts" do
      messages = JSON.parse(article_editor_data(upload_url: "/teams/blog/images")["rich-text-editor-messages-value"])

      assert_equal %w[refused format too_heavy too_many web_image forbidden failed uploading uploaded waiting not_saved], messages.keys
      assert_equal "L'image dépasse 1 Mo, même allégée.", messages["too_heavy"]
      assert_equal "L'article a déjà 10 images dans son texte.", messages["too_many"]
      assert_equal "« %{name} » n'a pas été ajoutée. %{reason}", messages["refused"]
      assert_includes messages["uploaded"], "%{number}"
    end

    test "article_editor_body : le texte enregistré passe au format de Trix, l'image avec son adresse et ses dimensions" do
      image = create_article_image
      html = article_editor_body(article_body_with(image, text: "Avant l'image"))

      figure = Nokogiri::HTML5.fragment(html).at_css("figure[data-trix-attachment]")
      attachment = JSON.parse(figure["data-trix-attachment"])
      assert_equal [ image.attachable_sgid, blog_image_path(image.public_id), 64, 48 ],
                   attachment.values_at("sgid", "url", "width", "height")
      assert_includes html, "Avant l'image"
    end

    test "article_editor_body : un texte vide reste vide ; le HTML de Trix déjà converti revient à l'identique" do
      image = create_article_image
      trix = article_editor_body(article_body_with(image))

      assert_equal "", article_editor_body(nil)
      assert_equal trix, article_editor_body(trix)
    end
  end
end
