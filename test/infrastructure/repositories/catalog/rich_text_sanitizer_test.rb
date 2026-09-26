require "test_helper"

module Repositories
  module Catalog
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
      end
    end
  end
end
