# 🌐 DELIVERY · School::CurrentSchoolsController
# Rôle : « Passer à <établissement> » du panneau du compte et de « Mes établissements » : la session change d'établissement courant
# ADR  : 0028, 0094 · UDR : 0098 (§3.2) · la session est celle de la requête, jamais un paramètre
module School
  class CurrentSchoolsController < AuthenticatedController
    allow_roles :teacher

    # Succès comme refus : retour à l'accueil, un toast ; un refus ne dit rien de plus (UDR-0098 §3.2).
    def update
      result = switch.call(actor: current_actor, session_id: current_session.id, school_public_id: params[:school_public_id].presence&.to_s)
      if result.success?
        redirect_to teacher_home_path, notice: t(".done", school: result.value.name), status: :see_other
      else
        redirect_to teacher_home_path, alert: t(".refused"), status: :see_other
      end
    end

    private

    def switch
      UseCases::School::SwitchCurrentSchool.new(schools: Repositories::School::SchoolRepository.new,
                                                sessions: Repositories::Identity::SessionRepository.new,
                                                policy: Policies::School::SwitchCurrentSchoolPolicy.new)
    end
  end
end
