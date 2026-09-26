# 🌐 DELIVERY · Classroom::TeachingSelectionsController
# Rôle : « Quelles classes enseignez-vous ? » ; sans école principale, l'écran de sortie, sans boucle de redirection
# ADR  : 0028, 0030, 0040 · UDR : 0025
module Classroom
  class TeachingSelectionsController < AuthenticatedController
    allow_roles :teacher

    # L'écran de sortie ne redirige jamais : un enseignant sans école y reste (TR-02).
    def index
      return redirect_to pending_account_path if current_actor.school_id.nil?

      @selection = Queries::Classroom::TeachingSelectionQuery.new.call(teacher_id: current_actor.user_id,
                                                                       school_id: current_actor.school_id)
    end
  end
end
