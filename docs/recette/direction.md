# Parcours direction

Compte : `0700000010`, PIN `2468` (Lycée Modèle Horizon, public, 6ème à Tle, séries A et C). Variantes : `0700000011` (collège privé, 5ème vide), `0700000012` (grand établissement mixte, 1 500 élèves, sans activité).

| # | Étape | Résultat attendu |
|---|---|---|
| 1 | `/login`, contact et PIN | Accueil de l'espace direction (`/school-admin`) |
| 2 | Lire l'accueil | Établissement, niveaux, effectifs ; activité récente chargée avec les séances du trimestre |
| 3 | Ouvrir un niveau (ex. Tle) | Classes du niveau, séries A et C distinguées |
| 4 | Ouvrir la Tle D | Élèves, enseignants de la classe, indicateurs |
| 5 | Chercher un élève par son nom | Résultat limité à cet établissement |
| 6 | Liste des enseignants | `0500000011` apparaît avec ses classes du lycée |
| 7 | Avec `0700000011` : ouvrir la 5ème | Classe vide : état vide explicite |
| 8 | Avec `0700000012` : parcourir niveaux et classes | Pages rapides malgré 1 500 élèves ; pagination ou recherche, pas de liste interminable |
| 9 | Se déconnecter | Retour à l'accueil public |

**Chemin d'erreur** : ouvrir l'adresse d'une classe d'un autre établissement. Résultat attendu : refus ou page introuvable ; la direction ne voit que son établissement.

À 390 px et sur ordinateur : aucun défilement horizontal de la page.
