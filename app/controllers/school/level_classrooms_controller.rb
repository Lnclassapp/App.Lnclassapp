# 🌐 DELIVERY · School::LevelClassroomsController
# Rôle : classes actives d'un niveau d'un établissement actif, publiques et limitées en débit : frame « picker_classrooms »
# ADR  : 0026, 0050, 0062, 0085 · UDR : 0081
module School
  class LevelClassroomsController < ApplicationController
    allow_unauthenticated_access
    # ADR-0085 §4.2 : 30 requêtes par minute et par adresse ; au-delà, l'état d'erreur du frame et « Réessayer ».
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # Chaque classe ne dit que son nom et si elle est complète (IL-04) ; aucune classe : l'état « introuvable ».
    def index
      classrooms = Queries::Classroom::LevelClassroomsQuery.new.call(school_public_id: params[:school_public_id],
                                                                     level_slug: params[:level_slug])
      render locals: { classrooms:, registration: nil, scope: DrenaSchoolsController.picker_scope(params[:scope]) }
    end

    private

    def refuse_too_many
      render :index, status: :too_many_requests, locals: { classrooms: [], registration: nil, rate_limited: true,
                                                           scope: DrenaSchoolsController.picker_scope(params[:scope]) }
    end
  end
end
