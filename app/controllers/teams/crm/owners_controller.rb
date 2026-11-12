# 🌐 DELIVERY · Teams::Crm::OwnersController
# Rôle : nomme le responsable d'une école, en modale du sous-bloc « Étape et responsable » ; `edit` renvoie à la fiche, où vit la modale
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi » de la fiche établissement)
module Teams
  module Crm
    class OwnersController < BaseController
      # Un public_id qui n'est pas celui d'un membre assignable : le use case le refuse (aucun id ne vaut 0).
      UNKNOWN_MEMBER = 0

      before_action :load_school
      before_action :load_panel

      def edit
        redirect_to school_path(@school.public_id), status: :see_other
      end

      def update
        @form = @owner_form = StagesController::OwnerForm.new(params.fetch(:owner, {}).permit(:owner_public_id))
        result = rename_owner_error(use_case.call(actor: current_actor, school_id: @school.id, owner_id: owner_id))
        @open = :owner
        result = conflict_message(result)
        render_result result, form: "teams/crm/stages/show", success: ->(_) { respond_updated }
      end

      private

      # Une première écriture simultanée perdue : le message dit quoi faire, dans la modale.
      def conflict_message(result)
        return result unless result.failure? && result.code == :conflict

        Shared::Result.failure(:conflict, errors: { base: [ t("teams.crm.stages.conflict") ] })
      end

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      def load_panel
        @panel = StagesController::Panel.load(@school)
        @stage_form = @panel.stage_form
        @owner_form = @panel.owner_form
      end

      def owner_id
        return nil if @form.owner_public_id.blank?

        @panel.members.find { it.public_id == @form.owner_public_id }&.user_id || UNKNOWN_MEMBER
      end

      def respond_updated
        load_panel
        @open = nil
        respond_to do |format|
          format.turbo_stream { render "teams/crm/owners/update" }
          format.html { redirect_to school_path(@school.public_id), notice: t(".done"), status: :see_other }
        end
      end

      # Le use case parle d'ids, le formulaire de public_id.
      def rename_owner_error(result)
        return result unless result.failure? && result.errors.key?(:owner_id)

        Shared::Result.failure(result.code, errors: { owner_public_id: result.errors[:owner_id] })
      end

      def use_case
        UseCases::Crm::AssignOwner.new(accounts: Repositories::Crm::AccountRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
                                       transaction: Repositories::Shared::Transaction.new, policy: Policies::Crm::ManageCrmPolicy.new,
                                       assignable: Queries::Crm::AssignableMembersQuery.new, clock: Time.zone)
      end
    end
  end
end
