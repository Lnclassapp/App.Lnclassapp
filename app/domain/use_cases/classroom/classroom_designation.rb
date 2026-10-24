# 🧠 DOMAINE · UseCases::Classroom::ClassroomDesignation
# Rôle : la classe que désigne un élève, celle d'un lien valide, de son code ou choisie dans la cascade, et sa voie ; règle commune à RegisterStudent, JoinAsStudent et ChangeClassroom
# ADR  : 0040, 0041, 0085, 0088, 0095, XXXX-code-de-classe-a-six-caracteres · UDR : 0081
module UseCases
  module Classroom
    class ClassroomDesignation
      # La classe désignée et la voie qui y mène (Entities::Classroom::StudentArrivalChannel::WRITABLE).
      Destination = Data.define(:classroom, :via)
      STANDARD = "standard".freeze
      LINK = "link".freeze
      CODE = "code".freeze
      BLANK = { classroom_public_id: [ :blank ] }.freeze
      UNAVAILABLE = { classroom_public_id: [ :unavailable ] }.freeze
      UNKNOWN_CODE = { join_code: [ :unknown ] }.freeze

      def initialize(classrooms:, schools:, taxonomy:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @clock = clock
      end

      # Avec un jeton, la classe du lien, qui ne retombe pas sur la cascade (ADR-0085 §4.1) ; sans, celle du code, sinon la classe choisie.
      # ADR-0088 : le lien d'une classe archivée dit pourquoi il refuse ; tout autre lien mort reste inconnu.
      # → Destination | failure(:invalid) | failure(:not_found) | failure(:forbidden, classroom_archived)
      def designate(dto)
        return coded_or_chosen(dto) unless dto.link_token

        linked(dto.link_token) || unavailable_link(dto.link_token)
      end

      # ADR-0085 §4.1 : le lien n'ouvre qu'une classe active d'un établissement actif, verrouillée (ADR-0041).
      # → Destination | nil (pas de jeton, jeton inconnu ou changé, classe archivée, établissement qui n'est pas actif)
      def linked(token)
        classroom = token && @classrooms.lock_by_link_token(token:)
        Destination.new(classroom:, via: LINK) if classroom&.active? && school_of(classroom).active?
      end

      # ADR code-de-classe §4.6 : le code ouvre une classe active d'un établissement actif, lue puis verrouillée (ADR-0041). Une
      # classe archivée, un établissement qui n'est pas actif et un code inconnu ou mal formé se ressemblent : nil (CA-B3).
      # → Destination | nil
      def coded(code)
        found = code && @classrooms.find_by_join_code(code:)
        classroom = found && @classrooms.lock_by_public_id(public_id: found.public_id)
        # Relu sous le verrou : un code changé entre la lecture et le verrou n'ouvre plus la classe (ADR code §4.3).
        Destination.new(classroom:, via: CODE) if classroom && classroom.join_code == code && classroom.active? && school_of(classroom).active?
      end

      # Un code envoyé l'emporte sur les listes de la cascade, qui ne sont alors pas lues ; il ne retombe pas sur elles.
      # → Destination | failure(:invalid, join_code: unknown) | failure(:invalid) (cascade)
      def coded_or_chosen(dto)
        return chosen(dto) unless dto.join_code

        coded(dto.join_code) || Shared::Result.failure(:invalid, errors: UNKNOWN_CODE)
      end

      # ADR-0088 : le jeton d'une classe archivée d'un établissement actif, pour refuser avec le motif plutôt qu'avec un lien inconnu.
      def archived_link?(token)
        classroom = token && @classrooms.lock_by_link_token(token:)
        classroom.present? && classroom.archived? && school_of(classroom).active?
      end

      # ADR-0085 §4.2 : la classe choisie doit être de celles que la cascade propose, sinon la même erreur sous le champ.
      # → Destination | failure(:invalid)
      def chosen(dto)
        return Shared::Result.failure(:invalid, errors: BLANK) if dto.classroom_public_id.nil?

        classroom = @classrooms.lock_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:invalid, errors: UNAVAILABLE) unless listed?(classroom, dto)

        Destination.new(classroom:, via: STANDARD)
      end

      private

      def unavailable_link(token)
        return Shared::Result.failure(:not_found) unless archived_link?(token)

        Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] })
      end

      # Active, de l'année en cours, du niveau et de l'établissement envoyés, établissement actif.
      def listed?(classroom, dto)
        return false unless classroom&.active? && classroom.school_year == Entities::Classroom::SchoolYear.current(@clock.now.to_date)

        school = school_of(classroom)
        level = dto.level_slug && @taxonomy.find_level(slug: dto.level_slug)
        school.active? && school.public_id == dto.school_public_id && level&.id == classroom.level_id
      end

      # Une classe a toujours son établissement (clé étrangère, NOT NULL).
      def school_of(classroom) = @schools.find_by_id(id: classroom.school_id)
    end
  end
end
