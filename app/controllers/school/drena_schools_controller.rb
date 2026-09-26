# 🌐 DELIVERY · School::DrenaSchoolsController
# Rôle : établissements actifs d'une DRENA, publics et limités en débit : frame « schools » de l'inscription, ou JSON
# ADR  : 0026, 0029, 0050 · UDR : 0024
module School
  class DrenaSchoolsController < ApplicationController
    allow_unauthenticated_access
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }

    def index
      return render_not_found unless drena_known?

      schools = options.schools_for(drena_public_id:)
      respond_to do |format|
        format.html { render locals: { schools:, drena_public_id:, registration: nil } }
        format.json { render json: schools.map { { public_id: it.public_id, name: it.name } } }
      end
    end

    private

    def drena_public_id = params[:drena_public_id]
    def drena_known? = options.drenas.any? { it.public_id == drena_public_id }
    def options = @options ||= Queries::School::SchoolOptionsQuery.new
  end
end
