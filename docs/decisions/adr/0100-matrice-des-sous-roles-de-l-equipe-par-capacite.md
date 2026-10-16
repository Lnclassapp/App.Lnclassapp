# ADR-0100 : Les policies de l'équipe testent une capacité, lue dans une matrice unique du domaine qui couvre toutes les pages de l'équipe
<!-- index
titre: Sous-rôles de l'équipe appliqués par capacité, matrice unique et complète
statut: Proposé — amende 0038 (§4, matrice) et 0031 (§4, réinitialisation du TOTP)
problematique: 21 policies testent `team?` sans le sous-rôle ; une douzaine de pages livrées après l'ADR-0038 n'ont pas de ligne dans sa matrice ; aucun moyen de changer un sous-rôle. Capacités nommées, `Actor#may?`, `Identity::ChangeTeamRole`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/sous-roles-equipe`](../../chantiers/sous-roles-equipe/memo.md) |
| **Amende** | [ADR-0038](0038-comptes-de-l-equipe-et-sous-roles.md) §4 (matrice de la V4 : lignes ajoutées, forme du contrôle) · [ADR-0031](0031-second-facteur-totp-pour-l-equipe.md) §4 (réinitialisation du TOTP : `admin` seul) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0038 a créé `users.team_role` (`admin`, `content`, `field`) dès la V1 et fixé une matrice de neuf lignes, à appliquer en V4. En V1, toute policy de l'équipe testait `actor.team?`. Le 2026-10-16, l'état est le suivant :

- **6 policies** lisent déjà le sous-rôle, chacune avec sa propre constante `TEAM_ROLES` : `InviteTeamPolicy`, `DeleteUserPolicy` (admin) ; `ManageArticlesPolicy` (admin, content ; amendement ADR-0074) ; `InviteSchoolStaffPolicy`, `RemoveSchoolStaffPolicy`, `RestoreSchoolStaffPolicy` (admin, field).
- **21 policies** laissent passer tout `team?`, dont `ResetSecondFactorPolicy` (n'importe quel membre réinitialise le TOTP d'un autre) et `ReadUserPolicy` (numéro de tout compte). Mission Control (`/teams/jobs`) n'a que la garde de `Teams::BaseController`.
- **Douze pages** livrées après l'ADR-0038 n'ont pas de ligne dans sa matrice : Pilotage, Croissance, validation des enseignants en attente, code d'établissement, barème, génération, ajout, retrait et archivage des classes, illustrations d'annonce, demandes de suppression, modération des annonces (question Q9 de la feuille de route).
- **Aucun use case** ne change un sous-rôle : l'action d'audit `team_role.changed` existe sans émetteur.
- La navigation (`NavigationHelper::DESTINATIONS[:team]`) et l'accueil de l'équipe montrent les mêmes entrées à tous.

Recopier une constante `TEAM_ROLES` dans 21 policies de plus répartirait la matrice dans 27 fichiers : impossible à relire d'un coup d'œil, impossible à tester d'un seul test paramétré, et chaque nouvelle page devrait se souvenir de la règle.

## 2. Moteurs de décision

1. **Le moindre privilège** (ADR-0038 §2) : chaque membre n'a que ce que son travail exige ; les données nominatives de mineurs ne sont lues que par qui en a besoin.
2. **Une matrice lisible en un seul endroit**, du domaine, en Ruby pur, que le test de la porte de V4 parcourt case par case.
3. **Les policies restent les gardiennes** (ADR-0028) : la vue masque, la policy refuse ; masquer ne remplace jamais refuser.
4. **Aucune migration** : `team_role` existe et ses contraintes aussi.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une constante `TEAM_ROLES` par policy (le motif actuel des 6) | Déjà dans le code, local à chaque policy | 27 copies de la matrice ; aucun endroit pour la lire ; une nouvelle page oublie la règle sans que rien ne casse |
| B — **Capacités nommées, matrice unique `Entities::Identity::TeamCapabilities`, `Actor#may?(capacité)`** | Une table lisible, un test paramétré exhaustif, des policies d'une ligne ; la vue lit le même booléen | Une indirection de plus ; une capacité trop large regroupe des gestes que le porteur voudra peut-être séparer un jour |
| C — Garde par contrôleur (`allow_team_roles :admin, :field` dans `Teams::*Controller`) | Simple à poser | Contourne les policies du domaine (ADR-0028) ; ne couvre pas les pages hors de `Teams::` (classes, annonces, déblocage du PIN) |
| D — Table de permissions en base | Souple | Écartée par l'ADR-0038 (option C) : surdimensionné pour une équipe de quelques personnes |

