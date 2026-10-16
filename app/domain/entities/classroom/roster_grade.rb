# 🧠 DOMAINE · Entities::Classroom::RosterGrade
# Rôle : note sur 20 d'un élève dans sa classe (moyenne de ses meilleurs scores aux exercices assignés) et son groupe de la liste
# ADR  : 0033, 0097 (§4.7, amendé le 2026-10-16) · UDR : 0108 · décision du porteur : 0–10, 11–15, 16–20, puis « pas encore de note »
module Entities
  module Classroom
    module RosterGrade
      GROUPS = { "0-10" => 0..10, "11-15" => 11..15, "16-20" => 16..20 }.freeze
      UNGRADED = "none"
      # L'ordre du sélecteur, et celui du choix par défaut.
      KEYS = [ *GROUPS.keys, UNGRADED ].freeze

      # mean_best : moyenne, en pourcentage, des meilleurs scores de l'élève sur les exercices assignés qu'il a faits ;
      # nil s'il n'en a fait aucun. → note sur 20, arrondie comme partout (Grading.grade_on_20), ou nil
      def self.grade_for(mean_best) = mean_best && Assessment::Grading.grade_on_20(mean_best)

      def self.group_for(grade) = grade.nil? ? UNGRADED : GROUPS.find { |_, range| range.cover?(grade) }.first

      # requested : le groupe demandé (paramètre `note`), gardé s'il est connu, même vide ; sinon le premier groupe non vide
      # depuis 0–10 ; une classe sans élève, 0–10. counts : { clé => nombre d'élèves }.
      def self.selected(requested, counts)
        return requested if KEYS.include?(requested)

        KEYS.find { counts.fetch(it, 0).positive? } || KEYS.first
      end
    end
  end
end
