# 🌐 DELIVERY · Classroom::TeacherOnboardingsController
# Rôle : « Terminer la configuration » : enregistre l'onboarding, puis l'accueil enseignant ; sans classe, la sélection en 422
# ADR  : 0026, 0028, 0030 · UDR : 0025
module Classroom
  class TeacherOnboardingsController < AuthenticatedController
    allow_roles :teacher

    def create
      result = complete_onboarding.call(actor: current_actor)
      return render_no_classroom if result.code == :invalid

      render_result result, success: ->(_) { redirect_to teacher_home_path, notice: t(".completed"), status: :see_other }
    end

    private

    def render_no_classroom
      @onboarding_error = t(".no_classroom")
      @selection = Queries::Classroom::TeachingSelectionQuery.new.call(teacher_id: current_actor.user_id,
                                                                       school_id: current_actor.school_id)
      render "classroom/teaching_selections/index", status: :unprocessable_entity
    end

    def complete_onboarding
      UseCases::Identity::CompleteTeacherOnboarding.new(
        profiles: Repositories::Identity::TeacherProfileRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
        policy: Policies::Identity::CompleteOnboardingPolicy.new, clock: Time.zone
      )
    end
  end
end
