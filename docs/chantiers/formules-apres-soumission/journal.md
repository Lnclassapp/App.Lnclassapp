# Journal — formules-apres-soumission

## Décisions
| Date | Décision | Pourquoi |
|---|---|---|
| 2026-11-14 | Correctif dans `math_controller`, pas dans chaque vue | Tout frame ou stream sous un élément `math` avait le même défaut |
| 2026-11-14 | L'observateur se déconnecte pendant le rendu | Évite la boucle, et le sélecteur `.katex` ne doit pas entrer dans le bundle commun (test d'architecture) |

## Trou de test comblé
Rendu KaTeX après une mise à jour Turbo : `practice_in_sheet_test.rb` (parcours complet à 390 px) et `math_rendering_test.rb` (contenu injecté sous un élément déjà connecté).

## « valeur d'exercice » (artefact de rédaction, à corriger dans le dépôt des contenus)
Recherche dans `docs/contenus/lecons-traitees/` : 3 leçons.
- `2nde-c/mathematiques/vecteurs-et-points-du-plan.json` (1 occurrence)
- `2nde-c/svt/l-influence-des-sels-mineraux-sur-la-croissance-de-la-plante-verte.json` (2)
- `1ere/histoire-geographie/geographie-la-croissance-demographique-mondiale-et-ses-consequences.json` (plusieurs)

## À trancher
- « Indice » vide sur la capture : ce n'est pas un bug de code. L'indice de l'entraînement est un `<details>` replié (`_question.html.erb`) : seul le titre « Indice » se voit tant qu'on ne le touche pas ; ouvert, le texte s'affiche (et ses formules, désormais). Option prudente retenue : ne rien changer. À décider par le porteur : rendre le repli plus visible (flèche), dans le chantier simplification-ecrans-eleve.
