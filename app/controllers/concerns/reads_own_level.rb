# 🌐 DELIVERY · ReadsOwnLevel — un élève ne lit que les cours de son niveau (catalogue, cours, fiche, exercice, session)
# Rôle : `refuse_out_of_level(...)` rend 404 à un élève hors niveau et le dit ; `student_audience` : ses niveaux de l'année
# ADR  : 0028, 0035 (amendement du 2026-10-01) · UDR : 0013 (amendement du 2026-10-01), 0077 (§3.2) · audit B-046 : un enseignant, ses matières
module ReadsOwnLevel
  extend ActiveSupport::Concern

  private

  # content_key : course_slug:, course_id: ou exercise_public_id:. → true si la réponse 404 est rendue (élève hors niveau).
  def refuse_out_of_level(**content_key)
    return false unless current_actor.student? # AuthenticatedController : l'acteur est toujours là

    course_level = Queries::Catalog::CourseLevelQuery.new.call(**content_key)
    allowed = course_level &&
              Policies::Catalog::ReadOwnLevelPolicy.new.call(actor: current_actor, audience: student_audience, course_level:).success?
    render_not_found unless allowed
    !allowed
  end

  # Audit B-046 : un enseignant ne lit une leçon par son adresse que dans ses matières (catalogue compris), 404 sinon.
  # content_key : course_slug: ou course_id:. → true si la réponse 404 est rendue.
  def refuse_out_of_material(**content_key)
    return false unless current_actor.teacher?

    scope = Queries::Catalog::TeacherAudienceQuery.new.call(teacher_id: current_actor.user_id, school_id: current_actor.school_id)
    allowed = Policies::Catalog::ReadOwnMaterialPolicy.new.call(
      actor: current_actor, own_material_slugs: scope.materials.map(&:slug),
      material_slug: Queries::Catalog::CourseMaterialQuery.new.call(**content_key)
    ).success?
    render_not_found unless allowed
    !allowed
  end

  def student_audience = @student_audience ||= Queries::Catalog::StudentAudienceQuery.new.call(student_id: current_actor.user_id)
end
