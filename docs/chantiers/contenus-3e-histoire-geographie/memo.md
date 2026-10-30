# Memo — Leçons de 3ème en Histoire-Géographie, et leurs figures (frise, carte, schéma, courbe)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-histoire-geographie` |
| **Programme** | `contenus-3e-autres-matieres` (vague 2) |

---

## Le problème

Un élève de 3ème n'a aucune leçon d'Histoire-Géographie à réviser au format en vigueur : les 10 premières leçons de la progression nationale sont des fiches vides, et les 3 anciennes leçons rédigées sont dans un format retiré. Une leçon d'histoire-géographie sans frise ni carte ne s'apprend pas : or aucune figure actuelle ne dessine une frise, une carte, un schéma fléché ou une courbe d'évolution.

## Pour qui

- **Student** de 3ème, qui révise avant une interrogation, un devoir ou le BEPC.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

La vague 1 (Français) part sans code ; l'Histoire-Géographie est la première matière qui a besoin de figures nouvelles, et ses sortes (schéma, carte de Côte d'Ivoire) servent ensuite à l'EDHC (vague 5).

## Hors périmètre

- Les sortes `plate`, `optics`, `molecule` (vagues 3 et 4) : pas dans `FigureKinds` à cette vague.
- Les leçons d'HG au-delà des 10 premières, et les autres niveaux.
- Toute vue nouvelle : les figures passent par le partial et le contrôleur existants (UDR des figures de 3ème).
- La modification de `valider.rb` et des prompts de rédaction tant que la PR de la vague 1 n'est pas fusionnée dans `Develop`.
- L'import, la relecture et la publication des leçons : faits par l'équipe dans l'application.

## Ce que le grill a révélé

Cadrage fait au niveau du programme (memo et feuille de route du programme, ADR et UDR acceptés). Grill court, sur ce qui reste propre à la vague.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le script de contrôle peut-il valider les cartes sans être modifié pendant que la vague 1 le change ? | Oui, si la figure charge elle-même ses listes fermées. | Le domaine des figures charge lui-même les listes des fonds ; le script n'est pas touché à cette vague. |
| Les zones naturelles de Côte d'Ivoire (forêt, savane, littoral, montagnes) n'existent dans aucune base publique : comment les tracer ? | Par des contours simplifiés écrits dans le script de fabrication, découpés sur le contour du pays. | Le tracé des zones est schématique et le dit : la carte nomme les grandes zones, elle ne délimite pas au kilomètre. |
| Natural Earth n'a pas les 14 districts ivoiriens (il a les 19 anciennes régions). | La décision prévoit geoBoundaries (CC BY 4.0) dans ce cas. | Le fond de Côte d'Ivoire vient de geoBoundaries, avec la ligne d'attribution sous la carte. |
| Un fond de carte se charge à la demande : le module de la carte ne peut pas dessiner au moment où il est créé. | Le contrôleur attend la création de la figure. | Le socle rend la création des figures asynchrone, sans changer les sortes existantes. |
| Les questions rédigées ne passent le script qu'après la vague 1. | Les leçons utilisent des types à choix tant que la vague 1 n'est pas fusionnée. | Toutes les questions des 10 leçons sont corrigées automatiquement si la vague 1 n'est pas fusionnée à la rédaction. |
| Génocide des Tutsi, crises : quel vocabulaire ? | Celui de la progression nationale et des sources reconnues (ONU), neutre. | Relecture IA indépendante dédiée aux faits, aux dates et aux chiffres. |

## Cas limites identifiés

- Un lieu ou une aire absents du fond : refus `figure_invalid`, jamais dessinés « à peu près ».
- Une frise zoomée par curseur : les événements hors de la fenêtre ne sont pas dessinés.
- Des étiquettes de carte qui se chevauchent à 390 px : remplacées par des numéros renvoyés dans la légende.
- Un schéma en arbre à deux racines, ou avec un cycle : refusé.
- Un fond de carte qui ne charge pas : la description reste affichée.

## Questions encore ouvertes

- Aucune.
