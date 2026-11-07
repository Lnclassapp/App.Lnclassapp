# 🌐 DELIVERY · Billing::SubscriptionsController
# Rôle : Mon abonnement, réservé à l'élève : état de l'accès, points relais de son école, saisie du code ; zéro logique métier
# ADR  : cartes-activation (contexte billing, §4.5) · UDR : abonnement-eleve
module Billing
  class SubscriptionsController < AuthenticatedController
    allow_roles :student
    helper_method :subscription_date

    def show
      load_page
    end

    private

    # Partagée avec Billing::ActivationsController, qui re-rend la page en échec : l'accès (gratuit, abonné, bloqué) et,
    # sauf abonné, les points relais actifs de l'école de l'élève.
    def load_page
      @access = Queries::Billing::StudentAccessQuery.new.call(student_id: current_actor.user_id, at: Time.zone.now)
      return if @access.status == :subscribed

      school_id = relay_points.school_id_of_student(student_id: current_actor.user_id)
      @relay_points = school_id ? relay_points.for_school(school_id:) : []
    end

    # « 31 juillet 2027 » ; nil reste nil.
    def subscription_date(date) = date && I18n.l(date, format: :long).squish

    def relay_points = @relay_points_repository ||= Repositories::Billing::RelayPointRepository.new
  end
end
