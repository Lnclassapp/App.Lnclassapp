# 🌐 DELIVERY · Teams::Crm::FollowUpsController
# Rôle : relances ouvertes d'une école (frame de la fiche), création en modale, page « Relances » (« À relancer », « Mes relances », « Sans destinataire » pour l'admin)
# ADR  : XXXX (contexte crm) · UDR : XXXX (bloc « Suivi »), XXXX (pipeline et relances)
module Teams
  module Crm
    class FollowUpsController < BaseController
            DEFAULT_DELAY = 3 # jours

      # Saisie du formulaire de création : les règles sont celles du use case, qui rend ses erreurs ici.
      class Form
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :due_on, :string
        attribute :assignee_public_id, :string
        attribute :reason, :string

        def self.model_name = ActiveModel::Name.new(self, nil, "FollowUpForm")
      end

      before_action :load_school, only: %i[school new create]
      before_action :load_members, only: %i[new create]

      def school
        @follow_ups = query.for_school(school_id: @school.id)
      end

      def index
        @orphans_visible = current_actor.team_role == "admin"
        @tab = selected_tab
        @all_schools = params[:scope] == "all"
        @signals = @all_schools ? signals_query.all(page: params[:signals_page]) : signals_query.mine(user_id: current_actor.user_id, page: params[:signals_page])
        @mine = query.mine(user_id: current_actor.user_id, page: params[:mine_page])
        @orphans = query.orphans(page: params[:orphans_page]) if @orphans_visible
      end

      def new
        @form = Form.new(due_on: (Date.current + DEFAULT_DELAY).iso8601, assignee_public_id: default_assignee.public_id)
      end

      def create
        @form = Form.new(form_params)
        assignee = @members.find { it.public_id == @form.assignee_public_id }
        result = use_case.call(actor: current_actor, school_id: @school.id, assignee_id: assignee&.user_id, due_on: parsed_date(@form.due_on),
                               reason: @form.reason)
        render_result rename_assignee_error(result), form: "teams/crm/follow_ups/new", success: ->(_) { respond_created }
      end

      private

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      def load_members
        @members = Queries::Crm::AssignableMembersQuery.new.call
      end

      # Le responsable de l'école, sinon moi.
      def default_assignee
        owner_id = query.owner_id(school_id: @school.id)
        @members.find { it.user_id == owner_id } || @members.find { it.user_id == current_actor.user_id } || @members.first
      end

      def respond_created
        @follow_ups = query.for_school(school_id: @school.id)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to school_path(@school.public_id), notice: t(".done"), status: :see_other }
        end
      end

      def selected_tab
        return "orphans" if @orphans_visible && (params[:tab] == "orphans" || (params[:tab].blank? && params[:orphans_page].present?))
        return "mine" if params[:tab] == "mine" || (params[:tab].blank? && params[:mine_page].present?)

        "signals" # l'onglet par défaut (UDR pipeline et relances)
      end

      def form_params = params.fetch(:follow_up, {}).permit(:due_on, :assignee_public_id, :reason)

      def parsed_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      # Le use case parle d'ids, le formulaire de public_id.
      def rename_assignee_error(result)
        return result unless result.failure? && result.errors.key?(:assignee_id)

        Shared::Result.failure(result.code, errors: result.errors.transform_keys { it == :assignee_id ? :assignee_public_id : it })
      end

      def use_case
        UseCases::Crm::ScheduleFollowUp.new(follow_ups: Repositories::Crm::FollowUpRepository.new,
                                            policy: Policies::Crm::ManageCrmPolicy.new, assignable: Queries::Crm::AssignableMembersQuery.new,
                                            clock: Time.zone)
      end

      def query = Queries::Crm::FollowUpsQuery.new

      def signals_query = Queries::Crm::FollowUpSignalsQuery.new
    end
  end
end
