# 🌐 DELIVERY · School::DrenaSchoolsController
# Rôle : établissements actifs d'une DRENA, publics et limités en débit : frame « schools » (enseignant), « picker_schools » (élève) ou JSON
# ADR  : 0026, 0029, 0050, 0083, 0085 · UDR : 0024, 0079, 0081
module School
  class DrenaSchoolsController < ApplicationController
    allow_unauthenticated_access
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    # Le scope des champs du frame : inscription (défaut) ou écran d'attente (ADR-0082 §4.5) ; toute autre valeur → défaut.
    SCOPES = %w[teacher_registration school_join].freeze
    # ADR-0085 §4.2 : la cascade élève (UDR-0081 §3.3), à l'inscription ou dans « Choisis ta classe ».
    PICKER_SCOPES = %w[student_registration student_classroom_choice].freeze

    # Le scope d'une liste de la cascade élève ; toute autre valeur → l'inscription.
    def self.picker_scope(raw) = (PICKER_SCOPES.include?(raw) ? raw : PICKER_SCOPES.first).to_sym

    def index
      return render_not_found unless drena_known?

      schools = options.schools_for(drena_public_id:)
      respond_to do |format|
        format.html { render locals: { schools:, drena_public_id:, registration: nil, scope:, picker: picker? } }
        format.json { render json: schools.map { { public_id: it.public_id, name: it.name } } }
      end
    end

    private

    def drena_public_id = params[:drena_public_id]
    def picker? = PICKER_SCOPES.include?(params[:scope])
    def drena_known? = options.drenas.any? { it.public_id == drena_public_id }
    def options = @options ||= Queries::School::SchoolOptionsQuery.new

    def scope
      return self.class.picker_scope(params[:scope]) if picker?

      SCOPES.include?(params[:scope]) ? params[:scope].to_sym : SCOPES.first.to_sym
    end

    # La cascade élève montre l'état d'erreur dans son frame, avec « Réessayer » ; ailleurs, la réponse 429 de Rails.
    def refuse_too_many
      raise ActionController::TooManyRequests unless picker? && request.format.html?

      render :index, status: :too_many_requests,
                     locals: { schools: [], drena_public_id:, registration: nil, scope:, picker: true, rate_limited: true }
    end
  end
end
