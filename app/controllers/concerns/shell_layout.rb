# 🌐 DELIVERY · ShellLayout — ce dont le shell a besoin : la personne connectée, sous la forme d'un ShellUser
# Rôle : fournit shell_user aux contrôleurs qui rendent layouts/shell (espaces connectés, et /aide pour un compte connecté)
# ADR  : 0060 · UDR : 0006, 0061 (amendement du 2026-10-06)
module ShellLayout
  extend ActiveSupport::Concern

  included do
    helper_method :shell_user
  end

  private

  # La photo remplace les initiales du menu du compte et de la barre latérale (ADR-0060).
  def shell_user
    @shell_user ||= Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id).then do |row|
      NavigationHelper::ShellUser.new(name: row.name, role: row.role, detail: row.detail,
                                      avatar_url: helpers.account_photo_src(row.public_id, row.photo_version))
    end
  end
end
