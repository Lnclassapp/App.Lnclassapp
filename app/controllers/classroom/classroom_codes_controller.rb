# 🌐 DELIVERY · Classroom::ClassroomCodesController
# Rôle : GET /classroom-codes/:code vérifie un code de classe et répond par un Turbo Frame : trouvée, inconnue (archivée comprise) ou trop d'essais
# ADR  : 0109 (§4.4, §4.5) · UDR : 0081
module Classroom
  class ClassroomCodesController < ApplicationController
    FRAME = "classroom_code_preview".freeze

    allow_unauthenticated_access
    # ADR code-de-classe §4.5 : le compteur du lien (/c/<jeton>) et de l'inscription, partagé ; au-delà, rien n'est révélé.
    rate_limit **Classroom::JoinsController::LINK_RATE_LIMIT, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # Le code est tapé par l'élève : la requête ne dit rien de plus que le nom de la classe, son niveau et son établissement.
    def show
      @preview = Queries::Classroom::JoinCodePreviewQuery.new.code(code: params[:code])
    end

    private

    def refuse_too_many
      @rate_limited = true
      render :show, status: :too_many_requests
    end
  end
end
