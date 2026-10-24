# 🌐 DELIVERY · Classroom::StudentRegistrationsController
# Rôle : inscription élève publique en trois étapes : classe donnée par son code, par le jeton d'un lien ou choisie dans la cascade ; succès : session, accueil élève
# ADR  : 0026, 0028, 0050, 0062, 0085, XXXX-code-de-classe-a-six-caracteres (§4.5, §4.6) · UDR : 0079, 0081, XXXX-inscription-eleve-en-trois-etapes
module Classroom
  class StudentRegistrationsController < ApplicationController
    include ClassPicker

    FIELDS = %i[last_name first_name gender contact pin pin_confirmation drena_public_id school_public_id level_slug
                classroom_public_id link_token join_code].freeze
    # Repli sans JavaScript (UDR-0081 §3.3) : les choix reviennent en GET ; jamais les PIN, qui n'y sont pas relus.
    PICKER_FIELDS = %i[last_name first_name gender contact drena_public_id school_public_id level_slug
                       classroom_public_id].freeze

    allow_unauthenticated_access
    # Deux plafonds, les deux gardés : ADR code-de-classe §4.5, l'envoi compte dans le même débit que /c/<jeton> et la
    # vérification d'un code (10 par minute et par adresse), taper des codes dans l'inscription étant la même devinette ;
    # ADR-0085 §4.6, l'envoi seul est limité à 5 par minute et par adresse. Même réponse « Trop de tentatives » pour les deux.
    rate_limit **Classroom::JoinsController::LINK_RATE_LIMIT, only: :create, by: -> { request.remote_ip },
                                                              with: -> { refuse_too_many_posts }
    rate_limit to: 5, within: 1.minute, only: :create, name: "signup", by: -> { request.remote_ip },
                                                         with: -> { refuse_too_many_posts }

    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Classroom::StudentRegistrationInput.new(**picker_params)
      # Posé par /c/<jeton> quand le lien n'est plus valable (UDR-0081 §3.4) ; lu une fois.
      @link_invalid = flash[:link_invalid].present?
    end

    def create
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

    def form_input
      Dtos::Classroom::StudentRegistrationInput.new(**params.expect(student_registration: FIELDS).to_h.symbolize_keys)
    end

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
