# ADR-0026 : Un `Result` partagé pour les use cases, des objets de lecture typés pour les queries, des entités et des DTO sans ActiveRecord
<!-- index
titre: Un `Result` partagé pour les use cases, des objets de lecture typés pour les queries, des entités et des DTO sans ActiveRecord
statut: Accepté — *remplace 0006, 0012 §3.1, 0021, 0022 §2.A-C*
problematique: `Shared::Result` (`value`, `code`, `errors`) et six codes d'erreur fermés ; lectures par queries renvoyant des `Data` ; `ActiveModel` toléré dans entités et DTO ; domaine interdit à `ActiveRecord`, `Orm::`, `Repositories::`, `Queries::`. F-01 + F-03.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décisions de fondation **F-01** et **F-03**, bloque la V1 |
| **Remplace** | [ADR-0006](./0006-separation-ecriture-lecture-et-optimisation-queries.md) · [ADR-0012](./0012-deep-modules-et-strict-cqrs.md) §3.1 · [ADR-0021](./0021-gestion-de-l-identite.md) · [ADR-0022](./0022-modelisation-hexagonale-du-catalogue-pedagogique.md) §2.A à §2.C |
| **Amende** | [ADR-0014](./0014-standardisation-namespaces-et-validation-frontiere.md) §2.1 (tolérance `ActiveModel` étendue aux entités) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancien dépôt n'a aucun contrat de retour : `OpenStruct`, `Struct` locaux, exceptions et booléens coexistent ([`blueprints/result.md`](../../blueprints/result.md)). Le chemin de lecture se contredit : l'ADR-0006 §3.2 et l'ADR-0012 §3.1 interdisent le use case en lecture, l'ADR-0022 §2.C l'impose (**C-17**). L'ADR-0012 promet des `ViewObjects` qui n'existent pas, et les queries renvoient des `Hash` (**C-06**). Les entités du catalogue divergent de leurs ports (**C-19**). Vingt fichiers du domaine instancient `Repositories::…` par défaut, sans que le test de pureté le voie (**C-39**). L'ADR-0006 cite un `/admin` qui n'existe pas (**C-40**). Les ADR-0012 et 0021 se disent appliqués alors que le code ne les suit pas (**C-16**).

## 2. Moteurs de décision

1. Un appelant sait, sans lire le use case, comment distinguer succès, refus, absence et erreur de saisie.
2. Une lecture ne fait jamais fuir une relation ActiveRecord hors de l'infrastructure.
3. Le garde-fou de pureté est vérifiable par une commande, pas par une revue.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Exceptions métier | Idiomatique en Ruby | Le refus devient un flux de contrôle caché ; chaque contrôleur doit tout attraper |
| B — `Struct` local par use case | Déjà utilisé | Autant de contrats que de fichiers |
| C — **`Shared::Result` immuable unique** | Un seul contrat, testable | Une classe de plus à connaître |

## 4. Décision

> **Nous faisons renvoyer un `Shared::Result` à tout use case, des objets `Data` à toute query, et nous interdisons au domaine toute dépendance à ActiveRecord, aux repositories et aux queries.**

**Use cases.** Une seule méthode publique, `call`, à arguments nommés. Retour : `Shared::Result`, jamais `nil`, jamais une exception pour un cas métier. Une exception ne signale qu'un bug ou une panne d'infrastructure. Les repositories sont injectés **sans valeur par défaut**.

**Codes d'erreur** : liste fermée `Shared::Result::ERROR_CODES`. Le contrôleur les traduit par `RendersResult` :

| Code | Sens | HTTP |
|---|---|---|
| `:forbidden` | la policy refuse | 403, ou redirection vers la connexion si anonyme |
| `:not_found` | la ressource n'existe pas pour cet acteur | 404 |
| `:invalid` | la saisie est invalide ; `errors` porte `{ champ: [messages] }` | 422 |
| `:conflict` | l'état ne permet pas l'action (question déjà répondue, élément encore référencé) ; `errors[:base]` explique | 422 |
| `:locked` | compte verrouillé (ADR-0050) ; `errors[:retry_after]` | 429 |
| `:expired` | jeton ou code périmé (ADR-0032, ADR-0038) | 422 |

Ajouter un code demande d'amender cet ADR.

