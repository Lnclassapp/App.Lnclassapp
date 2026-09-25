# 🌐 DELIVERY · Authentication — session serveur, cookie signé, garde du second facteur et des rôles
# Rôle : résout la session à chaque requête ; un compte team non vérifié n'a pas d'acteur et ne voit que le second facteur
# ADR  : 0028, 0031, 0050
module Authentication
  extend ActiveSupport::Concern

  COOKIE = :session_token
  # Symbole de HomeDestination → route de l'accueil (UDR-0006, routes gelées du Lot 0a).
  HOME_ROUTES = {
    student_home: :student_home_path, teacher_home: :teacher_home_path, teacher_classrooms: :teacher_classrooms_path,
    team_home: :team_home_path, pending_account: :pending_account_path
  }.freeze

  included do
    before_action :require_authentication
    before_action :require_verified_second_factor
    helper_method :current_actor, :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, :require_verified_second_factor, **options
    end

    # Écrans du second facteur et déconnexion : une session suffit, l'acteur n'est pas exigé.
    def allow_unverified_second_factor(**options)
      skip_before_action :require_verified_second_factor, **options
    end

    # Un rôle hors liste reçoit 403 (ADR-0028) : l'autorisation fine reste l'affaire des policies.
    def allow_roles(*roles, **options)
      before_action(**options) { render_forbidden unless roles.include?(current_actor.role) }
    end
  end

  private

  def current_session = resolution.session
  def current_actor = resolution.actor
  def authenticated? = !current_session.nil?

  # Session absente, falsifiée ou expirée : une résolution anonyme, sans session ni acteur.
  def resolution
    @resolution ||= resolve_session.call(token: cookies.signed[COOKIE]).then do |result|
      result.success? ? result.value : UseCases::Identity::ResolveSession::Resolved.new(actor: nil, session: nil)
    end
  end

  def require_authentication
    redirect_to main_app.new_session_path unless authenticated?
  end

  def require_verified_second_factor
    redirect_to second_factor_path if current_actor.nil?
  end

  def second_factor_path
    return main_app.new_identity_second_factor_path if current_session.second_factor_confirmed

    main_app.new_identity_second_factor_enrollment_path
  end

  # Nouvel identifiant de session Rails et nouveau cookie à chaque connexion (ADR-0050).
  def start_session(token)
    reset_session
    cookies.signed.permanent[COOKIE] = { value: token, httponly: true, same_site: :lax, secure: !Rails.env.local? }
    @resolution = nil
  end

  def terminate_session
    sign_out.call(token: cookies.signed[COOKIE])
    cookies.delete(COOKIE)
    reset_session
  end

  def redirect_to_home(**options)
    return redirect_to(second_factor_path, **options) if current_actor.nil?

    destination = Queries::Identity::HomeDestinationQuery.new.call(actor: current_actor)
    redirect_to main_app.public_send(HOME_ROUTES.fetch(destination)), **options
  end

  def secret_digest_key = Rails.application.key_generator.generate_key("lnclass-secrets")

  def resolve_session
    UseCases::Identity::ResolveSession.new(
      sessions: Repositories::Identity::SessionRepository.new, users: Repositories::Identity::UserRepository.new,
      policy: Policies::Identity::SessionPolicy.new, digest_key: secret_digest_key, clock: Time.zone
    )
  end

  def sign_out
    UseCases::Identity::SignOut.new(sessions: Repositories::Identity::SessionRepository.new,
                                    policy: Policies::Identity::SessionPolicy.new, digest_key: secret_digest_key)
  end
end
