# acces-beta : rejoue la règle d'après-bêta (7 jours gratuits puis abonnement) en fermant le réglage Offer::BETA_OPEN_ACCESS.
# Les tests tournent en processus parallèles (pas en threads) : l'échange de constante ne fuit pas d'un test à l'autre.
module BillingBetaHelper
  ActiveSupport::TestCase.include(self)

  def set_beta_open_access(open)
    offer = Entities::Billing::Offer
    previous = offer::BETA_OPEN_ACCESS
    offer.send(:remove_const, :BETA_OPEN_ACCESS)
    offer.const_set(:BETA_OPEN_ACCESS, open)
    previous
  end

  # Ferme la bêta pour tout le test courant ; le réglage d'origine (retenu au premier appel seulement) revient au teardown.
  def close_beta_for_this_test
    previous = set_beta_open_access(false)
    @_billing_beta_restore = previous if @_billing_beta_restore.nil?
  end

  def after_teardown
    set_beta_open_access(@_billing_beta_restore) unless @_billing_beta_restore.nil?
    @_billing_beta_restore = nil
    super
  end
end
