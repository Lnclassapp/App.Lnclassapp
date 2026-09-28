require "test_helper"

class ComponentsHelperTest < ActionView::TestCase
  class Record
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :level, :string
    attribute :terms, :boolean
  end

  # --- Icônes -----------------------------------------------------------------

  test "ui_icon inlines a decorative heroicon by default" do
    show ui_icon("home")

    assert_select "svg.shrink-0.size-5[aria-hidden=true][focusable=false]"
    assert_select "svg[role]", 0
  end

  test "ui_icon becomes an image with a label, in any set and size" do
    show ui_icon("home", variant: :mini, size: :xl, label: "Accueil <b>", class: "text-brand")

    assert_select "svg.size-8.text-brand[role=img][aria-label='Accueil <b>']"
    assert_select "svg[aria-hidden]", 0
  end

  test "ui_icon refuses an unknown icon, a suspicious name and an unknown variant" do
    assert_raises(ArgumentError) { ui_icon("does-not-exist") }
    assert_raises(ArgumentError) { ui_icon("../../etc/passwd") }
    assert_raises(ArgumentError) { ui_icon("home", variant: :duotone) }
  end

  test "ui_spinner spins at the requested size" do
    show ui_spinner(size: :lg)

    assert_select "svg.animate-spin.size-6[aria-hidden=true]"
  end

  # --- Boutons ----------------------------------------------------------------

  test "ui_button renders a typed button with its variant and size" do
    show ui_button("Enregistrer", variant: :brand, size: :lg, type: :submit, full: true, class: "mt-4")

    assert_select "button[type=submit].bg-brand.min-h-14.w-full.mt-4", text: "Enregistrer"
    assert_select "button[disabled]", 0
  end

  test "ui_button accepts a block as its label and icons on both sides" do
    show ui_button(icon: "plus", icon_end: "chevron-right") { "Ajouter" }

    assert_select "button", text: "Ajouter"
    assert_select "button svg", 2
  end

  test "ui_button announces its loading state and is disabled meanwhile" do
    show ui_button("Envoyer", loading: true)

    assert_select "button[disabled][aria-busy=true] svg.animate-spin"
    assert_select "button .sr-only", text: I18n.t("components.button.loading")
  end

  test "ui_button becomes a link, with a Turbo method when asked" do
    show ui_button("Supprimer", href: "/x", variant: :danger, method: :delete, data: { confirm: "?" })

    assert_select "a[href='/x'][data-turbo-method=delete][data-confirm='?'].bg-error"
  end

  test "ui_button link without method keeps its data untouched" do
    show ui_button("Voir", href: "/x", variant: :ghost, size: :sm)

    assert_select "a[href='/x']:not([data-turbo-method]).h-10"
  end

  test "a disabled link keeps its place but loses its href" do
    show ui_button("Suivant", href: "/x", disabled: true, variant: :secondary)

    assert_select "a[role=link][aria-disabled=true]:not([href])"
  end

  test "ui_button refuses an unknown variant or size" do
    assert_raises(ArgumentError) { ui_button("x", variant: :fancy) }
    assert_raises(ArgumentError) { ui_button("x", size: :xxl) }
  end

  # --- Cartes -----------------------------------------------------------------

  test "ui_card renders header, actions, body and footer" do
    html = ui_card(title: "Classes", subtitle: "3 classes", icon: "user-group", heading: :h3, padding: :lg, id: "c") do |card|
      card.actions { "Tout voir" }
      card.footer { "Pied" }
      "Corps"
    end
    show html

    assert_select "div#c.rounded-card.p-6 h3", text: "Classes"
    assert_select "div#c p", text: "3 classes"
    assert_select "div#c svg"
    assert_select "div#c", text: /Tout voir.*Corps.*Pied/m
  end

  test "ui_card without block nor header renders an empty card" do
    show ui_card(padding: :none)

    assert_select "div.rounded-card:not(.p-5)"
    assert_select "h2", 0
  end

  test "ui_card with an href is a lifting link" do
    show ui_card(title: "Cours", href: "/courses", padding: :sm) { "Corps" }

    assert_select "a[href='/courses'].hover\\:shadow-lift.p-4 h2", text: "Cours"
  end

  test "ui_card refuses an unknown padding" do
    assert_raises(ArgumentError) { ui_card(padding: :huge) }
  end

  # --- Champs -----------------------------------------------------------------

  test "ui_field renders label, hint and control wired together" do
    show view.fields(:user, model: Record.new) { |form| ui_field(form, :name, hint: "Aide", required: true, placeholder: "Awa") }

    assert_select "label[for=user_name]", text: /Name/
    assert_select "input#user_name[type=text][required][placeholder=Awa][aria-describedby=user_name_hint]"
    assert_select "input:not([aria-invalid]).border-line.min-h-tap"
    assert_select "p#user_name_hint", text: "Aide"
  end

  test "ui_field shows the first error and marks the control invalid" do
    record = Record.new
    record.errors.add(:level, "Premier")
    record.errors.add(:level, "Second")
    show view.fields(:user, model: record) { |form|
      ui_field(form, :level, as: :select, label: "Niveau", choices: %w[6e 5e], prompt: "Choisir")
    }

    assert_select "select#user_level.border-error.appearance-none[aria-invalid=true][aria-describedby=user_level_error]"
    assert_select "select option", text: "Choisir"
    assert_select "p#user_level_error", text: "Premier"
    assert_select "label", text: "Niveau"
  end

  test "ui_field renders a checkbox and a textarea" do
    show view.fields(:user, model: Record.new) { |form|
      ui_field(form, :terms, as: :checkbox, label: "J'accepte") + ui_field(form, :name, as: :textarea)
    }

    assert_select "input[type=checkbox].size-5"
    assert_select "textarea.min-h-32"
  end

  test "ui_field works without a model and humanizes the label" do
    show view.fields(:search) { |form| ui_field(form, :query_text, as: :search) }

    assert_select "input[type=search]#search_query_text"
    assert_select "label", text: "Query text"
  end

  test "ui_field refuses an unknown type" do
    assert_raises(ArgumentError) { view.fields(:user) { |form| ui_field(form, :name, as: :color_wheel) } }
  end

  # --- Groupe de boutons radio ------------------------------------------------

  test "ui_radio_group renders a legend and one 48 px option per choice, checking the object's value" do
    show view.fields(:user, model: Record.new(level: "5e")) { |form|
      ui_radio_group(form, :level, label: "Niveau", required: true, choices: [ [ "Sixième", "6e" ], [ "Cinquième", "5e" ] ])
    }

    assert_select "fieldset#user_level > legend", text: /Niveau\s*\*/
    assert_select "fieldset .sm\\:grid-cols-2 > label.min-h-tap.border-line", 2
    assert_select "label", text: "Sixième" do
      assert_select "input#user_level_6e[type=radio][name='user[level]'][value='6e'][required]:not([checked])"
    end
    assert_select "input#user_level_5e[type=radio][checked]"
    assert_select "input[aria-invalid], input[aria-describedby], p", 0
  end

  test "ui_radio_group wires its hint and first error to every option" do
    record = Record.new
    record.errors.add(:level, "Premier")
    record.errors.add(:level, "Second")
    show view.fields(:user, model: record) { |form|
      ui_radio_group(form, :level, hint: "Aide", columns: 3, choices: [ %w[6e 6e], %w[5e 5e] ])
    }

    assert_select "legend", text: "Level"
    assert_select "legend span", 0
    assert_select "div.sm\\:grid-cols-3 > label.border-error", 2
    assert_select "input[type=radio]:not([required]):not([checked])[aria-invalid=true][aria-describedby='user_level_hint user_level_error']", 2
    assert_select "fieldset > p#user_level_hint + p#user_level_error", text: "Premier"
  end

  test "ui_radio_group stacks its options on one column and refuses an unknown column count" do
    show view.fields(:user, model: Record.new) { |form| ui_radio_group(form, :level, columns: 1, choices: [ %w[A a] ]) }

    assert_select "fieldset div.grid:not([class*=grid-cols]) > label", 1
    assert_raises(ArgumentError) { view.fields(:user) { |form| ui_radio_group(form, :level, columns: 4, choices: []) } }
  end

  # --- Modale, menu, onglets --------------------------------------------------

  test "ui_modal renders a native dialog with its trigger and footer" do
    html = ui_modal(title: "Nouvelle classe", trigger: "Ouvrir", trigger_icon: "plus", size: :lg, open: true) do |modal|
      modal.footer { "Pied" }
      "Corps"
    end
    show html

    assert_select "[data-controller=modal][data-modal-open-value=true]"
    assert_select "button[aria-controls=modal-nouvelle-classe][aria-haspopup=dialog]", text: "Ouvrir"
    assert_select "dialog#modal-nouvelle-classe.sm\\:max-w-2xl[aria-labelledby=modal-nouvelle-classe-title]", text: /Corps.*Pied/m
  end

  test "ui_modal without trigger nor block keeps an explicit id" do
    show ui_modal(title: "Info", id: "info")

    assert_select "dialog#info"
    assert_select "button[aria-haspopup]", 0
  end

  # Chantier modales-sans-js : une modale servie ouverte l'est dès le HTML, pour rester lisible sans JavaScript ; une
  # modale à déclencheur reste fermée.
  test "ui_modal served open carries the open attribute of its dialog, a closed one does not" do
    show ui_modal(title: "Modifier", id: "served", open: true) + ui_modal(title: "Plus tard", id: "later", trigger: "Ouvrir")

    assert_select "dialog#served[open]"
    assert_select "dialog#later[open]", 0
  end

  test "ui_dropdown renders a menu button and its items" do
    html = ui_dropdown(label: "Actions", align: :start) do
      ui_dropdown_item("Modifier", href: "/edit", icon: "pencil") +
        ui_dropdown_item("Supprimer", href: "/x", method: :delete, tone: :danger) +
        ui_dropdown_item("Bientôt")
    end
    show html

    assert_select "button[aria-haspopup=menu][aria-expanded=false][aria-controls=menu-actions]"
    assert_select "div#menu-actions[role=menu][hidden].left-0"
    assert_select "a[role=menuitem][href='/edit'] svg"
    assert_select "a[role=menuitem][data-turbo-method=delete].text-error"
    assert_select "span[role=menuitem][aria-disabled=true]", text: "Bientôt"
  end

  test "ui_dropdown_item marks the link of the current page, never an action on it (UDR-0041)" do
    request.path_info = "/profile"
    show ui_dropdown_item("Mon profil", href: "/profile") + ui_dropdown_item("Modifier", href: "/edit") +
         ui_dropdown_item("Supprimer", href: "/profile", method: :delete)

    assert_select "a[aria-current=page][href='/profile']", text: "Mon profil"
    assert_select "a[aria-current]", 1
  end

  test "ui_dropdown accepts a custom trigger and id" do
    show ui_dropdown(label: "Compte", id: "account", trigger: "Awa") { "" }

    assert_select "button[aria-controls=account]", text: /Awa/
    assert_select "div#account.right-0"
    assert_select "[data-dropdown-fixed-value]", 0
    assert_select "div#account.z-30"
  end

  test "ui_dropdown fixed escapes a scrolling table and follows it (UDR-0042)" do
    show ui_dropdown(label: "Actions pour Abidjan 1", id: "row-menu", fixed: true) { "" }

    assert_select "[data-controller=dropdown][data-dropdown-fixed-value=true]"
    assert_select "div#row-menu[role=menu].z-50", 1, "au-dessus de la barre basse (z-40) du mobile"
    assert_select "[data-controller=dropdown][data-action*='scroll@window->dropdown#place:capture']"
    assert_select "[data-controller=dropdown][data-action*='resize@window->dropdown#place']"
    assert_select "button[aria-label='Actions pour Abidjan 1'][aria-controls=row-menu] svg"
  end

  test "ui_dropdown_item frame: opens the link in a Turbo frame and dismisses the menu (UDR-0042)" do
    show ui_dropdown_item("Modifier", href: "/drenas/1/edit", icon: "pencil-square", frame: "modal")

    assert_select "a[role=menuitem][tabindex='-1'][href='/drenas/1/edit'][data-turbo-frame=modal]" \
                  "[data-action='dropdown#dismiss']", text: "Modifier"
    assert_select "a[data-turbo-method]", 0
  end

  test "ui_dropdown_item dialog: is a button that opens a dialog of the page (UDR-0042)" do
    show ui_dropdown_item("Supprimer", dialog: "delete-drena-1", icon: "trash", tone: :danger)

    assert_select "button[type=button][role=menuitem][tabindex='-1'][aria-haspopup=dialog][aria-controls=delete-drena-1]" \
                  "[data-action='dropdown#openDialog'][data-dropdown-dialog-param=delete-drena-1].text-error.min-h-tap svg",
                  count: 1
    assert_select "button", text: "Supprimer"
    assert_select "a", 0
  end

  test "ui_dropdown_item keeps the default tone for a dialog, and refuses an unknown tone" do
    show ui_dropdown_item("Désactiver", dialog: "deactivate-school-1")

    assert_select "button.text-ink[role=menuitem]", text: "Désactiver"
    assert_select "button.text-error", 0
    assert_raises(ArgumentError) { ui_dropdown_item("X", dialog: "x", tone: :loud) }
  end

  test "ui_tabs selects the first tab unless told otherwise" do
    html = ui_tabs(id: "t", label: "Vues") do |tabs|
      tabs.tab(:one, "Un", icon: "home") { "Premier" }
      tabs.tab(:two, "Deux") { "Second" }
    end
    show html

    assert_select "[role=tablist][aria-label=Vues]"
    assert_select "button#t-tab-one[aria-selected=true][tabindex='0'] svg"
    assert_select "button#t-tab-two[aria-selected=false][tabindex='-1']"
    assert_select "div#t-panel-two[hidden]", text: "Second"
  end

  test "ui_tabs honours an explicit selection and tolerates no tab" do
    show ui_tabs(id: "t", selected: :two) { |tabs| tabs.tab(:one, "Un") { "A" } }

    assert_select "div#t-panel-one[hidden]"
    assert_empty ui_tabs(id: "e") { nil }.scan("role=\"tab\"")
  end

  # --- Badges et avatars ------------------------------------------------------

  test "ui_badge renders a tone, a dot and an icon" do
    show ui_badge("Validé", tone: :success, size: :sm, icon: "check-circle", dot: true)

    assert_select "span.bg-success-soft.text-2xs", text: "Validé"
    assert_select "span span.bg-success[aria-hidden=true]"
    assert_select "span svg"
  end

  test "ui_badge refuses an unknown tone" do
    assert_raises(ArgumentError) { ui_badge("x", tone: :lilac) }
  end

  test "ui_role_badge names the role in its colour" do
    show ui_role_badge(:school_admin)

    assert_select "span.bg-school\\/10", text: I18n.t("shared.roles.school_admin")
    assert_raises(ArgumentError) { ui_role_badge(:parent) }
  end

  test "ui_subject_badge takes its tint from the category, never from the name" do
    show ui_subject_badge("Mathématiques", category: "science") + ui_subject_badge("Mathématiques", category: :literature)

    assert_select "span.bg-brand-soft", text: "Mathématiques"
    assert_select "span.bg-gold\\/20", text: "Mathématiques"
  end

  test "ui_subject_badge falls back to neutral for an unknown or missing category" do
    show ui_subject_badge("Latin", category: :ancient) + ui_subject_badge("Latin", category: nil, size: :sm)

    assert_select "span.bg-mist", 2
  end

  test "ui_avatar shows initials on a stable tone" do
    show ui_avatar("Awa Marie Koné", size: :lg)

    assert_select "span[role=img][aria-label='Awa Marie Koné'].size-14", text: "AK"
    assert_equal ui_avatar("Awa Marie Koné"), ui_avatar("Awa Marie Koné")
  end

  test "ui_avatar handles one word, no name, an explicit tone and a photo" do
    assert_includes ui_avatar("Kouassi", tone: :school), ">K<"
    assert_includes ui_avatar(nil), ">?<"
    show ui_avatar("Awa", src: "/a.png", size: :sm)

    assert_select "img[alt=Awa][src='/a.png'].size-8"
  end

  # --- Toasts -----------------------------------------------------------------

  test "ui_toast carries its message, title and delay" do
    show ui_toast("Cours enregistré", type: :warning, title: "Attention !")

    assert_select "div[data-controller=toast][data-toast-delay-value='8000'][data-toast-type=warning]:not([role])"
    assert_select "p", text: "Attention !"
    assert_select "p", text: "Cours enregistré"
  end

  test "an error toast is an alert, and a persistent toast never leaves by itself" do
    show ui_toast("Échec", type: :error) + ui_toast("Info", persistent: true)

    assert_select "div[role=alert][data-toast-delay-value='0']", text: /#{I18n.t("components.toast.titles.error")}/
    assert_select "div[data-toast-type=info][data-toast-delay-value='0']"
  end

  test "toast_type_for maps Rails flash keys" do
    assert_equal :success, toast_type_for(:notice)
    assert_equal :error, toast_type_for("alert")
    assert_equal :warning, toast_type_for(:warning)
    assert_equal :info, toast_type_for(:whatever)
  end

  test "flash_toast renders a flash message, or a message with its own title; any other value renders nothing" do
    show flash_toast(:alert, "Échec") + flash_toast(:info, { "message" => "Une seule à la fois.", "title" => "Déjà en cours" })

    assert_select "div[role=alert][data-toast-type=error]", text: /#{I18n.t("components.toast.titles.error")}\s*Échec/
    assert_select "div[data-toast-type=info]:not([role=alert])" do
      assert_select "p.font-semibold", text: "Déjà en cours"
      assert_select "p.text-mute", text: "Une seule à la fois."
    end
    assert_nil flash_toast(:reload_document, true)
  end

  test "turbo_stream_toast appends the rendered toast to the stack" do
    show view.turbo_stream_toast("Fait", type: :success)

    assert_select "turbo-stream[action=append][target=toasts] template"
    assert_includes rendered, "Fait"
  end

  # --- États ------------------------------------------------------------------

  test "ui_empty_state with a described action" do
    show ui_empty_state(title: "Vide", description: "Rien ici", icon: "building-library",
                                action: { label: "Créer", href: "/new", icon: "plus" })

    assert_select "p", text: "Vide"
    assert_select "p", text: "Rien ici"
    assert_select "a[href='/new'].bg-ink", text: "Créer"
  end

  test "ui_empty_state with a free block or nothing" do
    show ui_empty_state(title: "Vide") { "Libre" } + ui_empty_state(title: "Nu", action: { label: "A", href: "/", variant: :secondary })

    assert_includes rendered, "Libre"
    assert_select "a.bg-white", text: "A"
    assert_no_match(/<a|<button/, ui_empty_state(title: "Sans action"))
  end

  test "ui_error_state has default words and an optional retry" do
    show ui_error_state + ui_error_state(title: "Refusé", message: "Non", retry_href: "/r", retry_label: "Encore")

    assert_select "[role=alert]", 2
    assert_select "p", text: I18n.t("components.error_state.title")
    assert_select "a[href='/r']", text: "Encore"
  end

  test "ui_loading_state as spinner or skeleton" do
    show ui_loading_state + ui_loading_state(label: "Chargement des classes", variant: "skeleton", lines: 4)

    assert_select "[role=status] svg.animate-spin"
    assert_select "[role=status][aria-busy=true] .animate-pulse", 5
    assert_select ".sr-only", text: "Chargement des classes"
    assert_raises(ArgumentError) { ui_loading_state(variant: :shimmer) }
  end

  # --- Pagination et en-tête --------------------------------------------------

  test "ui_pagination renders nothing for a single page" do
    assert_nil ui_pagination(page: 1, pages: 1)
    assert_nil ui_pagination(page: 1, pages: nil)
  end

  test "ui_pagination keeps the query string and links both ways" do
    request.path = "/schools"
    request.query_string = "q=abidjan&page=3"
    show ui_pagination(page: "3", pages: 5)

    assert_select "nav a[rel=prev][href='/schools?page=2&q=abidjan']"
    assert_select "nav a[rel=next][href='/schools?page=4&q=abidjan']"
    assert_select "nav p", text: I18n.t("components.pagination.status", page: 3, pages: 5)
  end

  test "ui_pagination disables the ends and clamps the page" do
    show ui_pagination(page: 0, pages: 2, param: :p) + ui_pagination(page: 9, pages: 2)

    assert_select "button[disabled]", text: /#{I18n.t("components.pagination.previous")}/
    assert_select "a[rel=next][href$='p=2']"
    assert_select "a[rel=prev][href$='page=1']"
    assert_select "button[disabled]", text: /#{I18n.t("components.pagination.next")}/
  end

  test "ui_page_header with or without actions" do
    show ui_page_header(title: "Mes classes", subtitle: "3") { "Action" } + ui_page_header(title: "Seul")

    assert_select "h1", text: "Mes classes"
    assert_select "h1", text: "Seul"
    assert_includes rendered, "Action"
  end

  private

  # Les helpers rendent leurs partials par `render`, qui accumule dans `rendered` : on n'examine que le fragment voulu.
  def show(html)
    self.rendered = self.class.content_class.new(html.to_s)
  end
end
