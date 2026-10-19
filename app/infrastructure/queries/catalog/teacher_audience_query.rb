# 🔌 INFRA · Queries::Catalog::TeacherAudienceQuery
# Rôle : la portée du catalogue d'un enseignant : ses matières et les (niveau, série) de ses classes actives de l'année, dans l'établissement courant
# ADR  : 0035, 0041, 0094, 0103 · UDR : 0077 §3.2, 0126 §3.1 · une lecture, pas une règle d'accès : un cours hors portée reste ouvert par son adresse
module Queries
  module Catalog
    class TeacherAudienceQuery
      # audience : Entities::Catalog::LevelAudience (vide sans classe de l'année) ; materials : ses matières de
      # l'établissement courant, [Identity::TeacherMaterialsQuery::MaterialTag] dans l'ordre (ADR-0103).
      Scope = Data.define(:audience, :materials) do
        def material_ids = materials.map(&:id)
        # UDR-0126 §2 : au-delà d'une matière seulement, le catalogue se range par matière et propose le filtre.
        def several_materials? = materials.size > 1
      end

      # school_id : l'établissement courant (actor.school_id, ADR-0094 §4.6).
      def call(teacher_id:, school_id:, today: Date.current)
        pairs = Orm::Classroom.joins(:teacher_classrooms)
                              .where(teacher_classrooms: { teacher_id: }, school_id:, status: "active",
                                     school_year: Entities::Classroom::SchoolYear.current(today))
                              .distinct.pluck(:level_id, :series_id)
        Scope.new(audience: Entities::Catalog::LevelAudience.new(pairs:),
                  materials: Queries::Identity::TeacherMaterialsQuery.new.tags_for(teacher_ids: [ teacher_id ], school_id:).fetch(teacher_id))
      end
    end
  end
end
