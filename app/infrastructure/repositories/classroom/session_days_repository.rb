# 🔌 INFRA · Repositories::Classroom::SessionDaysRepository
# Rôle : jours de séance d'un enseignant dans une classe, une ligne par jour ; remplacer = supprimer puis insérer
# ADR  : 0072
module Repositories
  module Classroom
    class SessionDaysRepository
      include Ports::Classroom::SessionDaysRepositoryPort

      def for(teacher_id:, classroom_id:)
        Entities::Classroom::SessionDays.new(weekdays: scope(teacher_id, classroom_id).order(:weekday).pluck(:weekday))
      end

      # L'entité valide les jours avant toute écriture ; la clé composite refuse une classe non déclarée (l'enseignant l'a quittée
      # entre la lecture de la policy et l'écriture) : false, sous un savepoint qui laisse la transaction de l'appelant saine (B-021).
      def replace(teacher_id:, classroom_id:, weekdays:, at:)
        days = Entities::Classroom::SessionDays.new(weekdays:).weekdays
        Orm::ClassroomSessionDay.transaction(requires_new: true) do
          scope(teacher_id, classroom_id).delete_all
          Orm::ClassroomSessionDay.insert_all(days.map { |weekday| { teacher_id:, classroom_id:, weekday:, created_at: at } }) if days.any?
        end
        true
      rescue ActiveRecord::InvalidForeignKey
        false
      end

      private

      def scope(teacher_id, classroom_id) = Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:)
    end
  end
end
