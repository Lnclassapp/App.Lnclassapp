# Journal — Validateur pédagogique des leçons

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | L'étape « à faire valider par un enseignant » est supprimée ; l'agent `validateur-pedagogique` (Opus) tranche chaque point avant la PR | Décision du porteur | ADR-XXXX-validateur-pedagogique-agent |
| 2026-11-14 | Les points existants sont tranchés en 7 parts parallèles (Maths collège, Maths lycée, Physique-Chimie, SVT, Français, Histoire-Géographie, EDHC et Philosophie), chaque part écrivant ses décisions dans `decisions/<part>.md` | Contextes bornés, aucun fichier partagé entre deux agents | non |
| 2026-11-14 | Un point sur une leçon qui n'est que dans `a-reprendre/` est classé « Hors base » : rien ne la charge, le validateur passera à son retour | Ne pas corriger un fichier qui sera réécrit au format complet | non |
| 2026-11-14 | Les leçons « déjà publiées en production » sont, par prudence, toutes celles de `lecons-traitees/` présentes sur `origin/main` (3ème, 2nde, 1ère, Tle) : aucune trace écrite ne dit lesquelles l'équipe a publiées, et le 2026-11-12 la production montrait 3ème, 1ère et Tle | Une liste trop longue coûte une vérification ; une liste trop courte laisse une erreur en ligne | non |

## Décisions du validateur

Une table par part, une ligne par point (point, décision, justification) :

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

- …

## Ce qu'on a appris sur la codebase

- …

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points des leçons de `a-reprendre/` | Leçons hors base, réécrites avant leur retour | `base-de-lecons` |
