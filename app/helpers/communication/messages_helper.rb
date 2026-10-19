# 🌐 UI · Communication::MessagesHelper — signature d'une carte d'annonce
# Rôle : « Lnclass », « M. Kouassi · SVT », « M. Kouassi · PC, SVT », « Mme Kamaté · Direction » ; un auteur anonymisé ne garde que sa fonction
# ADR  : 0036, 0078, 0103 · UDR : 0071 (§3.2), 0127 (§3.4)
module Communication
  module MessagesHelper
    # card : Queries::Communication::InboxQuery::MessageCard. La civilité vient du genre, la fonction de l'enseignant
    # est sa matière, ou les noms courts de ses matières (UDR-0127 §3.4) ; aucune fonction de direction n'est en base
    # (UDR-0071 §2, écarts).
    def announcement_signature(card)
      return t("communication.signature.team") if card.author_role == :team

      function = card.author_role == :school_admin ? t("communication.signature.school_admin") : Queries::Identity::TeacherMaterialsQuery.label(card.materials)
      return function.to_s if card.anonymized?

      [ "#{t("communication.signature.#{card.gender}")} #{card.last_name}", function ].compact.join(" · ")
    end
  end
end
