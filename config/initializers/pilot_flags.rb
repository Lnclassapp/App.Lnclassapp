# Drapeaux du pilote du 27 octobre (chantier mvp-teacher-student) : lus par les vues, jamais décidés par elles.
# school_space_enabled (CA-A2) : le lien et la fenêtre « Espace établissement » de la page d'accueil publique. Éteint par
# défaut, jusqu'au 2 novembre ; SCHOOL_SPACE_ENABLED=true l'allume sans déploiement de code. Seules les valeurs true, 1, on et yes l'allument ; toute autre valeur, ou aucune,
# le laisse éteint : un oubli ne l'ouvre pas. Lecture : Rails.configuration.x.pilot_flags[:school_space_enabled].
Rails.application.config.x.pilot_flags = {
  school_space_enabled: %w[true 1 on yes].include?(ENV.fetch("SCHOOL_SPACE_ENABLED", "").strip.downcase)
}.freeze
