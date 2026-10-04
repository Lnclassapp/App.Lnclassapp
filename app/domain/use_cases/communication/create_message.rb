# 🧠 DOMAINE · UseCases::Communication::CreateMessage
# Rôle : l'équipe, une direction ou un enseignant rédige une annonce : brouillon, programmée, ou publiée et journalisée tout de suite
# ADR  : 0028, 0045, 0078 · UDR : 0071
module UseCases
  module Communication
    class CreateMessage
      # Ce que la création et la modification partagent : les destinataires résolus pour PublishPolicy, la saisie
      # validée avec l'erreur de la policy, les fichiers et le journal d'une publication.
      module Writing
        Targets = Data.define(:scope, :school_id, :audience, :classroom_ids, :teachable_classroom_ids)

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

        # Les erreurs de la saisie et celle de la policy (aucune classe cochée), ensemble sous leurs champs.
        def form_errors(dto, allowed, now:, live_since: nil)
          dto.valid_at?(now:, live_since:)
          allowed.errors.each { |attribute, codes| codes.each { dto.errors.add(attribute, it) } }
          dto.errors.to_hash
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

      def initialize(messages:, attachments:, schools:, classrooms:, teachings:, audit_log:, transaction:, policy:, clock:)
        @messages = messages
        @attachments = attachments
        @schools = schools
        @classrooms = classrooms
        @teachings = teachings
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Communication::MessageInput. → success(Message) | :forbidden | :invalid (erreurs par champ)
      def call(actor:, dto:)
        targets = targets(actor, dto)
        allowed = @policy.call(actor:, **targets.to_h)
        return allowed if allowed.code == :forbidden

        now = @clock.now
        errors = form_errors(dto, allowed, now:)
        return Shared::Result.failure(:invalid, errors:) unless errors.empty?

        @transaction.call { create(actor, dto, targets, now) }
      end

      private

      def create(actor, dto, targets, now)
        message = @messages.create(message: Entities::Communication::Message.new(
          author_id: actor.user_id, title: dto.title, body: dto.body, audience: targets.audience, school_id: targets.school_id,
          classroom_ids: targets.classroom_ids, illustration: dto.illustration, status: dto.status,
          published_at: dto.publication_time, ends_at: dto.ends_at
        ))
        store_files(message.id, dto)
        journal_publication(message, now) if message.status == "published"
        Shared::Result.success(message)
      end
    end
  end
end
