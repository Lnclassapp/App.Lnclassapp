# Parcours DRENA

Il n'existe pas de compte DRENA (décision du chantier). Le parcours est celui du compte équipe **terrain**, `0700003000`, PIN `2468` et code à six chiffres, rattaché à la DRENA Abidjan 1, sur le tableau de bord filtré par DRENA.

| # | Étape | Résultat attendu |
|---|---|---|
| 1 | `/login`, contact, PIN, code à six chiffres | Accueil équipe (`/teams`) |
| 2 | Tableau de bord (`/teams/dashboard`) | Indicateurs par période, « Par DRENA » |
| 3 | Filtrer sur la DRENA Abidjan 1 | « Par établissement » remplace « Par DRENA » ; les établissements de cette DRENA seulement (pagination et recherche côté serveur) |
| 4 | Changer de période | Les chiffres changent sans erreur ; période sans activité : zéros ou état vide |
| 5 | Ouvrir un établissement de la liste | Fiche de l'établissement |
| 6 | Croissance (`/teams/growth`) | Totaux affichés |
| 7 | Se déconnecter | Retour à l'accueil public |

**Chemin d'erreur** : filtrer sur une DRENA inconnue (adresse modifiée à la main). Résultat attendu : liste vide explicite ou retour au tableau non filtré, aucune erreur serveur.

À 390 px et sur ordinateur : les tableaux défilent dans leur cadre, la page non.
