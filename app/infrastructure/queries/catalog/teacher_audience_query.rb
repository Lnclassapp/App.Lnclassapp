# 🔌 INFRA · Queries::Catalog::TeacherAudienceQuery
# Rôle : la portée du catalogue d'un enseignant : sa matière, et les (niveau, série) de ses classes actives de l'année
# ADR  : 0035, 0041 · UDR : 0077 §3.2 · une lecture, pas une règle d'accès : un cours hors portée reste ouvert par son adresse
module Queries
  module Catalog
    class TeacherAudienceQuery
      # audience : Entities::Catalog::LevelAudience (vide sans classe de l'année) ; material_id : sa matière.
      Scope = Data.define(:audience, :material_id)

      def call(teacher_id:, today: Date.current)
        pairs = Orm::Classroom.joins(:teacher_classrooms)
                              .where(teacher_classrooms: { teacher_id: }, status: "active",
                                     school_year: Entities::Classroom::SchoolYear.current(today))
                              .distinct.pluck(:level_id, :series_id)
        Scope.new(audience: Entities::Catalog::LevelAudience.new(pairs:),
                  material_id: Orm::TeacherProfile.where(user_id: teacher_id).pick(:material_id))
      end
    end
  end
end
