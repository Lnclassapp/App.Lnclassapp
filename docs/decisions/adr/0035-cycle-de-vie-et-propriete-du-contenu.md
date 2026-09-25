# ADR-0035 : Cycle de vie `draft` / `published` / `archived` du contenu, lu par policy, et contenu propriété de la plateforme

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-13**, bloque la V1 (Lot B) |
| **Complète** | [ADR-0022](./0022-modelisation-hexagonale-du-catalogue-pedagogique.md) §2.A (`status`, `published_at` du cours) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Dans l'ancien, le statut du contenu est un texte libre : l'import écrit « publié », le code lit `published`, et les exercices portent un booléen `published`. Un brouillon est masqué des index, mais reste lisible par son URL. `team_id` n'est jamais renseigné : le libellé « Visible uniquement par vous » d'un brouillon est faux. L'ADR-0022 §2.A prévoit `status` et `published_at` sur le cours, que les entités n'ont jamais portés (C-19).

## 2. Moteurs de décision

1. Un élève ne lit jamais un brouillon, ni par l'index, ni par l'URL.
2. Un contenu consommé par des élèves ne disparaît pas (ADR-0036).
3. On sait qui a créé un contenu, et quand il a été publié.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Booléen `published` | Minimal | Pas d'archivage, donc suppression |
| B — **Énumération à trois états, trois tables** | Couvre l'archivage | Trois colonnes de plus par table |

## 4. Décision

> **Nous donnons aux cours, aux fiches et aux exercices le même cycle `draft` → `published` → `archived`, lu par une policy, et nous traitons le contenu comme propriété de la plateforme, dont l'auteur n'est qu'une trace.**

**Colonnes** sur `courses`, `essentials` et `exercises` :

| Colonne | Contrainte |
|---|---|
| `status` | `string NOT NULL DEFAULT 'draft'`, `CHECK IN ('draft','published','archived')` |
| `published_at` | `datetime NULL` ; posé à la première publication, jamais effacé |
| `archived_at` | `datetime NULL` |
| `author_id` | `bigint NOT NULL`, FK `users` (`on_delete: :restrict`) |

Index `(status)` sur chaque table ; `(essential_id, status)` sur `exercises`. Le booléen `published` et `team_id` n'existent plus.

**Transitions**, une paire de use cases par type : `Catalog::PublishCourse` et `Catalog::ArchiveCourse`, `Catalog::PublishEssential` et `Catalog::ArchiveEssential`, `Assessment::PublishExercise` et `Assessment::ArchiveExercise`. Policy : `Catalog::ManageContentPolicy`.

| De | Vers | Condition, sinon `:conflict` |
|---|---|---|
| `draft` | `published` | le parent est `published` ; pour un exercice : au moins une question, chacune conforme à son type (ADR-0054) |
| `published` | `archived` | aucune |
| `archived` | `published` | le parent est `published` |
| `published` ou `archived` | `draft` | **interdit** |

**Lecture** :

- `Catalog::ReadPublishedPolicy` (ADR-0028) est appelée par le contrôleur sur toute page de contenu.
- Pour un non-`team`, un contenu est lisible s'il est `published` **et** que ses parents le sont ; sinon, 404.
- Un contenu `archived` n'est ni listé ni assignable, et on n'y démarre plus de session. Les résultats déjà obtenus dessus restent lisibles (ADR-0054).
- Les queries de liste filtrent aussi par statut, mais c'est la policy qui fait foi : on la teste sur l'URL directe.

**Propriété** : tout membre `team` modifie tout contenu (ADR-0038 pour les sous-rôles de la V4). `author_id` trace le créateur, il ne donne aucun droit.

L'interface d'un brouillon affiche « Brouillon — visible par l'équipe ». Modifier le texte d'un contenu publié est permis ; supprimer une question ou une réponse déjà tentée ne l'est pas (ADR-0036).

**Journal** (`audit_events`) : `content.published`, `content.archived`.

## 5. Conséquences

### 🟢 Positives

- Un brouillon ne fuit plus par son URL.
- Un exercice consommé s'archive au lieu de se détruire.
- Le libellé mensonger « Visible uniquement par vous » disparaît.

### 🔴 Coûts consentis

- Pas de retour en brouillon : une erreur de publication se corrige en place ou par archivage.
- La visibilité dépend des parents : archiver un cours masque ses fiches et ses exercices, et chaque query doit joindre la chaîne des parents.
- Pas de relecture à deux (auteur, relecteur) avant la V4.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Policies::Catalog::ReadPublishedPolicy
# Rôle : un non-team ne lit qu'un contenu publié dont toute la chaîne de parents est publiée
# ADR  : 0028, 0035
module Policies
  module Catalog
    class ReadPublishedPolicy
      def call(actor:, content:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.role == :team
        return Shared::Result.success if content.readable_chain_published?

        Shared::Result.failure(:not_found)
      end
    end
  end
end
```

Le refus répond `:not_found`, pas `:forbidden` : on ne confirme pas l'existence d'un brouillon.

## 7. Comment vérifier que la décision est respectée

- Test d'intégration : un élève sur l'URL d'une fiche en brouillon reçoit 404, et un membre `team` 200.
- Tests de use case : publier un exercice sans question donne `:conflict`, publier une fiche d'un cours en brouillon donne `:conflict`, un retour à `draft` est refusé.
- Test de schéma : la contrainte `CHECK` refuse `'publié'`.

## 8. Remplace, complète, amende

- **Complète** l'ADR-0022 §2.A : statut sur les trois niveaux de contenu, transitions et lecture.
- **Supprime** la notion de propriété par `team_id`.

## 9. Points à confirmer par le porteur

- Aucun retour d'un contenu publié à l'état de brouillon.
- En V1, tout membre de l'équipe modifie tout contenu.
