# Conventions Lnclass

> **Ce fichier gèle les contrats.** Tout le reste de la documentation s'y conforme. Un agent qui hésite sur un nom, un format ou une règle vient ici.

---

## 1. Langue

| Quoi | Langue | Exemple |
|---|---|---|
| Code (classes, méthodes, variables, tables) | **anglais** | `Entities::Catalog::Course`, `def publish_course` |
| Interface utilisateur | **français** | via `t(".key")`, locale par défaut `:fr` |
| Documentation (`docs/`, commentaires, ADR, UDR) | **français** | ce fichier |
| Messages de commit et titres de PR | **anglais** | `feat(catalog): add course publication` |

Raison du mélange : le code parle à des outils et à des devs qui peuvent être internationaux ; la doc et l'UI parlent à l'équipe et aux utilisateurs ivoiriens.

---

## 2. Nommage des fichiers

### ADR et UDR

```
docs/decisions/adr/NNNN-titre-en-kebab-case.md
docs/decisions/udr/NNNN-titre-en-kebab-case.md
```

- **4 chiffres**, séquentiels, jamais réutilisés. `0022`, pas `22` ni `ADR-0022`.
- **kebab-case en français**, sans accent dans le nom de fichier : `0022-suppression-des-open-struct.md`.
- ⚠️ La convention `NNNN_SCREAMING_SNAKE.md` de la v1 est **abandonnée**. Ne plus jamais l'utiliser.
- Avant de créer un ADR, vérifier le dernier numéro dans l'index : `ls docs/decisions/adr/ | tail -3`.

### Chantiers

```
docs/chantiers/<slug>/
```

`<slug>` en kebab-case, court, sans type ni numéro : `messagerie-classe`, pas `feature-5-messagerie`. Le type de cycle vit dans le `memo.md`, pas dans le nom du dossier.

### Code

| Couche | Emplacement | Namespace |
|---|---|---|
| Entités | `app/domain/entities/<contexte>/` | `Entities::Catalog::Course` |
| Use cases | `app/domain/use_cases/<contexte>/` | `UseCases::Catalog::CreateCourse` |
| Ports | `app/domain/ports/<contexte>/` | `Ports::Catalog::CourseRepositoryPort` |
| DTO | `app/domain/dtos/<contexte>/` | `Dtos::Catalog::CourseInput` |
| Repositories | `app/infrastructure/repositories/<contexte>/` | `Repositories::Catalog::CourseRepository` |
| Queries (lecture) | `app/infrastructure/queries/` | `Queries::ClassroomReportQuery` |
| Modèles ActiveRecord | `app/infrastructure/orm/` | `Orm::Course` |

**Contextes bornés** : `assessment`, `catalog`, `classroom`, `communication`, `identity`, `school`.

Deux règles :
- **Tout est namespacé par contexte borné.** Un fichier à la racine de `entities/` ou `repositories/` est du **legacy à migrer**, pas un modèle à suivre.
- Le namespace ORM s'écrit **`Orm::`**, jamais `ORM::`.

### Autres emplacements

- Les **scripts utilitaires** vont dans `script/`, jamais à la racine du dépôt.
- Après avoir créé une constante dans un nouveau namespace, vérifier que Zeitwerk la charge :
  ```bash
  bin/rails runner "puts UseCases::Catalog::CreateCourse.name"
  ```
  Une erreur ici signifie que le chemin du fichier ne correspond pas au namespace — c'est le piège le plus courant en architecture hexagonale, et il ne se voit qu'à l'exécution.

---

## 3. Branches

```
<type>/<slug>              branche de chantier
<type>/<slug>-lot-<x>      branche de lot (parallélisme)
```

Types : `feature`, `fix`, `refactor`, `perf`, `hotfix`, `docs`.

Un chantier = une branche. Ses lots parallèles vivent chacun dans un **worktree git isolé** sur sa propre branche, et sont mergés dans la branche de chantier au fur et à mesure. **Une seule PR par chantier**, vers `Develop`.

### Le flux des branches longues

```
feature/<slug> ──PR──► Develop ──► Staging ──► main
   chantiers          intégration    recette   production
```

| Branche | Rôle | Règle |
|---|---|---|
| `feature/<slug>` | un chantier | créée depuis `Develop`, détruite après merge |
| `Develop` | intégration de tous les chantiers | **cible de toutes les PR** |
| `Staging` | recette avant production | reçoit `Develop` quand un lot de travail est prêt |
| `main` | **production** | ne reçoit que `Staging`. Être en retard sur `Develop` est normal et attendu. |

