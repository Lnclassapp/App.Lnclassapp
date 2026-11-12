# 🌐 DELIVERY · Assessment::OfflinePacksController
# Rôle : sert à l'élève autorisé le paquet de corrigé d'un exercice (JSON, no-store) pour le faire hors ligne, devoir à rendre compris ; trace chaque remise, sans trace pas de corrigé
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4 et amendement « Devoir à rendre », §4.7) · menace C1 (remise tracée, marque pour l'enseignant), C2 (même autorisation que StartExerciseSession), C3 (jeton signé)
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

      return :payment_required if Queries::Billing::StudentAccessQuery.new.call(student_id: current_actor.user_id, at: Time.zone.now).blocked?

      nil
    end

    def render_pack(pack)
      issued_at = Time.zone.now.utc.change(usec: 0)
      return head(:service_unavailable) unless record_delivery(pack.exercise_id, issued_at)

      token = Repositories::Assessment::OfflinePackSigner.new.sign(student_id: current_actor.user_id, exercise_id: pack.exercise_id,
                                                                  digest: pack.digest, issued_at:)
      response.headers["Cache-Control"] = "no-store"
      render json: { exercise_public_id: pack.exercise_public_id, title: pack.title, digest: pack.digest, issued_at: issued_at.iso8601, token:,
                     questions: pack.questions }
    end

    # Menace C1 : chaque remise du corrigé est tracée (la marque de l'enseignant en dépend). Option prudente (journal, À trancher) : si la
    # trace ne s'écrit pas, le corrigé n'est pas servi (503, l'appareil réessaiera) et l'erreur est signalée. → true | false
    def record_delivery(exercise_id, at)
      Repositories::Assessment::OfflinePackDeliveryRepository.new.record(student_id: current_actor.user_id, exercise_id:, at:)
      true
    rescue ActiveRecord::ActiveRecordError => e
      Rails.error.report(e, handled: true, context: { exercise_id: })
      false
    end
  end
end
