# Memo — Révision de l'élève (fiche de révision) aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

L'élève révise sur la page d'un cours (`catalog/courses#show`) et sur la page d'une fiche essentielle (`catalog/essentials#show`). Ces pages fonctionnent mais ne ressemblent pas encore aux écrans élève redessinés (`accueil-eleve`, `cours-eleve`, `ma-classe-eleve`, `exercice-eleve`).

## Pour qui

L'élève (Student), le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Hors périmètre

- Les vues enseignant et équipe du cours et de la fiche (actions de rôle, fiche dans la classe, compréhension).
- L'éditeur de contenu (Action Text) et le rendu KaTeX : seule la mise en forme du contenu affiché change.

## Point de départ : les pages actuelles

Relevées dans le code le 2026-10-15 (UDR-0013, UDR-0015, UDR-0057) :
- **Cours** : lien « Cours », en-tête (nom, sous-titre, matière, niveau), contenu riche, « Essentielles de la leçon » (nom, sous-titre, chevron ; 3 puis « Voir plus »).
- **Fiche essentielle** : lien vers le cours, en-tête, contenu riche ; bloc « Fiche essentielle à revoir » (règle du seuil, date, « Refaire un exercice ») ; « Exercices » avec Reprendre, Refaire ou Commencer et « Assigné par ton enseignant ».
- Pas de « Fiche suivante », pas de marque « lue ».

## Maquettes

Toile : https://claude.ai/artifact/2GWogAXzCziL8dR3FqcdGt (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page après le parcours d'exercice ? | La page de révision (porteur, 2026-10-15). | Le chantier couvre la page du cours et la page de la fiche essentielle. |
| Les fiches essentielles restent-elles telles quelles ? | Non : elles deviennent les « fiches de révision », et leur contenu est découpé en rubriques (porteur, 2026-10-15). | On applique les décisions du chantier `contenu-en-blocs` : une fiche de révision par leçon avec un sommaire, les fiches essentielles en deviennent les parties ; rubriques Tu dois savoir, À retenir, En clair (à masquer), Méthode, Exemple rédigé, Attention, Tableau, Document, Figure ; lexique en bulle et en bas de fiche, sources ; fond Seyès, écriture manuscrite, une couleur par rubrique ; exercices par partie (Comprendre, Appliquer, S'évaluer). La page du cours devient la fiche de révision. Accueil : « Fiches de révision à revoir » ; résultat d'exercice : « Relis ta fiche de révision ». |

## Questions ouvertes

1. Le contenu libre actuel de la leçon disparaît-il au profit des parties ?
2. Le sommaire reste-t-il visible en défilant (en haut au téléphone, à droite sur ordinateur) ?
3. Conflit avec `contenu-en-blocs` : il excluait « remettre dans l'ordre » et faisait trous et relier avec des choix uniques ; `exercice-eleve` vient d'ajouter les quatre types (porteur, 2026-10-15). À aligner dans `contenu-en-blocs`.
