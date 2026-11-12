# 🌐 DELIVERY · Assessment::OfflinePacksController
# Rôle : sert à l'élève autorisé le paquet de corrigé d'un exercice (JSON, no-store) pour le faire hors ligne ; n'écrit rien
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4, §4.7) · menace C1, C2 (même autorisation que StartExerciseSession), C3 (jeton signé)
module Assessment
  class OfflinePacksController < AuthenticatedController
    include ReadsOwnLevel

    allow_roles :student

    # Par compte : 30 paquets par minute (une requête par exercice ouvert).
    rate_limit to: 30, within: 1.minute, by: -> { current_actor.user_id }

    def show
      exercise = Repositories::Assessment::ExerciseRepository.new.find_by_public_id(public_id: params[:public_id])
      return render_not_found if exercise.nil?
      return if refuse_out_of_level(exercise_public_id: exercise.public_id)

      refusal = refusal_for(exercise)
      return head(refusal) if refusal

      render_pack(Queries::Assessment::OfflinePackQuery.new.call(public_id: exercise.public_id))
    end

    private

    # La même autorisation que le démarrage d'une copie (publication, rôle, accès Billing), sans rien écrire. → statut | nil
    def refusal_for(exercise)
      allowed = Policies::Assessment::StartSessionPolicy.new.call(actor: current_actor, exercise:)
      # allow_roles écarte déjà qui n'est pas élève : le seul refus restant est l'exercice non publié, qui n'existe pas pour l'élève.
      return :not_found if allowed.failure?

      :payment_required if Queries::Billing::StudentAccessQuery.new.call(student_id: current_actor.user_id, at: Time.zone.now).blocked?
    end

    def render_pack(pack)
      issued_at = Time.zone.now.utc.change(usec: 0)
      token = Repositories::Assessment::OfflinePackSigner.new.sign(student_id: current_actor.user_id, exercise_id: pack.exercise_id,
                                                                  digest: pack.digest, issued_at:)
      response.headers["Cache-Control"] = "no-store"
      render json: { exercise_public_id: pack.exercise_public_id, title: pack.title, digest: pack.digest, issued_at: issued_at.iso8601, token:,
                     questions: pack.questions }
    end
  end
end
