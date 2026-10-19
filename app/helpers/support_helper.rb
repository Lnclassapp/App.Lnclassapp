# 🌐 UI · SupportHelper — lignes de la carte d'aide (shared/_help_sheet), depuis config.x.support
# Rôle : FAQ toujours ; WhatsApp (avec un message prêt qui présente la personne, l'élève par son prénom seul) et appel si leur numéro est configuré
# UDR  : 0061 (§3.3, §3.4), 0128, 0057 (§2.5 : rien d'affiché pour une donnée absente) · ADR : 0049 (aucun service tiers), 0029
module SupportHelper
  # `hint` : la ligne grise (horaires, délai), ou nil. `external` : le lien ouvre une autre application.
  Contact = Data.define(:key, :icon, :href, :hint, :external)
  # UDR-0128 §3.1 : rôles présentés dans le message ; l'équipe et le visiteur ont le message simple.
  INTRODUCED_ROLES = %i[student teacher school_admin].freeze
  MESSAGE = "shared.help_sheet.whatsapp.message".freeze

  # `user` : le ShellUser de la personne connectée (déjà lu pour l'en-tête), nil pour un visiteur.
  def support_contacts(support = Rails.configuration.x.support, user: nil)
    [ faq_contact, whatsapp_contact(support, user), call_contact(support) ].compact
  end

  private

  def faq_contact
    Contact.new(key: :faq, icon: "question-mark-circle", href: help_path, hint: t("shared.help_sheet.faq.hint"),
                external: false)
  end

  # UDR-0128 §3.2 : wa.me/<numéro>?text=<message encodé en pourcent> ; jamais un numéro, un secret ni un identifiant.
  def whatsapp_contact(support, user)
    number = support[:whatsapp].presence or return
    hours, reply = support.values_at(:hours, :whatsapp_reply).map(&:presence)
    hint = hours && reply ? t("shared.help_sheet.whatsapp.hint", hours:, reply:) : hours || reply
    href = "https://wa.me/#{number}?text=#{ERB::Util.url_encode(whatsapp_message(user))}"
    Contact.new(key: :whatsapp, icon: "chat-bubble-left-right", href:,
                hint: hint || t("shared.help_sheet.whatsapp.hint_default"), external: true)
  end

  def whatsapp_message(user)
    about = user&.about
    return t("#{MESSAGE}.plain") unless about && INTRODUCED_ROLES.include?(user.role.to_sym)

    who = [ whatsapp_name(user), whatsapp_role(user.role.to_sym, about), about.school ].compact.join(", ")
    t("#{MESSAGE}.introduced", who:)
  end

  # UDR-0128 §3.1 : le texte part vers Meta dès le clic (il est dans l'URL) ; un élève, peut-être mineur, n'y met que son
  # prénom. Les adultes gardent leur nom complet.
  def whatsapp_name(user) = user.role.to_sym == :student ? user.first_name : user.name

  def whatsapp_role(role, about)
    case role
    when :student then about.classroom ? t("#{MESSAGE}.student", classroom: about.classroom) : t("#{MESSAGE}.student_alone")
    when :teacher
      gender = about.gender
      about.material ? t("#{MESSAGE}.teacher.#{gender}", material: about.material) : t("#{MESSAGE}.teacher_alone.#{gender}")
    else t("#{MESSAGE}.school_admin")
    end
  end

  def call_contact(support)
    number = support[:phone].presence or return
    hours = support[:hours].presence
    Contact.new(key: :call, icon: "phone", href: "tel:+#{number}",
                hint: (t("shared.help_sheet.call.hint", hours:) if hours), external: false)
  end
end
