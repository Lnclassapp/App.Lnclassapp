# 🧠 DOMAINE · Entities::Identity::HomeDestination
# Rôle : accueil d'un acteur connecté ; aucune destination ne renvoie vers une page qui la redirige
# ADR  : 0030, 0040, 0065, 0085
module Entities
  module Identity
    module HomeDestination
      ALL = %i[student_home teacher_home teacher_classrooms team_home school_admin_classrooms pending_account].freeze

      # primary_school_id : école principale de l'enseignant (teacher_schools), nil sinon
      def self.for(actor:, primary_school_id:, onboarded:)
        case actor.role
        when :student then :student_home
        when :teacher then teacher(primary_school_id, onboarded)
        when :team then :team_home
        else school_admin(actor)
        end
      end

      # ADR-0085 §4.3 : l'élève a une classe principale active. Sans elle, son accueil propose « Choisis ta classe » ; il n'y a
      # plus d'écran d'attente pour l'élève, qui y trouvait le code de classe.
      def self.enrolled?(membership) = (membership&.active? && membership.classroom_active?) || false

      def self.teacher(primary_school_id, onboarded)
        return :pending_account if primary_school_id.nil?

        onboarded ? :teacher_home : :teacher_classrooms
      end

      # « Travail des élèves » (UDR-0052) ; sans établissement, ReadOwnSchoolPolicy refuserait la page : l'écran d'attente.
      def self.school_admin(actor)
        actor.school_id ? :school_admin_classrooms : :pending_account
      end

      private_class_method :teacher, :school_admin
    end
  end
end
