---
name: lecon
description: Rédige une leçon Lnclass au format lnclass.course-tree v3, de bout en bout — rédacteur, relecteur indépendant, validateur pédagogique, puis valider.rb — et ouvre la PR de contenus. Utilise-la quand l'utilisateur tape /lecon, demande d'écrire, refaire ou corriger une leçon, une fiche de révision ou les exercices d'une leçon.
---

# Rédiger une leçon

Décision : ADR `contenus-dans-un-depot-dedie-copie-figee` (chantier `contenus-depot-dedie`). Les règles de rédaction ne sont **pas** ici : elles vivent dans `prompt-redaction.md` (source unique). Cette skill ne fait que jouer le circuit.

Argument : `<niveau> <matière> <intitulé exact de la progression>` (ex. `3ème Mathématiques Théorème de Thalès`), ou le chemin d'une leçon à corriger. S'il manque l'un des trois, déduis-le de la progression ; sinon arrête-toi et nomme ce qui manque.

## 0. Où écrire

| Situation | Dépôt de travail | Leçons | Prompts |
|---|---|---|---|
| `docs/contenus/VERSION` existe dans l'application (migration faite) | `<propriétaire>/App.Lnclassapp-contenus` (l'ajouter à la session avec `add_repo` s'il manque) | `lecons/<niveau-série>/<matière>/` | `prompts/` |
| Sinon (avant migration) | l'application | `docs/contenus/lecons-traitees/<niveau-série>/<matière>/` | `docs/contenus/` |

**Jamais** de leçon écrite à la main dans `docs/contenus/lecons-traitees/` après migration : la CI le refuse. Le contrôle `script/contenus/valider.rb` se lance **toujours depuis l'application** (il lit les règles du domaine).

Branche : `contenus/<slug-de-la-leçon>` depuis `main` (dépôt de contenus) ou `Develop` (application). Une branche vit moins d'un jour.

## 1. Rédacteur

Sous-agent (`model: sonnet`), avec `prompt-redaction.md` en entier et le bloc **ENTRÉE** rempli. Pour plusieurs leçons d'un même niveau et d'une même matière : `prompt-redaction-lot.md`. Il produit **un seul fichier** JSON v3, nommé comme ses voisins (`NN-intitule-en-kebab.json`).

Puis, toi : `ruby <app>/script/contenus/valider.rb <fichier>`. Un ✗ → le rédacteur corrige, on relance. On ne passe pas à 2 avec une erreur.

## 2. Relecteur indépendant

Un **autre** sous-agent que le rédacteur (contexte neuf, `model: opus`), qui ne réécrit pas : il refait chaque calcul, vérifie que chaque correction suit la méthode en étapes avec les mêmes mots, que l'exemple corrigé applique l'étape *n* à l'étape *n*, qu'aucune question ne dépend d'un élément absent. Il rend la liste des défauts avec leur chemin JSON (`courses[0].notions[1].exercise[0].questions[3]`). Le rédacteur corrige ; `valider.rb` est relancé. Un seul tour ; ce qui reste va au bilan.

## 3. Validateur pédagogique

L'agent `validateur-pedagogique` (`.claude/agents/validateur-pedagogique.md`) : conformité au programme ivoirien (DPFC), niveau de langue, exactitude des faits. S'il n'existe pas encore dans le dépôt, saute l'étape, écris-le au bilan et dans la PR (« validation pédagogique : agent absent, à refaire »). Ses défauts bloquants sont corrigés, puis `valider.rb` est relancé.

## 4. Contrôle final et aperçu

```bash
ruby script/contenus/valider.rb <fichier>          # depuis l'application : ✓ obligatoire
bin/apercu-lecon <fichier>                          # avant migration seulement (il refuse un fichier hors de docs/contenus/lecons-traitees/)
```

Après migration, l'aperçu se fait sur la PR de synchronisation (rendu ciblé de la CI à 390 px et sur ordinateur).

## 5. PR

- Une PR par lot de leçons d'un même niveau et d'une même matière ; titre `contenus(<niveau> <matière>): <intitulés>`.
- Corps : fichiers, verdict `valider.rb` (✓ par fichier, avertissements restants), défauts de relecture restants, verdict du validateur pédagogique, points à faire vérifier par un enseignant de la matière.
- Avant migration : PR applicative vers `Develop`, preuve `bin/ci-quiet` (CLAUDE.md). Après migration : PR de contenus vers `main` ; l'entrée dans l'application passe ensuite par `ruby script/contenus/synchroniser.rb <clone>` dans une PR applicative.
- Tu ne fusionnes pas. Tu surveilles la PR et tu ne finis pas sur une question (`docs/workflows/contrat-de-session.md`).

## Bilan (une ligne par leçon)

`<fichier> · valider.rb ✓ · relecture : N défauts corrigés, M restants · validateur : ✓ / défauts / absent`
