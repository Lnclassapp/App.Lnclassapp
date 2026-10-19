# 🧠 DOMAINE · UseCases::Catalog::UpdateEssential
# Rôle : l'équipe modifie le nom, le sous-titre ou le contenu d'une fiche ; son cours, son slug et son statut restent
# ADR  : 0026, 0028, 0029, 0035, 0105
module UseCases
  module Catalog
    class UpdateEssential
      def initialize(essentials:, transaction:, policy:)
        @essentials = essentials
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Catalog::EssentialInput.
      # → Result(Essential) | :forbidden | :not_found | :invalid (saisie ; fiche publiée rendue incomplète) | :conflict (nom pris)
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
        # Les textes de remplacement saisis ; le repository les écrit sur les images que cite le contenu (ADR-0105).
        essential.images = dto.images
        # ADR-0074 §4.2, ADR-0105 : une fiche en ligne ne perd jamais un texte de remplacement et ne reçoit pas d'emplacement.
        if current.published?
          ready = PublishEssential.images_ready(essential)
          return refuse_images(dto, ready) if ready.failure?
        end
        @transaction.call { @essentials.update(essential:) }
      end

      private

      # Les raisons de PublishEssential.images_ready, posées sur la saisie : le texte (emplacements), ou l'image sans texte de
      # remplacement, numérotée dans l'ordre du formulaire.
      def refuse_images(dto, ready)
        reason = ready.errors.fetch(:base).first
        if reason == :image_alts_blank
          order = dto.image_alts.keys
          ready.errors.fetch(:image_alts).each { |id| dto.errors.add(:"image_alts.#{id}", :image_alt_blank, number: order.index(id).to_i + 1) }
        else
          dto.errors.add(:content, reason)
        end
        Shared::Result.failure(:invalid, errors: dto.errors.to_hash)
      end
    end
  end
end
