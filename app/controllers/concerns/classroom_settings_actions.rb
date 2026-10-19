# 🌐 DELIVERY · ClassroomSettingsActions
# Rôle : « Modifier la classe » (edit, update) commun à l'équipe et à la direction ; l'espace donne l'établissement et le retour
# ADR  : 0098 · UDR : 0110, 0111 · le contrôleur fournit settings_school_public_id et saved_location
module ClassroomSettingsActions
  extend ActiveSupport::Concern

  FIELDS = %i[suffix max_students].freeze

  included do
    # L'écriture est jugée par le use case (policy, établissement, année) ; la lecture de la modale, ici.
    before_action :authorize_structure, :load_settings, only: :edit
  end

  # Une classe archivée n'a pas de modale de saisie : la sienne dit de la restaurer d'abord (UDR-0111). Un 404 vide
  # laisserait le cadre « modal » sans rien à montrer.
  def edit
    return render "shared/classroom_settings/archived" if settings.archived?

    @form = Dtos::Classroom::ClassroomSettingsInput.new(suffix: settings.suffix, max_students: settings.max_students)
  end

  # Succès : toast, modale refermée, page re-demandée (la carte change de nom). Classe archivée entre-temps : toast neutre,
  # même rafraîchissement. Saisie refusée : la modale revient en 422, l'erreur sous son champ.
  def update
    @form = Dtos::Classroom::ClassroomSettingsInput.new(**params.expect(classroom_settings: FIELDS).to_h.symbolize_keys)
    result = update_classroom.call(actor: current_actor, school_public_id: settings_school_public_id,
                                   classroom_public_id: params[:public_id], dto: @form)
    return respond_saved(result.value) if result.success?
    return render_error_page(result.code) if %i[forbidden not_found].include?(result.code)
    return respond_archived if result.errors[:base]&.include?(:archived)

    add_settings_errors(result)
    render :edit, status: :unprocessable_entity
  end

  private

  # La policy des gestes de structure (« + », « − », archivage) garde aussi la lecture de la modale.
  def authorize_structure
    school = Repositories::School::SchoolRepository.new.find_by_public_id(public_id: settings_school_public_id)
    return render_not_found if school.nil?

    render_result Policies::School::ManageSchoolStructurePolicy.new.call(actor: current_actor, school:), success: ->(_) { }
  end

  def load_settings
    render_not_found if settings.nil?
  end

  # Lue après un refus du use case, la classe existe : elle est de l'établissement et de l'année en cours.
  def settings
    @settings ||= Queries::Classroom::ClassroomSettingsQuery.new.call(public_id: params[:public_id],
                                                                       school: { public_id: settings_school_public_id })
  end

  def respond_saved(classroom)
    @notice = t(".saved", name: classroom.name)
    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_to saved_location, notice: @notice, status: :see_other }
    end
  end

  def respond_archived
    @alert = t("shared.classroom_settings.archived")
    respond_to do |format|
      format.turbo_stream { render :update, status: :unprocessable_entity }
      format.html { redirect_to saved_location, alert: @alert, status: :see_other }
    end
  end

  # Le préfixe et la place du suffixe, l'effectif sous verrou : les messages les citent (UDR-0110).
  def add_settings_errors(result)
    options = { suffix: { prefix: settings.prefix, count: settings.suffix_max }, max_students: { count: result.errors[:headcount] } }
    named = result.errors.except(:headcount)
    @form.errors.add(:base, t("errors.codes.#{result.code}")) if named.empty?
    named.each do |attribute, messages|
      messages.each do |message|
        @form.errors.add(attribute, message, **options.fetch(attribute, {})) unless @form.errors.added?(attribute, message)
      end
    end
  end

  def update_classroom
    UseCases::Classroom::UpdateClassroom.new(
      classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
      taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    )
  end
end
