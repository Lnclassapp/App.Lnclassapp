# 🧠 DOMAINE · UseCases::School::JoinSchoolWithCode
# Rôle : un enseignant rejoint un établissement actif, choisi dans sa DRENA ou par un lien /i/<jeton>, jamais celui qui l'a
#        retiré, trois au plus ; le premier est le principal, un suivant devient l'établissement courant de sa session
# ADR  : 0028, 0063, 0071, 0083, 0094, 0103 · UDR : 0056, 0079, 0099
module UseCases
  module School
    class JoinSchoolWithCode
      STANDARD = "standard".freeze
      # Le lien d'un établissement ou d'un collègue ne vaut que par l'établissement qu'il désigne ; le parrainage sans
      # établissement ne rattache à rien (ADR-0094 §11).
      INVALID_LINK = Shared::Result.failure(:invalid, errors: { base: [ :invite_invalid ] })

      # Un refus après une écriture traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("rattachement annulé : #{result.code}")
        end
      end

      # join_requests : Ports::School::JoinRequestRepositoryPort ; seule une demande en attente va à la policy (ADR-0071 §4.5).
      # Le nom de la classe reste celui de la voie par code (ADR-0083 §4.3), pour limiter le diff.
      # teacher_materials : Ports::Identity::TeacherMaterialRepositoryPort ; l'établissement ajouté reçoit les matières de
      # l'établissement courant (ADR-0103 §4.4).
      def initialize(schools:, drenas:, departures:, join_requests:, invite_links:, sessions:, audit_log:, policy:, transaction:,
                     clock:, teacher_materials:)
        @schools = schools
        @teacher_materials = teacher_materials
        @drenas = drenas
        @departures = departures
        @join_requests = join_requests
        @invite_links = invite_links
        @sessions = sessions
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::School::SchoolJoinInput (DRENA puis établissement) ou Dtos::School::SchoolInviteJoinInput (jeton).
      # session_id : la session de la requête, jamais un paramètre ; elle passe sur un établissement ajouté.
      # → Result(Entities::School::School) | :forbidden (policy ; plafond : base schools_limit) | :invalid (choix : neutre ;
      #   lien : base invite_invalid) | :conflict (base already_attached | schools_limit, sous verrou)
      def call(actor:, dto:, session_id: nil)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?

        schools_count = @schools.school_ids_for(teacher_id: actor.user_id).size
        allowed = @policy.call(actor:, pending_request: @join_requests.pending_for(teacher_id: actor.user_id), schools_count:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        destination = dto.is_a?(Dtos::School::SchoolInviteJoinInput) ? invited(actor, dto.token) : chosen(actor, dto)
        return destination if destination.is_a?(Shared::Result)

        school, via = destination
        @transaction.call { join(actor, school, via, session_id:, now: @clock.now) }
      rescue Aborted => e
        e.result
      end

      private

      # Inconnu, inactif ou en brouillon, d'une autre DRENA, ou qui l'a retiré : la même erreur, rien n'est révélé.
      def chosen(actor, dto)
        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        return Shared::Result.failure(:invalid, errors: { school_public_id: [ :inclusion ] }) unless joinable?(actor, school) &&
                                                                                                    in_drena?(school, dto.drena_public_id)

        [ school, STANDARD ]
      end

      # Résolu de nouveau à l'envoi (ADR-0083 §4.1) : inconnu, établissement inactif, collègue anonymisé, parrainage sans
      # établissement ou établissement qui l'a retiré : « Ce lien n'est plus valable », sans dire pourquoi.
      def invited(actor, token)
        link = @invite_links.resolve(token:)
        return INVALID_LINK unless link&.valid? && link.school_id

        school = @schools.find_by_id(id: link.school_id)
        joinable?(actor, school) ? [ school, link.channel ] : INVALID_LINK
      end

      def joinable?(actor, school)
        school&.active? && @departures.open_for(teacher_id: actor.user_id, school_id: school.id).nil?
      end

      def in_drena?(school, drena_public_id)
        @drenas.find_by_public_id(public_id: drena_public_id)&.id == school.drena_id
      end

      # Sous le verrou du compte (attach_teacher_within_cap) : déjà rattaché ou plafond atteint par un autre onglet. Le
      # principal est décidé sous ce verrou et rendu : un autre onglet a pu rattacher un établissement depuis la lecture.
      def join(actor, school, via, session_id:, now:)
        attached = @schools.attach_teacher_within_cap(teacher_id: actor.user_id, school_id: school.id,
                                                      cap: Entities::School::TeacherSchools::MAX, at: now)
        raise Aborted, attached if attached.failure?

        @teacher_materials.inherit(teacher_id: actor.user_id, school_id: school.id, from_school_id: actor.school_id, at: now)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: now, subject_type: "School",
                          subject_id: school.id, metadata: { change: "teacher_joined", via: })
        @sessions.set_current_school(id: session_id, school_id: school.id) if session_id && !attached.value
        Shared::Result.success(school)
      end
    end
  end
end
