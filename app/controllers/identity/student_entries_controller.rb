# 🌐 DELIVERY · Identity::StudentEntriesController
# Rôle : « Je suis élève » : numéro et code secret ; inscrit → connecté (tout rôle) ; inconnu → confirmer le code, puis l'inscription élève, numéro et code gardés
# ADR  : 0050, 0085 (§4.7), XXXX-entree-eleve-revele-un-numero-inscrit · UDR : XXXX-entree-eleve-unique
module Identity
  class StudentEntriesController < ApplicationController
    include StudentEntrySession

    # ADR-XXXX §4.2 : une classe entre ensemble derrière une seule adresse (le wifi de l'école) ; un nouvel élève envoie
    # deux fois (numéro et code, puis confirmation) : 120 par minute. Le plafond horaire borne qui teste des numéros. Le code
    # d'un compte reste protégé par le verrouillage par numéro (ADR-0050). L'inscription qui suit l'entrée a son compteur,
    # REGISTRATION_RATE_LIMIT (Classroom::StudentRegistrationsController).
    RATE_LIMIT = { to: 120, within: 1.minute, scope: "identity/student_entries" }.freeze
    HOURLY_RATE_LIMIT = { to: 600, within: 1.hour, scope: "identity/student_entries_hourly" }.freeze
    REGISTRATION_RATE_LIMIT = { to: 60, within: 1.minute, scope: "identity/student_entry_registrations" }.freeze
    # Revue sécurité : l'entrée connecte tout rôle ; 120 envois par minute laissaient tester un code courant sur beaucoup de
    # numéros (un essai par numéro échappe au verrouillage). Seuls les codes faux comptent, par adresse ; au-delà, même un bon code est refusé.
    WRONG_PIN_LIMIT = { to: 10, within: 1.minute }.freeze

    allow_unauthenticated_access only: %i[new create]
    rate_limit **RATE_LIMIT, only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many }
    rate_limit **HOURLY_RATE_LIMIT, name: "hourly", only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many }

    # ?fresh=1 : « Corriger mon numéro » : l'entrée est oubliée, le numéro revient dans le champ.
    def new
      return redirect_to_home if authenticated?

      entry = params[:fresh].present? ? forget_student_entry : student_entry
      return redirect_to(registration_path(entry.link_token), status: :see_other) if entry&.confirmed

      @link_token = entry&.link_token || link_token_param(params[:link])
      @stage = entry&.pin ? :confirm : :credentials
      @form = Dtos::Identity::StudentEntryInput.new(contact: entry&.contact)
      load_link
    end

    def create
      return redirect_to_home if authenticated?
      return refuse_too_many if wrong_pin_limit_reached?

      @form = form_input
      return redirect_to(new_student_entry_path, alert: t(".expired"), status: :see_other) unless @form

      result = enter.call(dto: @form)
      count_wrong_pin if result.failure? && result.errors[:pin]&.include?(:wrong_pin)
      return render_failure(result) if result.failure?

      entered(result.value)
    end

    private

    def entered(value)
      case value.outcome
      when :signed_in
        start_session(value.token)
        return redirect_to(join_classroom_path(@link_token), status: :see_other) if @link_token && value.user.student?

        redirect_to_home notice: t("identity.sessions.create.signed_in"), status: :see_other
      when :new_number
        keep_student_entry(contact: value.contact, pin: @form.pin, confirmed: false, link_token: @link_token)
        redirect_to new_student_entry_path, status: :see_other
      else # :confirmed (EnterAsStudent ne rend que ces trois issues)
        keep_student_entry(contact: value.contact, pin: @form.pin, confirmed: true, link_token: @link_token)
        redirect_to registration_path(@link_token), status: :see_other
      end
    end

    def render_failure(result)
      load_link
      return render_wrong_app if result.code == :conflict

      add_errors(result)
      render :new, status: RendersResult::FORM_STATUSES.fetch(result.code, :unprocessable_entity)
    end

    # ADR-0086 §4.5 : la coque d'un autre rôle ; le formulaire revient vide, sous un message qui renvoie au site.
    def render_wrong_app
      @form = Dtos::Identity::StudentEntryInput.new
      @form.errors.add(:base, t(".wrong_app"))
      @stage = :credentials
      render :new, status: :unprocessable_entity
    end

    def wrong_pin_key = "identity/student_entries/wrong_pin:#{request.remote_ip}"

    def wrong_pin_limit_reached? = Rails.cache.read(wrong_pin_key).to_i >= WRONG_PIN_LIMIT[:to]

    def count_wrong_pin
      Rails.cache.write(wrong_pin_key, 0, expires_in: WRONG_PIN_LIMIT[:within], unless_exist: true)
      Rails.cache.increment(wrong_pin_key, 1, expires_in: WRONG_PIN_LIMIT[:within])
    end

    def refuse_too_many
      @form = form_input || Dtos::Identity::StudentEntryInput.new
      @form.errors.add(:base, t("errors.codes.rate_limited"))
      load_link
      render :new, status: :too_many_requests
    end

    # Écran « pas encore de compte » : seule la confirmation est postée ; numéro et code viennent de l'entrée gardée.
    # Sans entrée (expirée), nil : le contrôleur renvoie à l'entrée.
    def form_input
      posted = params.expect(student_entry: %i[contact pin pin_confirmation link_token])
      context = { ip: request.remote_ip, user_agent: request.user_agent, client: lnclass_app&.to_s || "web" }
      if posted.key?(:pin_confirmation)
        entry = student_entry
        return unless entry&.pin

        @stage = :confirm
        @link_token = link_token_param(posted[:link_token]) || entry.link_token
        return Dtos::Identity::StudentEntryInput.new(contact: entry.contact, pin: entry.pin,
                                                     pin_confirmation: posted[:pin_confirmation].to_s, **context)
      end

      @stage = :credentials
      @link_token = link_token_param(posted[:link_token])
      Dtos::Identity::StudentEntryInput.new(contact: posted[:contact], pin: posted[:pin], **context)
    end

    def link_token_param(raw) = Dtos::Classroom::StudentRegistrationInput.normalize_link_token(raw)

    # Le bandeau de la classe du lien ; un lien devenu invalide est oublié sans rien dire (l'inscription prendra la voie standard).
    def load_link
      @preview = @link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: @link_token)
      @link_token = nil unless @preview
    end

    def registration_path(link_token) = link_token ? join_classroom_path(link_token) : new_student_registration_path

    def enter
      UseCases::Identity::EnterAsStudent.new(
        users: Repositories::Identity::UserRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
