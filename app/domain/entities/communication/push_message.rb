# 🧠 DOMAINE · Entities::Communication::PushMessage
# Rôle : le texte d'une notification, issu d'un gabarit fermé par motif : ni nom, ni note, ni titre d'annonce
# ADR  : 0146 (§4.2) · PRD §3.1, §4
module Entities
  module Communication
    # title, body : le texte de l'écran verrouillé ; url : où mène un toucher ; tag : un seul affichage par motif.
    PushMessage = Data.define(:title, :body, :url, :tag) do
      # Les clés vivent dans config/locales/communication/push.fr.yml ; seules `material` et `count` entrent dans un texte.
      def self.for(candidate)
        key = "communication.push.messages.#{candidate.motive}"
        # « résultat » a deux textes : une copie corrigée (copy) ou une médaille (medal).
        key += ".#{candidate.variables.fetch(:kind)}" if candidate.motive == "result"
        variables = candidate.variables.slice(:material, :count)
        new(title: I18n.t("communication.push.title"), body: I18n.t("#{key}.body", **variables),
            url: candidate.url, tag: candidate.motive)
      end
    end
  end
end
