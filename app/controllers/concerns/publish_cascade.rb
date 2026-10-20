# 🌐 DELIVERY · PublishCascade — action « Tout publier » d'un cours ou d'une fiche (menu ⋮ de l'équipe)
# Rôle : appelle UseCases::Catalog::PublishCascade ; toast du bilan puis page rafraîchie par morphing (tous les statuts changent)
# ADR  : 0026, 0035 (amendement du 2026-10-01), 0105 · UDR : 0042 (amendement du 2026-10-01), 0129
module PublishCascade
  extend ActiveSupport::Concern

  UNREADABLE = %i[image_slots_unreadable essential_unreadable].freeze

  def publish_all
    result = publish_cascade.call(actor: current_actor, root: cascade_root, slug: params[:slug])
    return cascade_refused(result) if result.code == :conflict

    render_result result, success: ->(summary) { cascade_done(summary) }
  end

  private

  # Refus métier, rien n'a été écrit : une fiche dont le cours n'est pas publié, une fiche racine sans ses images (count),
  # ou une fiche du cours qui n'est pas prête (essential_not_ready, nommée, ADR-0105 §4.4).
  def cascade_refused(result)
    reason = result.errors.fetch(:base).first
    scope = %i[essential_not_ready essential_unreadable].include?(reason) ? "teams.courses.transition" : "teams.essentials.transition"
    log_unreadable_text(slug: params[:slug], name: result.errors[:name]) if (result.errors[:base] & UNREADABLE).any?
    message = t("#{scope}.#{reason}", **result.errors.slice(:count, :name))
    respond_to do |format|
      format.turbo_stream { render turbo_stream: helpers.turbo_stream_toast(message, type: :error), status: :unprocessable_entity }
      format.html { redirect_back_or_to courses_path, alert: message, status: :see_other }
    end
  end

  # Le texte d'une fiche trop complexe à relire (menace.md, n° 13) : la fiche est nommée au journal, jamais son contenu.
  def log_unreadable_text(slug:, name: nil)
    Rails.logger.warn("[#{self.class.name}] image_slots_unreadable slug=#{slug} name=#{name.inspect}")
  end

  def cascade_done(summary)
    messages = cascade_messages(summary)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [ *messages.map { |type, text| helpers.turbo_stream_toast(text, type:) }, turbo_stream.refresh(request_id: nil) ]
      end
      format.html { redirect_back_or_to courses_path, notice: messages.map(&:last).join(" "), status: :see_other }
    end
  end

  def cascade_messages(summary)
    scope = "teams.publish_cascade"
    counts = { essentials: t("#{scope}.essentials", count: summary.essentials), exercises: t("#{scope}.exercises", count: summary.exercises) }
    done = [ :success, t("#{scope}.done.#{cascade_root}", name: summary.root.name, **counts) ]
    incomplete = summary.skipped - summary.skipped_images
    warnings = { skipped_images: summary.skipped_images, skipped: incomplete }.reject { _2.zero? }
    [ done, *warnings.map { |key, count| [ :warning, t("#{scope}.#{key}", count:) ] } ]
  end

  def publish_cascade
    dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
                     policy: Policies::Catalog::ManageContentPolicy.new, clock: Time.zone }
    courses = Repositories::Catalog::CourseRepository.new
    essentials = Repositories::Catalog::EssentialRepository.new
    exercises = Repositories::Assessment::ExerciseRepository.new
    UseCases::Catalog::PublishCascade.new(
      courses:, essentials:, exercises:, transaction: dependencies[:transaction], policy: dependencies[:policy],
      publish_course: UseCases::Catalog::PublishCourse.new(courses:, **dependencies),
      publish_essential: UseCases::Catalog::PublishEssential.new(essentials:, **dependencies),
      publish_exercise: UseCases::Assessment::PublishExercise.new(exercises:, **dependencies)
    )
  end
end