## 4. Décision

> **Nous nommons une liste fermée de capacités de l'équipe, nous fixons dans `Entities::Identity::TeamCapabilities` la seule matrice capacité → sous-rôles, et toute policy qui laisse passer l'équipe teste `actor.may?(:capacité)` au lieu de `actor.team?`. Un admin change le sous-rôle d'un autre membre par `Identity::ChangeTeamRole`.**

### 4.1 La matrice

*Elle remplace la matrice de l'ADR-0038 §4 et son amendement « Blog » (ADR-0074), qu'elle reprend. ✅ autorisé. Lignes marquées « Q n » : recommandation en attente de la réponse du porteur (memo, question n).*

| Capacité | Gestes couverts | `admin` | `content` | `field` |
|---|---|---|---|---|
| `manage_team` | inviter un membre ; changer le sous-rôle d'un autre membre ; réinitialiser son second facteur (Q4, Q5) | ✅ | | |
| `erase_accounts` | anonymiser un compte élève ; enregistrer, annuler, lister les demandes de suppression | ✅ | | |
| `supervise_jobs` | Mission Control, `/teams/jobs` (Q4) | ✅ | | |
| `manage_content` | créer, modifier, publier, archiver cours, fiches, exercices ; importer cours, fiches, exercices | ✅ | ✅ | |
| `manage_taxonomy` | niveaux, séries, matières, liens niveau × série | ✅ | ✅ | |
| `manage_blog` | articles et leurs images (ADR-0074) | ✅ | ✅ | |
| `manage_illustrations` | bibliothèque d'illustrations d'annonce (ADR-0081) (Q2) | ✅ | ✅ | |
| `manage_schools` | DRENA ; établissements (modifier, désactiver, supprimer, importer) ; code d'établissement ; barème ; génération, ajout, retrait, archivage, restauration des classes et des niveaux ; créer une classe ; valider ou refuser un enseignant en attente ; inviter, retirer, restaurer une direction (Q2) | ✅ | | ✅ |
| `read_people` | lire un compte nominatif (« Débloquer un compte », recherche du Pilotage) ; émettre un code de récupération du PIN ; pages de classe, élèves, suivis et assignations vus par l'équipe ; sessions d'exercice d'un élève (Q3) | ✅ | | ✅ |
| `moderate_announcements` | modérer et retirer l'annonce d'un autre auteur (Q10) | ✅ | | ✅ |
| `publish_announcements` | publier une annonce nationale ou d'un établissement (ADR-0045) | ✅ | ✅ | ✅ |
| `read_indicators` | Pilotage (indicateurs agrégés), Croissance (ADR-0049, ADR-0062, ADR-0063) (Q2) | ✅ | ✅ | ✅ |
| `read_catalog` | tout le catalogue, brouillons et archivés compris ; corrigés des exercices | ✅ | ✅ | ✅ |

Treize capacités, trente-neuf cases, **treize cases vides** : chacune a son test de refus (§7).

### 4.2 La forme du contrôle

