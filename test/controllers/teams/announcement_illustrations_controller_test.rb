require "test_helper"

# ADR-0081 §4.3, UDR-0075 §3.5 : la page « Illustrations d'annonce » de l'équipe. Elle ajoute un dessin SVG reconstruit
# (AV-08, AV-09), le renomme, le retire (AV-10) ; tout autre rôle reçoit 403, un visiteur va à « Se connecter » (AV-11).
class Teams::AnnouncementIllustrationsControllerTest < ActionDispatch::IntegrationTest
  ILLUSTRATION = Entities::Communication::Illustration
  BASE = Entities::Communication::Message::ILLUSTRATIONS
  REFUSALS = {
    unsafe: "Ce dessin n'est pas accepté : il contient autre chose que des formes.",
    not_svg: "Ce fichier n'est pas un dessin SVG.",
    empty: "Ce dessin est vide.",
    heavy: "Ce fichier est trop lourd (50 Ko au plus)."
  }.freeze

  setup do
    @fatou = create_team_member(team_role: "content", first_name: "Fatou")
  end

  def tl(key, **) = I18n.t("teams.announcement_illustrations.#{key}", **)
  def svg(name) = fixture_file_upload("illustrations/#{name}", "image/svg+xml")
  def add(name: "Bus scolaire", file: svg("inkscape_bus.svg")) = post(teams_announcement_illustrations_path, params: { illustration: { name:, file: }.compact })
  def rename(public_id, name) = patch(teams_announcement_illustration_path(public_id), params: { illustration: { name: } })
  def retire(public_id) = post(teams_announcement_illustration_retirement_path(public_id))
  def library = Repositories::Communication::IllustrationRepository.new

  # Chaque geste de la page, et les pages elles-mêmes, pour une illustration existante.
  def every_request(illustration)
    [ -> { get teams_announcement_illustrations_path }, -> { add }, -> { get edit_teams_announcement_illustration_path(illustration.public_id) },
      -> { rename(illustration.public_id, "Car") }, -> { retire(illustration.public_id) } ]
  end

  test "AV-11 — un enseignant, une direction ou un élève reçoit 403 sur chaque page et chaque geste ; rien ne change" do
    bus = create_illustration(name: "Bus scolaire", created_by: @fatou)

    [ create_teacher, create_school_admin, create_student ].each do |someone|
      sign_in_as someone
      assert_no_difference -> { Orm::MessageIllustration.count } do
        every_request(bus).each do |request|
          request.call

          assert_response :forbidden
        end
      end
      sign_out
    end
    assert_equal [ "Bus scolaire", nil ], bus.reload.values_at(:name, :retired_at)
  end

  test "AV-11 — un visiteur est envoyé à « Se connecter »" do
    every_request(create_illustration(name: "Bus scolaire", created_by: @fatou)).each do |request|
      request.call

      assert_redirected_to new_session_path
    end
  end

  test "la page « Illustrations d'annonce » : titre, retour au Référentiel, entrée courante, formulaire d'ajout" do
    sign_in_as @fatou

    get teams_announcement_illustrations_path

    assert_response :success
    assert_select "title", "Illustrations d'annonce · Équipe · Lnclass"
    assert_select "main h1", "Illustrations d'annonce"
    assert_select "main p", "Les auteurs les choisissent pour leurs annonces."
    assert_select "main a[href='#{teams_referential_path}']", text: /Référentiel/
    assert_select "nav#sidebar_secondary a[aria-current=page][href='#{teams_referential_path}']"
    # « advance » : le succès revient sur la page, que Turbo fusionnerait (morph) en gardant le fichier choisi.
    assert_select "form#illustration-form[action='#{teams_announcement_illustrations_path}'][method=post][enctype='multipart/form-data']" \
                  "[data-turbo-action=advance]" do
      assert_select "input#illustration_name[name='illustration[name]'][maxlength='30'][required]"
      assert_select "label[for=illustration_name]", text: /Nom/
      assert_select "#illustration_name_hint", "30 caractères au plus. Les auteurs le lisent dans le choix."
      assert_select "input#illustration_file[type=file][name='illustration[file]'][accept='image/svg+xml,.svg']:not([value])"
      assert_select "label[for=illustration_file]", text: /Dessin/
      assert_select "#illustration_file_hint", "SVG d'une seule couleur, 50 Ko au plus. Il prend la couleur du thème de l'annonce."
    end
    assert_select "h2", "Ajouter une illustration"
    assert_select "button[type=submit][form=illustration-form]", "Ajouter"
  end

  test "sans illustration de l'équipe : l'état vide, puis les 8 fournies par Lnclass, sans action" do
    sign_in_as @fatou

    get teams_announcement_illustrations_path

    assert_select "section#team_illustrations[aria-labelledby=team_illustrations_title]" do
      assert_select "h2#team_illustrations_title", "Ajoutées par l'équipe"
      assert_select "*", text: "Aucune illustration ajoutée pour l'instant."
      assert_select "li", 0
    end
    assert_select "section#base_illustrations ul.grid.grid-cols-4.gap-2 > li", BASE.size do |items|
      assert_equal BASE.map { I18n.t("communication.illustrations.#{it}") }, items.map { it.text.squish }
    end
    assert_select "section#base_illustrations h2", "Fournies par Lnclass"
    assert_select "section#base_illustrations svg.size-12", BASE.size
    assert_select "section#base_illustrations [role=menu], section#base_illustrations form", 0
  end

  test "chaque illustration de l'équipe : trois aperçus aux thèmes Ciel, Mangue et Nuit, son nom, sa date ; menu si active" do
    @bus = create_illustration(name: "Bus scolaire", created_by: @fatou, created_at: Time.zone.local(2026, 10, 5, 9))
    canteen = create_illustration(name: "Cantine", created_by: @fatou, retired_at: Time.current, created_at: Time.zone.local(2026, 11, 1, 8))
    sign_in_as @fatou

    get teams_announcement_illustrations_path

    assert_select "section#team_illustrations ul.grid.gap-3 > li", 2
    assert_equal %w[ciel mangue nuit], css_select("li#illustration_#{@bus.public_id} [data-announcement-theme]").map { it["data-announcement-theme"] }
    assert_select "li#illustration_#{@bus.public_id}.flex.items-center.gap-3.rounded-ln.border.border-line.p-3" do
      assert_select "[data-announcement-theme].bg-brand-soft.rounded-ln.p-1 > svg.size-12.fill-brand-strong[aria-hidden=true]", 3
      # Sur téléphone, un seul aperçu (Ciel) : le nom garde la place de se lire.
      assert_select "[data-announcement-theme=ciel]:not(.hidden)"
      assert_select "[data-announcement-theme=mangue].hidden.sm\\:block, [data-announcement-theme=nuit].hidden.sm\\:block", 2
      assert_select "p.font-bold.truncate", "Bus scolaire"
      assert_select "p.text-xs.text-mute", text: /Ajoutée le 5 oct\./
      assert_select "*", text: "Retirée", count: 0
      assert_select "a[role=menuitem][href='#{edit_teams_announcement_illustration_path(@bus.public_id)}']", text: "Renommer"
      assert_select "button[role=menuitem]", text: "Retirer"
      assert_select "dialog", text: /Retirer cette illustration \?/ do
        assert_select "*", text: "Elle ne sera plus proposée. Les annonces qui l'utilisent la gardent jusqu'à leur fin."
        assert_select "form[action='#{teams_announcement_illustration_retirement_path(@bus.public_id)}'][method=post]"
        assert_select "button", text: "Annuler"
        assert_select "button[type=submit]", text: "Retirer"
      end
    end
    assert_select "li#illustration_#{canteen.public_id}" do
      assert_select "p.text-xs.text-mute", text: /Ajoutée le 1ᵉʳ nov\./
      assert_select "span", text: "Retirée"
      assert_select "[role=menuitem], dialog", 0
    end
  end

  test "AV-08 — Fatou ajoute « Bus scolaire » : redirection, toast, et l'illustration est proposée après les 8 de base" do
    sign_in_as @fatou

    assert_difference -> { Orm::MessageIllustration.count }, 1 do
      add
    end

    assert_redirected_to teams_announcement_illustrations_path
    assert_response :see_other
    assert_equal "Illustration ajoutée.", flash[:notice]
    bus = Orm::MessageIllustration.last
    assert_equal [ "Bus scolaire", "0 0 64 64", @fatou.id, nil ], bus.values_at(:name, :view_box, :created_by_id, :retired_at)
    assert_equal [ bus.public_id ], library.available.map(&:public_id)
    follow_redirect!
    assert_select "li#illustration_#{bus.public_id}", text: /Bus scolaire/
  end

  test "AV-09 — le dessin enregistré est la reconstruction, et la page le rend depuis elle, jamais depuis le fichier" do
    sign_in_as @fatou
    add

    stored = Orm::MessageIllustration.last
    assert(stored.shapes.all? { ILLUSTRATION.valid_shape?(it, depth: 1) })
    assert_no_match(/inkscape|sodipodi|metadata|style|#1a1a1a|ÉCOLE/i, stored.shapes.to_json)
    get teams_announcement_illustrations_path
    previews = css_select("li#illustration_#{stored.public_id} [data-announcement-theme] > svg")
    assert_equal 3, previews.size
    previews.each do |preview|
      assert_equal "0 0 64 64", preview["viewBox"]
      assert_equal %w[circle ellipse g path rect], preview.css("*").map(&:name).uniq.sort
      assert_empty preview.css("[style], [id], [class], title, text, metadata")
    end
  end

  test "AV-09 — un SVG piégé est refusé en 422, avec sa raison sous « Dessin » ; rien n'est enregistré" do
    sign_in_as @fatou
    {
      "script.svg" => :unsafe, "onload.svg" => :unsafe, "foreign_object.svg" => :unsafe, "href.svg" => :unsafe,
      "xlink_href.svg" => :unsafe, "url_value.svg" => :unsafe, "doctype.svg" => :unsafe, "billion_laughs.svg" => :unsafe,
      "xxe.svg" => :unsafe, "entity_reference.svg" => :unsafe, "style_element.svg" => :unsafe, "use.svg" => :unsafe,
      "image.svg" => :unsafe, "too_many_shapes.svg" => :unsafe, "not_svg_root.svg" => :not_svg, "utf7.svg" => :not_svg,
      "empty_inkscape.svg" => :empty, "no_view_box.svg" => :empty, "too_heavy.svg" => :heavy
    }.each do |file, reason|
      assert_no_difference(-> { Orm::MessageIllustration.count }, file) { add(file: svg(file)) }

      assert_response :unprocessable_entity, file
      assert_select "#illustration_file_error", REFUSALS.fetch(reason), file
      assert_select "input#illustration_name[value='Bus scolaire']", 1, file
    end
  end

  test "la bibliothèque compte 50 illustrations actives au plus : la 51ᵉ est refusée en 422 sous « Dessin », rien n'est enregistré" do
    49.times { create_illustration(name: "Dessin #{it}", created_by: @fatou) }
    create_illustration(name: "Cantine", created_by: @fatou, retired_at: Time.current)
    sign_in_as @fatou

    add
    assert_redirected_to teams_announcement_illustrations_path

    assert_no_difference(-> { Orm::MessageIllustration.count }) { add(name: "Car scolaire") }
    assert_response :unprocessable_entity
    assert_select "#illustration_file_error", "La bibliothèque compte déjà 50 illustrations : retirez-en une avant d'en ajouter."
  end

  test "AV-09 — une image PNG n'est pas un dessin SVG" do
    sign_in_as @fatou

    add(file: fixture_file_upload("photos/photo.png", "image/svg+xml"))

    assert_response :unprocessable_entity
    assert_select "#illustration_file_error", REFUSALS[:not_svg]
  end

  test "sans fichier, ou un texte à la place du fichier : « Choisissez un dessin SVG. » ; un nom vide est refusé sous « Nom »" do
    sign_in_as @fatou

    [ nil, "pas un fichier" ].each do |file|
      add(file:)

      assert_response :unprocessable_entity
      assert_select "#illustration_file_error", "Choisissez un dessin SVG."
    end
    add(name: " ")
    assert_response :unprocessable_entity
    assert_select "#illustration_name_error", "Saisissez un nom."
    assert_select "#illustration_name[aria-invalid=true]"
    assert_equal 0, Orm::MessageIllustration.count
  end

  test "un refus re-rend la liste de l'équipe sous le formulaire" do
    bus = create_illustration(name: "Bus scolaire", created_by: @fatou)
    sign_in_as @fatou

    add(name: "Cantine", file: svg("script.svg"))

    assert_select "li#illustration_#{bus.public_id}", text: /Bus scolaire/
  end

  test "la page de renommage : le nom actuel, un aperçu, retour à la bibliothèque" do
    bus = create_illustration(name: "Bus scolaire", created_by: @fatou)
    sign_in_as @fatou

    get edit_teams_announcement_illustration_path(bus.public_id)

    assert_response :success
    assert_select "title", "#{tl('edit.page_title')} · Équipe · Lnclass"
    assert_select "main h1", tl("edit.title")
    assert_select "main a[href='#{teams_announcement_illustrations_path}']", text: /Illustrations d'annonce/
    assert_select "nav#sidebar_secondary a[aria-current=page][href='#{teams_referential_path}']"
    assert_select "[data-announcement-theme] svg.fill-brand-strong", 3
    assert_select "form#illustration-form[action='#{teams_announcement_illustration_path(bus.public_id)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input#illustration_name[value='Bus scolaire'][maxlength='30'][required]"
      assert_select "input[type=file]", 0
    end
    assert_select "button[type=submit][form=illustration-form]", tl("edit.submit")
  end

  test "l'équipe renomme une illustration : redirection et toast ; un nom vide est refusé en 422 sous « Nom »" do
    bus = create_illustration(name: "Bus scolaire", created_by: @fatou)
    sign_in_as @fatou

    rename(bus.public_id, "Car scolaire")

    assert_redirected_to teams_announcement_illustrations_path
    assert_equal "Illustration renommée.", flash[:notice]
    assert_equal "Car scolaire", bus.reload.name

    rename(bus.public_id, "")
    assert_response :unprocessable_entity
    assert_select "#illustration_name_error", "Saisissez un nom."
    assert_select "[data-announcement-theme] svg", 3
    assert_equal "Car scolaire", bus.reload.name
  end

  test "AV-10 — Fatou retire « Bus scolaire » : elle sort du choix, l'annonce qui la porte la garde" do
    bus = create_illustration(name: "Bus scolaire", created_by: @fatou)
    message = create_message(author: @fatou, illustration: bus, theme: "mangue")
    sign_in_as @fatou

    retire(bus.public_id)

    assert_redirected_to teams_announcement_illustrations_path
    assert_equal "Illustration retirée.", flash[:notice]
    assert_not_nil bus.reload.retired_at
    assert_empty library.available
    assert_equal bus, message.reload.library_illustration
    assert library.find_all_by_ids(ids: [ bus.id ]).fetch(bus.id).retired?
    follow_redirect!
    assert_select "li#illustration_#{bus.public_id}", text: /Retirée/
  end

  test "AV-10 — les 8 de base et une illustration inconnue ne se renomment ni ne se retirent : 404" do
    sign_in_as @fatou

    [ *BASE, "inconnue" ].each do |public_id|
      get edit_teams_announcement_illustration_path(public_id)
      assert_response :not_found, public_id
      rename(public_id, "Car")
      assert_response :not_found, public_id
      retire(public_id)
      assert_response :not_found, public_id
    end
  end
end
