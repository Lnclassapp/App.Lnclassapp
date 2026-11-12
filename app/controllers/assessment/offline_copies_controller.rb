# 🌐 DELIVERY · Assessment::OfflineCopiesController
# Rôle : la copie sur feuille faite hors ligne : même feuille que la copie en ligne, sans session, sans indice, sans aucune bonne réponse ; gardable par le programme d'arrière-plan
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.1, §4.4) · menace C1 · UDR : hors-connexion §3.4 · l'envoi des copies rendues est OfflineCopySyncsController (Lot C)
module Assessment
  class OfflineCopiesController < AuthenticatedController
    include ReadsOwnLevel
    include RedirectsSubscriptionRequired

    allow_roles :student
    keep_offline only: :new

    def new
      exercise = Repositories::Assessment::ExerciseRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if exercise.nil?
      return if refuse_out_of_level(exercise_public_id: exercise.public_id)

      allowed = Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:)
      # allow_roles écarte déjà qui n'est pas élève : le seul refus restant est l'exercice non publié, qui n'existe pas pour l'élève.
      return render_not_found if allowed.failure?
      return redirect_subscription_required(return_to: exercise_path(exercise.public_id)) if blocked?

      @sheet = Queries::Assessment::OfflinePackQuery.new.sheet(public_id: exercise.public_id)
    end

    private

    # Le même accès que le démarrage d'une copie (ADR-0126 §4.6).
    def blocked? = Queries::Billing::StudentAccessQuery.new.call(student_id: current_actor.user_id, at: Time.zone.now).blocked?
  end
end
