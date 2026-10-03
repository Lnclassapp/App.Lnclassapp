require "test_helper"

# ADR-0073 §4.1, §4.2 : un article suit le cycle des contenus ; publier, ou enregistrer un article déjà publié, exige un
# article complet, et chaque manque est nommé par son champ (BL-09, BL-13).
module Entities
  module Communication
    class ArticleTest < ActiveSupport::TestCase
      def image(public_id, alt: "Une salle de classe")
        ArticleImage.new(public_id:, alt:)
      end

      def article(**attributes)
        Article.new(title: "Réviser le BEPC en 4 semaines", excerpt: "Un plan semaine par semaine.",
                    body: "<div>Commencez par les maths.</div>", signature: "team", status: "draft", **attributes)
      end

      test "les plafonds, les signatures et les transitions sont ceux du blog et des contenus" do
        assert_equal [ 120, 200, 100_000 ], [ Article::TITLE_MAX, Article::EXCERPT_MAX, Article::BODY_MAX ]
        assert_equal %w[team author], Article::SIGNATURES
        assert_same Entities::Shared::ContentStatus::TRANSITIONS, Article::TRANSITIONS
      end

      test "un brouillon s'enregistre avec son seul titre ; un titre trop long, une signature ou un statut inconnus non" do
        assert Article.new(title: "Brouillon", signature: "team", status: "draft").valid?

        invalid = Article.new(title: "x" * 121, excerpt: "x" * 201, body: "x" * 100_001, signature: "moi", status: "publié")

        assert_not invalid.valid?
        assert_equal %i[title excerpt body signature status], invalid.errors.attribute_names
        assert_equal [ "Indiquez le titre de l'article." ], Article.new(title: " ", signature: "team", status: "draft")
                                                                   .tap(&:valid?).errors[:title]
      end

      test "un article complet est publiable : aucune erreur" do
        complete = article(cover: image("cover000000001"), cover_alt: "Des élèves au tableau",
                           images: [ image("image000000001"), image("image000000002") ])

        assert_equal({}, complete.publication_errors)
        assert complete.draft?
        assert_not complete.published?
      end

      test "BL-09 : sans résumé ni texte, la publication nomme chaque champ" do
        errors = article(excerpt: "  ", body: "<div><br></div>&nbsp;").publication_errors

        assert_equal %i[excerpt body], errors.keys
        assert_equal [ "Écrivez le résumé : il est obligatoire pour publier." ], errors[:excerpt]
        assert_equal [ "Écrivez le texte de l'article : il est obligatoire pour publier." ], errors[:body]
      end

      test "une espace insécable littérale (U+00A0), comme son entité, ne fait pas un texte" do
        assert_match Article::SPACES, "\u00A0"
        assert_equal [ :body ], article(body: "<div>\u00A0\u00A0</div>").publication_errors.keys
      end

      test "un titre vide est nommé aussi, dans l'ordre du formulaire" do
        assert_equal %i[title excerpt], article(title: "", excerpt: nil).publication_errors.keys
      end

      test "BL-13 : la couverture et chaque image du texte sans texte de remplacement sont nommées, avec leur numéro" do
        errors = article(cover: image("cover000000001"), cover_alt: " ",
                         images: [ image("image000000001"), image("image000000002", alt: nil) ]).publication_errors

        assert_equal [ :cover_alt, :"image_alts.image000000002" ], errors.keys
        assert_equal [ "Décrivez la couverture : son texte de remplacement est obligatoire pour publier." ], errors[:cover_alt]
        assert_equal [ "Saisissez le texte de remplacement de l'image 2 : il est obligatoire pour publier." ],
                     errors[:"image_alts.image000000002"]
      end

      test "sans couverture, aucun texte de remplacement de couverture n'est exigé" do
        assert_equal({}, article(cover: nil, cover_alt: nil).publication_errors)
      end

      test "au plus 10 images dans le texte, couverture non comptée" do
        ten = Array.new(10) { image("image#{it.to_s.rjust(9, '0')}") }

        assert_equal({}, article(images: ten, cover: image("cover000000001"), cover_alt: "Couverture").publication_errors)
        assert_equal [ "Un article compte au plus 10 images dans son texte : retirez-en une." ],
                     article(images: ten + [ image("image999999999") ]).publication_errors[:body]
      end

      test "l'état se lit sur le statut" do
        assert article(status: "published").published?
        assert article(status: "archived").archived?
        assert_equal [], Article.new.images
      end
    end
  end
end
