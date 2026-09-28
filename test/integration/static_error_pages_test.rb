require "test_helper"

# recette-v1-defauts, D2 (UDR-0005): the static error pages Rails serves from public/ speak French, in the colours of
# the design system, without JavaScript nor any external resource, and lead back home. They are served outside the
# application stack, without the CSP of ADR-0049: their inline <style> is the only way to style them.
class StaticErrorPagesTest < ActionDispatch::IntegrationTest
  PAGES = {
    "400" => "Requête invalide",
    "404" => "Page introuvable",
    "422" => "Modification refusée",
    "500" => "Une erreur est survenue"
  }.freeze

  PAGES.each do |code, title|
    test "public/#{code}.html is a French page titled « #{title} », with a link home" do
      get "/#{code}.html"

      assert_response :success
      assert_nil response.headers["Content-Security-Policy"]
      assert_select "html[lang=fr]"
      assert_select "title", text: "#{title} · Lnclass"
      assert_select "h1", text: title
      assert_select "meta[name=viewport][content*='width=device-width']"
      assert_select "a[href='/']", text: "Revenir à l'accueil"
      assert_select "script, link, img", count: 0
      assert_no_match %r{https?://}, response.body
    end
  end
end
