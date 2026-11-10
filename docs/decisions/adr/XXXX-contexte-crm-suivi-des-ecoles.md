# ADR-XXXX : Le suivi commercial des écoles vit dans un contexte borné `crm`
<!-- index
titre: Contexte crm — suivi des écoles
statut: Accepté
problematique: Où et comment stocker le suivi commercial des écoles (étape, responsable, contacts, échanges, relances) sans polluer le contexte school
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'équipe démarche les établissements ; leur suivi (où en est la relation, qui s'en occupe, qui a-t-on eu au téléphone, quand relancer) vivait dans les téléphones. L'espace équipe connaît pourtant chaque établissement (liste nationale importée) et son usage réel. Le chantier `crm-ecoles` greffe ce suivi sur l'espace équipe.

Le contexte `school` porte l'établissement comme **référentiel** (DRENA, codes, direction, rattachement des enseignants). Le suivi parle une autre langue : prospect, démo, relance, motif de perte. Le mélanger à `school` ferait grossir un contexte déjà central et lier des règles commerciales à des règles d'appartenance.

Deuxième question : l'étape du pipeline. Deux étapes (« Inscrite », « Active ») sont des **faits d'usage** que l'application connaît déjà ; les autres (« Prospect », « Démo faite », « Abonnée », « Perdue ») sont des **jugements** de l'équipe. Stocker une étape unique saisie à la main laisse le pipeline mentir dès que l'usage change.

Troisième question : qui. La policy existante de gestion des établissements autorise tout membre `team`, `content` compris. La matrice de l'ADR-0038 réserve « Gérer établissements » à `admin` et `field`.

## 2. Moteurs de décision

- Le pipeline ne doit jamais contredire l'usage réel.
- Le contexte `school` ne doit pas apprendre le vocabulaire commercial.
- Livrer en 8 jours ouvrés : réutiliser les lectures d'usage existantes, pas de nouvelle dépendance.
- Préparer les futurs agents : un journal structuré, pas un champ libre.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Colonnes ajoutées à `schools` (étape, responsable) et tables d'échanges dans `school` | Le moins de fichiers | Mélange deux vocabulaires ; `school` devient le fourre-tout de l'espace équipe |
| B — Outil externe (Twenty, tableur) | Rien à coder | ADR-0049 a retiré les outils tiers ; synchronisation à écrire ; pas d'usage réel dans la fiche |
| C — Contexte `crm`, tables à part, étape affichée calculée à la lecture | Vocabulaire isolé, usage réel lu à la source | Un septième contexte à documenter ; une lecture d'usage par école à écrire |
| D — Ouvrir un programme (nouveau contexte construit de zéro) | Ce que `docs/workflows/README.md` suggère pour un contexte neuf | Le contexte tient dans **un seul** graphe de lots : un programme ajouterait des vagues sans objet |

## 4. Décision

> **Nous créons le contexte borné `crm` (septième contexte), avec cinq tables préfixées `crm_` rattachées à `schools` et `users`. L'étape saisie est stockée ; l'étape affichée est calculée à la lecture par une entité pure qui croise la saisie et l'usage. Toute écriture et toute lecture du suivi passent par `Policies::Crm::ManageCrmPolicy`, qui n'admet que `team` en `admin` ou `field`. Les changements d'étape et de responsable sont écrits au journal d'audit.**

**Tables**

| Table | Colonnes métier | Règles |
|---|---|---|
| `crm_accounts` | `school_id` (unique), `stage` ∈ {`prospect`, `demo_done`, `subscribed`, `lost`} (défaut `prospect`), `owner_id` (→ `users`, nul), `lost_reason` ∈ {`price`, `equipment`, `network`, `calendar`, `competitor`, `no_interest`, `other`} (nul), `stage_changed_at` | Créée à la première écriture : son absence vaut `prospect` sans responsable. `CHECK (stage <> 'lost' OR lost_reason IS NOT NULL)` |
| `crm_contacts` | `public_id`, `school_id`, `full_name` (≤ 80), `position` ∈ {`director`, `censor`, `educator`, `teacher`, `founder`, `other`}, `phone` (`^0[157][0-9]{8}$`, nul), `note` (≤ 500), `created_by_id`, `archived_at` | Retrait = `archived_at`, jamais de suppression |
| `crm_interactions` | `public_id`, `school_id`, `author_id`, `kind` ∈ {`call`, `whatsapp`, `visit`, `demo`, `other`}, `occurred_at`, `contact_id` (nul), `contact_name` (copie), `outcome` ∈ {`positive`, `neutral`, `negative`}, `next_step` (≤ 200), `note` (≤ 2000), `source` ∈ {`manual`, `dictation`} | Ajout seul : aucune route de modification ni de suppression |
| `crm_follow_ups` | `public_id`, `school_id`, `assignee_id`, `due_on`, `reason` (≤ 200), `status` ∈ {`open`, `done`}, `done_at`, `done_by_id`, `created_by_id`, `interaction_id` (nul) | Index `(assignee_id, status, due_on)` |
| `crm_generations` | voir ADR-XXXX-modeles-de-langage-par-openrouter | — |

