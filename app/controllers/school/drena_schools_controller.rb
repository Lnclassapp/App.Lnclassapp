# 🌐 DELIVERY · School::DrenaSchoolsController
# Rôle : établissements actifs d'une DRENA, publics et limités en débit : frame « schools » (inscription, écran d'attente) ou JSON
# ADR  : 0026, 0029, 0050, 0082 · UDR : 0024, 0078
module School
  class DrenaSchoolsController < ApplicationController
    allow_unauthenticated_access
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }
    # Le scope des champs du frame : inscription (défaut) ou écran d'attente (ADR-0082 §4.5) ; toute autre valeur → défaut.
    SCOPES = %w[teacher_registration school_join].freeze

    def index
      return render_not_found unless drena_known?

      schools = options.schools_for(drena_public_id:)
      respond_to do |format|
        format.html { render locals: { schools:, drena_public_id:, registration: nil, scope: } }
        format.json { render json: schools.map { { public_id: it.public_id, name: it.name } } }
      end
    end

    private

    def drena_public_id = params[:drena_public_id]
    def scope = SCOPES.include?(params[:scope]) ? params[:scope].to_sym : SCOPES.first.to_sym
    def drena_known? = options.drenas.any? { it.public_id == drena_public_id }
    def options = @options ||= Queries::School::SchoolOptionsQuery.new
  end
end
