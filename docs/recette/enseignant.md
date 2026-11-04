# Parcours enseignant

Compte : `0500000011`, PIN `2468` (mathématiques, enseigne au Lycée Modèle Horizon et au Collège Modèle Les Palmiers). Variante un seul établissement : `0500000010` (français, lycée).

| # | Étape | Résultat attendu |
|---|---|---|
| 1 | `/login`, contact et PIN | Accueil enseignant (`/teachers`) |
| 2 | Choix des classes enseignées (`/teachers/classrooms`) | Les classes des deux établissements sont proposées |
| 3 | Ouvrir la Tle D du lycée | Élèves et activité du trimestre (séances, notes, lacunes) présents ; aucun chiffre vide ni `NaN` |
| 4 | Ouvrir la fiche d'un élève | Résultats, lacunes, devoirs rendus et en retard de cet élève |
| 5 | Ouvrir un cours de la classe | La leçon publiée s'affiche comme chez l'élève |
| 6 | Suivre un devoir existant | Rendus à temps, en retard, non rendus : les trois états se distinguent |
| 7 | Créer un devoir pour la classe | Le devoir apparaît dans le suivi |
| 8 | Ouvrir une classe vide (collège, 5ème) | État vide explicite, pas d'erreur |
| 9 | Se déconnecter | Retour à l'accueil public |

**Chemin d'erreur** : ouvrir l'adresse d'une classe d'un établissement où l'enseignant n'enseigne pas (grand établissement). Résultat attendu : accès refusé ou page introuvable, aucune donnée affichée.

À 390 px et sur ordinateur : les tableaux de la classe restent lisibles (défilement interne du tableau accepté, pas de défilement de la page).
