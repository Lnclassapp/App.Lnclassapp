# Entonnoir brut des élèves, par semaine depuis la première inscription : `bin/rails entonnoir:brut` (chantier entonnoir-aarrr).
# Exécutable en production : une transaction READ ONLY (PostgreSQL refuse toute écriture), et des comptes seulement,
# ni nom, ni numéro, ni identifiant. Définitions : docs/chantiers/entonnoir-aarrr/prd.md §3.
namespace :entonnoir do
  desc "Imprime l'entonnoir des élèves par semaine et par voie d'arrivée (lecture seule, comptes uniquement)"
  task brut: :environment do
    query = Queries::Identity::StudentFunnelQuery
    now = Time.current
    rows = Orm::User.transaction do
      Orm::User.connection.execute("SET TRANSACTION READ ONLY")
      # Borne la charge sur la base de production : au-delà, la lecture s'arrête au lieu d'occuper une connexion.
      Orm::User.connection.execute("SET LOCAL statement_timeout = '60s'")
      query.new.weekly(from: Time.zone.at(0), to: now, now:)
    end

    puts "Entonnoir brut des élèves — lecture seule, comptes uniquement (#{I18n.l(now, format: '%Y-%m-%d %H:%M')})"
    puts "Réussi = exercice terminé à #{query::PASS_SCORE} % ou plus (10/20) ; réussi ≥ n : exercices distincts. Comptes non anonymisés."
    next puts("Aucun élève inscrit.") if rows.empty?

    labels = { "standard" => "standard", "link" => "link", "code" => "code", "none" => "sans classe" }
    line = ->(head, channel, steps) { puts format("%-11s %-12s%s", head, channel, steps.to_a.map { format("%10d", it) }.join) }
    puts format("%-11s %-12s%s", "Semaine", "Voie", %w[Inscrits Notion Commencé Réussi≥1 Réussi≥2 Réussi≥5].map { format("%10s", it) }.join)
    rows.group_by(&:week_on).each do |week_on, week|
      line.call(week_on.iso8601, "total", week.sum(query::Steps.zero, &:steps))
      week.each { line.call("", labels.fetch(it.channel), it.steps) }
    end
    line.call("TOTAL", "total", rows.sum(query::Steps.zero, &:steps))
    query::CHANNELS.each do |channel|
      line.call("", labels.fetch(channel), rows.select { it.channel == channel }.sum(query::Steps.zero, &:steps))
    end
  end
end
