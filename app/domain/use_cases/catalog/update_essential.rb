# 🧠 DOMAINE · UseCases::Catalog::UpdateEssential
# Rôle : l'équipe modifie le nom, le sous-titre ou le contenu d'une fiche ; son cours, son slug et son statut restent
# ADR  : 0026, 0028, 0029, 0035, 0105
module UseCases
  module Catalog
    class UpdateEssential
      # Annule l'écriture d'une fiche publiée dont les images, relues, ne seraient pas complètes (menace.md, n° 15).
      class Refused < StandardError
        attr_reader :ready, :saved

        def initialize(ready, saved)
          @ready = ready
          @saved = saved
          super("images de la fiche incomplètes")
        end
      end

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
        return @transaction.call { @essentials.update(essential:) } unless current.published?

        ready = PublishEssential.images_ready(essential)
        return refuse_images(dto, ready, essential.images.map(&:public_id)) if ready.failure?

        write_published(dto, essential)
      end

      private

      # Le premier contrôle ne voit que les textes de remplacement envoyés : une image neuve citée sans sa clé le franchit. Le second
      # porte sur la fiche relue après l'écriture, textes de la base fusionnés avec la saisie ; refusée, la transaction est annulée
      # (menace.md, n° 15).
      def write_published(dto, essential)
        @transaction.call do
          @essentials.update(essential:).tap do |result|
            next if result.failure?

            ready = PublishEssential.images_ready(result.value)
            raise Refused.new(ready, result.value) if ready.failure?
          end
        end
      rescue Refused => e
        refuse_images(dto, e.ready, e.saved.images.map(&:public_id))
      end

      # Les raisons de PublishEssential.images_ready, posées sur la saisie : le texte (emplacements), ou l'image sans texte de
      # remplacement, numérotée dans l'ordre des images de la fiche (order).
      def refuse_images(dto, ready, order)
        reason = ready.errors.fetch(:base).first
        if reason == :image_alts_blank
          ready.errors.fetch(:image_alts).each { |id| dto.errors.add(:"image_alts.#{id}", :image_alt_blank, number: order.index(id).to_i + 1) }
        else
          dto.errors.add(:content, reason)
        end
        Shared::Result.failure(:invalid, errors: dto.errors.to_hash)
      end
    end
  end
end
