# 🌐 DELIVERY · Teams::Crm::FollowUpCompletionsController
# Rôle : « Faite » sur une relance (page « Relances » ou fiche d'une école) ; terminer une relance déjà faite est sans effet
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi »), XXXX (pipeline et relances)
module Teams
  module Crm
    class FollowUpCompletionsController < BaseController
      def update
        repository = Repositories::Crm::FollowUpRepository.new
        follow_up = repository.find_by_public_id(public_id: params[:follow_up_public_id])
        return render_not_found if follow_up.nil?

        result = UseCases::Crm::CompleteFollowUp.new(follow_ups: repository, policy: Policies::Crm::ManageCrmPolicy.new, clock: Time.zone)
                                                .call(actor: current_actor, public_id: follow_up.public_id)
        render_result result, success: ->(done) { respond_done(done) }
      end

      private

      def respond_done(follow_up)
        @public_id = follow_up.public_id
        @school = Repositories::School::SchoolRepository.new.find_by_id(id: follow_up.school_id)
        @follow_ups = Queries::Crm::FollowUpsQuery.new.for_school(school_id: follow_up.school_id)
        respond_to do |format|
          format.turbo_stream { render template: "teams/crm/follow_ups/complete" }
          format.html { redirect_to teams_follow_ups_path, notice: t(".done"), status: :see_other }
        end
      end
    end
  end
end
