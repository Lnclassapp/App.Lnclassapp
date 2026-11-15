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

## Régression de #625 : boucle de rendu, tâche `lecons` du train #626 (2026-11-14)
- **Le fait** : la tâche `lecons` de la PR #626 dépasse 5 min, deux fois (job 132623597082). Une leçon reste bloquée plus de 3 min.
- **Mesure** : `etude-d-un-dipole-actif-cas-d-une-pile-loi-de-pouillet.json` boucle ; `tle-c/philosophie/la-connaissance-scientifique.json` ne boucle pas (aucun `$`, 0 mutation). Page de la leçon chargée dans Chrome avec les vrais assets : 1 842 mutations du DOM à 0,5 s, 14 386 à 3 s, sans fin ; les 153 formules ne bougent plus.
- **Cause** : l'hypothèse « éléments `math` imbriqués » est juste, mais il lui faut un combustible que l'hypothèse ne disait pas. Une question à trous coupe sa formule par une case : `<span>Dans la loi de Pouillet, $I = \dfrac{E}{ </span><select…>`. Le texte garde un `$` seul. KaTeX le réécrit à chaque passage (mêmes caractères, nouveaux nœuds), donc à chaque passage le DOM mute. Le contrôleur de l'élément englobant et celui du `<span>` se renvoient alors ces mutations sans fin : chacun ne coupait que son observateur. Deuxième piste (`throwOnError: false`) : écartée, une erreur de syntaxe laisse un `.katex-error` sans délimiteur, qui ne se re-rend pas.
- **Correction** (`math_controller.js`) : les observateurs restent attachés ; après chaque rendu, tous les contrôleurs écartent (`takeRecords`) les mutations arrivées sous l'élément qui vient d'être rendu, qui sont les siennes. Une mutation hors de l'élément rendu reste due à son contrôleur. Turbo-frame, Turbo Stream et « Vérifier » rendent comme avant.
- **Preuve** : `math_rendering_test.rb` « des éléments math imbriqués avec un « $ » seul se posent ». Même scénario, mesuré dans Chrome : avant 49 154 mutations en 1 s et encore 98 306 à 2 s ; après 8, et 8 à 2 s. Page de Pouillet : 110 mutations, stables.

## À trancher
- « Indice » vide sur la capture : ce n'est pas un bug de code. L'indice de l'entraînement est un `<details>` replié (`_question.html.erb`) : seul le titre « Indice » se voit tant qu'on ne le touche pas ; ouvert, le texte s'affiche (et ses formules, désormais). Option prudente retenue : ne rien changer. À décider par le porteur : rendre le repli plus visible (flèche), dans le chantier simplification-ecrans-eleve.
- Leçon `etude-d-un-dipole-actif-cas-d-une-pile-loi-de-pouillet` : une formule est coupée par une case à remplir (`$I = \dfrac{E}{ [case] }$`), donc jamais rendue, brute à l'écran. Ce n'est pas un bug de code. Option prudente retenue : ne rien changer ici ; à corriger dans le dépôt des contenus (la case doit être entière dans la formule, ou hors d'elle).
