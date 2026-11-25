# 🌐 DELIVERY · FirstExercisePrompt — la fenêtre « Ton premier exercice » : l'élève qui n'a rendu aucune copie la voit sur l'accueil
# Rôle : first_exercise_prompt? dit si le shell porte le cadre différé de la fenêtre ; le drapeau de session tombe dès la première copie rendue
# ADR  : — · UDR : accueil-eleve-qr-fenetre-inviter §3.2, 0185 §3.1 · chantiers entree-et-accueil-eleve-allegees, premier-exercice-ux
module FirstExercisePrompt
  extend ActiveSupport::Concern

  # Posé par Classroom::StudentFirstExercisesController quand l'élève a rendu une copie (quelle que soit la note).
  SESSION_KEY = :first_exercise_done
  FRAME = "student_first_exercise_prompt".freeze

  included do
    helper_method :first_exercise_prompt?
  end

  private

  # Vrai pour un élève dont la session ne porte pas encore le drapeau. Le shell ne pose le cadre que sur l'accueil (content_for :first_exercise_prompt), hors mode concentré.
  def first_exercise_prompt? = current_actor.present? && current_actor.student? && !session[SESSION_KEY]
end
