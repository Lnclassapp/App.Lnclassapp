# 🧠 DOMAINE · Entities::School::TeacherDeparture
# Rôle : retrait d'un enseignant d'un établissement par la direction ; ouvert, il lui interdit d'y revenir par le code
# ADR  : 0071
module Entities
  module School
    TeacherDeparture = Data.define(:id, :teacher_id, :school_id, :detached_by_id, :detached_at, :reinstated_by_id, :reinstated_at) do
      # Clos à la réintégration ; un seul départ ouvert par enseignant et établissement (index unique partiel).
      def open? = reinstated_at.nil?
    end
  end
end
