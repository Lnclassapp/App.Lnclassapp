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

  test "a number is digits only, country code included, 12 or 13 digits, or left empty" do
    ENVIRONMENTS.each do |env|
      %i[phone whatsapp].each do |key|
        value = support(env)[key].to_s
        assert_match(/\A(\d{12,13})?\z/, value, "#{env}.#{key} : chiffres seuls, indicatif 225 compris, sans +")
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
