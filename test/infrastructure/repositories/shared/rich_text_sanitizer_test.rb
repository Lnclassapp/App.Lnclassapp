require "test_helper"

module Repositories
  module Shared
    class RichTextSanitizerTest < ActiveSupport::TestCase
      test "retire scripts, styles, iframes, attributs on*, liens javascript: et pièces jointes" do
        dirty = %(<p onclick="x()">A<script>alert(1)</script></p><style>p{}</style><iframe src="https://x.test"></iframe>) +
                %(<a href="javascript:alert(1)">lien</a><action-text-attachment sgid="x"></action-text-attachment>)

        clean = RichTextSanitizer.call(dirty)

        assert_equal "<p>A</p><a>lien</a>", clean
      end

      # ADR-0073 §4.5, BL-15 : sans image_ids (cours, fiches, imports), rien ne change : toute pièce jointe part, un h1 reste.
      test "BL-15 : sans image_ids, une image d'article citée part comme toute pièce jointe, et un h1 reste un h1" do
        image = article_image

        assert_equal "<h1>Titre</h1><p>a</p>", RichTextSanitizer.call(%(<h1>Titre</h1><p>a</p>#{attachment(image)}))
      end

      test "garde ce que Trix produit, les liens https et le texte des formules" do
        html = %(<h1>Titre</h1><div><strong>gras</strong> <em>italique</em> $x^2$<br></div><ul><li>un</li></ul>) +
               %(<ol><li>deux</li></ol><blockquote>cite</blockquote><pre>code</pre><a href="https://lnclass.test">lien</a>)

        assert_equal html, RichTextSanitizer.call(html)
        assert_nil RichTextSanitizer.call(nil)
        assert_equal "", RichTextSanitizer.call("")
      end

      # ADR-0068 §4 : une seule analyse donne, octet pour octet, ce que donnaient l'élagage puis la liste blanche de
      # Rails sur un HTML analysé une seconde fois.
      test "une seule analyse rend exactement ce que rendaient les deux, sur les leçons de Tle D" do
        two_passes = Rails::HTML5::SafeListSanitizer.new
        contents = Rails.root.glob("docs/contenus/lecons-traitees/tle-d/*.json").flat_map do |file|
          JSON.parse(file.read).fetch("courses").flat_map { |course| [ course["content"], *course["essentials"].pluck("content") ] }
        end.compact
        contents += [ %(<p>a &amp; b &lt; c &nbsp;é “q” 😀 $\\frac{1}{2}$</p>\n<pre>\ncode\tici</pre>), "<p>non fermé <b>gras", " " ]

        assert_operator contents.size, :>=, 12
        contents.each do |html|
          assert_equal two_passes.sanitize(Loofah.html5_fragment(html).scrub!(:prune).to_s), RichTextSanitizer.call(html)
        end
      end

      # ADR-0073 §4.5 : en mode article, seule une image admise reste, avec les seuls attributs d'une pièce jointe.
      test "BL-02 : avec image_ids, une image admise reste sans url ni href, et un h1 devient un h2" do
        image = article_image
        html = %(<h1>Partie 1</h1><div>Texte</div>) + attachment(image, url: "https://ailleurs.test/x.png", href: "https://x.test",
                                                                          onclick: "x()", caption: "Au tableau")

        assert_equal %(<h2>Partie 1</h2><div>Texte</div><action-text-attachment sgid="#{image.attachable_sgid}" ) +
                     %(content-type="image/webp" width="1600" height="900" caption="Au tableau"></action-text-attachment>),
                     RichTextSanitizer.call(html, image_ids: Set[image.id])
      end

      test "BL-16 : une image d'un autre article, un autre modèle, une image distante, un sgid illisible partent" do
        admitted = article_image
        other = article_image
        user = create_user(role: "student")
        html = attachment(admitted) + attachment(other) +
               %(<action-text-attachment sgid="#{user.to_sgid(expires_in: nil, for: 'attachable')}"></action-text-attachment>) +
               %(<action-text-attachment sgid="faux"></action-text-attachment><action-text-attachment url="https://x.test/a.png" ) +
               %(content-type="image/png"></action-text-attachment><img src="https://x.test/b.png"><img src="data:image/png;base64,AAAA">) +
               %(<action-text-attachment sgid="#{admitted.to_sgid(expires_in: nil, for: 'autre')}"></action-text-attachment>)

        clean = RichTextSanitizer.call(html, image_ids: Set[admitted.id])

        assert_equal [ admitted.attachable_sgid ], Nokogiri::HTML5.fragment(clean).css("action-text-attachment").map { it["sgid"] }
        assert_not_includes clean, "<img"
      end

      test "BL-16 : en mode article aussi, scripts, attributs on*, liens javascript: et contenu glissé dans une pièce jointe partent" do
        image = article_image
        dirty = %(<p onclick="x()">A<script>alert(1)</script></p><a href="javascript:alert(1)">lien</a><style>p{}</style>) +
                %(<action-text-attachment sgid="#{image.attachable_sgid}"><script>alert(2)</script><b>b</b></action-text-attachment>) +
                %(<a href="https://lnclass.test">ok</a>)

        assert_equal %(<p>A</p><a>lien</a><action-text-attachment sgid="#{image.attachable_sgid}"></action-text-attachment>) +
                     %(<a href="https://lnclass.test">ok</a>), RichTextSanitizer.call(dirty, image_ids: Set[image.id])
        assert_nil RichTextSanitizer.call(nil, image_ids: Set[])
      end

      # ADR-0073 §7 : les cours, les fiches et les imports n'admettent jamais d'image ; seul l'adaptateur des articles le fait.
      test "seul l'adaptateur des articles passe image_ids" do
        callers = Rails.root.glob("{app,lib}/**/*.rb").select { it.read.match?(/RichTextSanitizer\.call\([^)]*image_ids:/m) }

        assert_equal [ Rails.root.join("app/infrastructure/repositories/communication/article_repository.rb") ], callers
      end

      private

      def article_image
        Orm::ArticleImage.create!(content_type: "image/webp", byte_size: 2048, width: 1600, height: 900)
      end

      def attachment(image, **attributes)
        extra = attributes.map { |name, value| %( #{name}="#{value}") }.join
        %(<action-text-attachment sgid="#{image.attachable_sgid}" content-type="image/webp" width="1600" height="900"#{extra}>) +
          "</action-text-attachment>"
      end
    end
  end
end
