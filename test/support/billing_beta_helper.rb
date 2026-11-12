# acces-beta : rejoue la règle d'après-bêta (7 jours gratuits puis abonnement) en posant Offer::BETA_ENDS_ON.
# Fermer la bêta au jour de la mise en ligne (LAUNCH_ON) redonne exactement la règle d'ADR-0126 : les dates des tests restent vraies.
# Les tests tournent en processus parallèles (pas en threads) : l'échange de constante ne fuit pas d'un test à l'autre.
module BillingBetaHelper
  ActiveSupport::TestCase.include(self)

  BETA_UNSET = Object.new.freeze

  def set_beta_ends_on(date)
    offer = Entities::Billing::Offer
    previous = offer::BETA_ENDS_ON
    offer.send(:remove_const, :BETA_ENDS_ON)
    offer.const_set(:BETA_ENDS_ON, date)
    previous
  end

  # Ferme la bêta pour tout le test courant (par défaut au jour de la mise en ligne) ; le réglage d'origine, retenu au
  # premier appel seulement, revient au teardown.
  def close_beta_for_this_test(on: Entities::Billing::Offer::LAUNCH_ON)
    previous = set_beta_ends_on(on)
    @_billing_beta_restore = previous if billing_beta_restore.equal?(BETA_UNSET)
  end

  def after_teardown
    set_beta_ends_on(@_billing_beta_restore) unless billing_beta_restore.equal?(BETA_UNSET)
    @_billing_beta_restore = BETA_UNSET
    super
  end

  private

  def billing_beta_restore = defined?(@_billing_beta_restore) ? @_billing_beta_restore : BETA_UNSET
end
