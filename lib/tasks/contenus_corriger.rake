# Reporte en production les corrections de docs/chantiers/corrections-production/corrections.json (chantier corrections-production) par les
# use cases « Modifier le texte » : essai par défaut (aucune écriture), APPLIQUER=1 pour écrire. À retirer une fois appliqué.
# Usage : bin/rails contenus:corriger            (essai ; acteur : LNCLASS_TEAM_CONTACT, ou ACTEUR=<contact d'un membre équipe>)
#         APPLIQUER=1 bin/rails contenus:corriger
require "json"

namespace :contenus do
  desc "Reporte les corrections du validateur pédagogique par les use cases Modifier le texte (essai par défaut ; APPLIQUER=1 écrit)"
  task corriger: :environment do
    # Dans la tâche, pas en tête de fichier : `bin/rails test` sans fichier charge les tâches (test:prepare) avant que SimpleCov démarre,
    # et un `require` ici sortait lib/contenus/corrections_production.rb de la mesure (chantier couverture-locale-et-train-divergent).
    require Rails.root.join("lib/contenus/corrections_production")

    contact = ENV["ACTEUR"].presence || ENV["LNCLASS_TEAM_CONTACT"]
    abort "Acteur manquant : ACTEUR=<contact> ou la variable LNCLASS_TEAM_CONTACT." if contact.blank?

    user = Repositories::Identity::UserRepository.new.find_by_contact(contact:)
    abort "Acteur introuvable." if user.nil?

    actor = Repositories::Identity::UserRepository.new.actor_for(user_id: user.id)
    abort "L'acteur n'est pas un membre de l'équipe." unless actor&.team?

    transaction = Repositories::Shared::Transaction.new
    audit_log = Repositories::Identity::AuditLogRepository.new
    policy = Policies::Catalog::ManageContentPolicy.new
    data = JSON.parse(Rails.root.join("docs/chantiers/corrections-production/corrections.json").read)
    runner = Contenus::CorrectionsProduction.new(
      data:, actor:,
      notion_use_case: UseCases::Catalog::CorrectNotionText.new(essentials: Repositories::Catalog::EssentialRepository.new, audit_log:, transaction:, policy:, clock: Time.zone),
      exercise_use_case: UseCases::Assessment::CorrectExerciseText.new(exercises: Repositories::Assessment::ExerciseRepository.new, audit_log:, transaction:, policy:, clock: Time.zone)
    )
    rows = runner.call(apply: ENV["APPLIQUER"] == "1")
    exit(1) if rows.any? { it.status == :echec }
    exit(0)
  end
end
