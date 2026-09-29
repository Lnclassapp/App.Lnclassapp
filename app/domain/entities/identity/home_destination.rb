# 🧠 DOMAINE · Entities::Identity::HomeDestination
# Rôle : accueil d'un acteur connecté ; aucune destination ne renvoie vers une page qui la redirige
# ADR  : 0030, 0040, 0065
module Entities
  module Identity
    module HomeDestination
      ALL = %i[student_home teacher_home teacher_classrooms team_home school_admin_classrooms pending_account].freeze

      # primary_school_id : école principale de l'enseignant (teacher_schools), nil sinon
      def self.for(actor:, primary_membership:, primary_school_id:, onboarded:)
        case actor.role
        when :student then student(primary_membership)
        when :teacher then teacher(primary_school_id, onboarded)
        when :team then :team_home
        else school_admin(actor)
        end
      end

      def self.student(membership)
        membership&.active? && membership.classroom_active? ? :student_home : :pending_account
      end

      def self.teacher(primary_school_id, onboarded)
        return :pending_account if primary_school_id.nil?

        onboarded ? :teacher_home : :teacher_classrooms
      end

      # « Travail des élèves » (UDR-0052) ; sans établissement, ReadOwnSchoolPolicy refuserait la page : l'écran d'attente.
      def self.school_admin(actor)
        actor.school_id ? :school_admin_classrooms : :pending_account
      end

      private_class_method :student, :teacher, :school_admin
    end
  end
end
