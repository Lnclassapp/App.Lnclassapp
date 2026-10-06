# 🌐 DELIVERY · Identity::ProfileNamesController
# Rôle : chacun corrige son nom dans la modale ; succès en Turbo Stream (carte remplacée), repli HTML vers « Mon profil »
# ADR  : 0026, 0028, 0055 · UDR : 0006, 0041 (élève tutoyé, 2026-10-06)
module Identity
  class ProfileNamesController < AuthenticatedController
    include Tone

    def edit
      profile = profile_query.call(user_id: current_actor.user_id)
      @form = Dtos::Identity::PersonNameInput.new(last_name: profile.last_name, first_name: profile.first_name)
    end

    def update
      @form = Dtos::Identity::PersonNameInput.new(params.expect(profile_name: %i[last_name first_name]))
      result = update_own_name.call(actor: current_actor, user: users.find(id: current_actor.user_id), dto: @form, ip: request.remote_ip)
      render_result result, form: :edit, success: lambda { |_|
        respond_to do |format|
          format.turbo_stream { @profile = profile_query.call(user_id: current_actor.user_id) }
          format.html { redirect_to profile_path, notice: tone_t(".updated"), status: :see_other }
        end
      }
    end

    private

    def profile_query = Queries::Identity::ProfileQuery.new
    def users = (@users ||= Repositories::Identity::UserRepository.new)

    def update_own_name
      UseCases::Identity::UpdateOwnName.new(
        users:, audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
        policy: Policies::Identity::UpdateSelfPolicy.new, clock: Time.zone
      )
    end
  end
end
