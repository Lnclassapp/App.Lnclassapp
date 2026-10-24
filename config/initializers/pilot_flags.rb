# Drapeaux du pilote du 27 octobre (chantier mvp-teacher-student) : lus par les vues, jamais décidés par elles.
# school_space_enabled (CA-A2) : le lien et la fenêtre « Espace établissement » de la page d'accueil publique. Éteint par
# défaut, jusqu'au 2 novembre ; SCHOOL_SPACE_ENABLED=true l'allume sans déploiement de code. Seules les valeurs true, 1, on et yes l'allument ; toute autre valeur, ou aucune,
# le laisse éteint : un oubli ne l'ouvre pas. Lecture : Rails.configuration.x.pilot_flags[:school_space_enabled].
# teacher_announcements_enabled : l'enseignant rédige des annonces (« Mes annonces », le formulaire). Éteint pour le
# pilote (décision du porteur du 24 octobre) ; « Reçues » reste ouverte. TEACHER_ANNOUNCEMENTS_ENABLED=true l'allume.
pilot_flag = ->(name) { %w[true 1 on yes].include?(ENV.fetch(name, "").strip.downcase) }
Rails.application.config.x.pilot_flags = {
  school_space_enabled: pilot_flag.call("SCHOOL_SPACE_ENABLED"),
  teacher_announcements_enabled: pilot_flag.call("TEACHER_ANNOUNCEMENTS_ENABLED")
}.freeze
