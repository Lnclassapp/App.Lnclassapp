# 🌐 UI · SupportHelper — lignes de la carte d'aide (shared/_help_sheet), depuis config.x.support
# Rôle : FAQ toujours ; WhatsApp et appel seulement si leur numéro est configuré ; jamais un numéro dans une vue
# UDR  : 0061 (§3.3, §3.4), 0057 (§2.5 : rien d'affiché pour une donnée absente) · ADR : 0049 (aucun service tiers)
module SupportHelper
  # `hint` : la ligne grise (horaires, délai), ou nil. `external` : le lien ouvre une autre application.
  Contact = Data.define(:key, :icon, :href, :hint, :external)

  def support_contacts(support = Rails.configuration.x.support)
    [ faq_contact, whatsapp_contact(support), call_contact(support) ].compact
  end

  private

  def faq_contact
    Contact.new(key: :faq, icon: "question-mark-circle", href: help_path, hint: t("shared.help_sheet.faq.hint"),
                external: false)
  end

  def whatsapp_contact(support)
    number = support[:whatsapp].presence or return
    hours, reply = support.values_at(:hours, :whatsapp_reply).map(&:presence)
    hint = hours && reply ? t("shared.help_sheet.whatsapp.hint", hours:, reply:) : hours || reply
    Contact.new(key: :whatsapp, icon: "chat-bubble-left-right", href: "https://wa.me/#{number}",
                hint: hint || t("shared.help_sheet.whatsapp.hint_default"), external: true)
  end

  def call_contact(support)
    number = support[:phone].presence or return
    hours = support[:hours].presence
    Contact.new(key: :call, icon: "phone", href: "tel:+#{number}",
                hint: (t("shared.help_sheet.call.hint", hours:) if hours), external: false)
  end
end
