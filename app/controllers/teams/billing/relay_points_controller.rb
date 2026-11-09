# 🌐 DELIVERY · Teams::Billing::RelayPointsController
# Rôle : l'équipe liste, crée et modifie les points relais et leurs écoles (modale), lit la fiche d'un point relais, ses lots, ses chiffres de caisse et ses versements
# ADR  : 0126 (contexte billing, §4.1) · UDR : 0159 §3.2 et §3.3
module Teams
  module Billing
    class RelayPointsController < BaseController
      before_action :load_relay_point, only: %i[show edit update]
      before_action :load_school_choices, only: %i[new create edit update]

      def index
        @relay_points = relay_points.list
      end

      def show
        @batches = relay_points.batches_of(relay_point_id: @relay_point.id)
        @school_names = relay_points.school_names(school_ids: @relay_point.school_ids).values
        @cashbox_line = cashbox_line
        @remittances = Repositories::Billing::RemittanceRepository.new.for_relay_point(relay_point_id: @relay_point.id)
      end

      def new
        @form = Dtos::Billing::RelayPointInput.new
      end

      def create
        @form = form_input
        render_result save_relay_point.call(actor: current_actor, dto: @form), form: :new,
                                                                              success: ->(point) { saved(point, :created) }
      end

      def edit
        @form = Dtos::Billing::RelayPointInput.new(name: @relay_point.name, location: @relay_point.location, phone: @relay_point.phone,
                                                   active: @relay_point.active, school_ids: @relay_point.school_ids)
      end

      def update
        @form = form_input
        render_result save_relay_point.call(actor: current_actor, dto: @form, public_id: @relay_point.public_id), form: :edit,
                                                                                                                  success: ->(point) { saved(point, :updated) }
      end

      private

      def load_relay_point
        @relay_point = relay_points.find(public_id: params[:public_id])
        render_not_found if @relay_point.nil?
      end

      def load_school_choices = @school_choices = relay_points.school_choices

      # La modale est ouverte dans le frame « modal » : la redirection quitte le frame (data-turbo-frame="_top" du formulaire).
      def saved(point, change)
        redirect_to teams_billing_relay_point_path(point.public_id), notice: t(".#{change}", name: point.name), status: :see_other
      end

      def form_input
        Dtos::Billing::RelayPointInput.new(params.expect(relay_point: [ :name, :location, :phone, :active, { school_ids: [] } ]))
      end

      # Les chiffres de caisse du point relais : sa ligne de la caisse de l'équipe (une requête par agrégat, pas par point relais).
      def cashbox_line = Queries::Billing::CashboxQuery.new.call(at: Time.current).relays.find { it.id == @relay_point.id }

      def relay_points = @relay_points_repository ||= Repositories::Billing::RelayPointRepository.new

      def save_relay_point
        UseCases::Billing::SaveRelayPoint.new(relay_points:, audit_log: Repositories::Identity::AuditLogRepository.new,
                                              transaction: Repositories::Shared::Transaction.new,
                                              policy: Policies::Billing::ManageBillingPolicy.new, clock: Time.zone)
      end
    end
  end
end
