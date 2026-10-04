# 🌐 DELIVERY · Classroom::StudentArchivesController
# Rôle : « Mon historique » de l'élève, avec ou sans classe active : ses classes et ses exercices terminés, en lecture seule
# ADR  : 0026, 0036, 0040 · UDR : 0006, 0057 · atteint depuis l'écran de sortie de l'élève sans classe (pending_accounts)
module Classroom
  class StudentArchivesController < AuthenticatedController
    allow_roles :student

    def show
      @archive = Queries::Classroom::StudentArchiveQuery.new.call(student_id: current_actor.user_id)
    end
  end
end
