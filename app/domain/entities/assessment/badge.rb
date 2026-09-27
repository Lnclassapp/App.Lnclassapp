# 🧠 DOMAINE · Entities::Assessment::Badge
# Rôle : meilleur badge d'un élève sur un exercice (level ∈ Grading::BADGE_ORDER)
# ADR  : 0033
module Entities
  module Assessment
    Badge = Data.define(:student_id, :exercise_id, :session_id, :level, :awarded_at)
  end
end
