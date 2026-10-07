require "test_helper"

# installation-pwa, Lot A (ADR-0082 §4.1 and §4.2, UDR-0078 §3.2). CA-1: the manifest makes the site installable as
# « Lnclass », with the brand colours of config.x.pwa and three icons that exist in public/. CA-2: the service worker is
# JavaScript the browser revalidates at each visit, keeps only the three offline files and never stores a response.
# The offline page is static, without script, and the same for everyone: no account data, even for a signed-in student.
class PwaTest < ActionDispatch::IntegrationTest
  OFFLINE_FILES = %w[/offline.html /offline.css /icon-192.png].freeze

  # Width and height of a PNG, read from its IHDR chunk (bytes 16 to 24).
  def png_size(path) = File.binread(path, 24).byteslice(16, 8).unpack("NN")

  test "CA-1 — the manifest names the app « Lnclass », in French, standalone, from /?source=app over the whole site" do
    get "/manifest.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    manifest = response.parsed_body
    pwa = Rails.configuration.x.pwa

    assert_equal "Lnclass", manifest["name"]
    assert_equal "Lnclass", manifest["short_name"]
    assert_equal "fr", manifest["lang"]
    assert_equal "Cours, exercices et suivi des classes.", manifest["description"]
    assert_equal "standalone", manifest["display"]
    assert_equal "/?source=app", manifest["start_url"]
    assert_equal "/", manifest["scope"]
    assert_equal "/", manifest["id"]
    assert_equal pwa[:theme_color], manifest["theme_color"]
    assert_equal pwa[:background_color], manifest["background_color"]
  end

  test "CA-1 — the manifest declares a 192 px icon, a 512 px icon and a maskable 512 px icon, PNG files of public/" do
    get "/manifest.json"

    icons = response.parsed_body["icons"]

    assert_equal [ [ "/icon-192.png", "192x192", nil ], [ "/icon.png", "512x512", nil ], [ "/icon-maskable.png", "512x512", "maskable" ] ],
                 icons.map { [ it["src"], it["sizes"], it["purpose"] ] }
    icons.each do |icon|
      assert_equal "image/png", icon["type"]
      file = Rails.public_path.join(icon["src"].delete_prefix("/"))

      assert_predicate file, :exist?, "#{icon['src']} absent de public/"
      assert_equal icon["sizes"].split("x").map(&:to_i), png_size(file), "#{icon['src']} n'a pas la taille déclarée"
    end
  end

  test "CA-1 — a public page declares the manifest in its head" do
    get root_path

    assert_select "head link[rel=manifest][href='/manifest.json']", count: 1
  end

  test "CA-2 — the service worker is JavaScript that must be revalidated before being served again" do
    get "/service-worker.js"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    directives = response.headers["Cache-Control"].to_s.split(",").map(&:strip)

    assert directives.include?("no-cache") || (directives.include?("max-age=0") && directives.include?("must-revalidate")),
           "Cache-Control « #{response.headers['Cache-Control']} » laisse resservir le programme sans revalidation"
  end

  test "CA-2 — the service worker keeps exactly the three offline files and never puts a response in its cache" do
    get "/service-worker.js"

    list = response.body[/^const OFFLINE_FILES = \[([^\]]*)\]/, 1]

    assert list, "constante OFFLINE_FILES introuvable"
    assert_equal OFFLINE_FILES, list.scan(/"([^"]*)"/).flatten
    assert_no_match(/\.put\(/, response.body, "une réponse du réseau n'est jamais mise en cache (ADR-0082 §4.2)")
    assert_match(/addEventListener\("fetch"/, response.body, "Chrome n'installe qu'un site dont le programme répond aux navigations")
    assert_no_match(/addEventListener\("(push|sync)"/, response.body)
  end

  test "CA-3 — the offline page is static French, without script, and shows no account data to a signed-in student" do
    student = create_student(first_name: "Aïcha", last_name: "Bamba")
    sign_in_as student

    get "/offline.html"

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", text: "Pas de connexion · Lnclass"
    assert_select "h1", text: "Pas de connexion"
    assert_select "main.offline p", text: "Lnclass a besoin d'internet pour s'ouvrir. Vérifie ton réseau ou tes données mobiles, puis réessaie."
    assert_select "a.offline-retry[href='']", text: "Réessayer"
    assert_select "link[rel=stylesheet]", count: 1
    assert_select "link[rel=stylesheet][href='/offline.css']"
    assert_select "img", count: 1
    assert_select "img[src='/icon-192.png'][alt=Lnclass]"
    assert_select "script", count: 0
    body = response.body.dup.force_encoding(Encoding::UTF_8) # a file of public/ is served as bytes
    assert_no_match %r{https?://}, body
    [ "Aïcha", "Bamba", student.contact ].each { |data| assert_not_includes body, data }
  end

  test "CA-3 — the offline style sheet is CSS without web font nor external resource" do
    get "/offline.css"

    assert_response :success
    assert_equal "text/css", response.media_type
    assert_no_match(/@font-face|@import|url\(/, response.body)
    assert_match(/prefers-color-scheme: dark/, response.body)
  end
end
