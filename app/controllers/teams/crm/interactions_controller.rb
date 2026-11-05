# 🌐 DELIVERY · Teams::Crm::InteractionsController
# Rôle : le journal des échanges d'une école (frame school_crm_journal, 20 par page) et la modale « Noter un échange » ; ajout seul
# ADR  : XXXX (contexte crm), 0028 · UDR : XXXX (bloc « Suivi » de la fiche établissement) · CA-11, CA-12 : ni edit, ni update, ni destroy
module Teams
  module Crm
    class InteractionsController < BaseController
      PER_PAGE = 20
      FOLLOW_UP_DELAY = 3 # jours
      FIELDS = %i[kind outcome occurred_at contact_public_id contact_name next_step note create_follow_up follow_up_due_on source].freeze

      # Saisie de la modale : un objet de formulaire (les erreurs du use case s'y rejoignent), jamais une entité.
      class Form
        include ActiveModel::Model
        include ActiveModel::Attributes

        attribute :kind, :string
        attribute :outcome, :string
        attribute :occurred_at, :string
        attribute :contact_public_id, :string
        attribute :contact_name, :string
        attribute :next_step, :string
        attribute :note, :string
        attribute :create_follow_up, :boolean, default: false
        attribute :follow_up_due_on, :string
        attribute :follow_up_reason, :string
        attribute :source, :string, default: "manual"
        attribute :school_public_id, :string
      end

      before_action :load_school
      helper_method :contact_choices

      def index
        load_journal(params[:page].to_s.to_i.clamp(1, 10_000))
      end

      def new
        @form = Form.new(school_public_id: @school.public_id, occurred_at: now_field, create_follow_up: false,
                         follow_up_due_on: (Time.zone.today + FOLLOW_UP_DELAY).to_s)
      end

      def create
        @form = form_input
        contact = resolve_contact
        return render_unknown_contact if contact == :unknown

        result = record_interaction.call(actor: current_actor, school_id: @school.id, **interaction_values(contact))
        render_result(result, form: :new, success: ->(_interaction) { respond_created })
      end

      private

      def respond_created
        @follow_up_created = @form.create_follow_up
        load_journal(1)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to school_path(@school.public_id), notice: t(".created"), status: :see_other }
        end
      end

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      # Une ligne de plus que la page : savoir s'il reste des échanges plus anciens sans les compter.
      def load_journal(page)
        @page = page
        rows = Repositories::Crm::InteractionRepository.new.recent_for_school(school_id: @school.id, limit: PER_PAGE + 1,
                                                                              offset: (page - 1) * PER_PAGE)
        @has_older = rows.size > PER_PAGE
        @interactions = rows.first(PER_PAGE)
        @author_names = Queries::Crm::AssignableMembersQuery.new.call.to_h { [ it.user_id, it.name ] }
      end

      def form_input
        values = params.expect(interaction: FIELDS).to_h.symbolize_keys
        Form.new(school_public_id: @school.public_id, **values)
      end

      def contact_choices
        @contact_choices ||= Repositories::Crm::ContactRepository.new.active_for_school(school_id: @school.id)
                                                                  .map { [ it.full_name, it.public_id ] }
      end

      # Un contact choisi donne son nom ; un contact d'une autre école ou archivé est refusé.
      def resolve_contact
        return nil if @form.contact_public_id.blank?

        contact = Repositories::Crm::ContactRepository.new.find_by_public_id(public_id: @form.contact_public_id)
        contact && contact.school_id == @school.id && !contact.archived? ? contact : :unknown
      end

      def render_unknown_contact
        @form.errors.add(:contact_public_id, :invalid)
        render :new, status: :unprocessable_entity
      end

      def interaction_values(contact)
        { kind: @form.kind, outcome: @form.outcome, occurred_at: parse_time(@form.occurred_at), source: @form.source,
          contact_name: contact&.full_name || @form.contact_name, next_step: @form.next_step, note: @form.note,
          follow_up: follow_up_values }
      end

      # Un instant illisible reste illisible (le use case le refuse) : il ne devient pas « maintenant ».
      def parse_time(text)
        return nil if text.blank?

        Time.zone.parse(text) || Time.zone.at(0)
      rescue ArgumentError
        Time.zone.at(0)
      end

      def follow_up_values
        return nil unless @form.create_follow_up

        { due_on: parse_date(@form.follow_up_due_on), assignee_id: current_actor.user_id,
          reason: @form.next_step.to_s.strip.presence&.first(Entities::Crm::FollowUp::REASON_MAX) || t("teams.crm.interactions.create.default_reason") }
      end

      def parse_date(text)
        Date.iso8601(text.to_s)
      rescue Date::Error
        nil
      end

      def now_field = Time.zone.now.strftime("%Y-%m-%dT%H:%M")

      def record_interaction
        UseCases::Crm::RecordInteraction.new(
          interactions: Repositories::Crm::InteractionRepository.new, follow_ups: Repositories::Crm::FollowUpRepository.new,
          policy: Policies::Crm::ManageCrmPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
        )
      end
    end
  end
end
