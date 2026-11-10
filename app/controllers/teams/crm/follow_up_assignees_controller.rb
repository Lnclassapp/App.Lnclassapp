# 🌐 DELIVERY · Teams::Crm::FollowUpAssigneesController
# Rôle : réattribue une relance ouverte à un autre membre, en modale ; l'admin ou le responsable de l'école seuls (UseCases::Crm::ReassignFollowUp)
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi »), XXXX (pipeline et relances)
module Teams
  module Crm
    class FollowUpAssigneesController < BaseController
      # Saisie du formulaire de réattribution : le use case juge, ses erreurs arrivent ici.
      class Form
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :assignee_public_id, :string

        def self.model_name = ActiveModel::Name.new(self, nil, "FollowUpAssigneeForm")
      end

      before_action :load_follow_up
      before_action :load_members

      def edit
        return render_forbidden unless reassignable?

        @form = Form.new(assignee_public_id: current_member&.public_id)
        render template: "teams/crm/follow_ups/edit"
      end

      def update
        @form = Form.new(params.fetch(:follow_up, {}).permit(:assignee_public_id))
        assignee = @members.find { it.public_id == @form.assignee_public_id }
        result = use_case.call(actor: current_actor, public_id: @follow_up.public_id, assignee_id: assignee&.user_id)
        render_result rename_assignee_error(result), form: "teams/crm/follow_ups/edit", success: ->(reassigned) { respond_reassigned(reassigned, assignee) }
      end

      private

      def load_follow_up
        @follow_up = Repositories::Crm::FollowUpRepository.new.find_by_public_id(public_id: params[:follow_up_public_id])
        render_not_found if @follow_up.nil? || !@follow_up.open?
      end

      def load_members
        @members = Queries::Crm::AssignableMembersQuery.new.call
      end

      def reassignable?
        owner_id = Queries::Crm::FollowUpsQuery.new.owner_id(school_id: @follow_up.school_id)
        UseCases::Crm::ReassignFollowUp.allowed?(actor: current_actor, owner_id:)
      end

      # Un destinataire indisponible n'est pas dans la liste : rien n'est présélectionné.
      def current_member = @members.find { it.user_id == @follow_up.assignee_id }

      def respond_reassigned(follow_up, assignee)
        @public_id = follow_up.public_id
        @assignee_name = assignee.name
        @school = Repositories::School::SchoolRepository.new.find_by_id(id: follow_up.school_id)
        @follow_ups = Queries::Crm::FollowUpsQuery.new.for_school(school_id: follow_up.school_id)
        respond_to do |format|
          format.turbo_stream { render template: "teams/crm/follow_ups/reassign" }
          format.html { redirect_to teams_follow_ups_path, notice: t(".done", name: @assignee_name), status: :see_other }
        end
      end

      # Seule erreur possible du use case : le destinataire (il parle d'ids, le formulaire de public_id).
      def rename_assignee_error(result)
        return result unless result.failure? && result.errors.key?(:assignee_id)

        Shared::Result.failure(result.code, errors: { assignee_public_id: result.errors[:assignee_id] })
      end

      def use_case
        UseCases::Crm::ReassignFollowUp.new(follow_ups: Repositories::Crm::FollowUpRepository.new, owners: Queries::Crm::FollowUpsQuery.new,
                                            policy: Policies::Crm::ManageCrmPolicy.new, assignable: Queries::Crm::AssignableMembersQuery.new)
      end
    end
  end
end
