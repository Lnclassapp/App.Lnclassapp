# 🌐 DELIVERY · ShellLayout — ce dont le shell a besoin : la personne connectée, sous la forme d'un ShellUser
# Rôle : fournit shell_user aux contrôleurs qui rendent layouts/shell (espaces connectés, et /aide pour un compte connecté)
# ADR  : 0060, 0094 · UDR : 0006, 0061 (amendement du 2026-10-06), 0084 (§3.4), 0098 (§3.1), 0128 (about : message WhatsApp prêt)
module ShellLayout
  extend ActiveSupport::Concern

  included do
    helper_method :shell_user, :teacher_schools
  end

  private

  # Les établissements de l'enseignant connecté, lus une fois par requête : la rubrique « Établissement » du panneau du
  # compte et le lien « Changer » de l'accueil, à partir de deux (UDR-0098 §3.1, §3.3). Lu pour l'enseignant seul (vide
  # pour un autre compte : il n'a aucune ligne teacher_schools).
  def teacher_schools
    @teacher_schools ||= Queries::School::TeacherSchoolsQuery.new.call(teacher_id: current_actor.user_id,
                                                                       current_school_id: current_actor.school_id)
  end

  # La photo remplace les initiales du menu du compte et de la barre latérale (ADR-0060).
  def shell_user
    @shell_user ||= Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id,
                                                               current_school_id: current_actor.school_id).then do |row|
      NavigationHelper::ShellUser.new(name: row.name, role: row.role, detail: row.detail, public_id: row.public_id,
                                      avatar_url: helpers.account_photo_src(row.public_id, row.photo_version), about: row.about)
    end
  end
end
