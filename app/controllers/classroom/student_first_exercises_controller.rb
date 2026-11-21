# 🌐 DELIVERY · Classroom::StudentFirstExercisesController
# Rôle : le cadre de la fenêtre « Ton premier exercice » ; vide si l'élève a rendu une copie (le drapeau de session tombe) ou n'a rien à faire, sinon le premier exercice
# ADR  : 0035, 0049 · UDR : accueil-eleve-qr-fenetre-inviter (§3.2), 0174 activation-premier-exercice §2.2
module Classroom
  class StudentFirstExercisesController < AuthenticatedController
    allow_roles :student

    # Un cadre Turbo seul : la réponse est le cadre, jamais une page du shell.
    layout false

    def show
      student_id = current_actor.user_id
      activation = Queries::Classroom::ActivationQuery.new
      if activation.submitted_copy?(student_id:)
        session[FirstExercisePrompt::SESSION_KEY] = true
        return
      end

      # Aucun exercice à proposer : cadre vide, sans drapeau (un exercice peut venir).
      home = Queries::Classroom::StudentHomeQuery.new.call(student_id:)
      @exercise = activation.call(student_id:, home:) unless home.nil?
    end
  end
end
