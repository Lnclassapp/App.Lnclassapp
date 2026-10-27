# 🌐 DELIVERY · RendersResult — traduit un Shared::Result en réponse HTTP
# Rôle : succès → bloc du contrôleur ; échec → 403/404 (HTML, JSON, Turbo Stream), formulaire en 422, 429, ou connexion ;
#        classe d'un autre établissement de l'enseignant → retour à l'accueil, avec quoi faire
# ADR  : 0026, 0050, 0094 · UDR : 0098 (§3.5)
module RendersResult
  extend ActiveSupport::Concern

  FORM_STATUSES = { invalid: :unprocessable_entity, conflict: :unprocessable_entity, expired: :unprocessable_entity,
                    locked: :too_many_requests }.freeze
  ERROR_PAGES = { forbidden: "errors/forbidden", not_found: "errors/not_found" }.freeze
  MODAL_FRAME = "modal"
  # ADR-0094 §4.3 : le refus d'une classe hors de l'établissement courant (ReadClassroomPolicy, TeachPolicy,
  # DeclareTeachingPolicy) ; il ne nomme aucun établissement.
  OTHER_SCHOOL = :other_school

  private

  # success : appelé avec result.value. form : template re-rendu en cas d'échec de saisie, avec les erreurs sur @form.
  def render_result(result, success:, form: nil)
    return success.call(result.value) if result.success?

    case result.code
    when :forbidden then other_school?(result) ? render_other_school : render_error_page(:forbidden)
    when :not_found then render_error_page(:not_found)
    when :expired then form ? render_form(form, result) : redirect_to(main_app.new_session_path, alert: t("errors.session_expired"))
    else render_form(form, result)
    end
  end

  # Cible du `with:` de rate_limit : le contrôleur fournit `form_input`, la saisie reconstruite depuis les paramètres.
  def render_rate_limited(form)
    @form = form_input
    @form.errors.add(:base, t("errors.codes.rate_limited"))
    render form, status: :too_many_requests
  end

  def other_school?(result) = Array(result.errors[:base]).include?(OTHER_SCHOOL)

  # UDR-0098 §3.5 (amendée le 2026-10-16) : chaque établissement est un espace autonome ; l'enseignant revient à
  # l'accueil de son établissement courant, avec le geste qui ouvre l'autre (le panneau du compte).
  def render_other_school
    message = t("errors.codes.other_school")
    respond_to do |format|
      format.html { redirect_to main_app.teacher_home_path, alert: message, status: :see_other }
      format.json { render json: { error: :forbidden }, status: :forbidden }
      format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type: :error), status: :forbidden }
    end
  end

  def render_forbidden = render_error_page(:forbidden)
  def render_not_found = render_error_page(:not_found)

  # Dans le cadre « modal » et dans celui du panneau « Mon compte », la page d'erreur porte la balise de rechargement : Turbo quitte
  # le cadre et l'affiche entière, au lieu d'y mettre le cadre vide ou le menu du layout (document_reload_tag). Les autres cadres
  # (une recherche) gardent leur état d'erreur avec « Réessayer » (UDR-0054 §3.9) : seul le cadre manquant le déclenche.
  def render_error_page(code)
    status = code
    @reload_document = turbo_frame_request_id.in?([ MODAL_FRAME, NavigationHelper::ACCOUNT_PANEL_FRAME ])
    # Un formulaire du panneau demande le Turbo Stream d'abord : son toast resterait sous le panneau (une <dialog> modale) et sa
    # confirmation resterait ouverte. La page d'erreur, elle, quitte le frame et s'affiche entière.
    request.format = :html if turbo_frame_request_id == NavigationHelper::ACCOUNT_PANEL_FRAME && request.format.turbo_stream?
    respond_to do |format|
      format.html { render ERROR_PAGES.fetch(code), status:, layout: "application" }
      format.json { render json: { error: code }, status: }
      format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(t("errors.codes.#{code}"), type: :error), status: }
    end
  end

  # Les erreurs du use case rejoignent celles du DTO ; un échec sans erreur nommée reçoit le message de son code.
  def render_form(form, result)
    add_errors(result)
    render form, status: FORM_STATUSES.fetch(result.code)
  end

  def add_errors(result)
    errors = result.errors.except(:retry_after)
    errors = { base: [ t("errors.codes.#{result.code}") ] } if errors.empty?
    errors[:base] = [ locked_message(result.errors[:retry_after]) ] if result.errors.key?(:retry_after)
    errors.each do |attribute, messages|
      messages.each { |message| @form.errors.add(attribute, message) unless @form.errors.added?(attribute, message) }
    end
  end

  def locked_message(retry_after)
    return t("errors.locked.until_recovery") if retry_after == Entities::Identity::Lockout::UNTIL_RECOVERY

    t("errors.locked.until", time: l(Time.zone.now + retry_after, format: :hour_minute))
  end
end
