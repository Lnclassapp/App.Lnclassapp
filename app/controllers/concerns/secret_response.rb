# 🌐 DELIVERY · SecretResponse — marque les actions qui affichent un secret à usage unique
# Rôle : `secret_response :create` pose no-store + Pragma sur toute réponse de l'action, et exempte la page du cache Turbo
# ADR  : 0031, 0032, 0038, 0049
module SecretResponse
  extend ActiveSupport::Concern

  included do
    class_attribute :secret_actions, instance_writer: false, default: [].freeze
    before_action :keep_response_out_of_caches, if: :secret_response?
    helper_method :secret_response?
  end

  class_methods do
    # Liste close, vérifiée par test/controllers/concerns/secret_response_test.rb.
    def secret_response(*actions)
      self.secret_actions = (secret_actions + actions.map(&:to_s)).uniq.freeze
    end
  end

  private

  def secret_response? = secret_actions.include?(action_name)

  # Ni navigateur (bfcache, Retour), ni proxy ne gardent la réponse ; le layout et les flux ajoutent l'exemption Turbo.
  def keep_response_out_of_caches
    no_store
    response.headers["Pragma"] = "no-cache"
  end
end
