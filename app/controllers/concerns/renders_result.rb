# 🌐 DELIVERY · RendersResult — traduit un Shared::Result en réponse HTTP
# Rôle : succès → bloc du contrôleur ; échec → 403/404 (HTML, JSON, Turbo Stream), formulaire en 422, 429, ou connexion
# ADR  : 0026, 0050
module RendersResult
  extend ActiveSupport::Concern

  FORM_STATUSES = { invalid: :unprocessable_entity, conflict: :unprocessable_entity, expired: :unprocessable_entity,
                    locked: :too_many_requests }.freeze
  ERROR_PAGES = { forbidden: "errors/forbidden", not_found: "errors/not_found" }.freeze

  private

  # success : appelé avec result.value. form : template re-rendu en cas d'échec de saisie, avec les erreurs sur @form.
  def render_result(result, success:, form: nil)
    return success.call(result.value) if result.success?

    case result.code
    when :forbidden, :not_found then render_error_page(result.code)
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

  def render_forbidden = render_error_page(:forbidden)
  def render_not_found = render_error_page(:not_found)

  def render_error_page(code)
    status = code
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
