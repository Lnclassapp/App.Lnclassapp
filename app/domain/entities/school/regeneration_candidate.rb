# 🧠 DOMAINE · Entities::School::RegenerationCandidate
# Rôle : un établissement ou une classe qu'une régénération de masse va traiter ; jamais son code ni son jeton
# ADR  : 0096
module Entities
  module School
    # label : nom de l'établissement, ou « établissement · classe » (chemin d'une erreur du rapport) ;
    # school_id : l'établissement lui-même, ou celui de la classe (sujet de l'audit) ; rotated_at : dernier changement, ou nil.
    RegenerationCandidate = Data.define(:id, :public_id, :label, :school_id, :rotated_at) do
      def changed_since?(time) = !rotated_at.nil? && rotated_at >= time
    end
  end
end
