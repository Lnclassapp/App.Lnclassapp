# ADR-0114 : Le JavaScript commun passe de 60 à 61 Ko gzip
<!-- index
titre: Budget du JavaScript commun relevé à 61 Ko gzip
statut: Accepté — *amende [0051](./0051-navigateurs-supportes-et-budget-de-poids.md) (plafond du JS commun)*
problematique: La fiche de révision (Lot A de refonte-page-lecon) fait dépasser le point d'entrée commun de 22 octets, même chargée à la demande ; le plafond passe à 61 Ko.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/refonte-page-lecon` |
| **Remplace** | — *(amende le seul plafond du JS commun de l'ADR-0051)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0051 plafonne le point d'entrée commun (`app/assets/builds/application.js`) à 60 Ko gzip, vérifié par `test/javascript_bundle_test.rb`, et dit que relever ce plafond exige un nouvel ADR.

Le 2026-10-28, une fois le Lot C de `refonte-page-lecon` fusionné (copie à rendre, déjà passée en chargement à la demande pour tenir le budget), le Lot A (« Voir plus » de la fiche de révision, `catalog--revision-more`) porte le point d'entrée à **60,33 Ko**. Charger la logique de ce contrôleur à la demande, sur le modèle de `assessment--copy`, ne descend qu'à **60,02 Ko** : la coquille Stimulus et son `import()` coûtent presque autant que ce qu'ils retirent.

## 2. Moteurs de décision

- Livrer la fiche de révision sans dégrader son comportement sans JavaScript (UDR-0139 §2).
- Ne pas casser un contrôleur relu et testé pour gagner 22 octets.
- Garder un plafond bloquant en CI, avec une marge connue.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder 60 Ko et retirer ~25 octets ailleurs dans le JS commun | Le plafond ne bouge pas | Hors du champ du lot, pour un gain sans effet pour l'élève ; le prochain ajout retombe sur le même mur |
| B — Charger « Voir plus » à la demande | Patron déjà utilisé (`assessment--copy`) | Insuffisant (60,02 Ko) |
| C — Relever le plafond à 61 Ko | +1,7 % ; le contrôleur reste tel quel | Retenue |

## 4. Décision

> **Le point d'entrée commun est plafonné à 61 Ko gzip (au lieu de 60). Le reste de l'ADR-0051 tient : plafond CSS de 30 Ko, Trix, KaTeX, confetti, images et copie chargés à la demande, plafond bloquant en CI.**

Décision du porteur, 2026-10-28.

## 5. Conséquences

### 🟢 Positives
- Le Lot A fusionne avec son contrôleur relu, sans chargement différé.

### 🔴 Coûts consentis
- Environ 1 Ko de plus à télécharger à chaque première visite.
- La marge reste étroite : tout nouveau JavaScript commun envisage d'abord le chargement à la demande. Le retrait du code mort prévu au Lot E de `refonte-page-lecon` peut redonner de la marge.

## 6. Notes d'implémentation

`test/javascript_bundle_test.rb` : `BUDGET_KB = 61`.

## 7. Comment vérifier que la décision est respectée

`bin/rails test test/javascript_bundle_test.rb` (étape « Tests: Rails » de `bin/ci`) échoue au-delà de 61 Ko gzip.