> Liens par identifiant public (Lot 0 bis) : `InteractionRepositoryPort#create(interaction:, contact_public_id: nil)` et `FollowUpRepositoryPort#create(follow_up:, interaction_public_id: nil)` résolvent l'identifiant en interne (même école) ; un identifiant inconnu donne `failure(:not_found)`, jamais un lien nul.

Clés étrangères vers `schools` en `on_delete: :cascade` : une école supprimée emporte son suivi.

**Étape affichée** (ordre de priorité, `today` injecté) :

1. `subscribed` saisie → **Abonnée**
2. activité dans les 14 derniers jours → **Active**
3. `lost` saisie → **Perdue**
4. au moins un compte rattaché → **Inscrite**
5. `demo_done` saisie → **Démo faite**
6. sinon → **Prospect**

« Activité » = dernière `exercise_sessions.started_at` d'un élève placé dans une classe active de l'école, ou dernier `classroom_assignments.assigned_at` d'une classe de l'école. « Compte rattaché » = enseignant (`teacher_schools`), direction (`school_staffs`) ou élève placé, non anonymisé. Mêmes définitions que `Queries::School::TeamDashboardQuery`.

**À relancer** : quatre signaux calculés par une entité pure, chacun avec sa raison — relance échue (`due_on` ≤ aujourd'hui, ouverte), perte d'usage (dernière activité entre 15 et 60 jours), démo sans suite (étape affichée « Démo faite » et aucun échange depuis 7 jours), inscrite sans démarrage (premier rattachement il y a plus de 14 jours, jamais d'activité). Exclus : écoles désactivées, étape affichée « Perdue ».

**Audit** : `crm.stage_changed` (métadonnées : `from`, `to`, `lost_reason`), `crm.owner_changed` (`from`, `to`), ajoutées à `Entities::Identity::AuditAction::ALL`.

## 5. Conséquences

### 🟢 Positives

- `school` reste un référentiel ; le vocabulaire commercial est isolé et supprimable d'un bloc.
- Le pipeline ne peut pas mentir sur l'usage : « Active » et « Inscrite » ne se saisissent pas.
- Le journal structuré (type, résultat, motif, source) est directement exploitable par les assistants et les futurs agents.

### 🔴 Coûts consentis

- Un septième contexte : `docs/guide/conventions.md` §2, `CLAUDE.md` et le glossaire changent.
- L'étape affichée n'est pas une colonne : filtrer la liste par étape impose une sous-requête d'usage par école (coût mesuré au lot du pipeline, cible : requêtes constantes).
- Deux policies voisines (`ManageSchoolPolicy` admet `content`, `ManageCrmPolicy` non) : un écart volontaire à documenter dans les deux en-têtes.
- Pas de modification d'un échange : une faute de frappe se corrige par un nouvel échange.

## 6. Notes d'implémentation

```ruby
# app/domain/policies/crm/manage_crm_policy.rb
module Policies
  module Crm
    class ManageCrmPolicy
      TEAM_ROLES = %w[admin field].freeze

      def call(actor:)
        return Shared::Result.success(actor) if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

```ruby
# app/domain/entities/crm/stage.rb
module Entities
  module Crm
    module Stage
      ACTIVE_WINDOW = 14 # jours

      def self.resolve(saved:, accounts_count:, last_activity_on:, today:)
        return :subscribed if saved == "subscribed"
        return :active if last_activity_on && last_activity_on > today - ACTIVE_WINDOW
        return :lost if saved == "lost"
        return :registered if accounts_count.positive?
        return :demo_done if saved == "demo_done"

        :prospect
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/crm/stage_test.rb` : un cas par ligne de la table de priorité, dont CA-04 et CA-05 du PRD.
- `test/domain/policies/crm/manage_crm_policy_test.rb` : `content`, `teacher`, `student`, `school_admin` et `nil` refusés.
- `test/controllers/teams/crm/*_test.rb` : 403 pour `content` sur chaque route du suivi (CA-01).
- La contrainte `CHECK` sur `lost_reason` est testée par le test du repository des comptes.
- La pureté du domaine `crm` est vérifiée par le pre-commit et la CI existants (aucun `ActiveRecord` sous `app/domain/`).
