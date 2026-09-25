# Cycle Optimisation

> Détail de la colonne **Optimisation** de la [table de routage](README.md#table-de-routage). Le processus maître en 5 phases est dans [`README.md`](README.md).

Branche : `perf/<slug>` · Commits : `perf(<contexte>): …` · Chantier : `docs/chantiers/<slug>/`

**La règle qui domine tout le cycle** : mesure chiffrée **AVANT** dans le memo, bench chiffré **APRÈS** en phase 5. **Pas de chiffre = rejet automatique**, à l'entrée comme à la sortie. Optimiser sans mesure est un [interdit](README.md#les-interdits).

---

## Quand utiliser ce cycle

| Utilise **optimisation** si… | C'est un **autre** cycle si… |
|---|---|
| Le résultat est **correct** mais trop lent, trop gourmand, ou fait trop de requêtes | Le résultat est faux → [bugfix](bugfix.md) |
| Tu peux nommer la métrique et la mesurer **aujourd'hui** | Tu veux juste « du code plus propre » → [refactoring](refactoring.md) |
| La cible est chiffrée (« < 300 ms », « ≤ 5 requêtes », « 1 job au lieu de 4 000 INSERT ») | Un écran ou une capacité change → [feature](feature.md) |
| Un job time out, une page rame, la mémoire explose | La prod est down maintenant → [hotfix](hotfix.md), optimisation en chantier de suivi |

**Test de l'optimisation déguisée** : si tu ne peux pas produire un nombre avant d'écrire une ligne de code, tu n'as pas un chantier d'optimisation — tu as une intuition. Le chantier n'ouvre pas.

---

## Quoi mesurer, et comment, sur ce projet

| Symptôme | Métrique | Comment la prendre |
|---|---|---|
| Page de liste lente | **Nombre de requêtes SQL** pour un rendu | Compter les `SELECT` dans `log/development.log` sur un seul rendu, ou `ActiveSupport::Notifications.subscribe("sql.active_record")` dans un test |
| N+1 sur un fil ou un rapport | Requêtes par élément affiché | Doubler le jeu de données : si le nombre de requêtes double, c'est un N+1 |
| Requête de lecture complexe | Temps SQL (ms) | `EXPLAIN ANALYZE` sur la requête de la `Queries::…` concernée |
| Import massif / job qui time out | Durée totale + nombre d'`INSERT` | `Benchmark.realtime` autour du job sur un volume réaliste (une école complète) |
| Mémoire qui explose | Objets alloués | `GC.stat` ou `ObjectSpace.count_objects` avant/après, sur le même volume |
| Rendu de vue | Temps `View` du log Rails | La ligne `Completed 200 OK in Xms (Views: … / ActiveRecord: …)` |

Les leviers déjà entérinés sur ce projet :

- **Séparation lecture/écriture** — les lectures complexes passent par `app/infrastructure/queries/`, pas par des entités rechargées ([ADR-0006](../decisions/adr/0006-separation-ecriture-lecture-et-optimisation-queries.md)).
- **Bulk insert** — `insert_all!` / `upsert_all` dans le repository pour les imports massifs, avec génération explicite des `public_id`, `unique_code` et `slug` puisque les callbacks sont contournés ([ADR-0020](../decisions/adr/0020-optimisations-bulk-insert-donnees-catalogue.md)).

Une mesure sans **volume de données précisé** n'est pas une mesure. Toujours écrire : « 1 école, 12 classes, 45 élèves démo par classe ».

---

## Les 5 phases pour ce cycle

### 1. Cadrer — `memo.md` avec le **chiffre avant**

Le memo n'ouvre pas sans ce tableau :

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Durée `ImportSchoolsJsonJob` | 1 école, 12 classes, 45 élèves/classe | 47 s (timeout) | < 5 s | `Benchmark.realtime` |

`Hors périmètre` : nommer explicitement ce qu'on **n'optimise pas**, sinon le chantier absorbe toute la couche.

### 2. Décider — ADR si le contrat change

- **ADR obligatoire** si l'optimisation change un contrat : port modifié, callbacks contournés, invariant désormais garanti à la main, dénormalisation, cache introduit.
- **Pas d'ADR** si l'optimisation reste locale : ajout d'un index, `includes` correctement posé, `select` restreint.
- **Pas d'UDR** — si l'écran change, ce n'est plus une optimisation.

Un contournement de callbacks (`insert_all!`) est **toujours** un ADR : il déplace une garantie du framework vers ton code.

### 3. Planifier — un lot par optimisation **mesurable séparément**

- Un lot = un levier = un chiffre. Deux leviers dans le même lot et on ne sait plus lequel a payé.
- `Done quand` d'un lot d'optimisation s'écrit toujours en chiffres : **« l'import d'une école passe de 47 s à < 5 s, mesuré au même volume »**.
- Ordonner les lots par ratio gain/risque décroissant, et s'arrêter dès que la cible est atteinte. Un lot devenu inutile se ferme, il ne se joue pas « par principe ».

### 4. Exécuter — **le bench sert de test**

1. Écrire le **bench reproductible** (script ou test), qui produit la valeur *avant*. Il est versionné dans le chantier ou dans `test/`.
2. Écrire ou vérifier les tests de **non-régression fonctionnelle** : l'optimisation ne doit rien changer au résultat. Ils sont verts avant.
3. Appliquer **un seul levier**, relancer le bench, noter le chiffre.
4. Si le gain est nul ou marginal : **annuler le pas**. Une complexité ajoutée sans gain mesuré se retire.

L'ordre des couches ne change pas : la mesure indique où est le coût, la correction va dans la couche qui le porte — le plus souvent `app/infrastructure/queries/` ou `app/infrastructure/repositories/`, jamais dans la vue.

### 5. Prouver — **bench après, chiffré**

Le tableau `§7 Mesures` du [`prd.md`](../chantiers/_TEMPLATE/prd.md) (ou du memo si pas de PRD) est complété colonne **Après**, avec :

- la **même machine**, le **même volume**, la **même méthode** qu'avant ;
- au moins **3 exécutions**, et la médiane retenue — une mesure unique n'est pas une mesure ;
- les tests fonctionnels toujours verts.

**Sans chiffre après, la PR est rejetée.** Un gain non reproductible par le challenger est un gain non prouvé.

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Mesureur** (phase 1) | **OUI** | Produit le chiffre avant et le protocole. Sans lui, pas de chantier |
| **Explorer « coût »** | oui | Localise où part le temps : requêtes, allocations, sérialisation. Pas de supposition |
| **Exécutant** | 1 par levier | Un levier, un chiffre, annulation si gain nul |
| **Challenger avec bench** | **OUI** | **Relance lui-même le bench** sur sa machine et obtient le gain annoncé. Il vérifie aussi que le résultat fonctionnel est identique |

Le challenger de ce cycle ne lit pas le code : il **rejoue la mesure**. S'il n'obtient pas le chiffre, la PR ne passe pas.

---

## Portes de sortie — à copier dans `plan.md`

```markdown
- [ ] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [ ] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [ ] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [ ] ADR écrit si un contrat change (callbacks contournés, dénormalisation, cache, port modifié)
- [ ] Bench versionné, produisant la valeur avant
- [ ] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [ ] Un lot = un levier = un chiffre
- [ ] Chaque levier sans gain mesuré a été **annulé**, pas conservé
- [ ] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [ ] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi — c'est la partie la plus réutilisable
```

---

## Exemple réel — `school` : import massif d'établissements ([ADR-0020](../decisions/adr/0020-optimisations-bulk-insert-donnees-catalogue.md))

- **Avant** : `ImportSchoolsJsonJob` instanciait les entités une par une via les repositories. Sur 1 école / 12 classes / 45 élèves démo par classe → **milliers d'`INSERT` séquentiels**, job en timeout, GC saturé.
- **Cible** : génération complète d'un établissement en **< 5 s**.
- **Levier** : `bulk_create_classrooms_and_demo_students` dans le repository, en `insert_all!` / `upsert_all`.
- **Contrat changé → ADR** : les callbacks sont contournés, donc `public_id`, `unique_code` et `slug` sont calculés explicitement avant insertion ; le slug intègre le slug de l'école et le `unique_code` pour rester unique dans l'index global (`lycee-technique-6eme-1-rxu27`).
- **Piège attrapé au bench** : les contacts démo en `varchar(10)` purement aléatoires provoquaient des collisions (paradoxe des anniversaires) sous fort volume → génération déterministe `unique_code` + index séquentiel sur 5 chiffres.
- **Après** : **< 3 s par établissement**, import des programmes quasi instantané. Complexité concentrée dans les repositories, use cases inchangés.

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **Optimiser à l'intuition** | « Ça doit être la requête X » | L'explorer coût mesure. Le goulot est presque jamais là où on le croit |
| **Mesurer sur 3 lignes de fixture** | Gain spectaculaire en dev, nul en prod | Mesurer au **volume réel** : une école complète, un catalogue complet |
| **Deux leviers dans un lot** | Gain global connu, contribution de chacun inconnue | Un lot = un levier = un chiffre |
| **Mesure unique** | Le chiffre n'est pas reproductible | ≥ 3 exécutions, médiane, même machine |
| **Callbacks contournés en silence** | Unicité violée, slugs dupliqués, `public_id` nuls | `insert_all!` ⇒ ADR + génération explicite des identifiants ([ADR-0020](../decisions/adr/0020-optimisations-bulk-insert-donnees-catalogue.md)) |
| **Cache posé sur un N+1** | Le problème est masqué, pas résolu | Corriger la requête d'abord. Le cache est un dernier recours, et il s'ADR |
| **Comportement modifié au passage** | Un tri change, un champ disparaît | Ce n'est plus une optimisation. Tests de non-régression fonctionnelle obligatoires |
| **Complexité conservée sans gain** | Du code illisible « au cas où » | Gain non mesuré ⇒ pas gardé |
