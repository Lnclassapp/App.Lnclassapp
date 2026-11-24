# 🌐 DELIVERY · WrongPinLimit — plafond commun des codes secrets faux, par adresse
# Rôle : `/login` et l'entrée élève partagent une seule clé de débit : 5 codes faux par minute et par adresse, quel que soit le point d'entrée
# ADR  : 0050 (amendé le 2026-11-24)
module WrongPinLimit
  extend ActiveSupport::Concern

  WRONG_PIN_LIMIT = { to: 5, within: 1.minute }.freeze

  private

  def wrong_pin_key = "identity/wrong_pin:#{request.remote_ip}"

  # Réserve une place avant l'essai (atomique : des envois simultanés ne lisent pas tous 0). Refusée au-delà du plafond.
  def claim_pin_attempt
    Rails.cache.write(wrong_pin_key, 0, expires_in: WRONG_PIN_LIMIT[:within], unless_exist: true)
    return true if Rails.cache.increment(wrong_pin_key, 1, expires_in: WRONG_PIN_LIMIT[:within]).to_i <= WRONG_PIN_LIMIT[:to]

    release_pin_attempt
    false
  end

  # Rend la place quand l'essai n'était pas un code faux.
  def release_pin_attempt = Rails.cache.decrement(wrong_pin_key, 1, expires_in: WRONG_PIN_LIMIT[:within])
end
