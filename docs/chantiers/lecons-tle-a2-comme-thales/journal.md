# Journal — Les leçons de Terminale A2 préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | Les 28 leçons dont la fiche est identique à celle de Tle A1 reprennent tels quels les ajouts de Tle A1 (relus en Tle A1, ou repris de Tle C), recontrôlés par le script sur le fichier de Tle A2 | Décision 6 de #484 : une fiche commune n'est traitée qu'une fois | Non |
| 2026-11-08 | Exponentielle et logarithme, dont la fiche de A2 ne diffère de celle de A1 que par l'absence de primitive, reprennent les ajouts de A1 après une relecture ciblée sur le programme de A2 | Seule la définition de ln et une question de l'exercice d'application changent | Non |
| 2026-11-08 | « Probabilité », propre à la Tle A2, est rédigée, prouvée et relue comme en Tle A1 | Fiche différente de « Probabilité et variable aléatoire » de A1 (pas de variable aléatoire en A2) | Non |
| 2026-11-08 | Le jeu standard charge une leçon de Tle A2 par matière (manifeste : 24 couples) | `StandardTestSet` exige une ligne par couple qui a du v3 | Non |

## Leçons reprises de Tle A1 (30, non réécrites)

Ajouts repris du chantier [`lecons-tle-a1-comme-thales`](../lecons-tle-a1-comme-thales/journal.md), même script, 0 erreur sur chaque fichier de Tle A2 :

- **Français** (7) : les 6 leçons communes à toutes les Terminales et « Œuvre poétique » (rédigée en Tle A1).
- **Philosophie** (10) : les 9 leçons communes et « L'histoire et l'humanité » (rédigée en Tle A1).
- **Mathématiques** (6) : étude de fonctions polynômes et rationnelles, statistique à deux variables, suites numériques, systèmes d'équations linéaires ; fonction exponentielle et fonction logarithme après relecture pour A2 (241 questions relues, aucune à retirer).
- **SVT** (7) : les 7 leçons.

## Ce qui a dérapé

- **Preuve circulaire** (probabilité) : le rédacteur avait fait importer à `proof.py` les valeurs de son propre générateur, si bien que la preuve comparait le JSON à lui-même. Le relecteur a réécrit les 110 preuves par énumération à partir de l'énoncé. Un balayage des autres `proof.py` (Tle A1 et A2) ne trouve aucun autre import de générateur.
- **Question ambiguë** (probabilité, S3.E1.Q4) : « les deux couples d'événements incompatibles » alors qu'un troisième, non proposé, l'est aussi. Reformulée.

## Ce qu'on a appris sur la codebase

- Rien de neuf : `valider.rb` ne contrôle toujours pas les `subjects`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Le chantier ne touche que du contenu | À ouvrir |

## À trancher

> **Tranché le 2026-11-14** par le validateur pédagogique (chantier [`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur), ADR-XXXX-validateur-pedagogique-agent). Chaque point ci-dessous a sa décision (Confirmé, Corrigé, Retiré ou reformulé, Hors base) et sa justification dans la table de sa matière. Plus aucun point n'attend d'enseignant.

- **Course entre les tests du jeu standard et les dossiers `zz-preuve-test-*`** : déjà notée en Tle A1. En Tle A1, elle a aussi touché `standard_manifest_test` (fichier `zz-preuve-test-*/…/cassee.json` lu puis supprimé pendant le test). Option prudente appliquée : relancer seul. Option possible : un chantier qui isole ces tests.
- **Limite composée en logarithme** (S4.E3.Q6) : la limite de ln(6 − 2x) quand x tend vers 3 par la gauche se ramène à la limite de ln en 0⁺ de la fiche, mais la fiche ne parle pas de composition de limites. Option prudente appliquée : laissée, l'explication fait le pas. Option possible : la remplacer par une question de variations.
- **Lectures graphiques sans tolérance**, **valeurs illustratives**, **textes d'appui de l'oral**, **poèmes écrits pour Lnclass** : comme en Tle A1.

## Avancement

### Leçon propre à la Tle A2

Preuve : énumération en Python (dés, pièces, arbres, populations) à partir de l'énoncé ; chaque réponse faussée exprès est détectée. Aucune figure ajoutée. Relecture indépendante.

| Leçon | Questions | Vérifications | Réponses faussées détectées | Défauts de fond corrigés (rédaction + relecture) |
|---|---:|---:|---:|---:|
| Maths — Probabilité | 110 | 4 019 | 110/110 | 0 + 1 |
