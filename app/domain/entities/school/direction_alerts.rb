# 🧠 DOMAINE · Entities::School::DirectionAlerts
# Rôle : alertes de la carte « Établissement » de la direction : lesquelles, dans quel ordre, trois noms de classe au plus
# UDR  : 0072 (§3.2, §3.3) · une alerte n'existe que si son compte est positif ; « rouge » se lit par WorkSignal
module Entities
  module School
    module DirectionAlerts
      # submission_rate : taux de rendu en % entier, ou nil quand il n'est pas calculé.
      ClassroomFacts = Data.define(:name, :students_count, :teachers_count, :submission_rate)
      # names : les premiers noms de classe, dans l'ordre reçu ; others : les classes de l'alerte qui ne sont pas nommées.
      Alert = Data.define(:kind, :names, :others, :count)
      NAMED = 3

      # classrooms : [ClassroomFacts], triées comme les classes (niveau, puis nom) ; teachers_without_classroom : un compte.
      # → [Alert], dans l'ordre de la carte.
      def self.call(school_active:, classrooms:, teachers_without_classroom:)
        [
          unnamed(:inactive, school_active ? 0 : 1),
          named(:without_teacher, classrooms.select { it.teachers_count.zero? }),
          named(:without_students, classrooms.select { it.students_count.zero? }),
          named(:red_signal, classrooms.select { WorkSignal.for(it.submission_rate) == :red }),
          unnamed(:teachers_without_classroom, teachers_without_classroom)
        ].compact
      end

      def self.named(kind, classrooms)
        return if classrooms.empty?

        Alert.new(kind:, names: classrooms.first(NAMED).map(&:name), others: [ classrooms.size - NAMED, 0 ].max, count: classrooms.size)
      end

      # L'établissement non actif et les enseignants sans classe se comptent ; aucune classe n'y est nommée.
      def self.unnamed(kind, count)
        Alert.new(kind:, names: [], others: 0, count:) if count.positive?
      end

      private_class_method :named, :unnamed
    end
  end
end
