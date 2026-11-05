# 🔌 INFRA · Queries::Assessment::RemediationProposalsQuery
# Rôle : pour chaque fiche à revoir (lacune en attente) d'un élève, l'exercice qu'on lui propose pour la lever : toujours le même, aux trois endroits
# ADR  : 0043, 0101 · UDR : suivi-de-la-classe-sur-une-lecon §3.3 · choix par Entities::Assessment::RemediationPick ; deux requêtes quel que soit le nombre de fiches
module Queries
  module Assessment
    class RemediationProposalsQuery
      # exercise_public_id : nil quand la fiche n'a plus aucun exercice publié (le lien mène alors à la notion de la leçon).
      Proposal = Data.define(:essential_slug, :course_slug, :exercise_public_id)
      Candidate = Data.define(:id, :public_id, :exercise_type)

      GAP_COLUMNS = %w[essentials.id essentials.slug courses.slug exercise_sessions.exercise_id].freeze

      # essential_slugs : restreint aux fiches nommées (la page de résultat n'en lit qu'une) ; nil, toutes.
      # Fiche ou cours non publié : pas de page à ouvrir, pas de proposition. → { essential_slug => Proposal }
      def call(student_id:, essential_slugs: nil)
        scope = Orm::KnowledgeGap.joins(:source_session, essential: :course)
                                 .where(student_id:, status: "pending", essentials: { status: "published" }, courses: { status: "published" })
        scope = scope.where(essentials: { slug: essential_slugs }) if essential_slugs
        gaps = scope.pluck(*GAP_COLUMNS)
        return {} if gaps.empty?

        candidates = candidates(gaps.map(&:first))
        gaps.to_h do |essential_id, essential_slug, course_slug, source_exercise_id|
          pick = Entities::Assessment::RemediationPick.call(exercises: candidates.fetch(essential_id, []), source_exercise_id:)
          [ essential_slug, Proposal.new(essential_slug:, course_slug:, exercise_public_id: pick&.public_id) ]
        end
      end

      private

      # Les exercices publiés de chaque fiche, rangés par (position, id). → { essential_id => [Candidate] }
      def candidates(essential_ids)
        Orm::Exercise.where(essential_id: essential_ids, status: "published").order(:position, :id)
                     .pluck(:essential_id, :id, :public_id, :exercise_type)
                     .group_by(&:first).transform_values { |rows| rows.map { Candidate.new(*it.drop(1)) } }
      end
    end
  end
end
