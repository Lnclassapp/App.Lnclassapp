# 🧠 DOMAINE · Policies::Classroom::ClassroomTeacher
# Rôle : fait commun des policies d'une classe : l'acteur enseigne dans cette classe, et elle est dans son établissement courant
# ADR  : 0028, 0094 (amendement du 2026-10-16 : chaque établissement est un espace autonome)
module Policies
  module Classroom
    module ClassroomTeacher
      # classroom : répond à teacher_ids et school_id. Une classe d'un autre de ses établissements n'existe pas tant
      # qu'il n'y est pas passé (ADR-0094 §4.3).
      def self.teaches?(actor, classroom) = linked?(actor, classroom) && classroom.school_id == actor.school_id

      # Il y enseigne, mais dans un autre de ses établissements : le refus dit quoi faire (UDR-0098 §3.5).
      def self.elsewhere?(actor, classroom) = linked?(actor, classroom) && classroom.school_id != actor.school_id

      # Le refus d'une classe d'un autre de ses établissements : RendersResult le rend avec quoi faire (UDR-0098 §3.5).
      OTHER_SCHOOL = Shared::Result.failure(:forbidden, errors: { base: [ :other_school ] })

      def self.linked?(actor, classroom) = actor.teacher? && classroom.teacher_ids.include?(actor.user_id)
    end
  end
end
