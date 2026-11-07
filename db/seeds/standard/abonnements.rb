# Abonnements du jeu standard (chantier cartes-activation, Lot B ; ADR contexte billing §4.5) : après db/seeds/standard.rb, chaque
# élève du jeu est abonné par une carte d'un lot offert (prix 0) du point relais « Lnclass — interne », jusqu'au 31 juillet 2027.
# La garde de période gratuite ne laisse sinon plus démarrer d'exercice aux comptes de recette, 7 jours après leur création.
# Passe par le vrai dépôt des cartes (CardRepository#create_batch et #activate), jamais par une écriture directe.
# Idempotent : un élève déjà abonné n'est pas retouché, les cartes remises du lot interne sont reprises avant d'en tirer d'autres.
# Les lots sont de 200 cartes au plus (contrainte de la table). Élèves du jeu : ceux que standard.rb a inscrits (joined_via « standard »).
unless Rails.env.local? || PrEnvironment.active? || DemoEnvironment.active? ||
       Entities::Catalog::AutomaticLoadStage.for(name: ENV["RAILWAY_ENVIRONMENT_NAME"], pr_environment: PrEnvironment.active?).then { it.whole_lessons? || it.create_missing? }
  raise "db/seeds/standard/abonnements.rb est réservé au développement, au test, aux environnements de PR, à Demo, à Develop et à Staging"
end

relay_name = "Lnclass — interne"
cards = Repositories::Billing::CardRepository.new
now = Time.current
relay_point = Orm::Billing::RelayPoint.find_or_create_by!(name: relay_name) do |record|
  record.location = "Équipe Lnclass"
  record.phone = "0700000000"
end

subscribed = Orm::Billing::ActivationCard.where(state: "activated").where.not(student_id: nil).select(:student_id)
joined = Orm::ClassroomStudent.joins(:classroom).where(joined_via: "standard").where.not(student_id: subscribed)
pending = joined.distinct.pluck(:student_id, "classrooms.school_id")
if pending.empty?
  puts "[abonnements] tous les élèves du jeu sont déjà abonnés"
else
  spare = Orm::Billing::ActivationCard.where(relay_point_id: relay_point.id, state: "issued", price_xof: 0).order(:serial).pluck(:id)
  missing = [ pending.size - spare.size, 0 ].max
  while missing.positive?
    quantity = [ missing, 200 ].min
    batch = cards.create_batch(relay_point_id: relay_point.id, quantity:, unit_price_xof: 0, valid_until: Entities::Billing::Offer::VALID_UNTIL,
                               created_by_id: nil, at: now)
    spare.concat(cards.cards_of_batch(batch_public_id: batch.public_id).map(&:id))
    missing -= quantity
  end
  pending.zip(spare).each do |(student_id, school_id), card_id|
    result = cards.activate(card_id:, student_id:, school_id:, at: now)
    raise "[abonnements] abonnement refusé pour l'élève #{student_id} : #{result.errors.inspect}" if result.failure?
  end
  puts "[abonnements] #{pending.size} élèves abonnés par le lot offert du point relais « #{relay_name} »"
end
