# Memo — Leçons v3 en défaut d'affichage

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | décision |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `fix/lecons-defauts-affichage` |
| **Programme** | — |

---

## Symptôme

Le test d'affichage des leçons v3 (`test/system/catalog/lesson_rendering_test.rb`, chantier `standard-de-test`, Lot D) trouve
41 leçons sur 417 en défaut (liste : journal de `standard-de-test`, « Fichiers en défaut ») :

- **27 `**` visibles** : l'élève lit « Elle s'exprime en \*\*joules\*\* (J) » au lieu de « joules » en gras (vu à l'écran, 390 px et ordinateur).
- **15 débordements** : à 390 px, la page de la leçon défile sur le côté (scrollWidth 393 à 795 px pour 390).
- **1 figure** : « organisation-juridictions » (3ème EDHC) ne s'affiche pas, seule sa description reste.

## Comportement attendu (sources)

- `**gras**` rendu en gras dans la fiche : ADR-0116 §4.5, UDR-0137, UDR-0141 (`Catalog::SheetTextHelper`).
- `$$…$$` reconnu comme formule centrée : `math_controller.js` (délimiteurs `$$` et `$`).
- Page de cours sans défilement horizontal à 390 px : UDR-0013 ; « une formule trop large défile dans son propre cadre, jamais la page » (chantier `rendu-lecons-v3-390`).
- Une figure du fichier est dessinée : contrat des figures paramétrées (ADR-0116).

## Reproduction

Élève de la classe de la leçon, page `course_path(slug)` après import et publication (chaîne réelle), à 390 × 844 puis 1400 px :
`LECONS=<fichier> bin/rails test test/system/catalog/lesson_rendering_test.rb` (branche `feature/standard-de-test-lot-d`).
Reproduit à la main dans le navigateur de test : captures à 390 px montrant les `**` et le défilement (non commitées).

## Portée

- Depuis l'import de ces leçons ; tous les élèves des classes concernées (1ère A/C/D, 3ème, Tle A/C/D).
- Multi-appartenance : sans objet (rendu de contenu, identique pour tout lecteur).
- Données corrompues : **non**. Le texte stocké est juste ; seul le rendu est faux (Lots A, B). La figure EDHC se corrige dans le JSON et se réimporte.

## Hors périmètre

- Le validateur (`valider.rb`) ne simule pas la hauteur d'un schéma : dette notée au journal, chantier de suivi.
- Toute autre retouche de leçon remarquée en passant : journal.
- Le test d'affichage lui-même (piloté par `standard-de-test`).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les `**` sont-ils mal fermés dans le JSON ? | Non : 2 144 chaînes avec `**`, toutes appariées. Une simulation de `sheet_text` sur les 417 leçons désigne exactement les 27 fichiers, aucun de plus | Cause applicative, 0 fichier de leçon à toucher |
| Faux positif (MathML caché, rendu KaTeX asynchrone) ? | Non : `**` visibles à la capture ; débordement inchangé après 1,5 s d'attente et avec `.katex-mathml` masqué | Vrais défauts |
| Les formules chimiques débordent-elles elles-mêmes ? | Non : celles de la fiche défilent déjà dans leur cadre. Ce qui élargit la page est le bloc exercice (`ps-*`) : propositions de QCM, tableau d'association, tableau de données | Cause applicative (CSS du bloc exercice) |
| La figure EDHC est-elle mal rendue par l'application ? | Non : `diagram.js` lève « schéma trop haut » (arbre de 5 niveaux, libellés de 4 lignes) : limite documentée du schéma | Cause de contenu, 1 JSON |

## Questions encore ouvertes

- Aucune.
