# 🌐 DELIVERY · WrongPinLimit — plafond commun des codes secrets faux, par adresse
# Rôle : `/login` et l'entrée élève partagent une seule clé de débit : 5 codes faux par minute et par adresse, quel que soit le point d'entrée
# ADR  : 0050 (amendé le 2026-11-24)
module WrongPinLimit
  extend ActiveSupport::Concern

  WRONG_PIN_LIMIT = { to: 5, within: 1.minute }.freeze

  private

  def wrong_pin_key = "identity/wrong_pin:#{request.remote_ip}"

  def wrong_pin_limit_reached? = Rails.cache.read(wrong_pin_key).to_i >= WRONG_PIN_LIMIT[:to]

  def count_wrong_pin
    Rails.cache.write(wrong_pin_key, 0, expires_in: WRONG_PIN_LIMIT[:within], unless_exist: true)
    Rails.cache.increment(wrong_pin_key, 1, expires_in: WRONG_PIN_LIMIT[:within])
  end
end
