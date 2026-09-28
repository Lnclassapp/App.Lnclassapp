# 🧠 DOMAINE · Entities::Identity::HomeDestination
# Rôle : accueil d'un acteur connecté ; aucune destination ne renvoie vers une page qui la redirige
# ADR  : 0030, 0040, 0066
module Entities
  module Identity
    module HomeDestination
      ALL = %i[student_home teacher_home teacher_classrooms team_home school_admin_home pending_account].freeze

      # primary_school_id : école principale de l'enseignant (teacher_schools), nil sinon
      def self.for(actor:, primary_membership:, primary_school_id:, onboarded:)
        case actor.role
        when :student then student(primary_membership)
        when :teacher then teacher(primary_school_id, onboarded)
        when :team then :team_home
        # school_admin (Actor::ROLES) — ADR-0066 §4.1 : school_id est l'établissement actif de son rattachement actif.
        else actor.school_id.nil? ? :pending_account : :school_admin_home
        end
      end

      def self.student(membership)
        membership&.active? && membership.classroom_active? ? :student_home : :pending_account
      end

      def self.teacher(primary_school_id, onboarded)
        return :pending_account if primary_school_id.nil?

        onboarded ? :teacher_home : :teacher_classrooms
      end

      private_class_method :student, :teacher
    end
  end
end
