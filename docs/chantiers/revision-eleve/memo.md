# Memo — Révision de l'élève (cours et fiches essentielles) aux couleurs Wave et Djamo

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

## Questions ouvertes

1. Sur la page du cours, met-on les fiches avant la leçon (plus court au téléphone) ?
2. Ajoute-t-on « Fiche suivante » en bas d'une fiche ?
3. Marque-t-on les fiches déjà lues ?
