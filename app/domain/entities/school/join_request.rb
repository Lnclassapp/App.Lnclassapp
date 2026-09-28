# 🧠 DOMAINE · Entities::School::JoinRequest
# Rôle : demande d'un enseignant inscrit sans code, en attente d'une décision de l'équipe ou d'un garant ; plafond par école
# ADR  : 0063 · UDR : 0050
module Entities
  module School
    JoinRequest = Data.define(:id, :public_id, :teacher_id, :school_id, :status, :teacher_name) do
      def pending? = status == "pending"
    end
    # Défaut à confirmer par le porteur (ADR-0063) : au-delà, une nouvelle demande est refusée (compté sous verrou, B2).
    JoinRequest::MAX_PENDING_PER_SCHOOL = 5
  end
end
