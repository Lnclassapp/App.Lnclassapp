# Journal — Les 7 leçons de Français de Terminale (A1, A2, C, D)

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | Leçons écrites dans `tle-a1/`, déclinées dans `tle-a2/`, `tle-c/`, `tle-d/` par script : seuls `series_name` et le rang du `subtitle` changent | Mêmes intitulés dans les 4 progressions, rangs différents (oral, dissertation, résumé) | Non |
| 2026-10-31 | Aucune leçon ne cite un numéro de leçon ni ne s'appuie sur une autre leçon de Tle ; acquis de 1ère seulement | L'ordre des leçons diffère entre A et C/D | Non |
| 2026-10-31 | Aucune durée, aucun nombre de textes ni déroulement officiel de l'oral du BAC affirmé : « vérifie la consigne de ton établissement » ; « liste des textes étudiés » au lieu de « descriptif » | Règles d'épreuve ivoiriennes non vérifiables ici ; « descriptif » vient du bac français | Non (point enseignant) |
| 2026-10-31 | Le résumé ne mentionne pas de « discussion » après le résumé | Présence d'une discussion au BAC ivoirien non certaine | Non (point enseignant) |
| 2026-10-31 | Textes supports écrits pour Lnclass ; œuvres réelles en courtes références paraphrasées (auteur, titre, date), vérifiées par le relecteur | Règle du Français de 3ème (PR #373) | Non |

## Ce qui a dérapé

- **Aucune leçon n'était livrable au premier jet** : la relecture indépendante (Opus) a trouvé de 1 à 4 bloquants et de 9 à 17 mineurs par leçon. Exemples : vers annoncé alexandrin qui fait 13 syllabes (e muet de « encore » devant consonne), « rejet » qui n'en est pas un, « t » de « bat » dit prononcé, recueil de contes donné comme exemple de roman, sommaire appelé scène, résumé modèle qui recopie des phrases du texte contre son propre critère, réponses justes refusées par des `fill_blank` (« accumulation », « mais », « en revanche »), faute « s'embrasse » pour « s'embrase », scène « triste » classée tragique contre le piège de la leçon. Le contrôle mécanique n'en voit aucun.
- **Recopies entre fiche, exercice noté et « Je m'entraîne »** dans 5 leçons sur 7, malgré la consigne explicite du brief : la relecture reste la seule porte.
- **Corrigés modèles de rédigées qui ne respectent pas leurs critères** (citations, mots de comparaison, procédés nommés) : 3 leçons.
- **Les scripts de mesure des vers des rédacteurs oublient les e muets internes** : un recompte à la main par le relecteur est indispensable.

## Ce qu'on a appris sur la codebase

- Dans un exercice noté, le schéma refuse `hint` et les cases multiples (`blank`) : ils n'existent que dans `practice`.
- `valider.rb` ne contrôle pas `practice` ; le contrôle de l'entraînement (règles du test 3e) a été joué à part avec `NotionPractice.errors_for`, par `bin/rails runner`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague T7) | Aucun enseignant de Français dans le chantier ; règles d'épreuve du BAC ivoirien non accessibles ici | — (avant publication) |
| Liste des œuvres intégrales de l'établissement : aucune œuvre unique supposée | Varie selon l'établissement | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 (PR prête, fusion par l'orchestrateur) |
| **PR** | `feature/contenus-tle-francais` vers `Develop` |
| **ADR produits** | aucun |
| **UDR produits** | aucune |