```
Develop ◄── PR ── feature/messagerie-classe ◄── feature/messagerie-classe-lot-a
                                             ◄── feature/messagerie-classe-lot-b
```

> ⚠️ Une PR ouverte vers `main` au lieu de `Develop` court-circuite la recette. C'est l'erreur à ne jamais commettre.

**Une seule exception : le hotfix.** Une branche `hotfix/<slug>` part de `main` et sa PR vise `main`, parce que la production est cassée maintenant ([`hotfix.md`](../workflows/hotfix.md)). Le correctif est **reporté dans `Develop` le jour même**, par une PR `main → Develop` — sinon le prochain passage `Staging → main` le défait. Un hotfix non reporté est un hotfix perdu.

> ⚠️ **Le tiret n'est pas cosmétique.** Une branche de lot ne peut pas s'écrire `feature/<slug>/lot-a` : git refuse de créer `refs/heads/feature/x/lot-a` quand `refs/heads/feature/x` existe déjà, une référence ne pouvant être à la fois un fichier et un répertoire.

Création d'un worktree de lot — **depuis la branche de chantier**, jamais depuis `Develop`, sinon le lot n'a pas le socle :

```bash
git worktree add ../lnclass-lot-a -b feature/<slug>-lot-a feature/<slug>
```

Ne jamais committer directement sur `Develop`, `Staging` ni `main` : tout passe par une branche de chantier et une PR.

---

## 4. Messages de commit

**Conventional Commits**, en anglais, scope = contexte borné.

```
<type>(<scope>): <description à l'impératif, minuscule, sans point final>
```

Types : `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `ci`.
Scopes : les 6 contextes bornés, ou `ui`, `infra`, `deps`, `docs`.

```
feat(communication): add classroom message broadcasting
fix(assessment): prevent duplicate question attempts on retry
refactor(catalog): move course entity into catalog namespace
perf(school): replace N+1 with single insert_all import
```

Un commit qui corrige un bug référencé mentionne son chantier en pied de message :

```
fix(identity): reject login when contact is blank

