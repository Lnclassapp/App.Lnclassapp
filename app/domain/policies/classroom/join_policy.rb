# 🧠 DOMAINE · Policies::Classroom::JoinPolicy
# Rôle : entrée d'un visiteur ou d'un élève dans une classe active sous son plafond ; l'élève retiré n'y revient que par le lien
# ADR  : 0028, 0040, 0041, 0085
module Policies
  module Classroom
    class JoinPolicy
      # classroom : chargée sous verrou, avec active_students_count ; via_link : l'entrée vient d'un jeton de lien valide ;
      # removed : l'élève a été retiré de cette classe.
      def call(actor:, classroom:, via_link: false, removed: false)
        return Shared::Result.failure(:forbidden) unless actor.nil? || actor.student?
        return refuse(:classroom_archived) unless classroom.active?
        return refuse(:removed_from_classroom) if removed && !via_link
        return refuse(:classroom_full) if classroom.full?

        Shared::Result.success
      end

      private

      def refuse(reason) = Shared::Result.failure(:forbidden, errors: { base: [ reason ] })
    end
  end
end
