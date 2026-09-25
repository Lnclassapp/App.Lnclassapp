# ADR-0029 : `public_id` opaque sans préfixe dans les URL, slugs réservés au catalogue, clés `bigint` partout

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-05**, bloque la V1 |
| **Complète** | [ADR-0017](./0017-remplacement-nanoid-par-secure-random.md) |
| **Remplace** | [ADR-0018](./0018-remediation-just-in-time-et-historique-lacunes.md) : clé `has_nanoid(:id)` des lacunes |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le glossaire §7 préfixe le `public_id` des comptes par rôle (`stdt_`, `tch_`, `sadm_`…). Le rôle se lit donc dans l'URL, ce que `securite.md` signale, alors que l'ADR-0017 prévoit 14 caractères base58 sans préfixe (**C-11**). Les lacunes ont une clé primaire `string` quand toutes les autres tables sont en `bigint` (**C-15**). Le slug aléatoire de 2 octets des comptes démo fait échouer une création d'école sur quatre vers 50 écoles, contre la promesse de « 0 % de conflit » de l'ADR-0020 (**C-29**). Enfin, `GET /users/:id` accepte l'identifiant séquentiel (TR-21).

## 2. Moteurs de décision

1. Une URL ne révèle ni le volume, ni l'ordre de création, ni le rôle.
2. Une collision est impossible en pratique **et** refusée par la base.
3. Les jointures restent en `bigint`.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — `id` séquentiel | Simple | Énumérable (TR-21) |
| B — `public_id` préfixé par rôle | Lisible | Divulgue le rôle (C-11) |
| C — **`public_id` opaque, slug pour le catalogue** | Ni énumérable ni bavard ; URL lisibles pour le contenu public | Deux mécanismes à connaître |

## 4. Décision

> **Nous exposons dans les URL un `public_id` opaque de 14 caractères base58 pour tout enregistrement hors catalogue, un slug pour le contenu du catalogue, et jamais un `id`.**

**`public_id`** : colonne `public_id string(14) NOT NULL`, index unique, valeur `SecureRandom.base58(14)` générée à la création, sans préfixe. Elle est immuable.

- Tables concernées : `users`, `classrooms`, `exercise_sessions`, `exercises`, `schools`, `drenas`, `classroom_assignments`, `knowledge_gaps`, `messages`, `import_reports`.
- Toute nouvelle table dont une ligne apparaît dans une URL en reçoit un.

**Slug** : colonne `slug string NOT NULL`, index unique. On le dérive du nom par `parameterize` ; en cas de collision, on suffixe `-2`, `-3`….

- Tables concernées : `levels`, `series`, `materials`, `courses`, `essentials`.
- Le slug est **figé à la création** : renommer un cours ne casse aucun lien.

**Clés** : clé primaire `bigint` sur toutes les tables, lacunes comprises. Aucune clé primaire `string`.

**Recherche** :

- Un contrôleur trouve par `find_by!(public_id:)` ou `find_by!(slug:)`. L'échec donne `:not_found`, donc une 404.
- `to_param` renvoie le `public_id` ou le slug.
- Une route n'accepte jamais `:id` numérique.

**Collision** : l'index unique la refuse. Le repository régénère et réessaie **une fois** sur `ActiveRecord::RecordNotUnique` ; un second échec est une panne, qui lève.

**Secrets** : les jetons d'invitation, les codes de récupération et les codes de secours **ne sont pas** des `public_id`. Ils suivent leurs ADR (0031, 0032, 0038) et ne sont stockés qu'en empreinte.

## 5. Conséquences

### 🟢 Positives

- TR-21 et C-11 sont fermées : l'URL d'un compte ne dit ni son rang ni son rôle.
- 58¹⁴ ≈ 5·10²⁴ valeurs : la collision est théorique, et la base la refuse quand même (C-29).
- Les URL du catalogue restent lisibles et partageables.

### 🔴 Coûts consentis

- Une colonne et un index de plus par table exposée.
- Un slug figé peut devenir trompeur après renommage : on l'accepte pour ne casser aucun lien.
- `friendly_id` n'est pas repris ; le suffixe de collision est écrit à la main dans le repository.

## 6. Notes d'implémentation

```ruby
# 🔌 INFRA · Orm::HasPublicId
# Rôle : génère le public_id opaque à la création
# ADR  : 0029
module Orm
  module HasPublicId
    extend ActiveSupport::Concern

    included do
      before_validation(on: :create) { self.public_id ||= SecureRandom.base58(14) }
      validates :public_id, presence: true, length: { is: 14 }
    end

    def to_param = public_id
  end
end
```

Fichier : `app/infrastructure/orm/has_public_id.rb`. La macro trompeuse `has_nanoid` de l'ancien dépôt n'est pas reprise.

## 7. Comment vérifier que la décision est respectée

- `test/architecture/schema_conventions_test.rb` échoue si une table de la liste n'a pas de `public_id` ou de `slug` avec un index unique, ou si une clé primaire n'est pas `bigint`.
- `test/architecture/routes_test.rb` échoue si une route expose un segment `:id` hors des routes de l'infrastructure (`/up`, `/teams/jobs`).
- Test d'intégration : `GET /users/1` renvoie 404.

## 8. Remplace, complète, amende

- **Complète** l'ADR-0017 : longueur, liste des tables, absence de préfixe, index et nouvel essai.
- **Remplace** la clé `string` des lacunes de l'ADR-0018 (C-15) et les préfixes du glossaire §7 (C-11).
- **Ferme** C-29.

## 9. Points à confirmer par le porteur

- Les exercices prennent un `public_id`, pas un slug : on n'y accède que connecté.
