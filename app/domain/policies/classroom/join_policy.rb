# 🧠 DOMAINE · Policies::Classroom::JoinPolicy
# Rôle : entrée d'un visiteur ou d'un élève dans une classe active sous son plafond ; l'élève retiré n'y revient que par le lien
# ADR  : 0028, 0040, 0041, 0083
module Policies
  module Classroom
    class JoinPolicy
      # classroom : chargée sous verrou, avec active_students_count ; via_link : l'entrée vient d'un jeton de lien valide ;
      # removed : l'élève a été retiré de cette classe. code : seulement sur l'ancien chemin par code (JoinWithCode,
      # JoinAsStudent), qui disparaît au Lot F ; nil ailleurs, et alors aucun code n'est vérifié.
      def call(actor:, classroom:, via_link: false, removed: false, code: nil)
        return Shared::Result.failure(:forbidden) unless actor.nil? || actor.student?
        return refuse(:classroom_archived) unless classroom.active?
        return refuse(:join_code_revoked) unless code.nil? || current_code?(classroom, code)
        return refuse(:removed_from_classroom) if removed && !via_link
        return refuse(:classroom_full) if classroom.full?

        Shared::Result.success
      end

      private

      def current_code?(classroom, code)
        classroom.join_code.present? && classroom.join_code == Entities::Classroom::JoinCode.normalize(code)
      end

      def refuse(reason) = Shared::Result.failure(:forbidden, errors: { base: [ reason ] })
    end
  end
end
