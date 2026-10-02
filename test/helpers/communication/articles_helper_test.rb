require "test_helper"

# UDR-0064 §3.1, ADR-0073 §4.4, §4.6 : l'adresse d'une image d'article, les adresses absolues sur l'hôte canonique
# (jamais request.host : lnclass.com et www.lnclass.com servent tous deux l'application), la date d'un article.
module Communication
  class ArticlesHelperTest < ActionView::TestCase
    Image = Data.define(:public_id, :alt, :width, :height)

    def with_canonical_host(host)
      previous = Rails.configuration.x.canonical_host
      Rails.configuration.x.canonical_host = host
      yield
    ensure
      Rails.configuration.x.canonical_host = previous
    end

    test "une image d'article est servie par Lnclass, à son adresse publique" do
      assert_equal "/blog/images/abcdefghijkmno", article_image_src(Image.new(public_id: "abcdefghijkmno", alt: "", width: 1, height: 1))
    end

    test "BL-03 : une adresse absolue vise https://lnclass.com par défaut, l'hôte canonique configuré sinon" do
      assert_equal "lnclass.com", Rails.configuration.x.canonical_host
      assert_equal "https://lnclass.com/blog/reviser-le-bepc", canonical_url("/blog/reviser-le-bepc")

      with_canonical_host("www.lnclass.com") do
        request.host = "lnclass.com"

        assert_equal "https://www.lnclass.com/sitemap.xml", canonical_url("/sitemap.xml")
      end
    end

    test "la date d'un article s'écrit en toutes lettres" do
      assert_equal "5 octobre 2026", article_date(Date.new(2026, 10, 5))
      assert_equal "1 janvier 2027", article_date(Date.new(2027, 1, 1))
    end
  end
end
