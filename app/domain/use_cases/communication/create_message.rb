# 🧠 DOMAINE · UseCases::Communication::CreateMessage
# Rôle : l'équipe, une direction ou un enseignant rédige une annonce : brouillon, programmée, ou publiée tout de suite sous le plafond de 3
# ADR  : 0028, 0045, 0078, 0081 · UDR : 0071, 0075
module UseCases
  module Communication
    class CreateMessage
      # ADR-0081 §4.1 : le plafond, appliqué à chaque parution (création publiée tout de suite, brouillon ou programmée
      # publiée par son auteur, passage du job). Demande @messages (MessageRepositoryPort).
      module Parution
        # Levée dans la transaction de la parution quand l'annonce s'est figée depuis sa lecture (archivée ou retirée) :
        # l'exception annule tout ce que la transaction a écrit, archivages compris.
        Frozen = Class.new(StandardError)

        private

        # À appeler dans la transaction de la parution, avant d'écrire l'annonce qui paraît : live_of verrouille le compte
        # auteur, puis ses plus anciennes en ligne sont archivées jusqu'à ce qu'il lui en reste LIVE_CAP - 1. Une
        # annonce figée entre-temps n'est pas réécrite (update rend nil). → [Message archivées], la plus ancienne d'abord
        def make_room(author_id, now)
          live = @messages.live_of(author_id:, now:)
          excess = [ live.size - (Entities::Communication::Message::LIVE_CAP - 1), 0 ].max
          live.first(excess).filter_map { @messages.update(message: it.with(status: "archived")) }
        end
      end

      # Ce que la création et la modification partagent : les destinataires résolus pour PublishPolicy, la saisie
      # validée avec l'erreur de la policy, le dessin de l'équipe choisi, les fichiers et le journal d'une publication.
      module Writing
        include Parution

        Targets = Data.define(:scope, :school_id, :audience, :classroom_ids, :teachable_classroom_ids)
        # La valeur d'un succès : l'annonce écrite, et celles que sa parution a archivées (plafond, ADR-0081 §4.1), la
        # plus ancienne d'abord, que le toast nomme (UDR-0075 §3.3). Aucune hors d'une parution.
        Saved = Data.define(:message, :archived)

        private

        # Les valeurs envoyées, même forgées, vont telles quelles à la policy, qui refuse ; une absence prend la valeur
        # du formulaire du rôle : l'équipe, la portée nationale ; la direction et l'enseignant, leur établissement ;
        # l'enseignant, ses classes. Une classe inconnue reste dans la liste (nil) : la policy la refuse.
        def targets(actor, dto)
          role = actor&.role
          scope = dto.scope.presence || (role == :team ? "national" : "school")
          classrooms = dto.classroom_public_ids.map { @classrooms.find_by_public_id(public_id: it) }
          Targets.new(scope:, school_id: (school_id(actor, dto) if scope == "school"),
                      audience: dto.audience.presence || ("classrooms" if role == :teacher),
                      classroom_ids: classrooms.map { it&.id }, teachable_classroom_ids: teachable(actor, classrooms))
        end

        # L'établissement nommé par l'équipe (sa fiche), ou celui de l'acteur.
        def school_id(actor, dto)
          return actor&.school_id if dto.school_public_id.blank?

          @schools.find_by_public_id(public_id: dto.school_public_id)&.id
        end

        # Les classes cochées que l'enseignant peut viser : actives, de son établissement, et où il enseigne.
        def teachable(actor, classrooms)
          return [] unless actor&.teacher?

          open = classrooms.compact.select { it.active? && it.school_id == actor.school_id }.map(&:id)
          @teachings.classroom_ids_for(teacher_id: actor.user_id) & open
        end

        # Les erreurs de la saisie, du dessin de l'équipe choisi et de la policy (aucune classe cochée), ensemble sous
        # leurs champs. live : l'annonce déjà publiée qu'une modification garde en ligne, ou nil.
        # → [erreurs, id du dessin de l'équipe | nil]
        def form_errors(dto, allowed, now:, live: nil)
          dto.valid_at?(now:, live_since: live&.published_at, live_until: live&.ends_at)
          illustration_id = library_illustration_id(dto)
          allowed.errors.each { |attribute, codes| codes.each { dto.errors.add(attribute, it) } }
          [ dto.errors.to_hash, illustration_id ]
        end

        # ADR-0081 §4.3 : un dessin de l'équipe est choisi par son public_id ; inconnu ou retiré, il n'est pas dans la
        # bibliothèque et l'erreur va sous « Illustration » (AV-10). → son id | nil (clé de base, ou refusé)
        def library_illustration_id(dto)
          return unless dto.library_illustration?

          illustration = @illustrations.find_by_public_id(public_id: dto.illustration)
          return illustration.id if illustration && !illustration.retired?

          dto.errors.add(:illustration, :inclusion)
          nil
        end

        # Ce que la saisie écrit sur l'annonce, en création comme en modification.
        def written(dto, targets, illustration_id)
          { title: dto.title, body: dto.body, audience: targets.audience, school_id: targets.school_id,
            classroom_ids: targets.classroom_ids, theme: dto.theme, illustration: dto.base_illustration, illustration_id:,
            status: dto.status, published_at: dto.publication_time, ends_at: dto.ends_at }
        end

        # Un fichier envoyé remplace le précédent ; sinon la case « Retirer » l'efface.
        def store_files(message_id, dto)
          %i[image audio].each do |kind|
            upload = dto.upload(kind)
            if upload
              @attachments.attach(message_id:, kind:, **upload.to_h)
            elsif dto.remove?(kind)
              @attachments.remove(message_id:, kind:)
            end
          end
        end

        def journal_publication(message, at)
          @audit_log.record(action: "message.published", actor_id: message.author_id, at:, subject_type: "Message",
                            subject_id: message.id)
        end
      end

      include Writing

      # illustrations : IllustrationRepositoryPort, la bibliothèque de l'équipe (ADR-0081 §4.3).
      def initialize(messages:, attachments:, schools:, classrooms:, teachings:, audit_log:, illustrations:, transaction:,
                     policy:, clock:)
        @messages = messages
        @attachments = attachments
        @schools = schools
        @classrooms = classrooms
        @teachings = teachings
        @audit_log = audit_log
        @illustrations = illustrations
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Communication::MessageInput.
      # → success(Saved : l'annonce, et les annonces archivées par sa parution) | :forbidden | :invalid (erreurs par champ)
      def call(actor:, dto:)
        targets = targets(actor, dto)
        allowed = @policy.call(actor:, **targets.to_h)
        return allowed if allowed.code == :forbidden

        now = @clock.now
        errors, illustration_id = form_errors(dto, allowed, now:)
        return Shared::Result.failure(:invalid, errors:) unless errors.empty?

        @transaction.call { create(actor, dto, targets, now, illustration_id) }
      end

      private

      # Publiée tout de suite : une parution, sous le plafond (ADR-0081 §4.1) ; brouillon et programmée n'archivent rien.
      def create(actor, dto, targets, now, illustration_id)
        archived = dto.status == "published" ? make_room(actor.user_id, now) : []
        message = @messages.create(message: Entities::Communication::Message.new(
          author_id: actor.user_id, **written(dto, targets, illustration_id)
        ))
        store_files(message.id, dto)
        journal_publication(message, now) if message.status == "published"
        Shared::Result.success(Saved.new(message:, archived:))
      end
    end
  end
end
