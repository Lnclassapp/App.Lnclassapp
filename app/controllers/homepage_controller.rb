# 🌐 DELIVERY · HomepageController
# Rôle : sert la page d'accueil publique ; une personne connectée est envoyée vers son accueil, l'ouverture depuis l'app installée datée
# ADR  : 0001, 0050, 0082
class HomepageController < ApplicationController
  allow_unauthenticated_access

  def index
    return unless authenticated?

    record_app_open if params[:source] == "app"
    redirect_to_home
  end

  private

  # ADR-0082 §4.3 : l'icône de l'app installée ouvre « /?source=app ». Le résultat n'est pas lu : un refus de la policy
  # (direction, équipe, second facteur non vérifié) est muet, et une panne de la base ne bloque jamais l'accueil : elle
  # est journalisée (config/initializers/error_reporting.rb). Toute autre erreur est un bogue : elle remonte.
  def record_app_open
    UseCases::Identity::RecordAppOpen.new(
      users: Repositories::Identity::UserRepository.new, policy: Policies::Identity::RecordAppOpenPolicy.new,
      clock: Time.zone, reporter: Rails.error, recoverable: ActiveRecord::ActiveRecordError
    ).call(actor: current_actor)
  end
end
