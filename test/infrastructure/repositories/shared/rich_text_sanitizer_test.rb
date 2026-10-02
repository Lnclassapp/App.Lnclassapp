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
    end
  end
end
