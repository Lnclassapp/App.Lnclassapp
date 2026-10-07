# 🌐 DELIVERY · Identity::ProfilePhotosController
# Rôle : chacun ajoute, change ou retire sa photo dans la modale ; succès en Turbo Stream (toast, page rafraîchie), repli HTML
# ADR  : 0026, 0028, 0060 · UDR : 0006, 0041 (élève tutoyé, 2026-10-06), 0047
module Identity
  class ProfilePhotosController < AuthenticatedController
    include Tone

    helper_method :profile

    def edit
      @form = Dtos::Identity::ProfilePhotoInput.new
    end

    def update
      @form = Dtos::Identity::ProfilePhotoInput.new(photo: uploaded_photo)
      result = change.call(actor: current_actor, user: own_user, dto: @form, ip: request.remote_ip)
      render_result result, form: :edit, success: ->(_) { saved(tone_t(".changed")) }
    end

    def destroy
      result = remove.call(actor: current_actor, user: own_user, ip: request.remote_ip)
      render_result result, success: ->(_) { saved(tone_t(".removed")) }
    end

    private

    # Le rafraîchissement (morphing) met à jour d'un coup la carte, l'en-tête et la barre latérale ; le toast est permanent.
    def saved(message)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ helpers.turbo_stream_toast(message, type: :success), turbo_stream.update("modal", ""),
                                 turbo_stream.refresh(request_id: nil) ]
        end
        format.html { redirect_to profile_path, notice: message, status: :see_other }
      end
    end

    # Seul un vrai fichier téléversé compte ; une chaîne dans le paramètre vaut une absence de fichier.
    def uploaded_photo
      photo = params.dig(:profile_photo, :photo)
      photo if photo.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def profile = @profile ||= Queries::Identity::ProfileQuery.new.call(user_id: current_actor.user_id)
    def own_user = users.find(id: current_actor.user_id)
    def users = @users ||= Repositories::Identity::UserRepository.new

    def dependencies
      { photos: Repositories::Identity::ProfilePhotoStore.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        transaction: Repositories::Shared::Transaction.new, policy: Policies::Identity::UpdateSelfPolicy.new, clock: Time.zone }
    end

    def change = UseCases::Identity::ChangeOwnPhoto.new(**dependencies)
    def remove = UseCases::Identity::RemoveOwnPhoto.new(**dependencies)
  end
end
