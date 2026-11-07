# 🌐 DELIVERY · RedirectsSubscriptionRequired — le refus « période gratuite finie » mène à Mon abonnement
# Rôle : sur :subscription_required, range le chemin de retour en session (relu par l'activation) puis redirige vers Mon abonnement
# ADR  : cartes-activation (contexte billing, §4.6) · UDR : abonnement-eleve (§3, « Redirection de blocage »)
module RedirectsSubscriptionRequired
  extend ActiveSupport::Concern

  RETURN_KEY = :billing_return_to

  private

  def subscription_required?(result) = result.failure? && result.errors.fetch(:base, []).include?(:subscription_required)

  # return_to : le chemin de la page d'où l'élève vient (jamais une adresse complète : seule une chaîne « /… » est gardée).
  # Sous un frame Turbo (entraînement de notion), une redirection n'aurait pas le frame : le frame propose le lien, hors du frame.
  def redirect_subscription_required(return_to:)
    session[RETURN_KEY] = return_to if return_to.is_a?(String) && return_to.start_with?("/") && !return_to.start_with?("//")
    if turbo_frame_request?
      render html: helpers.tag.turbo_frame(helpers.link_to(t("billing.subscription_required"), billing_subscription_path, class: "text-brand underline"),
                                           id: request.headers["Turbo-Frame"], target: "_top"),
             layout: false, status: :payment_required
    else
      redirect_to billing_subscription_path, flash: { info: t("billing.subscription_required") }, status: :see_other
    end
  end
end
