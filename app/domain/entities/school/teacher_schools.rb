# 🧠 DOMAINE · Entities::School::TeacherSchools
# Rôle : plafond des établissements d'un enseignant (rejoindre, réintégrer)
# ADR  : 0094
module Entities
  module School
    module TeacherSchools
      # Le rattachement est sans preuve (ADR-0083) : le plafond le borne (ADR-0094 §4.1).
      MAX = 3
    end
  end
end
