# Entonnoir des classes, de l'enseignant aux élèves : `bin/rails entonnoir:classes` (chantier acquisition-classes, lot A).
# Exécutable en production : une transaction READ ONLY (PostgreSQL refuse toute écriture), et des comptes seulement,
# ni nom, ni numéro, ni identifiant. Définitions : docs/chantiers/acquisition-classes/prd.md §3 ; ADR « adoption par les classes ».
namespace :entonnoir do
  desc "Imprime l'entonnoir enseignant → classe → élèves, les écoles du CRM et le goulot désigné (lecture seule, comptes uniquement)"
  task classes: :environment do
    now = Time.current
    data = Orm::User.transaction do
      Orm::User.connection.execute("SET TRANSACTION READ ONLY")
      # Borne la charge sur la base de production : au-delà, la lecture s'arrête au lieu d'occuper une connexion.
      Orm::User.connection.execute("SET LOCAL statement_timeout = '60s'")
      Queries::Classroom::ClassAdoptionQuery.new.call(today: now.to_date)
    end
    query = Queries::Classroom::ClassAdoptionQuery
    bottlenecks = {
      teachers: [ "1", "trop peu d'enseignants inscrits" ],
      awareness: [ "4", "les établissements ne sont pas encore joints" ],
      no_open_class: [ "2a", "établissements sans classe ouverte" ],
      no_class_ticked: [ "2a′", "enseignants qui ne cochent pas de classe" ],
      code_not_shared: [ "2b", "code de classe pas donné aux élèves" ],
      code_ignored: [ "3", "code donné, élèves absents" ],
      none: [ "aucun", "aucun seuil franchi" ]
    }
    stages = { "prospect" => "prospect", "demo_done" => "démo faite", "subscribed" => "abonné", "lost" => "perdu" }
    channels = { "standard" => "standard", "colleague" => "collègue", "direction" => "direction", "team" => "équipe", "code" => "code" }
    counts = ->(row) { %i[e1 e2 e3 e4 e5 e6 blocked].map { format("%8d", row.public_send(it)) }.join }
    line = ->(label, row) { puts format("%-12s%s", label, counts.call(row)) }
    voies = ->(split) { split.empty? ? "aucun élève" : query::STUDENT_CHANNELS.select { split.key?(it) }.map { "#{it} #{split.fetch(it)}" }.join(" · ") }

    puts "Entonnoir des classes — lecture seule, comptes uniquement (#{I18n.l(now, format: '%Y-%m-%d %H:%M')})"
    puts "Année en cours : #{Entities::Classroom::SchoolYear.current(now.to_date)}. Comptes non anonymisés."
    puts
    puts "1. Enseignants — E1 inscrit · E2 établissement avec classe ouverte · E3 classe cochée · E4 classe peuplée · E5 devoir donné · E6 classe adoptée (5 élèves ont commencé un exercice) · bloqués = E1 − E2"
    if data.total.e1.zero?
      puts "Aucun enseignant inscrit."
    else
      puts format("%-12s%s", "", %w[E1 E2 E3 E4 E5 E6 Bloqués].map { format("%8s", it) }.join)
      line.call("total", data.total)
      channels.each { |channel, label| line.call("  #{label}", data.by_channel.fetch(channel)) }
      puts "Par mois d'inscription"
      data.by_month.each { |month, row| line.call(month, row) }
      puts
      puts "2. Indice des classes cochées vides (E3 sans E4) — classe vide avec devoir : #{data.empty_with_assignment} · sans devoir : #{data.empty_without_assignment}"
    end
    puts
    puts "3. Élèves des classes ouvertes, par voie d'arrivée"
    puts "avec enseignant : #{voies.call(data.students.fetch('with_teacher'))}"
    puts "sans enseignant : #{voies.call(data.students.fetch('without_teacher'))}"
    median = data.median_students
    puts "Médiane d'élèves par classe cochée et peuplée : #{median ? format('%.1f', median).tr('.', ',') : 'aucune classe peuplée'}"
    puts
    puts "4. Écoles du CRM par étape saisie (sans ligne : prospect) — établissements actifs"
    puts format("%-12s%s", "", [ "Établ.", "Échange", "Enseign.", "Cl. ouv.", "Cl. peupl." ].map { format("%11s", it) }.join)
    data.crm_stages.each do |row|
      puts format("%-12s%s", stages.fetch(row.stage), row.to_h.values.drop(1).map { format("%11d", it) }.join)
    end
    puts "Échanges notés sur #{query::INTERACTION_DAYS} jours : #{data.crm_interactions_30d}"
    puts
    code, label = bottlenecks.fetch(Entities::Classroom::AdoptionVerdict.call(**data.verdict_counters))
    puts "Goulot désigné : #{code} (#{label})"
    puts
    puts "Limites :"
    puts "- le partage d'un code n'est pas enregistré : 2b et 3 ne se distinguent que par l'indice ;"
    puts "- une déclaration de classe retirée est effacée ;"
    puts "- une ré-adhésion écrase la voie ;"
    puts "- le code appartient à la classe, pas à l'enseignant."
  end
end
