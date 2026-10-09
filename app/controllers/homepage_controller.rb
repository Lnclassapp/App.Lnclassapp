# 🌐 DELIVERY · HomepageController
# Rôle : sert la page d'accueil publique ; une personne connectée est envoyée vers son accueil, l'ouverture depuis l'app installée datée
# ADR  : 0001, 0050, 0082, 0084, 0086
class HomepageController < ApplicationController
  allow_unauthenticated_access

  def index
    return unless authenticated?

    channel = app_open_channel
    record_app_open(channel) if channel
    redirect_to_home
  end

  private

  # ADR-0082 §4.3 : l'icône de l'app installée ouvre « /?source=app » (canal :pwa). ADR-0084 §4.6, ADR-0086 §4.6 : une
  # coque Android reconnue, élèves ou enseignants, ouvre « /?source=android » (canal :android), compté seulement s'il
  # vient d'elle ; tapé dans un navigateur, il ne date rien. Toute autre source est ignorée.
  def app_open_channel
    case params[:source]
    when "app" then :pwa
    when "android" then :android if lnclass_app?
    end
  end

  # Le résultat n'est pas lu : un refus de la policy (direction, équipe, second facteur non vérifié) est muet, et une
  # panne de la base ne bloque jamais l'accueil : elle est journalisée (config/initializers/error_reporting.rb). Toute
  # autre erreur est un bogue : elle remonte.
  def record_app_open(channel)
    UseCases::Identity::RecordAppOpen.new(
      users: Repositories::Identity::UserRepository.new, policy: Policies::Identity::RecordAppOpenPolicy.new,
      clock: Time.zone, reporter: Rails.error, recoverable: ActiveRecord::ActiveRecordError
    ).call(actor: current_actor, channel:)
  end
end
