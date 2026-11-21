# 🌐 DELIVERY · FirstExercisePrompt — la fenêtre « Ton premier exercice » : l'élève qui n'a rendu aucune copie la voit sur chaque écran
# Rôle : first_exercise_prompt? dit si le shell porte le cadre différé de la fenêtre ; le drapeau de session tombe dès la première copie rendue
# ADR  : — · UDR : accueil-eleve-qr-fenetre-inviter §3.2 · chantier entree-et-accueil-eleve-allegees
module FirstExercisePrompt
  extend ActiveSupport::Concern

  # Posé par Classroom::StudentFirstExercisesController quand l'élève a rendu une copie (quelle que soit la note).
  SESSION_KEY = :first_exercise_done
  FRAME = "student_first_exercise_prompt".freeze

  included do
    helper_method :first_exercise_prompt?
  end

  private

  # Vrai pour un élève dont la session ne porte pas encore le drapeau. Le mode concentré (content_for :focus) est écarté par le shell.
  def first_exercise_prompt? = current_actor&.student? == true && !session[SESSION_KEY]
end
