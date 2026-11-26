# 🌐 DELIVERY · Identity::SessionsController
# Rôle : connexion « numéro d'abord » (le numéro, puis le code, ou « pas de compte » vers l'inscription élève ou enseignant), déconnexion ;
#        numéro et code envoyés ensemble : la connexion d'ADR-0050, message unique ; échec re-rendu en 422 (le code ne revient jamais), dont le refus d'une coque Android
# ADR  : 0026, 0050, 0084 (§4.5), 0086 (§4.5), hors-connexion (§4.2), XXXX-connexion-revele-un-numero-inscrit · UDR : 0019, 0054 (§3.8), 0080, 0082 (§3.4), XXXX-connexion-numero-d-abord (§3.1 à §3.3)
module Identity
  class SessionsController < ApplicationController
    include StudentEntrySession
    include WrongPinLimit
    include NumberEntryLimit

    # Lien du refus : la fiche Play Store de l'app proposée quand elle est publiée, sinon le site (ADR-0086 §4.5).
    STORE_APPS = { android_student: :student, android_teacher: :teacher }.freeze
    SITE_URL = "https://lnclass.com".freeze

    allow_unauthenticated_access only: %i[new create]
    allow_unverified_second_factor only: :destroy
    # ADR-XXXX §4.2 : les compteurs de l'entrée élève, partagés ; les codes faux restent à 5 par minute (WrongPinLimit).
    limit_number_entries with: -> { refuse_too_many }

    # Le numéro laissé par une invitation acceptée est lu et supprimé : un rechargement ne le montre plus ; il ouvre l'étape du
    # code. ?fresh=1 : « Ce n'est pas mon numéro » : l'entrée est oubliée, le numéro revient dans le champ.
    def new
      invited = Entities::Identity::Contact.normalize(session.delete(:login_contact))
      return redirect_to_home if authenticated?

      entry = params[:fresh].present? ? forget_student_entry : student_entry
      keep_student_entry(contact: invited, pin: nil, confirmed: false, link_token: nil, known: true) if invited.present?
      entry = student_entry if invited.present?
      @stage = params[:fresh].present? ? :contact : entry_stage(entry)
      @form = Dtos::Identity::NumberEntryInput.new(contact: entry&.contact)
    end

    # Trois envois : le numéro seul (session[contact]), le code seul (session[pin], numéro gardé), ou les deux ensemble.
    def create
      return authenticate_both if both_posted?

      @form = entry_input
      return redirect_to(new_session_path, alert: t(".expired"), status: :see_other) unless @form

      enter_by_number
    end

    def destroy
      terminate_session
      # Vide le cache HTTP du navigateur, PAS le Cache Storage (lnclass-pages-*) : celui-ci est purgé par le JavaScript puis par
      # le programme d'arrière-plan (message ou en-tête Lnclass-Offline: forget). Jamais « storage » : il désinscrirait
      # le programme et effacerait les files d'autres comptes sur l'appareil.
      response.set_header("Clear-Site-Data", '"cache"')
      redirect_to main_app.root_path, notice: t(".signed_out"), status: :see_other
    end

    private

    def posted = @posted ||= params.expect(session: %i[contact pin])
    def both_posted? = posted.key?(:contact) && posted.key?(:pin)
    def context = { ip: request.remote_ip, user_agent: request.user_agent, client: lnclass_app&.to_s || "web" }

    # ADR-XXXX §4.5 : la coque ou le gestionnaire de mots de passe envoie numéro et code ensemble : ADR-0050, message unique.
    def authenticate_both
      @stage = :both
      @form = Dtos::Identity::CredentialsInput.new(contact: posted[:contact], pin: posted[:pin], **context)
      return refuse_too_many unless claim_pin_attempt

      result = authenticate.call(dto: @form)
      release_pin_attempt unless result.failure? && result.errors == UseCases::Identity::Authenticate::INVALID
      return render_wrong_app(result.errors[:app].first) if wrong_app?(result)

      render_result result, form: :new, success: ->(authenticated) { signed_in(authenticated.token) }
    end

    # Le numéro seul, ou le code seul avec le numéro gardé ; nil si l'entrée a expiré.
    def entry_input
      unless posted.key?(:pin)
        @stage = :contact
        return Dtos::Identity::NumberEntryInput.new(contact: posted[:contact], **context)
      end

      entry = student_entry
      return unless entry&.known

      @stage = :pin
      Dtos::Identity::NumberEntryInput.new(contact: entry.contact, pin: posted[:pin].to_s, **context)
    end

    def enter_by_number
      return refuse_too_many if !@form.lookup? && !claim_pin_attempt

      result = enter.call(dto: @form, creates: false)
      release_pin_attempt if !@form.lookup? && !(result.failure? && result.errors[:pin]&.include?(:wrong_pin))
      return render_wrong_app(result.errors[:app].first) if wrong_app?(result)
      return render_form(:new, result) if result.failure?

      entered(result.value)
    end

    def entered(value)
      return signed_in(value.token) if value.outcome == :signed_in

      # :known ou :new_number (creates: false) : le numéro est gardé, l'écran suivant le relit (PRG).
      keep_student_entry(contact: value.contact, pin: nil, confirmed: false, link_token: nil, known: value.outcome == :known)
      redirect_to new_session_path, status: :see_other
    end

    def signed_in(token)
      start_session(token)
      redirect_to_home notice: t(".signed_in"), status: :see_other
    end

    # 429 : l'écran où l'on était (le code, si le numéro gardé est inscrit), sous « Trop de tentatives ».
    def refuse_too_many
      sent = params[:session].is_a?(ActionController::Parameters) ? params[:session] : ActionController::Parameters.new
      entry = student_entry
      @stage = :contact
      @stage = :pin if sent.key?(:pin) && entry&.known
      @stage = :both if sent.key?(:contact) && sent.key?(:pin)
      @form = Dtos::Identity::NumberEntryInput.new(contact: @stage == :pin ? entry.contact : sent[:contact].to_s)
      @form.errors.add(:base, t("errors.codes.rate_limited"))
      render :new, status: :too_many_requests
    end

    def wrong_app?(result)
      result.code == :conflict && result.errors[:base] == [ UseCases::Identity::Authenticate::WRONG_APP ]
    end

    # UDR-0082 §3.4 : le formulaire revient vide, ni numéro ni PIN, sous le message de la coque qui nomme la bonne app.
    def render_wrong_app(app)
      @wrong_app = { shell: lnclass_app, app:, url: wrong_app_url(app) }
      forget_student_entry
      @stage = @stage == :both ? :both : :contact
      @form = Dtos::Identity::NumberEntryInput.new
      render :new, status: :unprocessable_entity
    end

    def wrong_app_url(app)
      store = STORE_APPS[app]
      (store && Rails.configuration.x.android.dig(:apps, store, :store_url)) || SITE_URL
    end

    def dependencies
      { users: Repositories::Identity::UserRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        digest_key: secret_digest_key, clock: Time.zone }
    end

    def authenticate = UseCases::Identity::Authenticate.new(**dependencies)
    def enter = UseCases::Identity::EnterByNumber.new(**dependencies)
  end
end
