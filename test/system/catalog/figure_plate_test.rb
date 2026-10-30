require "application_system_test_case"

# CA-1 à CA-4 dans un navigateur : la sorte `plate` dessine une planche légendée, en noms ou en numéros, surligne ses parties et, si la
# planche reçue est inconnue, montre la description seule. Le partial rendu par le serveur est injecté dans une page réelle ; la planche
# est modifiée après coup dans le HTML, comme le ferait une page corrompue.
class Catalog::FigurePlateSystemTest < ApplicationSystemTestCase
  HEART = {
    "plate" => "heart", "numbering" => "names", "highlight" => %w[aorta],
    "labels" => [ { "part" => "right_atrium" }, { "part" => "left_ventricle" }, { "part" => "aorta" }, { "part" => "septum", "text" => "Cloison" } ]
  }.freeze
  NAMES = [ "oreillette droite", "ventricule gauche", "aorte", "Cloison" ].freeze

  def figure(params)
    Entities::Catalog::Figure.new(key: "figure-test", kind: "plate", params:, controls: [],
                                  description: Factories::RevisionSheet::FIGURE_DESCRIPTION)
  end

  def html(params) = ApplicationController.render(partial: "catalog/figures/figure", locals: { figure: figure(params) })

  def mount_html(markup)
    visit new_session_path
    page.execute_script(<<~JS, markup)
      document.getElementById("host")?.remove()
      const host = document.createElement("div")
      host.id = "host"
      host.innerHTML = arguments[0]
      document.body.prepend(host)
    JS
  end

  def label_texts = page.evaluate_script("[...document.querySelectorAll('#host svg [data-label]')].map((node) => [...node.querySelectorAll('text')].map((line) => line.textContent.trim()).join(' '))")

  test "a heart plate in names draws four labels with their text, the highlight, and keeps the description for screen readers" do
    mount_html(html(HEART))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host figcaption.sr-only", text: Factories::RevisionSheet::FIGURE_DESCRIPTION, visible: :all
    assert_selector "#host svg [data-plate=heart]", visible: :all
    assert_selector "#host svg [data-label]", count: 4, visible: :all
    assert_equal NAMES.sort, label_texts.sort
    assert_selector "#host svg [data-highlight]", visible: :all
    assert_selector "#host svg [data-part=aorta][data-highlight]", visible: :all
    assert_no_selector "#host svg [data-part=septum][data-highlight]", visible: :all
    assert_selector "#host svg [data-label] line", count: 4, visible: :all
    # L'aorte est un tube : sa teinte primary à 0,35 est le trait superposé à son contour.
    tint = page.evaluate_script("[...document.querySelectorAll('#host svg [data-plate] path')].filter((node) => node.style.stroke.includes('--sheet-primary') && node.getAttribute('stroke-opacity') === '0.35').length")
    assert_equal 1, tint
  end

  test "a highlighted filled part is tinted primary at 0.35" do
    mount_html(html(HEART.merge("highlight" => %w[septum])))

    assert_selector "#host svg [data-part=septum][data-highlight]", visible: :all
    fill, opacity = page.evaluate_script("(() => { const node = document.querySelector('#host svg [data-part=septum][data-highlight]'); return [node.style.fill, node.getAttribute('fill-opacity')] })()")
    assert_includes fill, "--sheet-primary"
    assert_equal "0.35", opacity
  end

  test "the same plate in numbers shows 1 to 4 and no part name" do
    mount_html(html(HEART.merge("numbering" => "numbers")))

    assert_selector "#host [data-figure-state=ready]", visible: :all
    assert_selector "#host svg [data-label]", count: 4, visible: :all
    assert_equal %w[1 2 3 4], label_texts.sort
    NAMES.each { assert_no_selector "#host svg text", text: it, exact_text: true, visible: :all }
    assert_selector "#host svg [data-highlight]", visible: :all
  end

  test "each of the eight plates draws and labels its first part" do
    Entities::Catalog::FigureCatalogs::PLATES.each do |plate, parts|
      mount_html(html({ "plate" => plate, "numbering" => "names", "labels" => [ { "part" => parts.first } ], "highlight" => [ parts.last ] }))

      assert_selector "#host [data-figure-state=ready]", visible: :all
      assert_selector "#host svg [data-plate=#{plate}] [data-part=#{parts.last}][data-highlight]", visible: :all
      assert_selector "#host svg [data-label=#{parts.first}]", visible: :all
    end
  end

  # La planche est posée dans le HTML après coup : l'entité Figure refuserait « skeleton ».
  test "an unknown plate shows the description alone" do
    mount_html(html(HEART).sub("&quot;heart&quot;", "&quot;skeleton&quot;"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
    assert_selector "#host figcaption", text: Factories::RevisionSheet::FIGURE_DESCRIPTION
    assert_no_selector "#host figcaption.sr-only", visible: :all
  end

  # Chaque faute est posée dans le HTML après coup : l'entité Figure la refuserait.
  test "a label of another plate shows the description alone" do
    mount_html(html(HEART).sub("&quot;part&quot;:&quot;aorta&quot;", "&quot;part&quot;:&quot;liver&quot;"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end

  test "an unknown highlight shows the description alone" do
    mount_html(html(HEART).sub("&quot;highlight&quot;:[&quot;aorta&quot;]", "&quot;highlight&quot;:[&quot;liver&quot;]"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end

  test "a part labelled twice shows the description alone" do
    mount_html(html(HEART).sub("&quot;part&quot;:&quot;left_ventricle&quot;", "&quot;part&quot;:&quot;aorta&quot;"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end

  test "a label with an unknown key shows the description alone" do
    mount_html(html(HEART).sub("&quot;part&quot;:&quot;aorta&quot;", "&quot;part&quot;:&quot;aorta&quot;,&quot;texte&quot;:&quot;Aorte&quot;"))

    assert_selector "#host [data-figure-state=error]", visible: :all
    assert_no_selector "#host svg"
  end
end
