# 🌐 DELIVERY · Billing::ActivationsController
# Rôle : l'élève saisit le code de sa carte ; succès → Mon abonnement (ou l'exercice qui l'avait bloqué), échec → la page en 422, 5 essais par 10 minutes
# ADR  : 0126 (contexte billing, §4.3 et §4.4), 0050 · UDR : 0158
module Billing
  # Hérite de la page pour la re-rendre en échec (mêmes données, mêmes vues) ; seule l'action `create` est routée.
  class ActivationsController < SubscriptionsController
    rate_limit to: 5, within: 10.minutes, only: :create, by: -> { current_actor.user_id }, with: -> { refuse_rate_limited }

    def create
      result = activate_card.call(actor: current_actor, raw_code: typed_code)
      return redirect_after(result.value) if result.success?
      return render_forbidden if result.code == :forbidden

      refuse(result)
    end

    private

    def typed_code
      code = params[:code]
      code.is_a?(String) ? code : ""
    end

    # Le chemin rangé en session par le blocage d'un exercice (lot « période gratuite ») : relatif au site seulement.
    def redirect_after(card)
      target = safe_return_path(session.delete(RedirectsSubscriptionRequired::RETURN_KEY)) || billing_subscription_path
      redirect_to target, notice: t(".activated", date: subscription_date(card.valid_until)), status: :see_other
    end

    def safe_return_path(value)
      value if value.is_a?(String) && value.match?(%r{\A/(?![/\\])})
    end

    def refuse(result)
      key = Array(result.errors[:base]).first || Array(result.errors[:code]).first
      fallback = t("errors.codes.#{result.code}")
      @code_error = key ? t(".errors.#{key}", date: subscription_date(Array(result.errors[:subscribed_until]).first), default: fallback) : fallback
      render_page(:unprocessable_content)
    end

    def refuse_rate_limited
      @code_error = t("billing.activations.create.errors.rate_limited")
      render_page(:too_many_requests)
    end

    def render_page(status)
      @code = typed_code
      load_page
      render :show, status:
    end

    def activate_card
      UseCases::Billing::ActivateCard.new(cards: Repositories::Billing::CardRepository.new, schools: relay_points,
                                          audit_log: Repositories::Identity::AuditLogRepository.new,
                                          transaction: Repositories::Shared::Transaction.new,
                                          policy: Policies::Billing::ActivateCardPolicy.new, clock: Time.zone)
    end
  end
end
