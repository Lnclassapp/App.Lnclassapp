# Journal — Les 11 leçons de Français de Première (A, C, D)

> Rempli **pendant** le chantier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Séries A1 et A2 conservées en 1ère (une leçon A = deux fichiers, `1ere-a1/` et `1ere-a2/`, même rang) ; pas de dossier `1ere-a/` | `db/seeds/catalog.rb` déclare A1, A2, C, D ; un cours « A » ne s'importerait pas (décision de l'orchestrateur) | Non |
| 2026-11-01 | Leçons écrites une fois puis déclinées en A1, A2, C et D, « Les valeurs des temps verbaux » (C et D seulement) dans `1ere-c/` ; déclinaison par script (`series_name`, rang du `subtitle`) | Rangs différents selon la série | Non |
| 2026-11-01 | Aucune leçon ne cite un numéro de leçon ni ne s'appuie sur une autre leçon de 1ère | L'ordre diffère entre A et C/D | Non |
| 2026-11-01 | Rédaction par Sonnet (un agent par leçon, 3 au plus), relecture indépendante par Opus (un tour), corrections par l'auteur | Décision du porteur du 2026-11-01 | Non (applique ADR-0104) |
| 2026-11-01 | Aucune mention du BEPC (examen de 3ème) ; sujets « de devoir » | Trois rédacteurs sur onze l'avaient écrit | Non |

## Ce qui a dérapé

- **Aucune leçon n'était livrable au premier jet** : la relecture Opus a trouvé de 1 à 5 bloquants et de 9 à 16 mineurs par leçon. Exemples : « tour à tour » classé en focalisation zéro (c'est l'interne variable), « test de la question » à l'envers pour le présupposé, vers de 13 syllabes là où 12 étaient annoncés, « il finit » à la fois présent et passé simple, conditionnel passé et irréel du passé utilisés sans être enseignés, barèmes dont le nombre de critères ne suit pas les postes, texte de problème recopié d'un exercice noté, stéréotype xénophobe dans un exemple de généralisation hâtive. Le contrôle mécanique n'en voit aucun.
- **Recopies entre fiche, exercice noté, « Je m'entraîne » et QCM/rédigées d'un même exercice** : dans les 11 leçons, malgré la consigne du brief ; la relecture reste la seule porte.
- **Comptes de syllabes proposés par le relecteur parfois faux** (« palmier », « cahin-caha ») : les auteurs ont recompté à la main, ce qui a évité deux erreurs.
- **Générateurs du scratchpad écrasés** par un agent concurrent (dossier commun) : les correctifs ont été appliqués directement aux JSON.

## Ce qu'on a appris sur la codebase

- Un `fill_blank` accepte 5 réponses au plus ; `hint` et cases multiples n'existent que dans `practice`.
- `valider.rb` ne contrôle pas `practice` : `practice_check.rb` (règles du test 3e, par `bin/rails runner`) a été joué sur les 40 fichiers.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague P8) — **soldé le 2026-11-14 par le validateur pédagogique** ([`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur)) | Aucun enseignant de Français dans le chantier ; programme détaillé de 1ère non accessible | — (avant publication) |
| Une seule tournée de relecture : les corrections n'ont pas été relues une seconde fois | Règle du lot : un seul tour | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-01 (PR prête, fusion par l'orchestrateur) |
| **PR** | `feature/contenus-1ere-francais` vers `Develop` |
| **ADR produits** | aucun |
| **UDR produits** | aucune |
