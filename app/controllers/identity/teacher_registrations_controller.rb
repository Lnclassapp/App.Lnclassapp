# 🌐 DELIVERY · Identity::TeacherRegistrationsController
# Rôle : inscription enseignant publique, DRENA → établissement ou lien /i/<jeton> (limités en débit) ; succès : session, voie notée
# ADR  : 0026, 0028, 0030, 0050, 0063, 0082 · UDR : 0024, 0050, 0078
module Identity
  class TeacherRegistrationsController < ApplicationController
    FIELDS = %i[full_name last_name first_name gender contact pin pin_confirmation drena_public_id school_public_id
                material_slug invite_token].freeze

    allow_unauthenticated_access
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { refuse_too_many_posts }
    # Le lien d'invitation a son propre compteur, comme l'ancien /e/<code> (ADR-0082 §4.1) ; au-delà, rien n'est révélé.
    rate_limit to: 10, within: 1.minute, only: :invite, name: "invite_link", by: -> { request.remote_ip },
               with: -> { refuse_too_many }
    helper_method :material_options, :drena_options, :school_options

    # Sans JavaScript, la DRENA choisie revient ici en GET (formulaire teacher-signup-drena) et liste ses établissements.
    def new
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::TeacherRegistrationInput.new(
        drena_public_id: params.permit(teacher_registration: :drena_public_id).dig(:teacher_registration, :drena_public_id)
      )
    end

    # /i/<jeton> : le même formulaire, l'établissement déjà choisi ; le jeton voyage dans un champ caché, sans cookie ni
    # session. Un lien invalide ouvre la voie standard avec l'alerte, en 200, sans jamais dire pourquoi.
    def invite
      return redirect_to_home if authenticated?

      @form = Dtos::Identity::TeacherRegistrationInput.new(invite_token: params[:token])
      @preview = preview_of(@form.invite_token)
      @invite_invalid = @preview.nil?
      render :new
    end

    def create
      @form = form_input
      result = register.call(actor: current_actor, dto: @form, ip: request.remote_ip, user_agent: request.user_agent)
      show_invite if result.failure?
      render_result result, form: :new, success: lambda { |registered|
        start_session(registered.token)
        redirect_to teacher_classrooms_path, notice: t(".welcome"), status: :see_other
      }
    end

    private

    # Un lien encore valide garde son bandeau ; devenu invalide depuis l'ouverture, il laisse la voie standard et l'alerte.
    def show_invite
      @preview = preview_of(@form.invite_token)
      @invite_invalid = @form.invite_token.present? && @preview.nil?
    end

    def refuse_too_many_posts
      @form = form_input
      show_invite
      render_rate_limited(:new)
    end

    def refuse_too_many
      @rate_limited = true
      render :new, status: :too_many_requests
    end

    def form_input
      Dtos::Identity::TeacherRegistrationInput.new(**params.expect(teacher_registration: FIELDS).to_h.symbolize_keys)
    end

    def preview_of(token)
      link = token && invite_links.resolve(token:)
      Queries::School::SchoolPreviewQuery.new.call(school_id: link.school_id) if link&.valid?
    end

    def invite_links = Repositories::Identity::InviteLinkRepository.new
    def options = @options ||= Queries::School::SchoolOptionsQuery.new
    def material_options = Queries::Catalog::ReferentialOptionsQuery.new.call.materials.map { [ it.name, it.slug ] }
    def drena_options = options.drenas.map { [ it.name, it.public_id ] }

    # Seule une DRENA connue est cherchée (comme School::DrenaSchoolsController) : un identifiant forgé ne touche pas la base.
    def school_options
      return [] unless options.drenas.any? { it.public_id == @form.drena_public_id }

      options.schools_for(drena_public_id: @form.drena_public_id)
    end

    def register
      UseCases::Identity::RegisterTeacher.new(
        registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
        drenas: Repositories::School::DrenaRepository.new, invite_links:,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, sessions: Repositories::Identity::SessionRepository.new,
        referrals: Repositories::Identity::ReferralRepository.new, policy: Policies::Identity::RegisterTeacherPolicy.new,
        transaction: Repositories::Shared::Transaction.new, digest_key: secret_digest_key, clock: Time.zone
      )
    end
  end
end
