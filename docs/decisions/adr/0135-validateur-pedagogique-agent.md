# ADR-0135 : Un agent validateur pédagogique tranche, avant la PR, ce qu'on laissait à un enseignant
<!-- index
titre: Validateur pédagogique des leçons
statut: Accepté
problematique: Les points de fond des leçons (faits, programme, niveau, barème, figures) étaient renvoyés « à faire valider par un enseignant », et aucun enseignant ne les relisait : des centaines de points restaient ouverts et les leçons en brouillon. Un agent Opus, jamais auteur ni relecteur de la leçon, tranche chaque point dans le processus, avant la PR.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-14 |
| **Chantier** | [`docs/chantiers/validation-pedagogique-agent`](../../chantiers/validation-pedagogique-agent/memo.md) |
| **Remplace** | — *(amende l'étape « Validation par l'équipe… un enseignant relit » du pipeline des contenus, [`docs/contenus/README.md`](../../contenus/README.md), et complète [ADR-0104](0104-routage-des-modeles-par-role.md))* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le pipeline d'une leçon finissait par « import en brouillon → validation par l'équipe → publication », et pour le pilote de 3ème « un enseignant de mathématiques relit avant publication ». Chaque rédacteur et chaque relecteur IA renvoyait donc ce qu'il ne pouvait pas trancher dans une liste « À faire valider par un enseignant » : rattachement d'une notion au programme, date ou chiffre, niveau d'un problème, barème, planche.

Aucun enseignant ne relit. Au 2026-11-14, ces listes couvraient une trentaine de journaux de chantier et plus de 400 lignes, et le README des contenus répétait « Aucun enseignant ne les a relues » sous chaque niveau. Les points restaient ouverts indéfiniment, alors que la plupart se tranchent avec une source, un calcul ou la progression DPFC 2026-2027 déjà dans le dépôt.

Le porteur a décidé, le 2026-11-14, de supprimer l'étape et de la remplacer par un agent qui tranche ces points dans le processus, avant la PR.

## 2. Moteurs de décision

1. **Aucun point ne reste ouvert** : une leçon livrée n'a rien « à valider ».
2. **Exactitude** : une erreur de fait ou de calcul arrive devant l'élève ; dans le doute, on retire plutôt que d'affirmer.
3. **Indépendance** : celui qui tranche n'a ni écrit ni relu la leçon.
4. **Trace** : chaque décision est justifiée (source, calcul, raison) et lisible au journal.
5. **Coût** : une étape de plus par leçon, bornée.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Garder la relecture enseignante | Un regard métier humain | Personne ne la fait : les points restent ouverts, les leçons en brouillon |
| B — Laisser le relecteur IA trancher lui-même | Pas d'étape de plus | Le relecteur relève les défauts sans réécrire ; il a hésité sur ces points, il ne peut pas être celui qui les tranche |
| C — **Agent `validateur-pedagogique` (Opus), après le relecteur, avant la PR** | Indépendant, outillé (sympy, sources, progression), trace au journal, retire ce qui reste incertain | Une étape de plus ; un agent peut se tromper, d'où la règle « retirer plutôt qu'affirmer » |

## 4. Décision

**Option C.** Le pipeline d'une leçon devient :

**rédaction → `valider.rb` → relecture IA indépendante → validateur pédagogique (agent) → `valider.rb` → PR → import → publication.**

1. **Rôle.** L'agent [`.claude/agents/validateur-pedagogique.md`](../../../.claude/agents/validateur-pedagogique.md) reprend chaque point qu'un rédacteur ou un relecteur aurait renvoyé à un enseignant : exactitude d'un fait, d'une date, d'un chiffre ; rattachement au programme et à la progression DPFC 2026-2027 ; niveau adapté à la classe et à la série ; barème ; cohérence de méthode ; planches et figures.
2. **Deux issues par point** : **confirmer** (avec la source ou la raison) ou **corriger** le fichier de leçon. Un point qu'il ne peut établir avec certitude est **retiré** ou **reformulé de façon sûre**. Rien ne reste « à valider ».
3. **Outils** : calculs refaits avec sympy ; faits sur des sources sûres ; progression du dépôt (`docs/contenus/progressions-2026-2027/`).
4. **Indépendance** : jamais auteur ni relecteur de la même leçon.
5. **Modèle** : Opus (ADR-0104 : jugement).
6. **Trace** : une ligne par point au journal du chantier (point, décision, justification).
7. **Contrôle** : `ruby script/contenus/valider.rb` après ses corrections ; les tests de contenu restent stricts, aucun n'est rendu tolérant.
8. **Production** : une leçon déjà sur le train de production qu'il corrige produit une liste Avant / Après (lieu : notion › exercice › question, champ) que l'équipe reporte à la main. L'agent ne touche jamais la production.

## 5. Conséquences

- Les listes « À faire valider par un enseignant » disparaissent des prompts, du README des contenus et des journaux à venir ; les listes existantes ont été tranchées le 2026-11-14 (chantier `validation-pedagogique-agent`).
- L'équipe ne relit plus le fond avant publication ; elle vérifie le rendu dans l'application.
- Le risque d'une erreur que seul un enseignant aurait vue est accepté par le porteur ; la règle « retirer plutôt qu'affirmer » le borne.
- La future certification des enseignants (ADR-0073) n'est pas concernée : elle porte sur les comptes, pas sur les contenus.

## 6. Notes d'implémentation

- Agent : `.claude/agents/validateur-pedagogique.md`.
- Processus : `docs/contenus/README.md` (« Le pipeline d'une leçon »), `docs/contenus/prompt-redaction.md`, `docs/contenus/prompt-redaction-lot.md`, `docs/chantiers/contenus-v3-tous-niveaux/{prompt-vague,plan-de-test,feuille-de-route}.md`, table des modèles de `docs/workflows/README.md`, `CLAUDE.md`.
- Points existants tranchés : `docs/chantiers/validation-pedagogique-agent/decisions/`.

## 7. Comment vérifier que la décision est respectée

- `grep -rn "faire valider par un enseignant" docs/contenus/prompt-redaction*.md` ne rend rien.
- Le journal de tout chantier de leçons a ses décisions du validateur (Confirmé / Corrigé / Retiré-reformulé), sans section « à faire valider ».
- Les tests de contenu (`test/integration/contenus/`, `test/integration/catalog/*_lessons_test.rb`) ne sont pas assouplis.
