# 🌐 DELIVERY · Teams::Crm::StagesController
# Rôle : sous-bloc « Étape et responsable » de la fiche (frame school_crm_stage) ; saisit l'étape en modale ; garde ManageCrmPolicy héritée
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi » de la fiche établissement)
module Teams
  module Crm
    class StagesController < BaseController
      # Saisie de l'étape : les règles sont celles du use case, qui rend ses erreurs ici.
      class StageForm
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :stage, :string
        attribute :lost_reason, :string

        def self.model_name = ActiveModel::Name.new(self, nil, "StageForm")
      end

      # Saisie du responsable (public_id du membre, vide = aucun).
      class OwnerForm
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :owner_public_id, :string

        def self.model_name = ActiveModel::Name.new(self, nil, "OwnerForm")
      end

      # Ce que le sous-bloc affiche : l'école, son suivi, l'étape affichée (saisie croisée avec l'usage), le responsable parmi les membres assignables.
      Panel = Data.define(:school, :account, :stage, :members, :owner) do
        def self.load(school)
          account = Repositories::Crm::AccountRepository.new.find_by_school_id(school_id: school.id) || Entities::Crm::Account.blank(school.id)
          usage = Queries::Crm::SchoolUsageQuery.new.call(school_ids: [ school.id ]).fetch(school.id)
          members = Queries::Crm::AssignableMembersQuery.new.call
          new(school:, account:, stage: usage.stage(saved: account.stage, today: Date.current), members:,
              owner: members.find { it.user_id == account.owner_id })
        end

        # Un responsable nommé mais absent des membres assignables (anonymisé, devenu `content`) est indisponible.
        def owner_unavailable? = account.owned? && owner.nil?
        def stage_form = StageForm.new(stage: account.stage, lost_reason: account.lost_reason)
        def owner_form = OwnerForm.new(owner_public_id: owner&.public_id.to_s)
      end

      before_action :load_school
      before_action :load_panel

      def show; end

      def update
        @form = @stage_form = StageForm.new(params.fetch(:stage, {}).permit(:stage, :lost_reason))
        result = use_case.call(actor: current_actor, school_id: @school.id, stage: @form.stage, lost_reason: @form.lost_reason)
        @open = :stage
        render_result result, form: "teams/crm/stages/show", success: ->(_) { respond_updated }
      end

      private

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      def load_panel
        @panel = Panel.load(@school)
        @stage_form = @panel.stage_form
        @owner_form = @panel.owner_form
      end

      # Le suivi est relu après l'écriture : le sous-bloc remplacé montre l'état enregistré, modales fermées.
      def respond_updated
        load_panel
        @open = nil
        respond_to do |format|
          format.turbo_stream { render "teams/crm/stages/update" }
          format.html { redirect_to school_path(@school.public_id), notice: t(".done"), status: :see_other }
        end
      end

      def use_case
        UseCases::Crm::SetStage.new(accounts: Repositories::Crm::AccountRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
                                    transaction: Repositories::Shared::Transaction.new, policy: Policies::Crm::ManageCrmPolicy.new,
                                    clock: Time.zone)
      end
    end
  end
end
