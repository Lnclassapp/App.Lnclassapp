# Memo — Parcours matière → exercice

| | |
|---|---|
| **Type de cycle** | optimisation (du parcours, en clics et en mots ; UDR obligatoire, voir « Lecture tranchée ») |
| **Statut** | livré |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `perf/parcours-matiere-exercice` |
| **Programme** | — |

---

## Le problème

Un élève qui touche une matière de sa grille pour faire un exercice passe par **4 clics et 3 écrans intermédiaires** : la matière (liste des leçons), la leçon (fiche de révision **puis** les exercices), le sujet de l'exercice, puis la feuille. Sur la page de la leçon, il lit ou fait défiler **461 mots et 1 623 px** (téléphone) avant le premier lien d'exercice : rien ne lui dit où cliquer.

## Pour qui

L'élève (Student), de la 6ème à la Tle, depuis la grille des matières de son accueil. Mesuré avec un élève de 3ème.

## Pourquoi maintenant

But du porteur : réduire le nombre de clics entre la grille des matières et un exercice. Les 60 leçons complètes de 3ème rendent le chemin long dès la première leçon.

## Lecture tranchée de « 50 mots »

La piste du porteur : « réduire le nombre de mots à 50 mots », lue par lui comme « chaque écran intermédiaire affiche 50 mots au plus ».

Le code montre une lecture plus juste : **50 mots au plus avant la cible du clic suivant, et cette cible visible sans défiler à 390 px.**

- La page de la leçon n'est pas qu'un écran de passage : c'est la **fiche de révision** (UDR-0139), un contenu à lire. La couper à 50 mots retirerait le cours. Ce qui gêne l'élève, ce n'est pas le contenu, c'est qu'il passe *avant* le chemin vers l'exercice.
- La vue d'une matière liste 10 leçons : leurs titres sont les choix, pas du bruit. Les compter comme « texte à lire » pousserait à couper des leçons.
- Ce qui fait « voir tout de suite où cliquer », c'est le nombre de mots à parcourir avant la cible, et le défilement. C'est ce que mesure `mesure_parcours.js` (`wordsBeforeTarget`, `scrollToTarget`) ; le total de mots de l'écran est relevé pour information.

## Mesure avant

Volume : 1 établissement de test (`Test — Lycée Moderne Les Cocotiers`), élève de **3ème 1** sans activité (`0131001003`, `0131001004`), 60 leçons complètes de 3ème publiées (10 en Maths), seeds `trois_etablissements.rb` puis `lecons_completes.rb`. Chemin le plus court vers un exercice de Maths. Commit `8cfaa6b`. Résultat identique sur les passages (rendu déterministe).

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Clics grille → feuille de l'exercice | 390 px et 1 280 px | **4** | **≤ 2** | `mesure_parcours.js` (`clicks`) |
| Mots avant la cible, écran matière | 390 px · 1 280 px | 8 · 18 | ≤ 50 | `wordsBeforeTarget` |
| Mots avant la cible, écran leçon | 390 px · 1 280 px | **461 · 461** | **≤ 50** | `wordsBeforeTarget` |
| Défilement avant la cible, écran leçon | 390 px · 1 280 px | **1 623 px · 1 007 px** | **0** | `scrollToTarget` |
| Mots avant la cible, sujet de l'exercice | 390 px | 344 | écran évité | `wordsBeforeTarget` |
| Mots de l'écran (information) | matière · leçon, 390 px | 54 · 545 | — | `words` |

Protocole (rejouable) : `bin/rails db:seed`, `bin/rails runner db/seeds/demo/trois_etablissements.rb`, `bin/rails runner db/seeds/demo/lecons_completes.rb`, `bin/rails s`, puis `NODE_PATH=<racine des modules globaux contenant playwright> node docs/chantiers/parcours-matiere-exercice/mesure_parcours.js http://localhost:3000 <élève de 3ème sans activité>`. Les mots : nœuds texte rendus dans `<main>` (hors `sr-only`, `hidden`, `display: none`) contenant une lettre ou un chiffre.

## Grill

1. **« Prochain exercice » dans une matière, c'est lequel ?** La session en cours la plus récente de la matière (« Reprendre ») ; sinon, après le dernier exercice terminé, le suivant non terminé dans l'ordre du programme (leçon, notion, exercice) ; sinon le premier non terminé. Tout terminé → pas de carte.
2. **Et les exercices assignés ?** La carte de l'accueil les porte déjà (UDR-0132, échéance d'abord). Les répéter dans la matière dirait deux fois la même chose (charte §1) : hors périmètre.
3. **Sauter le sujet de l'exercice, c'est permis ?** Oui : la carte de l'accueil démarre déjà la session sans passer par le sujet (`next_step/_start`). Le sujet reste à un clic depuis la liste de la leçon.
4. **Ordinateur et téléphone ont deux vues de la matière** (UDR écrans élève §3.6 bis). La carte va dans les deux, au-dessus de la recherche.
5. **Sur la page de la leçon ?** La même carte, sous l'en-tête, limitée à la leçon, avec un lien « Tous les exercices » vers `#prepare-interros`. La fiche de révision reste en place et entière.
6. **Hors ligne, chargement ?** La carte est rendue par le serveur avec la page : pas d'état de chargement propre.

## Hors périmètre

- L'exercice lui-même (sujet, feuille, résultat) et la ligne d'un exercice dans une liste (`catalog/courses/_exercise_row`) : **session parallèle**. On ne les modifie pas.
- La carte « Prochain exercice » de l'accueil et la grille des matières : inchangées.
- L'ordre des sections de la leçon (UDR-0139) et la coupe de la fiche à 150 mots.
- L'enseignant et l'équipe : rien ne change pour eux.

## Liens

- PRD : [`prd.md`](prd.md) · Plan : [`plan.md`](plan.md) · Journal : [`journal.md`](journal.md)
- UDR : UDR-0144
