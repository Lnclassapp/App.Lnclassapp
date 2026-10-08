require "test_helper"

class ComponentsHelperTest < ActionView::TestCase
  class Record
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :level, :string
    attribute :terms, :boolean
    attribute :pin, :string
    attribute :classrooms
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

  test "ui_icon_sprite draws each icon of its block once, in a <symbol> after the block, taken back by <use>" do
    show(ui_icon_sprite { safe_join([ ui_icon("home"), ui_icon("home", size: :lg), ui_icon("home", variant: :mini, label: "Accueil") ]) })

    assert_select "svg.size-5[aria-hidden=true][focusable=false] use[href='#icon-24-outline-home']"
    assert_select "svg.size-6 use[href='#icon-24-outline-home']"
    assert_select "svg[role=img][aria-label=Accueil] use[href='#icon-20-solid-home']"
    # Lever 3c (ecrans-direction-lents): the root attributes of the file are written once, on the <symbol>.
    assert_select "svg:has(> use)[viewBox], svg:has(> use)[fill], svg:has(> use)[stroke], svg:has(> use)[stroke-width]", 0
    assert_select "svg.absolute.size-0[aria-hidden=true]:last-child" do
      assert_select "symbol", 2
      assert_select "symbol#icon-24-outline-home[viewBox='0 0 24 24'][fill=none][stroke=currentColor][stroke-width='1.5']"
      assert_select "symbol#icon-20-solid-home[viewBox='0 0 20 20'][fill=currentColor]:not([stroke])"
    end
    assert_equal icon_paths(ui_icon("home")), css_select("symbol#icon-24-outline-home[viewBox='0 0 24 24'] path").map { it["d"] }
    assert_select "svg[xmlns], svg[data-slot]", 0
    assert_select "svg > path", 0

    show ui_icon("home")
    assert_select "svg.size-5 > path", true, "après le bloc, l'icône est de nouveau en ligne"
  end

  # Lot E4 (politique-cache) : deux blocs de la même page (pages du catalogue chargées au défilement) ne partagent aucun id.
  test "ui_icon_sprite prefixes its symbols when asked, so that two blocks of a page never share an id" do
    show(safe_join([ ui_icon_sprite { ui_icon("home") }, ui_icon_sprite(prefix: "courses-page-2-") { ui_icon("home") } ]))

    assert_select "use[href='#icon-24-outline-home']", 1
    assert_select "use[href='#courses-page-2-icon-24-outline-home']", 1
    assert_select "symbol#icon-24-outline-home", 1
    assert_select "symbol#courses-page-2-icon-24-outline-home", 1

    show ui_icon_sprite { ui_icon("home") }
    assert_select "symbol#icon-24-outline-home", 1, "le préfixe ne survit pas à son bloc"
  end

  test "ui_spinner spins at the requested size" do
    show ui_spinner(size: :lg)

    assert_select "svg.animate-spin.size-6[aria-hidden=true]"
  end

  # --- Boutons ----------------------------------------------------------------

  test "ui_button renders a typed button with its variant and size" do
    show ui_button("Enregistrer", variant: :brand, size: :lg, type: :submit, full: true, class: "mt-4")

    assert_select "button[type=submit].ui-button-brand.ui-button-lg.w-full.mt-4", text: "Enregistrer"
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

    assert_select "a[href='/x'][data-turbo-method=delete][data-confirm='?'].ui-button-danger"
  end

  test "ui_button link without method keeps its data untouched" do
    show ui_button("Voir", href: "/x", variant: :ghost, size: :sm)

    assert_select "a[href='/x']:not([data-turbo-method]).ui-button-sm"
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

    assert_select "div#c.rounded-card.p-5 h3", text: "Classes"
    assert_select "div#c p", text: "3 classes"
    assert_select "div#c svg"
    assert_select "div#c", text: /Tout voir.*Corps.*Pied/m
  end

  test "ui_card without block nor header renders an empty card" do
    show ui_card(padding: :none)

    assert_select "div.rounded-card:not(.p-4)"
    assert_select "h2", 0
  end

  test "ui_card with an href is a lifting link" do
    show ui_card(title: "Cours", href: "/courses", padding: :sm) { "Corps" }

    # Lot E5 (politique-cache) : survol et focus par la classe partagée ui-card-link (test/design/shared_classes_test.rb).
    assert_select "a[href='/courses'].ui-card-link.p-4 h2", text: "Cours"
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

  # --- Afficher le code PIN (UDR-0051) ----------------------------------------

  test "a password field has no reveal button unless asked" do
    show view.fields(:user, model: Record.new) { |form| ui_field(form, :pin, as: :password) }

    assert_select "input#user_pin[type=password]"
    assert_select "[data-controller=password-reveal]", 0
    assert_select "button", 0
  end

  test "reveal: true renders the masked state, labelled « Afficher le code », hidden until JavaScript" do
    show view.fields(:user, model: Record.new) { |form|
      ui_field(form, :pin, as: :password, reveal: true, required: true, maxlength: 4, inputmode: "numeric",
                           autocomplete: "current-password", hint: "4 chiffres")
    }

    assert_select "div.relative[data-controller=password-reveal]" \
                  "[data-password-reveal-show-label-value='Afficher le code']" \
                  "[data-password-reveal-hide-label-value='Masquer le code']" do
      assert_select "input#user_pin[type=password].pr-14[data-password-reveal-target=input][maxlength='4']" \
                    "[inputmode=numeric][autocomplete=current-password][required][aria-describedby=user_pin_hint]"
      assert_select "input + button[type=button][hidden][aria-controls=user_pin][aria-pressed=false]" \
                    "[aria-label='Afficher le code'][data-password-reveal-target=toggle].w-tap.right-0"
      assert_select "button[data-action~='password-reveal#toggle'][data-action~='mousedown->password-reveal#keepFocus']"
    end
    assert_select "p#user_pin_hint", text: "4 chiffres"
  end

  test "masked shows the eye icon, shown the eye-slash icon, both outline at the field icon size" do
    show view.fields(:user, model: Record.new) { |form| ui_field(form, :pin, as: :password, reveal: true) }

    masked = css_select("button span[data-icon=eye]").first
    revealed = css_select("button span[data-icon=eye-slash]").first

    assert_not masked.key?("hidden"), "PIN masqué : l'œil est visible"
    assert revealed.key?("hidden"), "PIN masqué : l'œil barré attend l'état affiché"
    assert_equal "maskedIcon", masked["data-password-reveal-target"]
    assert_equal "revealedIcon", revealed["data-password-reveal-target"]
    assert_equal icon_paths(ui_icon("eye", variant: :outline, size: :md)), icon_paths(masked)
    assert_equal icon_paths(ui_icon("eye-slash", variant: :outline, size: :md)), icon_paths(revealed)
    assert_not_equal icon_paths(masked), icon_paths(revealed)
    assert_select "button svg.size-5[aria-hidden=true]", 2
  end

  test "reveal: true is refused outside a password field" do
    error = assert_raises(ArgumentError) { view.fields(:user) { |form| ui_field(form, :name, reveal: true) } }

    assert_match "reveal", error.message
  end

  test "an invalid PIN keeps its error wiring next to the reveal button" do
    record = Record.new
    record.errors.add(:pin, "PIN incorrect.")
    show view.fields(:user, model: record) { |form| ui_field(form, :pin, as: :password, reveal: true) }

    assert_select "input#user_pin.border-error[aria-invalid=true][aria-describedby=user_pin_error]"
    assert_select "p#user_pin_error", text: "PIN incorrect."
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

  # --- Groupe de cases à cocher (UDR-0071 §3.8) -------------------------------

  test "ui_checkbox_group renders a legend, one 48 px option per choice and checks the object's values" do
    show view.fields(:announcement, model: Record.new(classrooms: %w[b2 c3])) { |form|
      ui_checkbox_group(form, :classrooms, label: "Classes", required: true,
                                           choices: [ [ "3ème A", "a1" ], [ "3ème B", "b2" ], [ "3ème C", "c3" ] ])
    }

    assert_select "fieldset#announcement_classrooms > legend", text: /Classes\s*\*/
    assert_select "fieldset > input[type=hidden][name='announcement[classrooms][]'][value='']:not([id])", 1
    assert_select "fieldset .sm\\:grid-cols-2 > label.min-h-tap.border-line", 3
    assert_select "label", text: "3ème A" do
      assert_select "input#announcement_classrooms_a1[type=checkbox][name='announcement[classrooms][]'][value=a1]:not([checked])"
    end
    assert_select "input[type=checkbox][checked]", 2
    assert_select "input#announcement_classrooms_c3.size-5.accent-brand[checked]"
    assert_select "input[type=checkbox][name='announcement[classrooms][]']", 3
    assert_select "input[type=hidden][name='announcement[classrooms][]']", 1
    assert_select "input[required], input[aria-invalid], input[aria-describedby], p", 0
  end

  test "ui_checkbox_group wires its hint and first error to every option, never makes each box required" do
    record = Record.new
    record.errors.add(:classrooms, "Choisis au moins une de tes classes.")
    record.errors.add(:classrooms, "Second")
    show view.fields(:announcement, model: record) { |form|
      ui_checkbox_group(form, :classrooms, hint: "Aide", columns: 3, choices: [ %w[A a], %w[B b] ])
    }

    assert_select "legend", text: "Classrooms"
    assert_select "legend span", 0
    assert_select "div.sm\\:grid-cols-3 > label.border-error", 2
    assert_select "input[type=checkbox]:not([required]):not([checked])[aria-invalid=true][aria-describedby='announcement_classrooms_hint announcement_classrooms_error']", 2
    assert_select "fieldset > p#announcement_classrooms_hint + p#announcement_classrooms_error", text: "Choisis au moins une de tes classes."
  end

  test "ui_checkbox_group works without a model, stacks on one column and refuses an unknown column count" do
    show view.fields(:announcement) { |form| ui_checkbox_group(form, :classrooms, columns: 1, choices: [ %w[A a] ]) }

    assert_select "legend", text: "Classrooms"
    assert_select "fieldset div.grid:not([class*=grid-cols]) > label > input:not([checked])", 1
    error = assert_raises(ArgumentError) { view.fields(:announcement) { |form| ui_checkbox_group(form, :classrooms, columns: 4, choices: []) } }
    assert_match "ui_checkbox_group", error.message
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

  # UDR-0080 §3.2 : le panneau du compte de l'élève, une feuille ancrée à gauche.
  test "ui_modal placed as a drawer is a dialog anchored to the left, without the bottom sheet's handle" do
    show ui_modal(title: "Mon compte", id: "account_panel", size: :sm, placement: :drawer)

    assert_select "dialog#account_panel.ui-dialog.dialog-drawer"
    assert_select "dialog#account_panel .sheet-handle", 0
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

  # UDR-0064 (RH-13) : une entrée de rôle est un déclencheur `lg` pleine largeur ; sans option, celui d'aujourd'hui.
  test "ui_modal sizes and stretches its trigger on demand, and keeps the default trigger otherwise" do
    show ui_modal(title: "Élève", id: "entry", trigger: "Je suis élève", trigger_variant: :primary, trigger_size: :lg,
                  trigger_full: true) +
         ui_modal(title: "Plus tard", id: "plain", trigger: "Ouvrir")

    assert_select "button[aria-controls=entry][aria-haspopup=dialog].ui-button-primary.ui-button-lg.w-full", text: "Je suis élève"
    assert_select "button[aria-controls=plain].ui-button-md:not(.w-full)", text: "Ouvrir"
    # Levée par ui_button pendant le rendu du partial : ActionView l'enveloppe, la cause reste l'ArgumentError.
    error = assert_raises(ActionView::Template::Error) { ui_modal(title: "Taille", trigger: "Ouvrir", trigger_size: :xl) }
    assert_kind_of ArgumentError, error.cause
  end

  # UDR-0061 §3.3 : `placement: :sheet` fait de la modale une feuille basse sous lg, avec sa poignée ; le défaut
  # (`:center`) rend exactement le même HTML qu'avant l'option.
  test "ui_modal placed as a sheet carries the sheet class and a decorative handle" do
    show ui_modal(title: "Contacte-nous", id: "help-sheet", size: :sm, placement: :sheet) { "Corps" }

    # Mouvement réduit : ui-dialog ne glisse qu'en motion-safe (revue de la PR #191), la feuille n'a plus à l'arrêter.
    assert_select "dialog#help-sheet.ui-dialog.dialog-sheet.sm\\:max-w-sm"
    assert_select "dialog#help-sheet > span.sheet-handle.lg\\:hidden[aria-hidden=true]", 1
  end

  test "ui_modal keeps its centred rendering by default, and refuses an unknown placement" do
    default = ui_modal(title: "Supprimer ?", id: "confirm", size: :sm, trigger: "Ouvrir") { "Corps" }

    assert_equal default, ui_modal(title: "Supprimer ?", id: "confirm", size: :sm, trigger: "Ouvrir", placement: :center) { "Corps" }
    show default
    assert_select ".dialog-sheet, .sheet-handle, .motion-reduce\\:animate-none", 0
    assert_raises(ArgumentError) { ui_modal(title: "Info", placement: :side) }
  end

  # UDR-0061 §3.2 : sans JavaScript, le déclencheur reste un lien vers la page de repli ; le contrôleur l'intercepte.
  test "ui_modal trigger with a fallback href is a link that opens the dialog" do
    show ui_modal(title: "Contacte-nous", id: "help-sheet", trigger: "Besoin d'aide ?", trigger_href: "/aide",
                  trigger_variant: :ghost, trigger_size: :sm)

    assert_select "a[href='/aide'][data-action='modal#open'][aria-haspopup=dialog][aria-controls=help-sheet]",
                  text: "Besoin d'aide ?"
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
    assert_select "a[role=menuitem][data-turbo-method=delete].ui-menu-item-danger"
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
    # Lot E6 (politique-cache) : défilement et redimensionnement sont écoutés par le contrôleur, menu ouvert seulement ;
    # le HTML de chaque menu ne déclare plus que le clavier (test système : teams/row_actions_menu_test.rb).
    assert_select "[data-controller=dropdown][data-action='keydown->dropdown#keydown']"
    assert_select "[data-action*='@window'], [data-action*='@document']", 0
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
                  "[data-action='dropdown#openDialog'][data-dropdown-dialog-param=delete-drena-1].ui-menu-item.ui-menu-item-danger svg",
                  count: 1
    assert_select "button", text: "Supprimer"
    assert_select "a", 0
  end

  test "ui_dropdown_item keeps the default tone for a dialog, and refuses an unknown tone" do
    show ui_dropdown_item("Désactiver", dialog: "deactivate-school-1")

    assert_select "button.ui-menu-item-default[role=menuitem]", text: "Désactiver"
    assert_select "button.ui-menu-item-danger", 0
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

    assert_select "span.ui-badge.ui-badge-sm.bg-success-soft", text: "Validé"
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

  # RE-13, RE-17 (UDR-0069 §3.3) : l'illustration suit le slug figé de la matière ; toute autre matière prend la générique.
  test "subject_illustration picks the drawing and tint by the frozen slug, aliases included" do
    {
      "mathematiques" => %w[maths indigo], "maths" => %w[maths indigo], "physique-chimie" => %w[physique-chimie lilac],
      "svt" => %w[svt green], "francais" => %w[francais yellow], "histoire-geo" => %w[histoire-geographie lavender],
      "edhc" => %w[edhc pink], "philosophie" => %w[philosophie pink], invite: %w[inviter red]
    }.each do |slug, (file, tint)|
      illustration = subject_illustration(slug)

      assert_equal "subjects/#{file}.svg", illustration.path, slug
      assert_equal "bg-tint-#{tint}", illustration.tint, slug
    end
  end

  test "subject_illustration falls back to the generic drawing for any other subject" do
    [ "anglais", "eps", nil ].each do |slug|
      assert_equal ComponentsHelper::Illustration.new(path: "subjects/generique.svg", tint: "bg-mist"), subject_illustration(slug)
    end
  end

  test "every illustration file exists, standalone and without style attributes" do
    paths = [ *ComponentsHelper::SUBJECT_ILLUSTRATIONS.values.map(&:path), ComponentsHelper::SUBJECT_ILLUSTRATION_FALLBACK.path ].uniq

    assert_equal 9, paths.size
    paths.each do |path|
      svg = Rails.root.join("app/assets/images", path).read

      assert_match(/\A<svg xmlns="http:\/\/www.w3.org\/2000\/svg" viewBox="0 0 48 48">/, svg, path)
      assert_no_match(/\sstyle=|\sclass=/, svg, path)
    end
  end

  test "ui_subject_bubble is a link with a tinted disc, a decorative drawing, a label and an optional spoken suffix" do
    show ui_subject_bubble(label: "Tle D", href: "/courses?level=tle", illustration: subject_illustration("mathematiques"),
                           sr_suffix: ", cours de Mathématiques", id: "course_level_tle_d") +
         ui_subject_bubble(label: "Inviter", href: "/teachers/invite", illustration: subject_illustration(:invite))

    assert_select "a#course_level_tle_d.min-h-tap[href='/courses?level=tle']" do
      assert_select "span.size-15.rounded-full.bg-tint-indigo img[alt=''][aria-hidden=true][src*='maths']"
      assert_select "span", text: "Tle D"
      assert_select "span.sr-only", text: ", cours de Mathématiques"
    end
    assert_select "a[href='/teachers/invite']:not([id]) span.bg-tint-red"
    assert_select "a[href='/teachers/invite'] span.sr-only", 0
  end

  # Constat du challenger : le nom accessible se lit « Tle D, cours de … », sans espace avant la virgule.
  test "ui_subject_bubble reads its label and spoken suffix without a stray space" do
    show ui_subject_bubble(label: "Tle D", href: "/courses", illustration: subject_illustration("svt"), sr_suffix: ", cours de SVT")

    assert_equal "Tle D, cours de SVT", css_select("a").first.text.gsub(/\s+/, " ").strip
  end

  # AD-07, AD-09 (UDR-0074 §3.5): the direction's bubbles carry a decorative dot of the work signal; without a signal the
  # bubble stays the one of UDR-0069.
  test "ui_subject_bubble puts a decorative signal dot on its disc, in the colour of the signal" do
    %i[green yellow red].each do |signal|
      show ui_subject_bubble(label: "3ème", href: "/school-admin/levels/3eme", illustration: subject_illustration(nil), signal:)

      assert_select "a span.relative.size-15.rounded-full span.absolute.rounded-full.ring-2.ring-white.bg-signal-#{signal}[aria-hidden=true]",
                    count: 1
    end
  end

  # UDR-0076 §3.1, charte §5 et §9 : la bulle d'une matière en retard porte la pastille ambre, celle de l'urgence.
  test "ui_subject_bubble puts the amber dot of a late subject" do
    show ui_subject_bubble(label: "SVT", href: "/courses?material=svt", illustration: subject_illustration("svt"), signal: :warning)

    assert_select "a span.relative.size-15.rounded-full span.absolute.rounded-full.ring-2.ring-white.bg-warning[aria-hidden=true]",
                  count: 1
  end

  test "ui_subject_bubble without a signal has no dot, and refuses an unknown signal" do
    show ui_subject_bubble(label: "Tle D", href: "/courses", illustration: subject_illustration("svt"))

    assert_select "span[class*='bg-signal-']", 0
    assert_raises(ArgumentError) { ui_subject_bubble(label: "3ème", href: "/", illustration: subject_illustration(nil), signal: :blue) }
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

  # ADR-0060, UDR-0047: a photo is round, cropped to fill, loaded lazily; the xl size serves the photo modal.
  test "ui_avatar shows a photo round and cropped, lazily, in every size up to xl" do
    show ui_avatar("Awa Koné", src: "/accounts/abc/photo?v=1", size: :xl)

    assert_select "img[alt='Awa Koné'][src='/accounts/abc/photo?v=1'][loading=lazy][decoding=async].ui-avatar.object-cover.size-28"
    assert_includes ui_avatar("Awa Koné", size: :xl), "size-28"
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

  # UDR-0071 §3.6 : « Annuler » dans le toast. Le toast part au départ de la requête (turbo:submit-start), pas au clic :
  # retiré au clic, le formulaire ne serait plus dans la page et le navigateur ne l'enverrait pas.
  test "ui_toast with an action renders its button between the text and the close button" do
    show ui_toast("Elle n'apparaît plus sur ton accueil.", type: :info, title: "Annonce masquée",
                  action: { label: "Annuler", href: "/announcements/abcdefghijkmno/dismissal", method: :delete })

    assert_select "div[data-controller=toast][data-toast-type=info][data-toast-delay-value='5000']" do
      assert_select "div.flex-1 + form[action='/announcements/abcdefghijkmno/dismissal'][method=post] + button[data-action='toast#dismiss']"
      assert_select "form[data-action='turbo:submit-start->toast#dismiss'] input[type=hidden][name=_method][value=delete]"
      assert_select "form button[type=submit][data-turbo-stream=true]", text: "Annuler" do |buttons|
        assert_equal "min-h-tap shrink-0 rounded-ln px-3 text-sm font-bold text-brand-strong hover:bg-brand-soft", buttons.first["class"]
      end
    end
    assert_select "p", text: "Annonce masquée"
  end

  test "ui_toast without action renders no form, and an action defaults to POST" do
    show ui_toast("Fait") + ui_toast("Rétabli", action: { label: "Refaire", href: "/redo" })

    assert_select "form", 1
    assert_select "form[action='/redo'][method=post]:not(:has(input[name=_method]))"
  end

  test "turbo_stream_toast carries the action of its toast" do
    show view.turbo_stream_toast("Masquée", action: { label: "Annuler", href: "/undo", method: :delete })

    assert_includes rendered, "turbo:submit-start-&gt;toast#dismiss"
    assert_includes rendered, "Annuler"
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
    assert_select "a[href='/new'].ui-button-primary", text: "Créer"
  end

  test "ui_empty_state titles in a p, or in the heading it is given when it is the whole page" do
    show ui_empty_state(title: "Vide")
    assert_select "p", text: "Vide"
    assert_select "h1", 0

    show ui_empty_state(title: "Tu n'as pas encore de classe", heading: :h1)
    assert_select "h1.font-display", text: "Tu n'as pas encore de classe"
  end

  test "ui_empty_state with a free block or nothing" do
    show ui_empty_state(title: "Vide") { "Libre" } + ui_empty_state(title: "Nu", action: { label: "A", href: "/", variant: :secondary })

    assert_includes rendered, "Libre"
    assert_select "a.ui-button-secondary", text: "A"
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
    assert_select "nav", 0
  end

  # --- Finitions (UDR-0054) ---------------------------------------------------

  test "ui_back_link is a named nav holding one chevron link labelled by the page it leads to" do
    show ui_back_link("Établissements", href: "/teams/schools?search=lyc")

    assert_select "nav.mb-4.text-sm[aria-label=?]", I18n.t("components.back_link.label") do
      assert_select "a.inline-flex.min-h-tap.text-mute[href='/teams/schools?search=lyc']", text: "Établissements" do
        assert_select "svg.size-4[aria-hidden=true]"
        assert_select "span.truncate", text: "Établissements"
      end
    end
  end

  test "ui_page_header renders its back link above the h1" do
    show ui_page_header(title: "Lycée moderne de Cocody", back: { label: "Établissements", href: "/teams/schools" })

    assert_select "nav[aria-label=?] + div h1", I18n.t("components.back_link.label"), text: "Lycée moderne de Cocody"
    assert_select "nav a[href='/teams/schools']", text: "Établissements"
  end

  test "ui_info_tip is a native details whose summary names the help and whose panel stays in the flow" do
    show ui_info_tip("Part des devoirs rendus.", label: "Taux de rendu")

    assert_select "details.group.inline-block.align-middle[data-controller=info-tip]" \
                  "[data-action='pointerenter->info-tip#enter pointerleave->info-tip#leave']" do
      assert_select "summary.summary-plain.size-tap.cursor-pointer[data-action='click->info-tip#pin']" do
        assert_select "svg[aria-hidden=true]"
        assert_select "span.sr-only", text: I18n.t("components.info_tip.label", label: "Taux de rendu")
      end
      assert_select "summary + div.max-w-form.bg-mist.text-ink", text: "Part des devoirs rendus."
    end
    assert_select "details [class*=absolute]", 0
  end

  test "ui_copy_button carries the value, a hidden button and both toasts for the clipboard controller" do
    show ui_copy_button("https://lnclass.ci/c/KFM37", label: "Copier le lien", copied: "Lien copié.",
                                                      aria_label: "Copier le lien de la classe", icon: "link")

    assert_select "span[data-controller=clipboard][data-clipboard-text-value='https://lnclass.ci/c/KFM37']" do
      assert_select "button[type=button][hidden][data-clipboard-target=button][data-action='clipboard#copy']" \
                    "[aria-label='Copier le lien de la classe'].ui-button-secondary.ui-button-sm", text: "Copier le lien"
      assert_select "template[data-clipboard-target=copied]"
      assert_select "template[data-clipboard-target=failed]"
    end
    copied, failed = Nokogiri::HTML5.fragment(rendered).css("template").map { it.inner_html }

    assert_match "Lien copié.", copied
    assert_match "data-toast-type=\"success\"", copied
    assert_match I18n.t("shared.clipboard.failed"), failed
    assert_match "data-toast-type=\"error\"", failed
  end

  test "ui_copy_button defaults: secondary, small, clipboard icon, no aria-label of its own" do
    show ui_copy_button("KFM37", label: "Copier", copied: "Code copié.", failed: "Raté.", variant: :ghost, size: :md)

    assert_select "button[hidden].ui-button-md:not([aria-label])", text: "Copier"
    assert_equal icon_paths(ui_icon("clipboard-document", size: :md)), icon_paths(css_select("button").first)
    assert_match "Raté.", Nokogiri::HTML5.fragment(rendered).css("template").last.inner_html
  end

  # --- « Voir plus » (UDR-0057 R3) ---------------------------------------------

  test "ui_reveal_data wires the reveal controller with both announcements" do
    data = ui_reveal_data(step: 2)

    assert_equal "reveal", data[:controller]
    assert_equal 2, data[:reveal_step_value]
    assert_equal "1 ligne de plus affichée.", data[:reveal_one_value]
    assert_equal "{count} lignes de plus affichées.", data[:reveal_other_value]
  end

  test "ui_reveal_item hides the lines after the third and targets them all" do
    assert_equal({ hidden: false, data: { reveal_target: "item" } }, ui_reveal_item(2))
    assert_equal({ hidden: true, data: { reveal_target: "item" } }, ui_reveal_item(3))
  end

  test "ui_reveal_more renders a full-width ghost button and a polite status, only beyond three lines" do
    assert_nil ui_reveal_more(3)

    show ui_reveal_more(4)

    assert_select "button.w-full[data-reveal-target=button][data-action='reveal#more']", text: "Voir plus"
    assert_select "button.ui-button-primary", 0
    assert_select "p.sr-only[role=status][aria-live=polite][data-reveal-target=status]"
  end

  test "ui_modal hands its document title to the modal controller and its dialog to the autofocus controller" do
    html = ui_modal(title: "Nouveau niveau", id: "level", document_title: "Nouveau niveau · Équipe · Lnclass") do |modal|
      modal.footer { "Pied" }
      "Corps"
    end
    show html

    assert_select "[data-controller=modal][data-modal-document-title-value='Nouveau niveau · Équipe · Lnclass']"
    assert_select "dialog#level[data-controller=autofocus][data-autofocus-mode-value=dialog]"
    assert_select "dialog#level[data-action~='modal:opened->autofocus#focus']"
    assert_select "dialog#level div[data-autofocus-footer]", text: "Pied"
  end

  test "ui_modal without a document title leaves the tab title alone" do
    show ui_modal(title: "Supprimer ?", id: "confirm")

    assert_select "[data-controller=modal]:not([data-modal-document-title-value])"
    assert_select "dialog#confirm[data-controller=autofocus]"
  end

  test "ui_field autofocus declares the autofocus target instead of the autofocus attribute" do
    show view.fields(:user, model: Record.new) { |form|
      ui_field(form, :name, autofocus: true) + ui_field(form, :pin, as: :password, reveal: true, autofocus: true) +
        ui_field(form, :level, data: { turbo_permanent: true })
    }

    assert_select "input#user_name[data-autofocus-target=field]:not([autofocus])"
    assert_select "input#user_pin[data-autofocus-target=field][data-password-reveal-target=input]:not([autofocus])"
    assert_select "input#user_level[data-turbo-permanent]:not([data-autofocus-target])"
  end

  private

  # Les helpers rendent leurs partials par `render`, qui accumule dans `rendered` : on n'examine que le fragment voulu.
  # Les tracés d'une icône heroicons : ce qui la distingue d'une autre, quelle que soit la sérialisation.
  def icon_paths(node)
    node = Nokogiri::HTML5.fragment(node.to_s) unless node.respond_to?(:css)
    node.css("svg path").map { it["d"] }
  end

  def show(html)
    self.rendered = self.class.content_class.new(html.to_s)
  end
end
