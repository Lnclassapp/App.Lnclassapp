# 🧠 DOMAINE · UseCases::Catalog::UpdateEssential
# Rôle : l'équipe modifie le nom, le sous-titre ou le contenu d'une fiche ; son cours, son slug et son statut restent
# ADR  : 0026, 0028, 0029, 0035
module UseCases
  module Catalog
    class UpdateEssential
      def initialize(essentials:, transaction:, policy:)
        @essentials = essentials
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Catalog::EssentialInput. → Result(Essential) | :forbidden | :not_found | :invalid | :conflict (nom pris)
      def call(actor:, slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @essentials.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # Tout, sauf le texte, vient de la fiche enregistrée, jamais de la saisie (ADR-0029).
        essential = Entities::Catalog::Essential.new(
          id: current.id, slug: current.slug, course_id: current.course_id, position: current.position,
          author_id: current.author_id, status: current.status, course_status: current.course_status, **dto.essential_attributes
        )
        @transaction.call { @essentials.update(essential:) }
      end
    end
  end
end
