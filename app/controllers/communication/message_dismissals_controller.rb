# 🌐 DELIVERY · Communication::MessageDismissalsController
# Rôle : l'élève masque une annonce (croix), puis « Annuler » ou « Réafficher » ; réponse en Turbo Stream, repli HTML par redirection
# ADR  : 0045, 0078 (§4.2) · UDR : 0071 (§3.5, §3.6, §3.7)
module Communication
  class MessageDismissalsController < AuthenticatedController
    allow_roles :student

    def create
      answer dismiss.call(actor: current_actor, public_id: params[:public_id]),
             toast: { info: { "message" => t("communication.dismissal.message"), "title" => t("communication.dismissal.title") } }
    end

    # « Annuler » (toast) et « Réafficher » (liste) : sans nouveau toast.
    def destroy
      answer restore.call(actor: current_actor, public_id: params[:public_id]), toast: {}
    end

    private

    # Turbo Stream : create/destroy.turbo_stream.erb remplacent la carte et le carrousel recalculés. Sans Turbo : retour
    # à la page de la croix (l'accueil par défaut), le toast par le flash.
    def answer(result, toast:)
      return refuse if result.code == :forbidden

      render_result result, success: lambda { |_|
        respond_to do |format|
          format.turbo_stream { load_announcements }
          format.html { redirect_back_or_to student_home_path, status: :see_other, flash: toast }
        end
      }
    end

    # Annonce officielle (requête forgée) ou illisible : rien n'est écrit, et le toast dit pourquoi (UDR-0071, États).
    def refuse
      message = t("communication.dismissal.refused")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type: :error), status: :forbidden }
        format.html { redirect_back_or_to student_home_path, status: :see_other, alert: message }
      end
    end

    def load_announcements
      reader = readable.reader_for(actor: current_actor)
      now = Time.current
      @card = inbox.card(reader:, now:, public_id: params[:public_id])
      @carousel = inbox.carousel(reader:, now:)
    end

    def readable = @readable ||= Queries::Communication::ReadableMessages.new
    def inbox = Queries::Communication::InboxQuery.new(readable:)

    def dependencies
      { messages: Repositories::Communication::MessageRepository.new, readable:,
        dismissals: Repositories::Communication::DismissalRepository.new, policy: Policies::Communication::DismissPolicy.new,
        clock: Time.zone }
    end

    def dismiss = UseCases::Communication::DismissMessage.new(**dependencies)
    def restore = UseCases::Communication::RestoreMessage.new(**dependencies)
  end
end