- `Entities::Identity::TeamCapabilities::MATRIX` est un `Hash` gelé `Symbol => Array<String>` ; `allows?(team_role, capability)` lève `ArgumentError` sur une capacité inconnue (une faute de frappe ne refuse pas en silence, elle casse le test).
- `Entities::Identity::Actor#may?(capability)` : `team? && TeamCapabilities.allows?(team_role, capability)`. Un acteur qui n'est pas de l'équipe reçoit toujours `false` ; les règles des autres rôles restent dans leurs branches.
- Une policy remplace `actor.team?` (ou sa constante `TEAM_ROLES`) par `actor.may?(:capacité)`. Les six constantes `TEAM_ROLES` existantes disparaissent.
- Un refus de sous-rôle donne **`:forbidden`** (403), comme un refus de rôle. Il n'est pas maquillé en `:not_found` : le membre sait que la page existe.
- Mission Control : `config.mission_control.jobs.base_controller_class` passe à `Teams::JobsBaseController`, qui hérite de `Teams::BaseController` et refuse sans `supervise_jobs`.
- La vue ne reçoit jamais le sous-rôle : le contrôleur lui passe des booléens tirés des policies (`can_manage_content`, …), comme l'accueil le fait déjà (UDR-0067 §3.1). Le shell filtre ses entrées par la capacité attachée à chaque destination (UDR-0116).

### 4.3 Changer un sous-rôle

