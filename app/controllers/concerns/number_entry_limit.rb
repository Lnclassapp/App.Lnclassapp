# 🌐 DELIVERY · NumberEntryLimit — débit commun de l'entrée « numéro d'abord », par adresse
# Rôle : /login et /student partagent deux compteurs (minute, heure) : un numéro essayé sur l'une compte pour l'autre ; les codes faux ont le leur (WrongPinLimit)
# ADR  : 0141-entree-eleve-revele-un-numero-inscrit (§4.2), XXXX-connexion-revele-un-numero-inscrit (§4.2)
module NumberEntryLimit
  extend ActiveSupport::Concern

  # Une classe entre ensemble derrière une seule adresse (le wifi de l'école) et envoie deux fois (numéro, puis code) : 120 par
  # minute. Le plafond horaire borne qui teste des numéros. Même scope et même nom dans les deux contrôleurs : une seule clé.
  MINUTE = { to: 120, within: 1.minute, scope: "identity/number_entries" }.freeze
  HOURLY = { to: 600, within: 1.hour, scope: "identity/number_entries_hourly" }.freeze

  class_methods do
    # with : la réponse « Trop de tentatives » du contrôleur.
    def limit_number_entries(with:)
      rate_limit(**MINUTE, only: :create, by: -> { request.remote_ip }, with:)
      rate_limit(**HOURLY, name: "hourly", only: :create, by: -> { request.remote_ip }, with:)
    end
  end
end
