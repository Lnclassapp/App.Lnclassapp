require "test_helper"

# UDR-0061 §3.4 et §3.6 : les données du support sont publiques, rangées dans config/support.yml, jamais dans une vue,
# une locale ni les credentials. Un numéro mal formé est refusé ici, avant d'atteindre la carte d'un élève.
class SupportConfigTest < ActiveSupport::TestCase
  ENVIRONMENTS = %w[development test production].freeze
  KEYS = %i[phone whatsapp hours whatsapp_reply].freeze

  def support(env) = Rails.application.config_for(:support, env:)

  test "every environment declares the four keys" do
    ENVIRONMENTS.each do |env|
      assert_equal KEYS.sort, support(env).keys.sort, "config/support.yml (#{env})"
    end
  end

  # UDR-0128 §3.2 : wa.me n'accepte que le format international sans « + » ni zéro de tête : 0584258085 (sans
  # indicatif) n'ouvre aucune conversation ; la Côte d'Ivoire, c'est 225 suivi des 10 chiffres, 2250584258085.
  test "a number is digits only, country code included and not starting with 0, 12 or 13 digits, or left empty" do
    ENVIRONMENTS.each do |env|
      %i[phone whatsapp].each do |key|
        value = support(env)[key].to_s
        assert_match(/\A([1-9]\d{11,12})?\z/, value, "#{env}.#{key} : chiffres seuls, indicatif 225 compris, sans + ni 0 de tête")
      end
    end
  end

  test "the application reads the support data of its environment" do
    assert_equal support("test"), Rails.configuration.x.support
    assert_predicate Rails.configuration.x.support[:whatsapp], :present?
  end

  # Porteur, 2026-10-02 : WhatsApp et appel au +225 05 84 25 80 85, de 8h à 20h ; aucun délai de réponse donné.
  test "production carries the values given by the owner, and no invented reply delay" do
    %w[production development].each do |env|
      support = support(env)

      assert_equal "2250584258085", support[:whatsapp], env
      assert_equal "2250584258085", support[:phone], env
      assert_equal "8h à 20h", support[:hours], env
      assert_empty support[:whatsapp_reply].to_s, env
    end
  end
end
