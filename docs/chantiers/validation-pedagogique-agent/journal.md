# Journal — Validateur pédagogique des leçons

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | L'étape « à faire valider par un enseignant » est supprimée ; l'agent `validateur-pedagogique` (Opus) tranche chaque point avant la PR | Décision du porteur | ADR-0135 |
| 2026-11-14 | Les points existants sont tranchés en 7 parts parallèles (Maths collège, Maths lycée, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC et Philosophie), chaque part écrivant ses décisions dans `decisions/<part>.md` | Contextes bornés, aucun fichier partagé entre deux agents | non |
| 2026-11-14 | Un point sur une leçon qui n'est que dans `a-reprendre/` est classé « Hors base » : rien ne la charge, le validateur passera à son retour | Ne pas corriger un fichier qui sera réécrit au format complet | non |
| 2026-11-14 | Les leçons « déjà publiées en production » sont, par prudence, toutes celles de `lecons-traitees/` présentes sur `origin/main` (3ème, 2nde, 1ère, Tle) : aucune trace écrite ne dit lesquelles l'équipe a publiées, et le 2026-11-12 la production montrait 3ème, 1ère et Tle | Une liste trop longue coûte une vérification ; une liste trop courte laisse une erreur en ligne | non |

## Décisions du validateur

Une table par part, une ligne par point (point, décision, justification). Bilan du 2026-11-14 : **569 points tranchés**, aucun laissé « à valider ».

| Part | Confirmé | Corrigé | Retiré ou reformulé | Hors base | Leçons corrigées |
|---|---:|---:|---:|---:|---:|
| Mathématiques, collège | 52 | 9 | 1 | 0 | 9 |
| Mathématiques, lycée | 134 | 7 | 0 | 10 | 9 |
| Physique-Chimie | 90 | 8 | 0 | 2 | 9 |
| SVT | 56 | 13 | 0 | 12 | 13 |
| Français | 49 | 12 | 0 | 6 | 12 |
| Histoire-Géographie | 45 | 9 | 1 | 1 | 8 |
| EDHC et Philosophie | 43 | 7 | 1 | 1 | 13 |
| **Total** | **469** | **65** | **3** | **32** | **73** |

Aucun calcul n'était faux (chaque calcul refait avec sympy) ; les corrections portent sur des faits, des dates, des formulations trop absolues, une règle mal énoncée ou un barème. Les 73 fichiers passent `valider.rb` sans erreur ; tests de contenu inchangés et verts (727 runs). « Hors base » : la leçon n'est que dans `a-reprendre/`, le validateur passera à son retour.

- [Mathématiques, collège](decisions/mathematiques-college.md)
- [Mathématiques, lycée](decisions/mathematiques-lycee.md)
- [Physique-Chimie](decisions/physique-chimie.md)
- [SVT](decisions/svt.md)
- [Français](decisions/francais.md)
- [Histoire-Géographie](decisions/histoire-geographie.md)
- [EDHC et Philosophie](decisions/edhc-philosophie.md)

Corrections à reporter à la main dans l'application : [`a-reporter-en-production.md`](a-reporter-en-production.md).

## À trancher

> Format : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-14 · validation-pedagogique-agent · Quelles leçons l'équipe a-t-elle réellement publiées en production ? — appliqué : toutes celles de `lecons-traitees/` présentes sur `origin/main` sont traitées comme publiées (liste Avant / Après pour chacune) ; autres : seulement 3ème, 1ère, Tle (pages publiques du 2026-11-12) ; recommandé : l'équipe ignore les lignes d'une leçon qu'elle n'a pas publiée.

## Ce qui a dérapé

- Beaucoup de points relevés en v1 décrivaient des fichiers réécrits depuis en v3 : le validateur les a tranchés sur le fichier actuel (souvent « Confirmé : le défaut a disparu »). Un point « à faire valider » vieillit plus vite que la leçon.

## Ce qu'on a appris sur la codebase

- Aucun test de `test/` ne vérifie mot pour mot le texte d'une leçon : les tests de contenu portent sur la structure et « Je m'entraîne ». Corriger un fait ne casse donc aucun test, et n'en assouplit aucun.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points des leçons de `a-reprendre/` (32 lignes « Hors base ») | Leçons hors base, réécrites avant leur retour | `base-de-lecons` |
| Figures : bandeau de longueurs des figures `geometry`, sortes « schéma électrique » et « lignes de champ » absentes | Code, pas contenu (relevé par la part Physique-Chimie) | à ouvrir |
| « Mouvement du centre d'inertie » (Tle C/D) ne traite pas le mouvement circulaire | Ajouter une notion relève de la rédaction ; rien n'y est faux | vague de rédaction suivante |
