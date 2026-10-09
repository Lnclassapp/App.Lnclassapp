# 🧠 DOMAINE · UseCases::Classroom::ClassroomDesignation
# Rôle : la classe que désigne un élève, celle d'un lien valide ou celle choisie dans la cascade, et sa voie ; règle commune à RegisterStudent et JoinAsStudent
# ADR  : 0040, 0041, 0085 · UDR : 0081
module UseCases
  module Classroom
    class ClassroomDesignation
      # La classe désignée et la voie qui y mène (Entities::Classroom::StudentArrivalChannel::WRITABLE).
      Destination = Data.define(:classroom, :via)
      STANDARD = "standard".freeze
      LINK = "link".freeze
      BLANK = { classroom_public_id: [ :blank ] }.freeze
      UNAVAILABLE = { classroom_public_id: [ :unavailable ] }.freeze

      def initialize(classrooms:, schools:, taxonomy:, clock:)
        @classrooms = classrooms
        @schools = schools
        @taxonomy = taxonomy
        @clock = clock
      end

      # ADR-0085 §4.1 : le lien n'ouvre qu'une classe active d'un établissement actif, verrouillée (ADR-0041).
      # → Destination | nil (pas de jeton, jeton inconnu ou changé, classe archivée, établissement qui n'est pas actif)
      def linked(token)
        classroom = token && @classrooms.lock_by_link_token(token:)
        Destination.new(classroom:, via: LINK) if classroom&.active? && school_of(classroom).active?
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
