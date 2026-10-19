# 🌐 DELIVERY · Classroom::StudentClassroomChangesController
# Rôle : « Changer de classe » de l'élève à classe active : la cascade (GET), la confirmation relue côté serveur (GET), l'envoi (POST) ; succès : accueil
# ADR  : 0026, 0085, 0095 · UDR : 0102 (§3.1, §3.2, §3.3)
module Classroom
  class StudentClassroomChangesController < AuthenticatedController
    include ClassPicker

    FIELDS = %i[drena_public_id school_public_id level_slug classroom_public_id].freeze
    STATUSES = { forbidden: :forbidden, conflict: :conflict }.freeze
    NO_CLASSROOM_SCOPE = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes.base".freeze

    allow_roles :student
    # ADR-0095 §4.4 : 5 envois par minute et par compte, comme l'inscription.
    rate_limit to: 5, within: 1.minute, only: :create, by: -> { current_actor.user_id }, with: -> { refuse_too_many }
    # ADR-0085 §4.1 : la confirmation par lien dit si un jeton ouvre une classe ; elle partage le compteur de /c/<jeton>.
    rate_limit **JoinsController::LINK_RATE_LIMIT, only: :confirm, if: :link?, by: -> { request.remote_ip },
                                                   with: -> { refuse_too_many }
    # L'élève sans classe active choisit la sienne par « Choisis ta classe » (JoinAsStudent).
    before_action :load_current, only: %i[new confirm]

    # Sans choix envoyés (repli sans JavaScript), l'établissement actuel replié en étape 1.
    def new
      @form = Dtos::Classroom::StudentRegistrationInput.new(**(picker_params.presence || cascade_of(@current, level: false)))
      # Posé quand le lien de la confirmation n'est plus valable (UDR-0081 §3.4) ; lu une fois.
      @link_invalid = flash[:link_invalid].present?
    end

    # Rien n'est écrit : la classe visée est relue pour la montrer ; une classe impossible renvoie à la cascade.
    def confirm
      @form = submitted
      @destination = link? ? preview.linked(token: @form.link_token) : chosen(@form)
      return refuse_link if link? && @destination.nil?

      attribute, error, status = refusal
      render_change_page(@form, side: @destination, status:) { it.errors.add(attribute, error) } if error
    end

    # ADR-0095 §4.4 : seul cet envoi change la classe ; la garde est ChangeClassroom.
    def create
      dto = submitted
      result = change.call(actor: current_actor, dto:, ip: request.remote_ip)
      return redirect_to(student_home_path, notice: t(".welcome", classroom: result.value.name), status: :see_other) if result.success?
      return redirect_to(new_student_classroom_change_path, flash: { link_invalid: true }, status: :see_other) if result.code == :not_found

      side = preview.linked(token: dto.link_token)
      log_conflict(side&.public_id || dto.classroom_public_id) if result.code == :conflict
      render_change_page(dto, side:, status: STATUSES.fetch(result.code, :unprocessable_entity)) { add_errors(result) }
    end

    private

    def load_current
      @current = preview.current(student_id: current_actor.user_id)
      redirect_to new_student_classroom_choice_path unless @current
    end

    def refuse_too_many
      render_change_page(submitted, status: :too_many_requests) { it.errors.add(:base, t("errors.codes.rate_limited")) }
    end

    # ADR-0088 : le lien d'une classe archivée dit son motif, comme à l'envoi ; tout autre lien mort, « plus valable ».
    def refuse_link
      return redirect_to(new_student_classroom_change_path, flash: { link_invalid: true }, status: :see_other) unless
        preview.archived_link?(token: @form.link_token)

      render_change_page(@form, status: :forbidden) { it.errors.add(:base, :classroom_archived) }
    end

    # La page « Changer de classe » avec une raison en tête ou sous la classe, la cascade sur la classe visée. Sans classe
    # active (archivée entre la confirmation et l'envoi) : « Choisis ta classe », qui dit pourquoi.
    def render_change_page(dto, status:, side: nil)
      @current ||= preview.current(student_id: current_actor.user_id)
      return redirect_to(new_student_classroom_choice_path, alert: t(:no_active_classroom, scope: NO_CLASSROOM_SCOPE), status: :see_other) unless @current

      @form = dto.link_token ? Dtos::Classroom::StudentRegistrationInput.new(**cascade_of(side || @current)) : dto
      yield @form
      render :new, status:
    end

    # → [attribut, erreur, statut] | [] (la confirmation peut s'afficher)
    def refusal
      return [ :classroom_public_id, @form.classroom_public_id ? :unavailable : :blank, :unprocessable_entity ] unless @destination
      return [ :base, :same_classroom, :unprocessable_entity ] if @destination.public_id == @current.public_id
      return [ :base, :classroom_full, :forbidden ] if @destination.full

      []
    end

    def chosen(form)
      preview.chosen(school_public_id: form.school_public_id, level_slug: form.level_slug, classroom_public_id: form.classroom_public_id)
    end

    def cascade_of(side, level: true)
      { drena_public_id: side.drena_public_id, school_public_id: side.school_public_id, level_slug: (side.level_slug if level) }
    end

    def link? = params[:link_token].present?

    # Le jeton (normalisé, mal formé → nil) ou les quatre champs de la cascade.
    def submitted
      return Dtos::Classroom::StudentRegistrationInput.new(link_token: params[:link_token]) if link?

      Dtos::Classroom::StudentRegistrationInput.new(**picker_params)
    end

    # Une valeur qui n'est pas un hash est écartée par permit, pas levée.
    def picker_params = (params.permit(student_classroom_change: FIELDS)[:student_classroom_change] || {}).to_h.symbolize_keys

    def preview = @preview ||= Queries::Classroom::ClassroomChangePreviewQuery.new

    # Aucun contact dans le journal : l'élève et la classe visée, par leurs identifiants.
    def log_conflict(to_classroom)
      Rails.logger.warn("classroom.change_conflict user_id=#{current_actor.user_id} to_classroom=#{to_classroom}")
    end

    def change
      UseCases::Classroom::ChangeClassroom.new(
        classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::Classroom::JoinPolicy.new,
        transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      )
    end
  end
end
