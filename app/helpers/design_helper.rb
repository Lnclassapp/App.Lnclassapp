# 🌐 UI · DesignHelper — cadres de la page /design (sections et exemples)
# Rôle : helpers plutôt que partials à `render layout:` — le bloc garde ainsi les clés `t(".key")` de design/index
# UDR  : 0005
module DesignHelper
  def design_section(id:, title:, api: nil, &block)
    tag.section(id:, "aria-labelledby": "#{id}-title", class: "scroll-mt-6 border-t border-line py-10") do
      safe_join([
        tag.h2(title, id: "#{id}-title", class: "font-display text-2xl font-extrabold tracking-tight"),
        (tag.p(tag.code(api, class: "rounded-sm bg-mist px-1.5 py-0.5 font-mono text-sm wrap-anywhere text-ink"), class: "mt-2 max-w-2xl text-mute") if api),
        tag.div(capture(&block), class: "mt-6 space-y-8")
      ].compact)
    end
  end

  def design_example(name:, label:, &block)
    tag.div(data: { example: name }) do
      tag.p(label, class: "mb-3 text-xs font-bold tracking-widest text-mute uppercase") + capture(&block)
    end
  end
end