- Use case `Identity::ChangeTeamRole` (`actor:`, `target_public_id:`, `team_role:`), policy `Policies::Identity::ChangeTeamRolePolicy` : `actor.may?(:manage_team)` et `target.id != actor.user_id`, sinon `:forbidden`.
- Cible absente, anonymisée ou hors de l'équipe : `:not_found`. Sous-rôle hors de `User::TEAM_ROLES` : `:invalid`.
- Même sous-rôle : succès sans écriture ni journal.
- Rétrograder le **dernier admin non anonymisé** : `:conflict` (invariant de l'ADR-0038 §4). Le comptage et la mise à jour se font dans une transaction qui verrouille les lignes `users` des admins (`SELECT … FOR UPDATE`), pour que deux rétrogradations croisées ne laissent pas l'équipe sans admin.
- Journal : `team_role.changed`, `subject_id` = la cible, `metadata: { from:, to: }`.
- Prise d'effet : à la requête suivante de la cible, l'acteur étant relu en base à chaque requête (`UserRepository#actor_for`). Aucune session n'est fermée.

### 4.4 Membres existants

Aucune donnée n'est migrée : chaque membre garde le sous-rôle choisi à son invitation. Avant le déploiement, le porteur relit la liste des comptes `team` (lecture seule par la console) et fait corriger, après le déploiement, tout sous-rôle erroné par l'écran du §4.3 (Q7).

## 5. Conséquences

### 🟢 Positives

- La porte de la V4 devient un test : la matrice se parcourt case par case.
- Le contenu ne voit plus aucun numéro d'élève ; le terrain ne touche plus au catalogue ; seul un admin réinitialise un second facteur ou relance un job.
- Une nouvelle page de l'équipe choisit une capacité existante, ou en ajoute une par amendement de cet ADR : la question « qui voit quoi » ne peut plus être oubliée.
- L'écran d'invitation dit vrai.

### 🔴 Coûts consentis

- **Un membre invité « Contenu » ou « Terrain » perd des accès au déploiement**, sans préavis applicatif ; le porteur prévient les personnes (Q7).
- Une capacité groupe des gestes : `manage_schools` couvre à la fois la suppression d'un établissement et la validation d'un enseignant. Séparer l'un de l'autre demandera un amendement.
- Les pages hors de `Teams::` (classes, annonces, déblocage du PIN, catalogue) changent aussi : le chantier touche les contextes `classroom`, `communication`, `catalog`, `assessment` et `school`, pas seulement `identity`.
- Le dernier admin qui perd son téléphone et ses codes de secours reste débloqué par la console seule (ADR-0031 §5, inchangé).
- Le shell porte une capacité par entrée : une donnée de plus dans `NavigationHelper`.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/identity/team_capabilities.rb
# 🧠 DOMAINE · Entities::Identity::TeamCapabilities
# Rôle : seule matrice capacité → sous-rôles de l'équipe ; lue par Actor#may?
# ADR  : 0038, 0100
module Entities
  module Identity
    module TeamCapabilities
      ALL = %w[admin content field].freeze
      MATRIX = {
        manage_team: %w[admin], erase_accounts: %w[admin], supervise_jobs: %w[admin],
        manage_content: %w[admin content], manage_taxonomy: %w[admin content], manage_blog: %w[admin content],
        manage_illustrations: %w[admin content],
        manage_schools: %w[admin field], read_people: %w[admin field], moderate_announcements: %w[admin field],
        publish_announcements: ALL, read_indicators: ALL, read_catalog: ALL
      }.freeze

      def self.allows?(team_role, capability) = MATRIX.fetch(capability).include?(team_role)
    end
  end
end
```

```ruby
# app/domain/entities/identity/actor.rb (ajout)
def may?(capability) = team? && TeamCapabilities.allows?(team_role, capability)
```

```ruby
# app/domain/policies/catalog/manage_content_policy.rb (après)
def call(actor:)
  return Shared::Result.success if actor&.may?(:manage_content)

  Shared::Result.failure(:forbidden)
end
```

```ruby
# app/controllers/teams/jobs_base_controller.rb
# 🌐 DELIVERY · Teams::JobsBaseController
# Rôle : socle de Mission Control (/teams/jobs) ; équipe vérifiée et capacité supervise_jobs (admin)
# ADR  : 0031, 0052, 0100
module Teams
  class JobsBaseController < BaseController
    before_action { render_forbidden unless current_actor.may?(:supervise_jobs) }
  end
end
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/identity/team_capabilities_test.rb` : la matrice a exactement les treize capacités du §4.1 ; chaque case (39) a son assertion ; une capacité inconnue lève `ArgumentError`.
- **Un test de refus par case vide**, au niveau de la policy concernée (13 cases, plusieurs policies par case).
- `test/integration/teams/sub_role_matrix_test.rb` : parcourt les routes `GET` de `config/routes/teams.rb` (Mission Control compris) avec un membre de chaque sous-rôle, second facteur vérifié ; attend 200 ou 403 selon la capacité de la route, déclarée dans le test. Une route ajoutée sans capacité déclarée fait échouer le test.
- `grep -rn "actor&\?\.team?" app/domain/policies` ne renvoie plus que `SecondFactorPolicy` (qui protège la session elle-même) : vérifié dans le test d'architecture du lot E.
- `test/domain/use_cases/identity/change_team_role_test.rb` : soi-même `:forbidden` ; non-admin `:forbidden` ; dernier admin `:conflict` ; cible enseignant `:not_found` ; même sous-rôle sans journal ; succès journalisé.

## 8. Remplace, complète, amende

- **Amende l'ADR-0038 §4** : la matrice de la V4 est celle du §4.1 (lignes ajoutées, contrôle par capacité). L'invariant « au moins un admin », le second facteur pour tout sous-rôle et l'absence de « gestionnaire DRENA » sont inchangés.
- **Amende l'ADR-0031 §4** : la réinitialisation du second facteur d'un autre membre exige `manage_team` (admin), ce que l'ADR prévoyait « à partir de la V4 ».
- Reprend l'amendement « Blog » de l'ADR-0074 sous la capacité `manage_blog`, sans en changer la règle.
- Les ADR-0044 et 0077 (invitation, retrait, restauration de la direction par `admin` ou `field`) sont inchangés : leur règle devient `manage_schools`.

## 9. Points à confirmer par le porteur

Les questions 1 à 10 du [memo](../../chantiers/sous-roles-equipe/memo.md#ce-que-le-grill-a-révélé). Cet ADR reste `Proposé` jusqu'à leurs réponses ; toute réponse différente de la recommandation modifie le §4.1 avant le Lot 0.
