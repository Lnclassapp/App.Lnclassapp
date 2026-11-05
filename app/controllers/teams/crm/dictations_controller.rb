# 🌐 DELIVERY · Teams::Crm::DictationsController
# Rôle : « Dicter un compte rendu » : la modale d'enregistrement, la réception de l'audio (refusé avant tout appel et tout stockage), le formulaire « Noter un échange » pré-rempli ; garde ManageCrmPolicy héritée
# ADR  : XXXX (modèles de langage, menace du compte rendu dicté) · UDR : XXXX (assistants du suivi) · CA-25 à CA-27
module Teams
  module Crm
    class DictationsController < BaseController
      FOLLOW_UP_DELAY = 3 # jours, comme « Noter un échange »
      # Le corps contient l'audio (10 Mo au plus) et quelques champs : 1 Mo de marge pour l'enveloppe multipart.
      MAX_REQUEST_BYTES = UseCases::Crm::SubmitDictation::MAX_BYTES + 1.megabyte

      # Avant tout : la lecture du corps (jeton CSRF, paramètres) écrit l'audio sur disque, donc la taille annoncée se refuse d'abord.
      prepend_before_action :reject_oversized_request, only: :create
      before_action :load_school, except: :create
      helper_method :contact_choices

      def new
        return if params[:generation].blank?

        @generation = ready_generation
        return render_not_found if @generation.nil?

        @form = prefilled_form(Entities::Crm::DictationDraft.from_content(@generation.content))
      end

      def create
        # Sans fichier du tout (le « Réessayer » d'un échec) : l'enregistreur revient, sans message.
        return render_recorder unless request.request_parameters.key?("audio")

        result = submit_dictation.call(actor: current_actor, school_public_id: params[:school_public_id], audio: upload)
        return render_not_found if result.code == :not_found
        return render_recorder(error: :running, status: :conflict) if result.code == :conflict
        return render_recorder(error: :unavailable, status: :service_unavailable) if result.code == :unavailable
        return render_recorder(error: result.errors[:audio], status: :unprocessable_entity) if result.failure?

        # Relue après la demande : un travail déjà exécuté (file en ligne) est montré fini, pas en attente.
        render_recorder(generation: generations.find_by_public_id(public_id: result.value.generation.public_id))
      end

      private

      def generations = @generations ||= Repositories::Crm::GenerationRepository.new

      def load_school
        @school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: params[:school_public_id])
        render_not_found if @school.nil?
      end

      def reject_oversized_request
        return if request.content_length.to_i <= MAX_REQUEST_BYTES

        render_recorder(error: :too_large, status: :unprocessable_entity)
      end

      # La fenêtre « Dicter un compte rendu » remplace la modale par Turbo Stream : la réponse porte l'état (enregistreur, erreur, attente).
      def render_recorder(error: nil, generation: nil, status: :ok)
        render turbo_stream: turbo_stream.update("modal", partial: "teams/crm/dictations/recorder",
                                                          locals: { school_public_id: request.path_parameters[:school_public_id], error:, generation: }),
               status:
      end

      # Un fichier téléversé ; toute autre valeur (texte, liste) est un fichier absent.
      def upload
        file = params[:audio]
        size = file.respond_to?(:tempfile) ? file.size : 0
        UseCases::Crm::SubmitDictation::Upload.new(io: (file.tempfile if size.positive?), byte_size: size, content_type: nil)
      end

      def submit_dictation
        UseCases::Crm::SubmitDictation.new(
          generations:, schools: Repositories::School::SchoolRepository.new, policy: Policies::Crm::ManageCrmPolicy.new, logger: Rails.logger,
          # Le type réel par les octets magiques seuls : ni le nom, ni le type annoncé par le navigateur.
          type_of: ->(io) { Marcel::MimeType.for(io) },
          enqueue: ->(public_id, stored) { ::Crm::DictationJob.submit(public_id, stored) }
        )
      end

      # Une dictée terminée de cette école seulement.
      def ready_generation
        generation = generations.find_by_public_id(public_id: params[:generation])
        generation if generation&.done? && generation.kind == "dictation" && generation.school_id == @school.id
      end

      # Le formulaire du Lot C, pré-rempli : rien n'est enregistré avant que l'humain le valide.
      def prefilled_form(draft)
        days = draft.follow_up_in_days
        Teams::Crm::InteractionsController::Form.new(
          school_public_id: @school.public_id, source: "dictation", kind: draft.kind, outcome: draft.outcome, contact_name: draft.contact_name,
          next_step: draft.next_step, note: draft.note, occurred_at: Time.zone.now.strftime("%Y-%m-%dT%H:%M"),
          create_follow_up: days.present?, follow_up_due_on: (Time.zone.today + (days || FOLLOW_UP_DELAY)).to_s
        ).tap { @structured = draft.structured }
      end

      def contact_choices
        @contact_choices ||= Repositories::Crm::ContactRepository.new.active_for_school(school_id: @school.id)
                                                                  .map { [ it.full_name, it.public_id ] }
      end
    end
  end
end
