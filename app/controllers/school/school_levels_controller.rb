# 🌐 DELIVERY · School::SchoolLevelsController
# Rôle : niveaux d'un établissement actif qui ont une classe active de l'année, publics et limités en débit : frame « picker_levels »
# ADR  : 0026, 0050, 0062, 0085 · UDR : 0081
module School
  class SchoolLevelsController < ApplicationController
    allow_unauthenticated_access
    # ADR-0085 §4.2 : 30 requêtes par minute et par adresse ; au-delà, l'état d'erreur du frame et « Réessayer ».
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # Un établissement inconnu, inactif ou sans classe donne l'état « introuvable », jamais une erreur.
    def index
      levels = Queries::School::SchoolLevelsQuery.new.call(school_public_id: params[:school_public_id])
      render locals: { levels:, registration: nil, scope: DrenaSchoolsController.picker_scope(params[:scope]) }
    end

    private

    def refuse_too_many
      render :index, status: :too_many_requests, locals: { levels: [], registration: nil, rate_limited: true,
                                                           scope: DrenaSchoolsController.picker_scope(params[:scope]) }
    end
  end
end
