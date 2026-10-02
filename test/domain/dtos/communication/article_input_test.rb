require "test_helper"

# ADR-0073 §4.1, UDR-0065 §3.0, §3.3 : la saisie d'un article dans la modale de l'équipe ; ses plafonds, sa signature, et
# les images du texte que la modale montre, gardées d'un re-rendu 422 à l'autre.
module Dtos
  module Communication
    class ArticleInputTest < ActiveSupport::TestCase
      Image = ArticleInput::Image

      def input(**attributes)
        ArticleInput.new(title: "Réviser le BEPC", excerpt: "Un plan.", body: "<div>Texte</div>", signature: "team", **attributes)
      end

      def details(dto)
        dto.valid?
        dto.errors.details.transform_values { |list| list.map { it[:error] } }
      end

      test "un nouvel article est signé « L'équipe Lnclass », sans couverture ni image" do
        dto = ArticleInput.new

        assert_equal [ "team", nil, nil, {}, [] ], [ dto.signature, dto.cover_public_id, dto.cover_alt, dto.image_alts, dto.images ]
        assert_equal [ "", nil, "" ], [ dto.title, dto.excerpt, dto.body ]
      end

      test "les saisies sont nettoyées des blancs superflus" do
        dto = ArticleInput.new(title: "  Réviser   le BEPC ", excerpt: " Un  plan. ", cover_public_id: " cover000000001 ",
                               cover_alt: "  ", signature: " author ", image_alts: { image000000001: " Un  tableau ", "image000000002" => " " })

        assert_equal [ "Réviser le BEPC", "Un plan.", "cover000000001", nil, "author" ],
                     [ dto.title, dto.excerpt, dto.cover_public_id, dto.cover_alt, dto.signature ]
        assert_equal({ "image000000001" => "Un tableau", "image000000002" => nil }, dto.image_alts)
      end

      test "plafonds : titre 120, résumé 200, texte 100 000, textes de remplacement 150 ; signature team ou author" do
        assert input.valid?
        assert input(title: "x" * 120, excerpt: "x" * 200, body: "x" * 100_000, cover_alt: "x" * 150,
                     image_alts: { "image000000001" => "x" * 150 }).valid?

        dto = input(title: "x" * 121, excerpt: "x" * 201, body: "x" * 100_001, signature: "moi", cover_alt: "x" * 151,
                    image_alts: { "image000000001" => "x" * 151, "image000000002" => "court" })

        assert_equal({ title: [ :too_long ], excerpt: [ :too_long ], body: [ :too_long ], signature: [ :inclusion ],
                       cover_alt: [ :too_long ], "image_alts.image000000001": [ :too_long ] }, details(dto))
      end

      test "un titre est exigé dès le brouillon ; chaque refus a son message en français" do
        dto = input(title: " ", excerpt: "x" * 201, body: "x" * 100_001, signature: "moi", cover_alt: "x" * 151,
                    image_alts: { "image000000001" => "x" * 151 })
        dto.valid?

        assert_equal({ title: [ "Indiquez le titre de l'article." ],
                       excerpt: [ "Le résumé dépasse 200 caractères." ],
                       body: [ "Le texte dépasse 100000 caractères : raccourcissez-le." ],
                       signature: [ "Choisissez une signature." ],
                       cover_alt: [ "Le texte de remplacement dépasse 150 caractères." ],
                       "image_alts.image000000001": [ "Le texte de remplacement dépasse 150 caractères." ] }, dto.errors.to_hash)
      end

      test "les images du texte, dans l'ordre du texte, se gardent avec leur sgid, leur adresse et leur texte" do
        images = [ Image.new(public_id: "image000000001", sgid: "s1", url: "/blog/images/image000000001", alt: "Un tableau") ]

        assert_equal images, input(images:).images
        assert_equal "s1", images.first.sgid
      end

      test "l'article à vérifier pour la publication reprend la saisie, la couverture et les images dans l'ordre du texte" do
        dto = input(cover_public_id: "cover000000001", cover_alt: "Des élèves",
                    images: [ Image.new(public_id: "image000000002", sgid: "s2", url: "/b/2", alt: nil),
                              Image.new(public_id: "image000000001", sgid: "s1", url: "/b/1", alt: nil) ],
                    image_alts: { "image000000002" => "Un cahier" })

        article = dto.to_article(status: "published")

        assert_equal [ "Réviser le BEPC", "Un plan.", "<div>Texte</div>", "team", "published", "Des élèves" ],
                     [ article.title, article.excerpt, article.body, article.signature, article.status, article.cover_alt ]
        assert_equal Entities::Communication::ArticleImage.new(public_id: "cover000000001"), article.cover
        assert_equal [ [ "image000000002", "Un cahier" ], [ "image000000001", nil ] ], article.images.map { [ it.public_id, it.alt ] }
        assert_equal [ :"image_alts.image000000001" ], article.publication_errors.keys
        assert_nil input.to_article(status: "draft").cover
      end
    end
  end
end
