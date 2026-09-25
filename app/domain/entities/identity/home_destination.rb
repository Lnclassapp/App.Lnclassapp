# 🧠 DOMAINE · Entities::Identity::HomeDestination
# Rôle : accueil d'un acteur connecté ; aucune destination ne renvoie vers une page qui la redirige
# ADR  : 0030, 0040
module Entities
  module Identity
    module HomeDestination
      ALL = %i[student_home teacher_home teacher_classrooms team_home pending_account].freeze

      def self.for(actor:, primary_membership:, onboarded:)
        case actor.role
        when :student then student(primary_membership)
        when :teacher then teacher(actor, onboarded)
        when :team then :team_home
        else :pending_account # school_admin : V2
        end
      end

      def self.student(membership)
        membership&.active? && membership.classroom_active? ? :student_home : :pending_account
      end

      def self.teacher(actor, onboarded)
        return :pending_account if actor.school_id.nil?

        onboarded ? :teacher_home : :teacher_classrooms
      end

      private_class_method :student, :teacher
    end
  end
end
