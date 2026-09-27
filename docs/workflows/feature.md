# Cycle Feature

> Détail de la colonne **Feature** de la [table de routage](README.md#table-de-routage). Le processus maître en 5 phases est dans [`README.md`](README.md) ; ce fichier ne le remplace pas, il l'instancie.

Branche : `feature/<slug>` · Commits : `feat(<contexte>): …` · Chantier : `docs/chantiers/<slug>/`

---

## Quand utiliser ce cycle

| Utilise **feature** si… | C'est un **autre** cycle si… |
|---|---|
| Un acteur pourra faire quelque chose qu'il ne pouvait pas faire | Le comportement attendu existe déjà et ne marche pas → [`bugfix.md`](bugfix.md) |
| Une nouvelle table, un nouveau port ou un nouveau contexte borné apparaît | Le comportement observable est strictement identique après → [`refactoring.md`](refactoring.md) |
| Une vue nouvelle ou une vue existante change de parcours | Seul le temps de réponse ou le nombre de requêtes change → [`optimisation.md`](optimisation.md) |
| Le PRD peut s'écrire en critères d'acceptation vérifiables | La production est cassée maintenant → [`hotfix.md`](hotfix.md) |

**Test de la feature déguisée** : si tu as ouvert un chantier `refactor/` ou `perf/` et que tu te surprends à écrire un critère d'acceptation utilisateur, ferme-le et rouvre un chantier feature. Un refactoring qui change un comportement est une feature ([interdits](README.md#les-interdits)).

---

## Les 5 phases pour ce cycle

### 1. Cadrer — `memo.md`

Poids : **maximum**. C'est ici qu'on gagne ou qu'on perd le chantier.

- [`memo.md`](../chantiers/_TEMPLATE/memo.md) rempli en entier, **`Hors périmètre` compris** — c'est la section qui empêche le chantier de gonfler.
- Grill adverse obligatoire : cas limites, acteurs oubliés (Parent, SchoolStaff, Team), multi-appartenance élève, permissions inter-établissements.
- Le tableau `Ce que le grill a révélé` doit avoir au moins une ligne. Sinon le grill n'a pas eu lieu.

**Non négociable** : pas de nom de fichier, pas de nom de classe dans le memo. On parle métier.

### 2. Décider — `prd.md` + ADR + UDR

| Produit | Obligatoire quand | Template |
|---|---|---|
| `prd.md` | **toujours** | [`_TEMPLATE/prd.md`](../chantiers/_TEMPLATE/prd.md) |
| ADR | nouveau port, nouvelle table, nouvelle dépendance, changement de contrat, nouvelle stratégie de persistance | [`adr/TEMPLATE.md`](../decisions/adr/TEMPLATE.md) |
| UDR | **dès qu'une vue est créée ou modifiée — sans exception** | [`udr/TEMPLATE.md`](../decisions/udr/TEMPLATE.md) |

- Les critères d'acceptation du PRD (§4) sont écrits en Gherkin et **chacun devient un test**. Un critère non testable est un critère à réécrire.
- L'UDR se rédige comme une consigne exécutable : tokens, états vide/chargement/erreur/succès, cible Turbo, `aria-*`. Un agent doit écrire la vue à partir de sa seule §3.
- Numérotation ADR/UDR : `ls docs/decisions/adr/ | tail -3`, 4 chiffres, kebab-case ([conventions §2](../guide/conventions.md#2-nommage-des-fichiers)).

**Ce qu'on peut sauter** : l'ADR, si le chantier n'ajoute qu'un use case sur des ports existants. **Jamais l'UDR dès qu'une vue bouge.**

### 3. Planifier — `plan.md`

Découpage **vertical** obligatoire : un lot = un cas d'usage complet, de la migration au pixel.

```
Lot 0 — SOCLE (séquentiel, court)
  migration · entités · ports (contrats gelés) · routes.rb · locales · layout
  ↓
  ├─► Lot A « cas d'usage 1 »  ┐
  ├─► Lot B « cas d'usage 2 »  ├─ parallèle, fichiers disjoints, worktrees isolés
  └─► Lot C « cas d'usage 3 »  ┘
```

- Format de lot gelé : 4 champs obligatoires ([conventions §6](../guide/conventions.md#6-format-dun-lot)).
- Tableau `Vérification de collision` rempli **avant** de lancer les lots parallèles. Fichier listé deux fois = il remonte au Lot 0.
- Le nombre d'agents n'est pas décidé : il vaut le nombre de lots sans dépendance en attente.

### 4. Exécuter — le code

Dans **chaque** lot, l'ordre est imposé :

| # | Couche | Règle |
|---|---|---|
| 1 | Test | Écrit avant le code, doit **échouer** d'abord |
| 2 | `app/domain/` | Ruby pur, zéro `ActiveRecord`/`Orm::` — pre-commit bloquant |
| 3 | `app/infrastructure/` | Migration, `Orm::`, repository implémentant le port du Lot 0 |
| 4 | `app/controllers/` | Params → use case → rendu. Zéro logique métier |
| 5 | `app/views/`, `app/javascript/` | Strictement conforme à l'UDR |

En-tête HITL 3 lignes sur chaque fichier de `app/` ([conventions §5](../guide/conventions.md#5-en-tête-hitl)). Blueprint de la couche : [`../blueprints/`](../blueprints/).

Un lot vertical **n'a pas le droit de redéfinir un port**. S'il en a besoin, il s'arrête et le Lot 0 rouvre.

### 5. Prouver — la PR

- Un rôle **distinct de l'auteur** exécute : lance les tests, ouvre l'app, refait le parcours nominal *et* un chemin d'erreur du PRD.
- Portes CI : pureté du domaine, rubocop, tests, parcours système, brakeman ([conventions §7](../guide/conventions.md#7-ce-qui-bloque)).
- **Une seule PR** vers `Develop`, référençant le chantier, les ADR et les UDR.
- `journal.md` clos : ce qui a dérapé, la dette laissée, les chantiers de suivi.

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Griller** (phase 1) | oui | Attaque le memo : acteurs oubliés, cas limites, périmètre qui gonfle |
| **Explorer** (phase 2) | oui si le contexte borné existe déjà | Cartographie use cases, ports et queries existants avant d'en inventer |
| **Architecte** (phase 3) | oui | Écrit le graphe de lots et le tableau de collision |
| **Exécutants** (phase 4) | 1 par lot parallèle | Un worktree chacun, fichiers disjoints |
| **Challenger** (phase 5) | oui | **Exécute**, ne relit pas. Rejoue chaque critère d'acceptation du PRD |

---

## Portes de sortie — à copier dans `plan.md`

```markdown
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
```

---

## Exemple réel — `communication` : messagerie de classe

- **Memo** : un enseignant ne peut pas adresser une information à sa classe ; hors périmètre = pièces jointes, messagerie 1-à-1, notifications push.
- **Grill** : « un élève multi-classes voit-il deux fois le message ? » → non, dédoublonnage par classe ; conséquence : un index unique dans le Lot 0.
- **PRD** : critère « les élèves des autres classes ne le voient pas » → test d'autorisation dédié.
- **ADR** : aucun — `Orm::` et les ports `communication` existent déjà, `UseCases::Communication::ManageMessage` s'y branche.
- **UDR** : obligatoire — le formulaire de composition et le fil de classe sont deux vues nouvelles (tokens, états vide/erreur, cible Turbo Stream du fil).
- **Lots** : Lot 0 (migration `messages`, entité, port, `routes.rb`, `fr.yml`) → Lot A « poster un message » ‖ Lot B « lire le fil élève ».

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **Découpage horizontal** | « Lot A = le domaine, Lot B = les vues » | Un lot va de la migration au pixel. Sinon rien n'est démontrable avant la fin |
| **UDR sautée** | La vue est « simple », on l'écrit directement | Interdit. C'est ce qui produit des interfaces incohérentes d'une session à l'autre |
| **Port redéfini en cours de route** | Deux lots divergent sur la même signature | Le port appartient au Lot 0. Il se regèle au Lot 0 ou pas du tout |
| **Fichier partagé oublié** | `routes.rb` ou `fr.yml` dans deux lots | Tableau de collision **avant** de lancer, pas après le conflit git |
| **Entité posée à la racine** | `app/domain/entities/message.rb` | Tout est namespacé par contexte borné ([conventions §2](../guide/conventions.md#2-nommage-des-fichiers)) |
| **PRD réécrit dans le code** | Le comportement livré ne correspond plus | Toute évolution post-phase 3 passe par une modification explicite de `prd.md` |
| **Contrat de retour du use case** | Hésitation `OpenStruct` vs `Result` | Écart connu non tranché ([conventions §8](../guide/conventions.md#8-écarts-connus-entre-la-doc-et-le-code)). Sur ce dépôt : suivre le code voisin, ne pas improviser. **Sur le projet cible : l'ADR doit être accepté avant le Lot 0** — il n'y a pas de code voisin |
