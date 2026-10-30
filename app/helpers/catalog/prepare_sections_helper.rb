# 🌐 UI · Catalog::PrepareSectionsHelper — découpe les exercices d'une leçon par type (« Prépare interros » / « Prépare devoirs »)
# Rôle : filtre un Prepare par type d'exercice (groupes vides retirés) et dit quelles ancres une section précédente a déjà posées
# ADR  : 0113 · UDR : 0145 (§3.2 bis, §3.2 ter) · la query reste inchangée : le filtrage est une affaire de présentation
module Catalog
  module PrepareSectionsHelper
    # Ordre de la page : l'ancre d'une notion va à la première carte qui la concerne dans cet ordre.
    PREPARE_TYPES = %w[fixation evaluation].freeze
    LESSON_WIDE_ANCHOR = "toute-la-lecon".freeze

    # → Prepare dont les groupes et les exercices de toute la leçon sont du seul type demandé.
    def prepare_for_type(prepare, type)
      groups = prepare.groups.filter_map do |group|
        rows = group.exercises.select { it.exercise_type == type }
        group.with(exercises: rows) if rows.any?
      end
      prepare.with(groups:, lesson_wide: prepare.lesson_wide.select { it.exercise_type == type })
    end

    # → les ids d'ancre (« notion-<slug> », « toute-la-lecon ») déjà posés par les sections qui précèdent ce type.
    def prepare_anchors_taken(prepare, type)
      PREPARE_TYPES.take_while { it != type }.flat_map do |earlier|
        section = prepare_for_type(prepare, earlier)
        section.groups.map { "notion-#{it.essential_slug}" } + (section.lesson_wide.any? ? [ LESSON_WIDE_ANCHOR ] : [])
      end
    end

    def prepare_any?(prepare, type) = prepare_for_type(prepare, type).then { it.groups.any? || it.lesson_wide.any? }
  end
end
