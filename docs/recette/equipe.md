# Parcours équipe

Compte : `0700001000` (admin), PIN `2468` et code à six chiffres ; `0700002000` (contenu) pour les imports. En développement, `bin/jeu-standard` affiche le secret TOTP et le code actuel.

| # | Étape | Résultat attendu |
|---|---|---|
| 1 | `/login`, contact, PIN, code à six chiffres | Accueil équipe (`/teams`) |
| 2 | Référentiel (`/teams/referential`) | Niveaux, séries, matières, plan des classes cohérents avec le jeu |
| 3 | Liste des établissements | Les trois établissements du jeu, avec leur DRENA |
| 4 | Ouvrir le Lycée Modèle Horizon | Classes, personnel, code d'établissement |
| 5 | Recherche de compte (`/teams/accounts`) | Un compte du jeu (ex. `0500000011`) est trouvé |
| 6 | Imports (`/teams/imports`), avec `0700002000` | Un fichier de leçon invalide est refusé avec ses erreurs ; la liste des cours montre ceux du jeu |
| 7 | Tableau de bord | Voir le parcours [DRENA](drena.md) pour le filtre |
| 8 | Se déconnecter | Retour à l'accueil public |

**Chemin d'erreur** : se connecter avec un mauvais code à six chiffres. Résultat attendu : refus, pas d'accès à `/teams`.

À 390 px et sur ordinateur : les formulaires d'administration restent utilisables, aucun défilement horizontal de la page.
