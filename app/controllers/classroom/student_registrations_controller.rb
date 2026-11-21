# 🌐 DELIVERY · Classroom::StudentRegistrationsController
# Rôle : inscription élève publique : classe donnée par son code, par le jeton d'un lien ou choisie dans la cascade ; succès : session, accueil élève.
#        Après l'entrée élève (mode entrée) : numéro et code viennent de l'entrée gardée en session, deux étapes ; sans elle, trois étapes.
# ADR  : 0026, 0028, 0050, 0062, 0085, 0109 (§4.5, §4.6, §4.7), XXXX-entree-eleve-revele-un-numero-inscrit · UDR : 0079, 0081, 0135, XXXX-entree-eleve-unique
module Classroom
  class StudentRegistrationsController < ApplicationController
    include ClassPicker
    include StudentEntrySession

    FIELDS = %i[last_name first_name gender contact pin pin_confirmation drena_public_id school_public_id level_slug
                classroom_public_id link_token join_code].freeze
    # Repli sans JavaScript (UDR-0081 §3.3) : les choix reviennent en GET ; jamais les PIN, qui n'y sont pas relus.
    PICKER_FIELDS = %i[last_name first_name gender contact drena_public_id school_public_id level_slug
                       classroom_public_id].freeze

    allow_unauthenticated_access
    # Avant les débits : leur refus re-rend le formulaire, numéro et code de l'entrée compris.
    before_action :load_entry
    # ADR-0085 §4.7 : un envoi qui porte un jeton de lien de forme valide compte dans le seul compteur du lien de classe
    # (60 par minute et par adresse, partagé avec /c/<jeton>) : une classe s'inscrit derrière une seule adresse.
    rate_limit **Classroom::JoinsController::CLASS_LINK_RATE_LIMIT, only: :create, if: :link_send?, by: -> { request.remote_ip },
                                                                    with: -> { refuse_too_many_posts }
    # Sans jeton de lien, deux plafonds, les deux gardés : ADR code-de-classe §4.5, l'envoi compte dans le même débit que la
    # vérification d'un code (10 par minute et par adresse), taper des codes dans l'inscription étant la même devinette ;
    # ADR-0085 §4.6, l'envoi seul est limité à 5 par minute et par adresse. Même réponse « Trop de tentatives » pour les deux.
    rate_limit **Classroom::JoinsController::LINK_RATE_LIMIT, only: :create, unless: :wide_send?, by: -> { request.remote_ip },
                                                              with: -> { refuse_too_many_posts }
    rate_limit to: 5, within: 1.minute, only: :create, name: "signup", unless: :wide_send?, by: -> { request.remote_ip },
                                                         with: -> { refuse_too_many_posts }
    # ADR-XXXX-entree-eleve-revele-un-numero-inscrit §4.2 : après l'entrée, sans code de classe, l'envoi a son compteur (60 par
    # minute et par adresse) : une classe qui choisit sa classe dans la cascade s'inscrit derrière un wifi.
    rate_limit **Identity::StudentEntriesController::REGISTRATION_RATE_LIMIT, only: :create, if: :entry_send?, by: -> { request.remote_ip },
                                                                 with: -> { refuse_too_many_posts }

    def new
      return redirect_to_home if authenticated?

      # L'entrée faite par un lien de classe s'inscrit sur la page du lien, qui garde sa classe ; « Ce n'est pas ta classe ? »
      # (?other_classroom=1) oublie le lien et ouvre la voie standard, numéro et code gardés.
      if @entry&.link_token
        return redirect_to(join_classroom_path(@entry.link_token)) unless params[:other_classroom]

        keep_student_entry(contact: @entry.contact, pin: @entry.pin, confirmed: true, link_token: nil)
        @entry = confirmed_student_entry
      end

      @form = Dtos::Classroom::StudentRegistrationInput.new(**picker_params)
      @form.contact = @entry.contact if @entry
      # Posé par /c/<jeton> quand le lien n'est plus valable (UDR-0081 §3.4) ; lu une fois.
      @link_invalid = flash[:link_invalid].present?
    end

    def create
      # Le formulaire du mode entrée revient sans son entrée (expirée) : rien n'est créé, retour à l'entrée.
      return redirect_to(new_student_entry_path, alert: t(".entry_expired"), status: :see_other) if @entry.nil? && entry_form?

      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      return render_refusal(result) if result.code == :forbidden

      show_link if result.failure?
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to student_home_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    # Un refus de JoinPolicy (classe complète) ou un élève déjà inscrit : la raison en tête du formulaire, en 403.
    def render_refusal(result)
      return render_forbidden if result.errors.empty?

      show_link
      add_errors(result)
      render :new, status: :forbidden
    end

    # Un lien encore valable garde son bandeau ; devenu invalide depuis l'ouverture, il laisse la voie standard et l'alerte.
    # Un code reconnu garde le rappel de classe à l'étape 2 (UDR inscription en trois étapes §3.3).
    def show_link
      @preview = @form.link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: @form.link_token)
      @link_invalid = @form.link_token.present? && @preview.nil?
      @code_preview = Queries::Classroom::JoinCodePreviewQuery.new.code(code: @form.join_code) if @form.join_code && @preview.nil?
    end

    # Au-delà du débit, rien n'est révélé : le lien garde son bandeau, le code n'est pas cherché (il serait une devinette de plus).
    # Le message est dit à l'étape 1 (UDR inscription en trois étapes §3.5).
    def refuse_too_many_posts
      @form = form_input
      @rate_limited = true
      @preview = @form.link_token && Queries::Classroom::JoinPreviewQuery.new.link(token: @form.link_token)
      @link_invalid = @form.link_token.present? && @preview.nil?
      render :new, status: :too_many_requests
    end

    # Le jeton posté, de forme valide (12 hexadécimaux), sans code : l'envoi vient d'un lien de classe (ADR-0085 §4.7).
    # Avec un code posté, les deux plafonds restent : RegisterStudent retombe sur le code quand le jeton ne résout rien,
    # et un faux jeton ne doit pas ouvrir la devinette de codes à 60 par minute.
    def link_send?
      posted = params.permit(student_registration: %i[link_token join_code])[:student_registration]
      return false if posted.blank? || posted[:join_code].present?

      Dtos::Classroom::StudentRegistrationInput.normalize_link_token(posted[:link_token]).present?
    end

    # En mode entrée, numéro et code viennent de l'entrée gardée, jamais du formulaire (UDR-XXXX §3.6).
    def form_input
      attributes = params.expect(student_registration: FIELDS).to_h.symbolize_keys
      attributes.merge!(contact: @entry.contact, pin: @entry.pin, pin_confirmation: @entry.pin) if @entry
      Dtos::Classroom::StudentRegistrationInput.new(**attributes)
    end

    def load_entry = @entry = confirmed_student_entry

    # Le champ caché entry_mode, hors du scope du formulaire, marque un formulaire du mode entrée.
    def entry_form? = params[:entry_mode] == "1"

    # Après l'entrée, sans code de classe : le compteur de l'entrée ; avec un code, la devinette de codes reste limitée.
    def entry_send?
      posted = params.permit(student_registration: %i[join_code])[:student_registration]
      confirmed_student_entry.present? && posted.to_h[:join_code].blank?
    end

    def wide_send? = link_send? || entry_send?

    # Une valeur qui n'est pas un hash (?student_registration=x) est écartée par permit, pas levée : la page s'ouvre vide.
    def picker_params = (params.permit(student_registration: PICKER_FIELDS)[:student_registration] || {}).to_h.symbolize_keys

    def register
      UseCases::Classroom::RegisterStudent.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, registrations: Repositories::Identity::RegistrationRepository.new,
        memberships: Repositories::Classroom::MembershipRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new,
        digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