Chantier: docs/chantiers/login-contact-vide
```

### Granularité

Un commit par lot (voir [`../workflows/README.md`](../workflows/README.md#phase-3--planifier)), avec la documentation du lot. Les index `docs/decisions/adr/README.md`, `docs/decisions/udr/README.md` et `docs/chantiers/README.md` ne changent qu'au commit de clôture du chantier. Raison mesurée : [`sobriete-tokens`](../chantiers/sobriete-tokens/memo.md).

---

## 5. En-tête HITL

Chaque fichier de `app/` porte un en-tête de **3 lignes maximum**. Son rôle est de permettre à un humain ou à un agent de situer le fichier sans lire son contenu.

```ruby
# 🧠 DOMAINE · UseCases::Catalog::CreateCourse
# Rôle : crée un cours et le rattache à sa matière
# ADR  : 0001, 0014
```

| Emoji | Couche | Fichiers |
|---|---|---|
| 🧠 | Domaine | `app/domain/**` |
| 🔌 | Infrastructure | `app/infrastructure/**` |
| 🌐 | Delivery | `app/controllers/**`, vues `.erb` |
| ⚡ | Front | `app/javascript/**` |

Syntaxe du commentaire selon le fichier : `#` en Ruby, `//` en JavaScript, `<%# … %>` en ERB.

> **Changement par rapport à la v1.** La micro-documentation obligatoire de chaque méthode et de chaque élément de vue est **supprimée**. Elle coûtait plus qu'elle ne rapportait et faisait passer le contrôle qualité pour un contrôle de prose. On commente ce qui est surprenant, pas ce qui est évident.

---

## 6. Format d'un lot

Le plan d'un chantier (`chantiers/<slug>/plan.md`) est un **graphe de lots**. Chaque lot se déclare ainsi :

```markdown
### Lot A — Envoyer un message à une classe

- **Couche**      : domaine + infrastructure + delivery + ui
- **Fichiers**    : app/domain/use_cases/communication/send_message.rb
                    app/infrastructure/repositories/communication/message_repository.rb
                    app/controllers/communication/messages_controller.rb
                    app/views/communication/messages/_form.html.erb
- **Dépend de**   : Lot 0
- **Test associé**: test/domain/use_cases/communication/send_message_test.rb
- **Done quand**  : un enseignant poste un message et il apparaît dans le fil de la classe
```

Les quatre champs sont **obligatoires**. Sans `Dépend de`, impossible de paralléliser. Sans `Test associé` et `Done quand`, impossible de fermer le lot.

**Le nombre d'agents n'est jamais décidé : il est égal au nombre de lots sans dépendance en attente.**

Deux règles de collision :
1. Le **Lot 0** détient les fichiers partagés — `config/routes.rb`, `config/locales/*.yml`, les layouts, la navigation — et les contrats (entités, ports).
2. Deux lots parallèles ne listent **jamais** le même fichier. Si c'est le cas, le fichier remonte au Lot 0.

---

## 7. Ce qui bloque

Ces règles ne sont pas des consignes : ce sont des tests qui refusent ton commit ou ta PR.

| Règle | Où elle bloque |
|---|---|
| `app/domain/` ne référence ni `ActiveRecord`, ni `ApplicationRecord`, ni `Orm::` | pre-commit + CI |
| Rubocop passe sur les fichiers modifiés | pre-commit + CI |
| Les tests concernés passent | pre-commit + CI |
| Les parcours critiques passent en test système | CI |
| L'en-tête HITL est présent sur tout fichier de `app/` | pre-commit |
| Brakeman et bundler-audit ne remontent rien de nouveau | CI |

### Couverture de tests — 100 %

**La règle est : 100 % de couverture, lignes *et* branches, sur tout fichier `.rb` de `app/` et `lib/`.** Décidé par l'[ADR-0024](../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md).

Trois clauses en font partie :

- **`# :nocov:` est interdit.** Une exclusion transforme un 100 % en chiffre décoratif. Toute exception passe par un ADR nommant le fichier et la raison.
- **Les branches comptent autant que les lignes.** Exécuter un `if` sans tester son `else` ne couvre rien. L'écart est mesurable sur ce dépôt : 45,8 % de lignes pour 29,5 % de branches.
- **Le test de mutation accompagne le seuil.** 100 % prouve qu'une ligne a été *exécutée*, jamais qu'elle a été *vérifiée* — on a trouvé ici des tests verts dont le double ignorait le paramètre qu'ils prétendaient tester. `mutant-minitest` sur `app/domain/` est la contrepartie obligatoire.

| Dépôt | Régime | Seuil |
|---|---|---|
| **Projet Rails cible** | **bloquant dès le premier commit** | 100 % lignes / 100 % branches |
| `App.Lnclassapp` (ici) | **cliquet non régressif** | 45 % lignes / 29 % branches |

Le cliquet de ce dépôt monte à chaque chantier livré, jamais l'inverse. Il n'est pas un objectif : l'objectif est 100 %, atteint par la migration et non par le rattrapage. La raison de ce double régime est opérationnelle et datée — à 45,8 %, activer 100 % ici refuserait le premier commit qui répare [`queries-constantes-orm-disparues`](../chantiers/queries-constantes-orm-disparues/memo.md).

---

## 8. Écarts connus entre la doc et le code

Cette section liste les divergences identifiées et **non encore tranchées**. Un agent qui les rencontre ne doit pas improviser : il ouvre un ADR.

> **Sur le projet Rails cible, ces écarts ne se contournent pas en « suivant le code voisin » : il n'y a pas de code voisin.** Chacun est une décision de fondation du programme [`refonte-application`](../chantiers/refonte-application/feuille-de-route.md#3-registre-des-décisions-de-fondation), à accepter par ADR **avant** le Lot 0 qui la consomme. La consigne « suis l'existant du contexte » ne vaut que sur ce dépôt-ci.

| Écart | État réel | À trancher |
|---|---|---|
| Contrat de retour des use cases | `#execute` retournant un `OpenStruct` (29 `execute` contre 10 `call` ; 166 usages d'`OpenStruct`). Le blueprint `result.md` décrit un `Shared::Result` **qui n'existe pas dans le code**. | ADR à écrire : figer un objet Result réel et migrer, ou entériner `OpenStruct` |
| Namespaces dupliqués | ~13 entités et 5 repositories existent **à la fois** à la racine et dans leur contexte borné | Chantier de migration à planifier |
| `app/presenters/` et `app/domain/validators/` | Documentés historiquement, **inexistants** | Créer à la première vraie nécessité, sinon retirer des docs |

Cette table ne liste que les écarts de forme. L'exploration du 2026-09-22 en a relevé plus de trente autres entre ADR, UDR, glossaire et code. Ils sont regroupés dans le [registre des contradictions](../chantiers/refonte-application/feuille-de-route.md#4-registre-des-contradictions-entre-sources) de la feuille de route, qui fait foi pour ces écarts ; ils ne sont pas recopiés ici.
