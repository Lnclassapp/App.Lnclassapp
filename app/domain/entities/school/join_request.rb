# 🧠 DOMAINE · Entities::School::JoinRequest
# Rôle : demande d'un enseignant inscrit sans code ; validée aussitôt tant que la validation est en pause ; plafond par école
# ADR  : 0063, 0073 · UDR : 0050
module Entities
  module School
    JoinRequest = Data.define(:id, :public_id, :teacher_id, :school_id, :status, :teacher_name) do
      def pending? = status == "pending"
    end
    # Défaut à confirmer par le porteur (ADR-0063) : au-delà, une nouvelle demande est refusée (compté sous verrou, B2).
    JoinRequest::MAX_PENDING_PER_SCHOOL = 5
    # Voie d'une demande validée à l'inscription, sans décideur, tant que la validation est en pause (ADR-0073).
    JoinRequest::AUTO = "auto".freeze
  end
end
