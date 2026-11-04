# Parcours élève

Compte : `0100000166`, PIN `2468` (Tle D du Lycée Modèle Horizon, la classe qui a de l'activité). Variante élève sans activité : un élève de la Tle A1 du lycée (`eleve_sans_activite` de `jeu.yml` ; `bin/jeu-standard` en donne la liste).

| # | Étape | Résultat attendu |
|---|---|---|
| 1 | `/login`, contact et PIN | Accueil élève (`/students`), sans message d'erreur |
| 2 | Lire l'accueil | Prochain exercice ou devoir proposé ; le nom de la classe est celui du compte ; aucun texte de gabarit (`translation missing`) |
| 3 | Ouvrir la classe (`/students/classroom`) | Matières et devoirs de la Tle D ; devoirs rendus, en retard et à faire se distinguent |
| 4 | Ouvrir un cours publié d'une matière | La leçon s'affiche : titre, fiche de révision, formules rendues, figures visibles, aucun `**` brut |
| 5 | Lancer un exercice, répondre, terminer | Le résultat de la séance s'affiche avec la correction ; retour à la classe possible |
| 6 | Menu du compte (`/students/menu`) | Nom, classe, déconnexion présents |
| 7 | Se déconnecter | Retour à l'accueil public |

À 390 px et sur ordinateur : aucun défilement horizontal de la page ; la leçon (étape 4) se lit en entier, les formules ne débordent pas.

**Chemin d'erreur** : se connecter avec un mauvais PIN. Résultat attendu : message d'erreur clair, pas de connexion.

Archive (`/students/archive`) : seulement si le chantier touche le changement de classe.
