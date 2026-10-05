# Plan d'exécution — L'élève voit son propre progrès

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [memo](memo.md) · [PRD](prd.md) · [UDR-0073](../../decisions/udr/0073-progres-de-l-eleve-sur-son-resultat.md) · [ADR-0079](../../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md)

**Préalable** : `Entities::Assessment::Comprehension` (Lot 0 de `rapports-exercices`, [Lnclassapp/App.Lnclassapp#164](https://github.com/Lnclassapp/App.Lnclassapp/pull/164)). Décision du 2026-10-04 : pour ne pas attendre la fusion de #164, `feature/progres-eleve` **intègre `feature/rapports-exercices`** (merge, sans réécriture). Tant que #164 n'est pas dans `Develop`, la PR de ce chantier montre aussi ses changements ; ce merge devient vide dès sa fusion. **Cette PR ne se fusionne qu'après #164.**

## Graphe

```
(rapports-exercices Lot 0 dans Develop)
  ↓
Lot A « la phrase de progrès sur le résultat de session »   → 1 agent
```

Un seul lot : un cas d'usage, une vue, aucun fichier partagé avec un autre lot. Pas de Lot 0 propre : aucune migration, aucun port, aucune route ; les seules locales touchées sont celles de la page, propriété du lot.

---

## Lot A — La phrase de progrès sur le résultat de session

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/session_result_query.rb`
                     `app/views/assessment/session_results/_progress.html.erb`
                     `app/views/assessment/session_results/show.html.erb`
                     `config/locales/assessment/session_results.fr.yml`
                     `test/infrastructure/queries/assessment/session_result_query_test.rb`
                     `test/controllers/assessment/session_results_controller_test.rb`
- **Dépend de**    : `rapports-exercices` Lot 0 (dans `Develop`)
- **Test associé** : `test/infrastructure/queries/assessment/session_result_query_test.rb` · `test/controllers/assessment/session_results_controller_test.rb`
- **Done quand**   : un élève qui termine un exercice pour la deuxième fois lit sur son résultat, sous sa note, une des quatre phrases de l'UDR-0073 selon ses essais ; aucune phrase au premier essai ni pour l'enseignant ; la page ne contient jamais « stagne » ni « baisse » ; tous les critères du PRD §4 sont verts.

Critères du PRD couverts : tous (§4).

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/assessment/session_results.fr.yml` | Lot A (seul lot) |

Aucun fichier en commun avec `rapports-exercices` : ce chantier lit `Comprehension`, il ne le modifie pas.

## Dispatch

```
Vague 1 : Lot A → 1 agent, sur feature/progres-eleve, après merge de Develop
```

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il se connecte comme élève, fait un exercice deux fois (30 % puis 90 %), lit « Tu progresses » ; le refait mal, lit « Ton meilleur résultat reste… » ; ouvre le même résultat comme enseignant et ne voit aucune phrase.
