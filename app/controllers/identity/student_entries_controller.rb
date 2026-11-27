# 🌐 DELIVERY · Identity::StudentEntriesController
# Rôle : « Je suis élève », numéro d'abord : inscrit → le code, puis connecté (tout rôle) ; inconnu → « Nouveau sur Lnclass », le code tapé une fois, puis l'inscription élève, numéro et code gardés
# ADR  : 0050, 0085 (§4.7), 0141-entree-eleve-revele-un-numero-inscrit, 0148-connexion-revele-un-numero-inscrit · UDR : 0176-entree-eleve-unique, 0189-connexion-numero-d-abord (§3.4)
module Identity
  class StudentEntriesController < ApplicationController
    include StudentEntrySession
    include WrongPinLimit
    include NumberEntryLimit

    # L'inscription qui suit l'entrée a son compteur (Classroom::StudentRegistrationsController), ADR-0141 §4.2.
    REGISTRATION_RATE_LIMIT = { to: 60, within: 1.minute, scope: "identity/student_entry_registrations" }.freeze

    allow_unauthenticated_access only: %i[new create]
    # ADR-0148 §4.2 : 120 par minute et 600 par heure, comptés avec /login ; les codes faux, avec ceux de /login (WrongPinLimit).
    limit_number_entries with: -> { refuse_too_many }

    # ?fresh=1 : « Corriger mon numéro » : l'entrée est oubliée, le numéro revient dans le champ.
    def new
      return redirect_to_home if authenticated?

      entry = params[:fresh].present? ? forget_student_entry : student_entry
      return redirect_to(registration_path(entry.link_token), status: :see_other) if entry&.confirmed

      @link_token = entry&.link_token || link_token_param(params[:link])
      @stage = params[:fresh].present? ? :contact : entry_stage(entry)
      @form = Dtos::Identity::StudentEntryInput.new(contact: entry&.contact)
      load_link
    end

    def create
      return redirect_to_home if authenticated?
      @form = form_input
      return redirect_to(new_student_entry_path, alert: t(".expired"), status: :see_other) unless @form

      return refuse_too_many if !@form.lookup? && !claim_pin_attempt

      result = enter.call(dto: @form)
      release_pin_attempt if !@form.lookup? && !(result.failure? && result.errors[:pin]&.include?(:wrong_pin))
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
      when :known, :new_number
        keep_student_entry(contact: value.contact, pin: nil, confirmed: false, link_token: @link_token, known: value.outcome == :known)
        redirect_to new_student_entry_path, status: :see_other
      else # :confirmed (EnterByNumber, creates: true, ne rend que ces quatre issues)
        keep_student_entry(contact: value.contact, pin: @form.pin, confirmed: true, link_token: @link_token)
        redirect_to registration_path(@link_token), status: :see_other
      end
    end

    def render_failure(result)
      load_link
      return render_wrong_app if result.code == :conflict

      add_errors(result)
      # L'écran du numéro n'a pas de champ de code : un code refusé (envoi groupé d'une page d'avant) se dit en alerte.
      @form.errors.messages_for(:pin).each { @form.errors.add(:base, it) } if @stage == :contact
      render :new, status: RendersResult::FORM_STATUSES.fetch(result.code, :unprocessable_entity)
    end

    # ADR-0086 §4.5 : la coque d'un autre rôle ; le formulaire revient vide, sous un message qui renvoie au site.
    def render_wrong_app
      @form = Dtos::Identity::StudentEntryInput.new
      @form.errors.add(:base, t(".wrong_app"))
      forget_student_entry
      @stage = :contact
      render :new, status: :unprocessable_entity
    end

    def refuse_too_many
      @form = form_input || Dtos::Identity::StudentEntryInput.new
      @stage ||= :contact
      @form.errors.add(:base, t("errors.codes.rate_limited"))
      load_link
      render :new, status: :too_many_requests
    end

    # Le numéro seul (student_entry[contact]) ; ou le code seul (student_entry[pin]), le numéro venant de l'entrée gardée ;
    # ou les deux ensemble (une page d'avant ce chantier, sans JavaScript). Le code seul sans entrée (expirée) : nil, le
    # contrôleur renvoie à l'entrée.
    def form_input
      posted = params.expect(student_entry: %i[contact pin link_token])
      context = { ip: request.remote_ip, user_agent: request.user_agent, client: lnclass_app&.to_s || "web" }
      @link_token = link_token_param(posted[:link_token])
      unless posted.key?(:contact)
        entry = student_entry
        return unless entry&.contact

        @stage = entry_stage(entry)
        @link_token ||= entry.link_token
        return Dtos::Identity::StudentEntryInput.new(contact: entry.contact, pin: posted[:pin].to_s, **context)
      end

      @stage = :contact
      Dtos::Identity::StudentEntryInput.new(contact: posted[:contact], pin: (posted[:pin] if posted.key?(:pin)), **context)
    end

    def link_token_param(raw) = Dtos::Classroom::StudentRegistrationInput.normalize_link_token(raw)

    # Le bandeau de la classe du lien ; un lien devenu invalide est oublié sans rien dire (l'inscription prendra la voie standard).
    def load_link
      @preview = @link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: @link_token)
      @link_token = nil unless @preview
    end

    def registration_path(link_token) = link_token ? join_classroom_path(link_token) : new_student_registration_path

    def enter
      UseCases::Identity::EnterByNumber.new(
        users: Repositories::Identity::UserRepository.new, login_attempts: Repositories::Identity::LoginAttemptRepository.new,
        sessions: Repositories::Identity::SessionRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
