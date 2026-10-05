# 🧠 DOMAINE · UseCases::Communication::AddIllustration
# Rôle : l'équipe ajoute un dessin SVG à la bibliothèque d'illustrations d'annonce, gardé en formes reconstruites seulement
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5)
module UseCases
  module Communication
    class AddIllustration
      ILLUSTRATION = Entities::Communication::Illustration

      def initialize(illustrations:, drawings:, transaction:, policy:)
        @illustrations = illustrations
        @drawings = drawings
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Communication::IllustrationInput.
      # → Result(Entities::Communication::Illustration écrite) | :forbidden | :invalid (name:, file: [raison rédigée])
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        # Une lecture rapide, sans verrou : le dessin d'une bibliothèque déjà pleine n'est pas lu.
        return full(dto) if full?

        drawing = read(dto)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) if dto.errors.any?

        illustration = ILLUSTRATION.new(name: dto.name, view_box: drawing[:view_box], shapes: drawing[:shapes],
                                        created_by_id: actor.user_id)
        @transaction.call { add(dto, illustration) }
      end

      private

      # Phase 5 (F3) : le plafond tient en concurrence. La bibliothèque est verrouillée, puis recomptée, dans la
      # transaction de l'écriture : un second ajout simultané attend, puis compte celui-ci.
      def add(dto, illustration)
        @illustrations.lock_library
        return full(dto) if full?

        Shared::Result.success(@illustrations.create(illustration:))
      end

      def full? = @illustrations.available.size >= ILLUSTRATION::LIBRARY_CAP

      # La bibliothèque pleine : rien n'est écrit, la raison s'affiche sous « Dessin ».
      def full(dto)
        dto.errors.add(:file, :library_full, count: ILLUSTRATION::LIBRARY_CAP)
        Shared::Result.failure(:invalid, errors: dto.errors.to_hash)
      end

      # Le nom et le poids d'abord. Le dessin n'est lu que si le fichier a passé le poids ; la raison d'un refus rejoint
      # les erreurs de la saisie, pour que le nom et le fichier se corrigent ensemble. Seul ce que la lecture rend est
      # écrit : jamais le fichier envoyé (ADR-0081 §4.3). → { view_box:, shapes: } revérifiés | nil
      def read(dto)
        dto.valid?(:add)
        return if dto.errors.include?(:file)

        drawing = @drawings.read(bytes: dto.bytes)
        drawing.errors.fetch(:file, []).each { dto.errors.add(:file, it) }
        return if drawing.failure?

        checked(dto, drawing.value)
      end

      # Défense en profondeur : le domaine ne se fie pas à l'adaptateur. La viewBox suit son expression, chaque forme
      # passe la liste blanche (valid_shape?) ou n'est pas écrite ; s'il n'en reste aucune, le dessin est vide.
      def checked(dto, drawing)
        view_box = drawing[:view_box].to_s
        shapes = Array(drawing[:shapes]).select { ILLUSTRATION.valid_shape?(it, depth: 1) }
        return { view_box:, shapes: } if ILLUSTRATION::VIEW_BOX.match?(view_box) && shapes.any?

        dto.errors.add(:file, :empty)
        nil
      end
    end
  end
end
