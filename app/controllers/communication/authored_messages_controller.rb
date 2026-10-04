# 🌐 DELIVERY · Communication::AuthoredMessagesController
# Rôle : « Mes annonces » et le formulaire d'annonce (nouvelle, modifiée) de l'équipe, d'une direction ou d'un enseignant
# ADR  : 0026, 0028, 0045, 0078 · UDR : 0071 (§3.7, §3.8)
module Communication
  class AuthoredMessagesController < AuthenticatedController
    allow_roles :teacher, :school_admin, :team

    helper_method :form_school, :classroom_choices, :edited, :announcement_date

    PERMITTED = [ :title, :body, :scope, :school_public_id, :audience, :illustration, :remove_image, :remove_audio,
                  :published_at, :visible_until, { classroom_public_ids: [] } ].freeze

    def index
      @page = query.page(author_id: current_actor.user_id, page: params[:page], now: Time.zone.now)
    end

    # L'équipe venue de la fiche d'un établissement (?school=<public_id>) le vise d'abord.
    def new
      @form = Dtos::Communication::MessageInput.blank(today: Date.current, school_public_id: params.permit(:school)[:school].presence)
    end

    def create
      @form = form_input
      render_result create_message.call(actor: current_actor, dto: @form), form: :new, success: ->(message) { saved(message) }
    end

    # Le formulaire n'existe que pour l'auteur (ManageOwnPolicy : 404 pour tout autre), et pas pour une annonce figée.
    def edit
      @message = messages.find_by_public_id(public_id: params[:public_id])
      managed Policies::Communication::ManageOwnPolicy.new.call(actor: current_actor, message: @message), success: lambda { |_|
        @form = Dtos::Communication::MessageInput.for(@message, school_public_id: edited.school_public_id,
                                                                classroom_public_ids: edited.classroom_public_ids, today: Date.current)
      }
    end

    def update
      @message = messages.find_by_public_id(public_id: params[:public_id])
      @form = form_input
      result = update_message.call(actor: current_actor, public_id: params[:public_id], dto: @form)
      managed result, form: :edit, success: ->(message) { saved(message) }
    end

    private

    # Une annonce archivée ou retirée est figée : retour à « Mes annonces », avec la raison.
    def managed(result, **)
      return redirect_to(my_announcements_path, alert: t("communication.authored_messages.frozen"), status: :see_other) if result.code == :conflict

      render_result(result, **)
    end

    def saved(message)
      redirect_to my_announcements_path, notice: saved_notice(message), status: :see_other
    end

    # UDR-0071 §3.8 : « Annonce modifiée. » pour une annonce déjà publiée, sinon selon ce qu'elle est devenue.
    def saved_notice(message)
      return t("communication.authored_messages.saved.edited") if message.edited_at
      return t("communication.authored_messages.saved.scheduled", date: announcement_date(message.published_at, time: true)) if message.status == "scheduled"

      t("communication.authored_messages.saved.#{message.status}")
    end

    # Design system §12 : « 5 oct. », « 1ᵉʳ nov. », « 5 oct. à 10:00 ».
    def announcement_date(value, time: false)
      day = l(value.to_date, format: t("communication.authored_messages.formats.#{value.day == 1 ? 'first_day' : 'day'}"))
      return day unless time

      t("communication.authored_messages.formats.day_and_time", day:, time: l(value, format: t("communication.authored_messages.formats.time")))
    end

    # Seul un vrai fichier téléversé compte ; une chaîne dans le paramètre vaut une absence de fichier.
    def form_input
      values = params.expect(announcement: PERMITTED).to_h.symbolize_keys
      Dtos::Communication::MessageInput.new(**values, image: uploaded(:image), audio: uploaded(:audio), commit: params[:commit])
    end

    def uploaded(kind)
      file = params.dig(:announcement, kind)
      file if file.is_a?(ActionDispatch::Http::UploadedFile)
    end

    # L'établissement que le formulaire nomme : celui que l'équipe vise depuis sa fiche, celui de la direction.
    def form_school
      @form_school ||= current_actor.team? ? query.school(public_id: @form.school_public_id) : query.school(id: current_actor.school_id)
    end

    def classroom_choices = query.classroom_choices(teacher_id: current_actor.user_id, school_id: current_actor.school_id)
    def edited = @edited ||= query.edited(@message)

    def query = @query ||= Queries::Communication::AuthoredMessagesQuery.new
    def messages = @messages ||= Repositories::Communication::MessageRepository.new

    def create_message
      UseCases::Communication::CreateMessage.new(**writing, policy: Policies::Communication::PublishPolicy.new)
    end

    def update_message
      UseCases::Communication::UpdateMessage.new(**writing, policy: Policies::Communication::ManageOwnPolicy.new,
                                                            publish_policy: Policies::Communication::PublishPolicy.new)
    end

    def writing
      { messages:, attachments: Repositories::Communication::AttachmentStore.new, schools: Repositories::School::SchoolRepository.new,
        classrooms: Repositories::Classroom::ClassroomRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone }
    end
  end
end