**Lectures.** Le chemin de l'ADR-0006 §3.2 est retenu : un contrôleur appelle directement une query `Queries::<Contexte>::<Nom>Query`, jamais un use case. Une query renvoie un objet `Data` (défini dans la query, constante `Row`), un tableau de `Row`, ou `nil` ; jamais une relation, jamais un `Hash`, jamais un modèle `Orm::`. Les agrégations se font en SQL (règle anti-`group_by` de l'ADR-0006, reprise telle quelle). L'autorisation d'une lecture est traitée par l'ADR-0028. Les `ViewObjects` et le use case CRUD générique de l'ADR-0012 sont abandonnés. `BrowseCatalog` et `ViewCourse` (ADR-0022 §2.C) ne sont pas repris.

**Entités et DTO.** Une entité est un objet Ruby ou un `Data`. Une entité comme un DTO peut inclure `ActiveModel::Model`, `ActiveModel::Validations` et `ActiveModel::Attributes`, et rien d'autre d'`ActiveModel`. Un DTO `Dtos::<Contexte>::<Nom>Input` valide la forme de la saisie. L'entité porte les invariants métier. Les ports déclarent exactement les méthodes que leurs repositories implémentent : un test de contrat par port le vérifie.

**Transactions.** Un use case qui écrit dans plusieurs tables reçoit `transaction:` (port `Ports::Shared::TransactionPort`, implémenté par `Repositories::Shared::Transaction`).

**Garde-fou de pureté.** Aucun fichier de `app/domain/` ne mentionne `ActiveRecord`, `ApplicationRecord`, `Orm::`, `Repositories::`, `Queries::`, `ActiveStorage`, `ActionController` ni `ActionDispatch`.

## 5. Conséquences

### 🟢 Positives

- Un seul contrat, que `RendersResult` traduit en réponse HTTP. Les contrôleurs n'ont plus de branche métier.
- C-17 est fermée : les lectures passent par les queries, et aucune ne passe par un use case.
- Le domaine se teste avec des doubles en mémoire, sans base.

### 🔴 Coûts consentis

- Le câblage est explicite : chaque contrôleur construit son use case avec ses repositories, ce qui est verbeux.
- Une query par écran : on accepte une duplication de SQL entre écrans voisins plutôt qu'une couche de lecture générique.
- Les blueprints [`result.md`](../../blueprints/result.md) et [`policy.md`](../../blueprints/policy.md) sont réécrits sur ce contrat le 2026-09-25.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Shared::Result
# Rôle : contrat de retour unique de tout use case
# ADR  : 0026
module Shared
  Result = Data.define(:value, :code, :errors) do
    def self.success(value = nil) = new(value:, code: nil, errors: {})

    def self.failure(code, errors: {})
      raise ArgumentError, "code d'erreur inconnu : #{code}" unless Result::ERROR_CODES.include?(code)

      new(value: nil, code:, errors:)
    end

    def success? = code.nil?
    def failure? = !success?
  end
  Result::ERROR_CODES = %i[forbidden not_found invalid conflict locked expired].freeze
end
```

Fichier : `app/domain/shared/result.rb`. Traduction HTTP : `app/controllers/concerns/renders_result.rb`. Le tableau de bord de l'équipe vit sous `/teams` (`Teams::BaseController`, [ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md)) : la mention `/admin` de l'ADR-0006 disparaît avec lui (C-40).

## 7. Comment vérifier que la décision est respectée

- `test/architecture/domain_purity_test.rb` échoue sur les motifs interdits du §4. Le hook pre-commit applique le même motif.
- `test/architecture/use_case_contract_test.rb` : chaque classe de `UseCases::` n'expose que `call`, et chaque constructeur n'a aucun argument par défaut qui soit un repository.
- `test/architecture/query_contract_test.rb` : chaque query appelée renvoie un `Data`, un `Array` de `Data` ou `nil`.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0006 en entier. Son §3.2 et la règle anti-`group_by` sont repris ici ; la référence `/admin` tombe.
- **Remplace** l'ADR-0012 §3.1 (`ViewObjects`) ; son §3.3 est remplacé par l'ADR-0039. L'ADR-0012 est donc remplacé en entier (C-16).
- **Remplace** l'ADR-0021 (délégation ORM → entités, jamais fusionnée, C-16).
- **Remplace** l'ADR-0022 §2.A à §2.C ; le statut du contenu passe à l'ADR-0035.
- **Amende** l'ADR-0014 §2.1 et **complète** l'ADR-0001 §3 (injection sans défaut).

## 9. Points à confirmer par le porteur

- Les champs du `Data` sont `value`, `code` et `errors`, et non `value` et `errors` seuls : le code symbolique est séparé du détail par champ.
