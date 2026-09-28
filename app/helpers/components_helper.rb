# 🌐 UI · ComponentsHelper — API publique de la bibliothèque app/views/components
# Rôle : calcule classes et attributs des composants ; le balisage vit dans les partials
# UDR  : 0005, 0006, 0041, 0042 · ADR : 0009, 0049
module ComponentsHelper
  # Zones nommées d'un composant, remplies dans le bloc d'appel : `card.actions { … }`, `modal.footer { … }`.
  class Slots
    def initialize(view)
      @view = view
      @content = {}
    end

    def actions(&) = fill(:actions, &)
    def footer(&) = fill(:footer, &)
    def [](name) = @content[name]

    private

    def fill(name, &block)
      @content[name] = @view.capture(&block)
      nil
    end
  end

  # Onglets déclarés dans le bloc de `ui_tabs` : `tabs.tab(:key, "Libellé") { panneau }`.
  class Tabs
    Tab = Data.define(:key, :label, :icon, :content)

    attr_reader :items

    def initialize(view)
      @view = view
      @items = []
    end

    def tab(key, label, icon: nil, &block)
      @items << Tab.new(key: key.to_s, label:, icon:, content: @view.capture(&block))
      nil
    end
  end

  ICON_ROOT = Rails.root.join("vendor/heroicons")
  ICON_SETS = { outline: "24/outline", solid: "24/solid", mini: "20/solid" }.freeze
  ICON_SIZES = { sm: "size-4", md: "size-5", lg: "size-6", xl: "size-8" }.freeze
  ICON_CACHE = {} # rubocop:disable Style/MutableConstant -- cache des SVG lus sur disque

  BUTTON_BASE = "relative inline-flex cursor-pointer items-center justify-center rounded-full font-medium " \
                "whitespace-nowrap select-none transition active:scale-95 focus-visible:outline-2 " \
                "focus-visible:outline-offset-2 focus-visible:outline-brand disabled:pointer-events-none " \
                "disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50"
  BUTTON_VARIANTS = {
    primary: "bg-ink text-white hover:bg-ink/85",
    brand: "bg-brand text-ink hover:bg-brand/85",
    secondary: "border border-line bg-white text-ink hover:bg-mist",
    ghost: "text-ink hover:bg-ink/5",
    danger: "bg-error text-white hover:bg-error/90"
  }.freeze
  # `sm` agrandit sa zone tactile à 48 px par un pseudo-élément : le bouton paraît petit, le doigt ne le rate pas.
  BUTTON_SIZES = {
    sm: "h-10 gap-1.5 px-4 text-sm after:absolute after:-inset-1",
    md: "min-h-tap gap-2 px-5 text-sm",
    lg: "min-h-14 gap-2 px-6 text-base"
  }.freeze
  BUTTON_ICON_SIZES = { sm: :sm, md: :md, lg: :md }.freeze

  CARD_BASE = "block rounded-card border border-line bg-white shadow-card"
  CARD_LINK = "transition duration-300 ease-out hover:-translate-y-1 hover:border-brand/40 hover:shadow-lift " \
              "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
  CARD_PADDINGS = { none: nil, sm: "p-4", md: "p-5 sm:p-6", lg: "p-6 sm:p-8" }.freeze

  FIELD_BUILDERS = {
    text: :text_field, email: :email_field, password: :password_field, tel: :telephone_field,
    number: :number_field, date: :date_field, search: :search_field, url: :url_field,
    textarea: :text_area, select: :select, checkbox: :check_box
  }.freeze
  FIELD_INPUT = "block w-full rounded-ln border bg-white px-4 text-base text-ink transition placeholder:text-mute " \
                "focus:outline-none focus:ring-4 disabled:cursor-not-allowed disabled:bg-mist disabled:text-mute"
  FIELD_SHAPES = { textarea: "min-h-32 py-3", select: "min-h-tap appearance-none pr-10" }.freeze
  FIELD_STATES = {
    valid: "border-line focus:border-brand focus:ring-brand/20",
    invalid: "border-error focus:border-error focus:ring-error/20"
  }.freeze
  FIELD_CHECKBOX = "size-5 shrink-0 cursor-pointer rounded-sm accent-brand focus-visible:outline-2 " \
                   "focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed"

  MODAL_SIZES = { sm: "sm:max-w-sm", md: "sm:max-w-lg", lg: "sm:max-w-2xl" }.freeze
  DROPDOWN_ALIGNS = { start: "left-0", end: "right-0" }.freeze
  DROPDOWN_TONES = {
    default: "text-ink hover:bg-mist focus:bg-mist",
    danger: "text-error hover:bg-error-soft focus:bg-error-soft"
  }.freeze

  BADGE_TONES = {
    neutral: { chip: "bg-mist text-ink", dot: "bg-mute" },
    brand: { chip: "bg-brand-soft text-brand-strong", dot: "bg-brand" },
    info: { chip: "bg-info-soft text-info", dot: "bg-info" },
    success: { chip: "bg-success-soft text-success", dot: "bg-success" },
    warning: { chip: "bg-warning-soft text-warning", dot: "bg-warning" },
    error: { chip: "bg-error-soft text-error", dot: "bg-error" },
    teacher: { chip: "bg-teacher/15 text-ink", dot: "bg-teacher" },
    school: { chip: "bg-school/10 text-school", dot: "bg-school" },
    team: { chip: "bg-team/10 text-team", dot: "bg-team" },
    gold: { chip: "bg-gold/20 text-ink", dot: "bg-gold" }
  }.freeze
  BADGE_SIZES = { sm: "px-2 py-0.5 text-2xs", md: "px-2.5 py-1 text-xs" }.freeze
  ROLE_TONES = { student: :brand, teacher: :teacher, team: :team, school_admin: :school }.freeze
  # Teinte d'une matière = sa catégorie (`materials.category`, enum literature / science / other), jamais son nom (CA-26).
  SUBJECT_CATEGORIES = {
    literature: { tone: :gold, icon: "book-open" },
    science: { tone: :brand, icon: "beaker" },
    other: { tone: :team, icon: "academic-cap" }
  }.freeze
  SUBJECT_FALLBACK = { tone: :neutral, icon: "book-open" }.freeze

  AVATAR_SIZES = { sm: "size-8 text-xs", md: "size-10 text-sm", lg: "size-14 text-lg", xl: "size-28 text-3xl" }.freeze
  AVATAR_TONES = {
    brand: "bg-brand text-ink", teacher: "bg-teacher text-ink", school: "bg-school text-white",
    team: "bg-team text-white", gold: "bg-gold text-ink"
  }.freeze

  TOAST_TYPES = {
    success: { icon: "check-circle", tone: "text-success", bar: "bg-success", delay: 5000 },
    info: { icon: "information-circle", tone: "text-info", bar: "bg-info", delay: 5000 },
    warning: { icon: "exclamation-triangle", tone: "text-warning", bar: "bg-warning", delay: 8000 },
    error: { icon: "x-circle", tone: "text-error", bar: "bg-error", delay: 0 }
  }.freeze
  FLASH_TYPES = { notice: :success, alert: :error }.freeze

  LOADING_VARIANTS = %i[spinner skeleton].freeze
  LOADING_WIDTHS = %w[w-full w-5/6 w-2/3].freeze

  # Icône heroicons vendorée (vendor/heroicons, MIT). Décorative par défaut ; `label:` la rend lisible.
  def ui_icon(name, variant: :outline, size: :md, label: nil, **html)
    svg = heroicon_source(option!(ICON_SETS, variant, "ui_icon variant"), name.to_s)
    classes = class_names("shrink-0", option!(ICON_SIZES, size, "ui_icon size"), html[:class])
    a11y = label ? %(role="img" aria-label="#{ERB::Util.html_escape(label)}") : %(aria-hidden="true")
    svg.sub(' aria-hidden="true"', "")
       .sub("<svg ", %(<svg class="#{ERB::Util.html_escape(classes)}" #{a11y} focusable="false" ))
       .html_safe
  end

  def ui_spinner(size: :md)
    render "components/spinner", classes: option!(ICON_SIZES, size, "ui_spinner size")
  end

  # Bouton, ou lien quand `href:` est donné. Désactivé et en chargement restent annoncés (`aria-disabled`, `aria-busy`).
  def ui_button(label = nil, variant: :primary, size: :md, href: nil, type: :button, icon: nil, icon_end: nil,
                disabled: false, loading: false, method: nil, full: false, **html, &block)
    inert = disabled || loading
    attributes = html.merge(
      class: class_names(BUTTON_BASE, option!(BUTTON_VARIANTS, variant, "ui_button variant"),
                         option!(BUTTON_SIZES, size, "ui_button size"), { "w-full" => full }, html[:class])
    )
    attributes[:"aria-busy"] = "true" if loading

    if href.nil?
      tag_name = :button
      attributes.merge!(type:, disabled: inert)
    elsif inert
      tag_name = :a
      attributes.merge!(role: "link", "aria-disabled": "true")
    else
      tag_name = :a
      attributes[:href] = href
      attributes[:data] = (attributes[:data] || {}).merge(turbo_method: method) if method
    end

    render "components/button", tag_name:, attributes:, content: block ? capture(&block) : label,
           icon:, icon_end:, loading:, icon_size: BUTTON_ICON_SIZES.fetch(size.to_sym)
  end

  # Carte : en-tête facultatif (icône, titre, sous-titre, `card.actions`), corps, `card.footer`.
  # Avec `href:`, toute la carte est un lien qui se soulève au survol — n'y mettez alors aucun autre élément interactif.
  def ui_card(title: nil, subtitle: nil, icon: nil, href: nil, padding: :md, heading: :h2, **html, &block)
    slots = Slots.new(self)
    body = block ? capture(slots, &block) : nil
    attributes = html.merge(
      href:,
      class: class_names(CARD_BASE, option!(CARD_PADDINGS, padding, "ui_card padding"), { CARD_LINK => href }, html[:class])
    )
    render "components/card", tag_name: href ? :a : :div, attributes:, title:, subtitle:, icon:, heading:, body:, slots:
  end

  # Champ complet : libellé, contrôle, aide, erreur, reliés par `aria-describedby`. Tout attribut en plus va au contrôle.
  def ui_field(form, method, as: :text, label: nil, hint: nil, required: false, choices: [], **input_html)
    builder = option!(FIELD_BUILDERS, as, "ui_field as")
    kind = as.to_sym
    id = form.field_id(method)
    error = field_errors(form.object, method).first
    described_by = [ ("#{id}_hint" if hint), ("#{id}_error" if error) ].compact

    input_html = input_html.merge(
      id:, required:, "aria-invalid": ("true" if error), "aria-describedby": described_by.join(" ").presence
    )
    input_html[:class] = field_classes(kind, error, input_html[:class])
    control = case kind
    when :select then form.select(method, choices, { prompt: input_html.delete(:prompt) }, input_html)
    else form.public_send(builder, method, input_html)
    end

    render "components/field", form:, method:, kind:, control:, id:, hint:, error:, required:,
           label: label || field_label(form.object, method)
  end

  def ui_modal(title:, id: nil, size: :md, trigger: nil, trigger_variant: :secondary, trigger_icon: nil, open: false, &block)
    slots = Slots.new(self)
    body = block ? capture(slots, &block) : nil
    render "components/modal", id: id || "modal-#{title.parameterize}", title:, trigger:, trigger_variant:,
           trigger_icon:, open:, body:, slots:, size_class: option!(MODAL_SIZES, size, "ui_modal size")
  end

  # Menu déroulant. `trigger:` remplace le bouton icône par un contenu libre (avatar + nom, par exemple).
  # `fixed: true` place le menu en position fixe à l'ouverture : il échappe au défilement d'un tableau (UDR-0042).
  def ui_dropdown(label:, icon: "ellipsis-vertical", trigger: nil, align: :end, id: nil, fixed: false, &block)
    render "components/dropdown", label:, icon:, trigger:, id: id || "menu-#{label.parameterize}", fixed:,
           align_class: option!(DROPDOWN_ALIGNS, align, "ui_dropdown align"), items: capture(&block)
  end

  # Entrée de menu : lien (`href:`, `method:`, `frame:` pour l'ouvrir dans un Turbo Frame), bouton qui ouvre une
  # <dialog> de la page (`dialog:` son id, UDR-0042), ou entrée inactive sans l'un ni l'autre.
  def ui_dropdown_item(label, href: nil, icon: nil, method: nil, tone: :default, frame: nil, dialog: nil)
    classes = class_names("flex min-h-tap w-full items-center gap-3 rounded-sm px-3 text-sm font-medium focus:outline-none",
                          option!(DROPDOWN_TONES, tone, "ui_dropdown_item tone"))
    content = safe_join([ (ui_icon(icon, class: "opacity-70") if icon), tag.span(label) ].compact)
    return dropdown_dialog_item(content, classes, dialog) if dialog
    return tag.span(content, class: class_names(classes, "opacity-50"), role: "menuitem", "aria-disabled": "true", tabindex: -1) if href.nil?

    # Un lien vers la page ouverte est marqué courant (« Mon profil », UDR-0041) ; une action (DELETE…) ne l'est jamais.
    link_to content, href, class: classes, role: "menuitem", tabindex: -1,
                           data: { turbo_method: method, turbo_frame: frame, action: ("dropdown#dismiss" if frame) }.compact,
                           "aria-current": ("page" if method.nil? && current_page?(href))
  end

  def ui_tabs(id:, label: nil, selected: nil, &block)
    tabs = Tabs.new(self)
    capture(tabs, &block)
    render "components/tabs", id:, label:, tabs: tabs.items, selected: (selected || tabs.items.first&.key).to_s
  end

  def ui_badge(label, tone: :neutral, size: :md, icon: nil, dot: false)
    colors = option!(BADGE_TONES, tone, "ui_badge tone")
    tag.span(class: class_names("inline-flex items-center gap-1.5 rounded-full font-medium whitespace-nowrap",
                                colors[:chip], option!(BADGE_SIZES, size, "ui_badge size"))) do
      safe_join([ (tag.span(class: "size-1.5 rounded-full #{colors[:dot]}", "aria-hidden": "true") if dot),
                  (ui_icon(icon, variant: :mini, size: :sm) if icon), label ].compact)
    end
  end

  def ui_role_badge(role, size: :md)
    ui_badge(t("shared.roles.#{role}"), tone: option!(ROLE_TONES, role, "ui_role_badge role"), size:, dot: true)
  end

  # Une catégorie inconnue ou absente donne la teinte neutre : le badge reste lisible, sans couleur inventée.
  def ui_subject_badge(label, category:, size: :md)
    config = SUBJECT_CATEGORIES.fetch(category.to_s.to_sym, SUBJECT_FALLBACK)
    ui_badge(label, tone: config[:tone], size:, icon: config[:icon])
  end

  # Photo si `src:`, sinon initiales (premier et dernier mot) sur une couleur stable dérivée du nom.
  def ui_avatar(name, src: nil, size: :md, tone: nil)
    classes = class_names("inline-grid shrink-0 place-items-center overflow-hidden rounded-full font-display font-extrabold",
                          option!(AVATAR_SIZES, size, "ui_avatar size"))
    # Photo de profil (ADR-0060, UDR-0047) : une seule taille servie, recadrée par le rond ; hors écran, pas chargée.
    return image_tag(src, alt: name, loading: "lazy", decoding: "async", class: class_names(classes, "object-cover")) if src

    tone ||= AVATAR_TONES.keys[name.to_s.sum % AVATAR_TONES.size]
    tag.span(avatar_initials(name), role: "img", "aria-label": name,
                                    class: class_names(classes, option!(AVATAR_TONES, tone, "ui_avatar tone")))
  end

  # Le message est rendu côté serveur, dans le HTML du toast : il survit au Turbo Stream comme à la redirection.
  # `persistent: true` garde le toast jusqu'à sa fermeture ; une erreur l'est toujours.
  def ui_toast(message, type: :info, title: nil, persistent: false)
    config = option!(TOAST_TYPES, type, "ui_toast type")
    render "components/toast", message:, title:, type: type.to_sym, config:, delay: persistent ? 0 : config[:delay]
  end

  def toast_type_for(flash_key)
    key = flash_key.to_sym
    FLASH_TYPES.fetch(key) { TOAST_TYPES.key?(key) ? key : :info }
  end

  def turbo_stream_toast(message, type: :info, title: nil)
    turbo_stream.append("toasts", ui_toast(message, type:, title:))
  end

  def ui_empty_state(title:, description: nil, icon: "inbox", action: nil, &block)
    actions = if block
      capture(&block)
    elsif action
      ui_button(action[:label], href: action[:href], variant: action.fetch(:variant, :primary), icon: action[:icon])
    end
    render "components/empty_state", title:, description:, icon:, actions:
  end

  def ui_error_state(title: nil, message: nil, retry_href: nil, retry_label: nil)
    render "components/error_state", title:, message:, retry_href:, retry_label:
  end

  def ui_loading_state(label: nil, variant: :spinner, lines: 3)
    variant = variant.to_sym
    raise ArgumentError, "ui_loading_state variant : « #{variant} » inconnu (#{LOADING_VARIANTS.join(', ')})" unless LOADING_VARIANTS.include?(variant)

    render "components/loading_state", label:, variant:, widths: Array.new(lines) { |i| LOADING_WIDTHS[i % LOADING_WIDTHS.size] }
  end

  # Pagination simple : précédent · « Page x sur y » · suivant. Ne rend rien s'il n'y a qu'une page.
  def ui_pagination(page:, pages:, param: :page)
    pages = pages.to_i
    return if pages <= 1

    page = page.to_i.clamp(1, pages)
    render "components/pagination", page:, pages:,
           previous_href: (pagination_href(param, page - 1) if page > 1),
           next_href: (pagination_href(param, page + 1) if page < pages)
  end

  def ui_page_header(title:, subtitle: nil, &block)
    render "components/page_header", title:, subtitle:, actions: (capture(&block) if block)
  end

  private

  def option!(table, key, component)
    table.fetch(key.to_sym) { raise ArgumentError, "#{component} : « #{key} » inconnu (#{table.keys.join(', ')})" }
  end

  # Ferme le menu, rend le focus au bouton ⋮ puis ouvre la <dialog> : à sa fermeture, le focus revient au bouton.
  def dropdown_dialog_item(content, classes, dialog)
    tag.button(content, type: "button", class: class_names(classes, "cursor-pointer text-left"), role: "menuitem",
                        tabindex: -1, "aria-haspopup": "dialog", "aria-controls": dialog,
                        data: { action: "dropdown#openDialog", dropdown_dialog_param: dialog })
  end

  def heroicon_source(set, name)
    ICON_CACHE[[ set, name ]] ||= begin
      path = ICON_ROOT.join(set, "#{name}.svg")
      raise ArgumentError, "ui_icon : icône « #{name} » absente de vendor/heroicons/#{set}" unless name.match?(/\A[a-z0-9-]+\z/) && path.file?

      path.read.strip
    end
  end

  def field_classes(kind, error, extra)
    return class_names(FIELD_CHECKBOX, extra) if kind == :checkbox

    class_names(FIELD_INPUT, FIELD_SHAPES[kind] || "min-h-tap", FIELD_STATES[error ? :invalid : :valid], extra)
  end

  def field_errors(object, method)
    object.respond_to?(:errors) ? object.errors[method] : []
  end

  def field_label(object, method)
    object.class.respond_to?(:human_attribute_name) ? object.class.human_attribute_name(method) : method.to_s.humanize
  end

  def avatar_initials(name)
    words = name.to_s.split
    return "?" if words.empty?

    [ words.first, words.last ].uniq.map { |word| word[0] }.join.upcase
  end

  def pagination_href(param, page)
    "#{request.path}?#{request.query_parameters.merge(param.to_s => page).to_query}"
  end
end
