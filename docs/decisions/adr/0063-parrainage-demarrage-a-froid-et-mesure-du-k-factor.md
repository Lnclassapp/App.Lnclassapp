# ADR-0063 : Parrainage par lien personnel, démarrage à froid par le code national et k-factor mesuré côté serveur
<!-- index
titre: Parrainage par lien personnel, démarrage à froid par le code national et k-factor mesuré côté serveur
statut: Accepté *(2026-09-28)*
problematique: `referrals` (filleul unique, source lien ou garant), `referral_shares` au clic, jeton `teacher_profiles.referral_token` tiré par la base ; `schools.national_code` facultatif et unique ; `school_join_requests` validées par l'équipe ou un garant ; `GrowthMetricsQuery` sur `/teams/growth`. Amende ADR-0057 et ADR-0030.
-->

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, défauts compris)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/croissance-parrainage`](../../chantiers/croissance-parrainage/prd.md) — critères CP-01 à CP-18 |
| **Remplace** | — *(amende [ADR-0057](./0057-code-d-etablissement.md) et [ADR-0030](./0030-une-ecole-par-enseignant-et-creation-des-classes.md))* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur vise un k-factor enseignant de 2 (memo du chantier : k = invitations par utilisateur × conversion). Depuis l'ADR-0057, un enseignant ne s'inscrit qu'avec le code secret de son établissement, transmis par l'équipe. Il manque trois choses :

1. **Attribuer** une inscription à l'enseignant qui l'a provoquée, et compter les invitations, sans traceur ni cookie (ADR-0049).
2. **Démarrer** un établissement dont personne n'a reçu le code. Le code national (6 chiffres, publié avec les résultats du BEPC) désigne l'établissement mais ne prouve rien : il est public.
3. **Mesurer** k, sa décomposition et sa vitesse, dans l'espace équipe, sans toucher à `/teams/dashboard` (chantier `pilotage-equipe`, ADR-0062).

## 2. Moteurs de décision

1. Aucune donnée ne quitte l'application : pas de pixel, pas de raccourcisseur, pas de cookie en plus de la session (ADR-0049).
2. Le lien de parrainage n'expose ni le numéro ni l'identifiant public du parrain.
3. Un compte créé sans code secret n'accède à **rien** tant qu'une personne de confiance ne l'a pas validé.
4. Un parrainage frauduleux (jeton collé sur un autre établissement) ne s'enregistre pas, et ne bloque pas l'inscription.
5. Chaque indicateur se relit depuis les tables, en un nombre de requêtes borné.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Colonne `users.referred_by_id` | Une colonne, une jointure | Ne dit ni **quand**, ni **comment** (lien ou garant), ni **pour quel établissement** ; alourdit `users`, partagé par tous les rôles |
| B — **Table `referrals`** (parrain, filleul unique, établissement, source, date) | Source et date lisibles par les métriques ; unicité du filleul par index ; `users` inchangé | Retenue — une table de plus |
| C — Jeton = `public_id` du parrain | Aucune colonne | Interdit par la demande : un identifiant exposé ailleurs (ADR-0029) |
| D — **Jeton aléatoire par enseignant, tiré par la base** (`teacher_profiles.referral_token`) | Tous les chemins d'écriture (inscription, seeds, fabriques) en reçoivent un sans changement ; l'existant est rempli par la migration | Retenue — voir coûts : le domaine ne tire pas ce jeton |
| E — Compter les clics par un paramètre `utm` lu à l'arrivée | Rien à écrire au clic | On ne sait rien des partages qui ne convertissent pas : *i* et *c* deviennent inconnus |
| F — **Événement serveur au clic** (`referral_shares`), envoyé par `navigator.sendBeacon` sur la session | Mesure *i* ; le lien de partage s'ouvre même si l'envoi échoue | Retenue |
| G — Compte en attente = rôle ou statut sur `users` | Lisible partout | Toucherait la contrainte des rôles et chaque requête ; or « enseignant sans école principale » mène **déjà** à l'écran d'attente (ADR-0030) |
| H — **Table `school_join_requests`**, sans rattachement tant qu'elle n'est pas validée | Réutilise l'écran d'attente existant ; état, décision, auteur et voie tracés | Retenue |

## 4. Décision

> **Chaque enseignant a un jeton de parrainage opaque ; son lien est `/e/<code d'établissement>?ref=<jeton>`. Une inscription par ce lien enregistre une ligne `referrals` si le parrain enseigne dans l'établissement actif du code. Un clic « Partager » enregistre une ligne `referral_shares`. Le code national, facultatif et unique, désigne un établissement pour une inscription en attente (`school_join_requests`), validée par l'équipe ou par un garant du même établissement, qui devient parrain. Les indicateurs sont lus par `Queries::Identity::GrowthMetricsQuery` sur `/teams/growth`.**

### Schéma

| Table / colonne | Contrainte |
|---|---|
| `teacher_profiles.referral_token` | `string(12) NOT NULL DEFAULT substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)`, index unique, `CHECK (referral_token ~ '^[0-9a-f]{12}$')` — 48 bits aléatoires |
| `referrals` | `referrer_id` → users, `referee_id` → users **unique**, `school_id` → schools, `source` ∈ {`link`, `sponsor`}, `created_at` ; `CHECK (referrer_id <> referee_id)` ; index `(referrer_id)`, `(created_at)` |
| `referral_shares` | `user_id` → users, `channel` ∈ {`whatsapp`, `sms`, `copy`, `native`}, `created_at` ; index `(user_id, created_at)`, `(created_at)` |
| `schools.national_code` | `string(6) NULL`, index unique **partiel** (`WHERE national_code IS NOT NULL`), `CHECK (national_code ~ '^[0-9]{6}$')` |
| `school_join_requests` | `public_id` (14) unique, `teacher_id` → users **unique**, `school_id` → schools, `status` ∈ {`pending`, `approved`, `rejected`}, `decided_at`, `decided_by_id` → users, `decided_via` ∈ {`team`, `sponsor`} ; `CHECK ((status = 'pending') = (decided_at IS NULL))` ; index `(school_id, status)` |

Clés étrangères en `ON DELETE RESTRICT`, comme les autres références à `users` (anonymisation, jamais de suppression physique, ADR-0036). Aucune adresse IP, aucun agent utilisateur dans ces tables.

### Attribution (`Identity::RegisterTeacher`)

- `GET /e/:code?ref=…` : le jeton, normalisé (`Entities::Identity::ReferralToken`), voyage dans un **champ caché** du formulaire ; mal formé, il est ignoré. Aucun cookie, aucune session avant l'inscription.
- Dans la transaction d'inscription, après le rattachement : `referrals.find_referrer(token:)` → `Referrer(user_id, school_id, school_active)` ; parrainage enregistré (`source: "link"`) **seulement si** `school_id` = l'établissement du code et `school_active`. Sinon rien, sans erreur.

### Partage (`Identity::RecordReferralShare`)

- `POST /teachers/invite/shares` (`channel`) → 204, sur la session ; policy `Identity::InviteColleaguePolicy` : enseignant dont l'établissement principal est **actif**.
- Déclenché par `navigator.sendBeacon` au clic (WhatsApp, SMS), après la copie (Copier) ou le partage natif (Partager…). Le lien `wa.me` / `sms:` est un vrai lien : sans JavaScript, il s'ouvre, sans être compté.

### Démarrage à froid (`Identity::RegisterPendingTeacher`)

- `GET/POST /teacher-signup/without-code` : même formulaire que l'inscription, l'établissement désigné par le **code national** ou par la DRENA puis l'établissement (liste publique existante `/drenas/:id/schools`, UDR-0024).
- Établissement inconnu, inactif ou en brouillon : la même erreur. **Au plus 5 demandes en attente par établissement** (`Entities::School::JoinRequest::MAX_PENDING_PER_SCHOOL`). Envoi limité à 5 par minute et par adresse.
- Une transaction : compte enseignant (profil, matière), demande `pending`, session. **Aucune ligne `teacher_schools`** : l'acteur n'a pas d'école, `HomeDestination` le mène à l'écran d'attente (ADR-0030, inchangé).
- **Garde** : dans les espaces connectés, un enseignant sans école principale est renvoyé vers l'écran d'attente, sauf l'écran lui-même et la déconnexion.

### Validation

- **Équipe** (`School::ReviewJoinRequest`, `School::ManageSchoolPolicy`) : `approve` rattache (`attach_teacher` principal) ; `reject` refuse ; la demande passe de `pending` à l'état décidé par un `UPDATE … WHERE status = 'pending'` (une décision concurrente → `:conflict`). Audit `school.changed`, `change: "join_request_approved"` / `"join_request_rejected"`.
- **Garant** (`School::VouchForTeacher`, `School::VouchPolicy`) : enseignant actif (établissement actif) du **même** établissement, qui n'est pas le demandeur. Même écriture que l'approbation, `decided_via: "sponsor"`, puis `referrals` `source: "sponsor"` si le filleul n'a pas déjà un parrain. Audit `change: "join_request_vouched"`.

### Mesure (`Queries::Identity::GrowthMetricsQuery#call(from:, to:)`)

| Indicateur | Définition |
|---|---|
| `shares` | partages créés dans `[from, to)` |
| `teacher_signups` / `referred_signups` | enseignants créés / parrainages créés dans la période |
| `conversion_rate` | `referred_signups ÷ shares` (nil sans partage ; peut dépasser 1) |
| `viral` | **cohorte** = enseignants créés dans la période ; `i` = partages de la cohorte ÷ cohorte ; `c` = filleuls de la cohorte ÷ partages de la cohorte ; **`k` = filleuls de la cohorte ÷ cohorte** (= i × c dès qu'il y a des partages) — `Entities::Identity::ViralCoefficient` |
| `viral_cycle_days` | médiane (`percentile_cont(0.5)`) de `referee.created_at − referrer.created_at`, parrainages de la période |
| `top_referrers` | 5 premiers parrains de la période |
| `students_joined`, `students_per_teacher` | élèves entrés dans une classe dans la période ; ÷ enseignants actifs (école principale) |
| `schools_leaderboard` | 10 établissements ayant le plus d'enseignants actifs (équipe seulement) |
| `pending_requests` | nombre de demandes en attente et les 5 plus anciennes |

Quatre requêtes, quel que soit le volume (les compteurs en une seule, par sous-requêtes scalaires). Page `/teams/growth` (`Teams::GrowthController`, `Identity::ReadGrowthPolicy`), liée depuis l'accueil équipe, **aucune entrée de navigation** (UDR-0006 : 5 destinations).

### Leviers sans argent

- Badge **Ambassadeur** à 3 filleuls (`Entities::Identity::Ambassador::THRESHOLD`), sur le profil et le bloc d'invitation.
- Classement des établissements : équipe seulement en V1.
- Toute récompense monétaire : hors périmètre, décision du porteur.

## 5. Conséquences

### 🟢 Positives

- *i*, *c*, k et le cycle viral se lisent chaque semaine, sans traceur ni bandeau.
- Un établissement que l'équipe n'a pas atteint peut démarrer ; les suivants s'y inscrivent par garant ou par lien, sans l'équipe.
- L'écran d'attente et la liste publique DRENA → établissement retrouvent un usage.

### 🔴 Coûts consentis

- **Le code secret circule davantage** : chaque enseignant actif le diffuse dans son lien. **Régénérer le code (ADR-0057) casse aussi tous les liens de parrainage** de l'établissement ; les enseignants doivent repartager.
- **Un seul garant suffit** : un enseignant peut valider un inconnu. La trace d'audit nomme le garant ; l'équipe retire l'enseignant par les gestes existants.
- **Le jeton est tiré par la base, pas par le domaine** (écart à la règle de l'ADR-0057 §2.5) : il ne porte aucun sens métier, et la valeur par défaut couvre l'inscription, les seeds, les fabriques et l'existant sans toucher un seul chemin d'écriture. Ajouter la colonne réécrit `teacher_profiles` (valeur par défaut volatile) : table petite, verrou bref.
- **Un partage n'est pas un destinataire** : *c* par partage peut dépasser 100 %. La page le dit.
- **k de cohorte incomplet** pour les cohortes récentes : un filleul peut arriver après la fin de la période ; la page affiche le cycle viral pour savoir combien attendre.
- Le compteur de partages repose sur `sendBeacon` : un navigateur sans JavaScript partage sans être compté (sous-estimation de *i*, surestimation de *c*).
- **Tout enseignant sans école principale** perd l'accès au catalogue et au profil (garde générale) : c'était l'intention de l'écran d'attente, désormais appliquée.
- Le démarrage à froid n'existe que pour un établissement déjà en base.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/identity/viral_coefficient.rb
module Entities
  module Identity
    ViralCoefficient = Data.define(:cohort_size, :shares, :referees) do
      def invitations_per_user = cohort_size.zero? ? nil : shares.fdiv(cohort_size)
      def conversion_rate = shares.zero? ? nil : referees.fdiv(shares)
      def k = cohort_size.zero? ? nil : referees.fdiv(cohort_size)
    end
  end
end
```

Migrations : `20260928150000_create_referrals.rb` (jeton, `referrals`, `referral_shares`), `20260928150100_add_national_code_to_schools.rb` (sans transaction DDL, index `CONCURRENTLY`, `CHECK` posée `NOT VALID` puis validée), `20260928150200_create_school_join_requests.rb`.

Import `lnclass.schools` v1 : clé facultative `national_code` (chaîne ou nombre, espaces retirés) ; mal formée → `invalid_value` ; déjà en base ou deux fois dans le fichier → `national_code_taken`, à la ligne ; les autres lignes s'importent.

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` : jeton (format, unicité, défaut), `referrals` (filleul unique, pas d'auto-parrainage, source), `referral_shares.channel`, `schools.national_code` (format, unicité partielle), `school_join_requests` (statut ↔ date de décision).
- `test/db/growth_migrations_test.rb` : les profils existants reçoivent un jeton distinct ; les établissements existants gardent leurs données.
- `test/domain/use_cases/identity/register_teacher_test.rb` : parrain valide, jeton d'un autre établissement, établissement inactif.
- `test/domain/use_cases/identity/register_pending_teacher_test.rb`, `test/domain/use_cases/school/review_join_request_test.rb`, `test/domain/use_cases/school/vouch_for_teacher_test.rb` : limites, garant, concurrence, audit.
- `test/infrastructure/queries/identity/growth_metrics_query_test.rb` : chaque indicateur, et le nombre de requêtes.
- `test/controllers/teams/growth_controller_test.rb`, `test/controllers/identity/referral_shares_controller_test.rb` : 403 des autres rôles.
- `test/integration/content_security_policy_test.rb` (existant) et `test/views/no_third_party_resources_test.rb` (existant) restent verts : `wa.me` n'est qu'un lien sortant.

## 8. Remplace, complète, amende

- **Amende l'ADR-0057** : le code secret est aussi diffusé par les liens de parrainage des enseignants actifs ; la régénération les invalide.
- **Amende l'ADR-0030** : un enseignant sans école principale n'accède qu'à l'écran d'attente ; le démarrage à froid le crée ainsi.
- **Complète l'ADR-0049** : premiers indicateurs de croissance, lus côté serveur.

## Amendement du 2026-09-28 — retour du challenger (916b6e01 KO)

*Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- **Suppression d'un établissement** : une demande d'enseignant (même décidée) ou un parrainage le référencent ; la suppression répond `:conflict` (« désactivez-le plutôt »), jamais une violation de clé étrangère.
- **Plafond des demandes en attente** : `JoinRequestRepositoryPort#create(…, max_pending:)` verrouille la ligne de l'école (`SELECT … FOR UPDATE`) jusqu'à la fin de la transaction d'inscription, puis compte et insère. Douze inscriptions simultanées n'en laissent que cinq en attente (test de concurrence). Le compte est créé avant : « trop de demandes » ne se lit qu'au bout d'un formulaire entièrement valide, et l'annule.
- **Oracle du code national** : le formulaire est validé, puis la matière, et seulement ensuite l'établissement désigné.
- **Garant** : une demande d'un autre établissement répond 404, comme une demande inconnue. Côté équipe, une demande ne se décide que depuis la fiche de son établissement (404 sinon).
- **Partages** : 30 par heure et par compte ; un enseignant en attente reçoit 403 (pas l'écran d'attente), un enseignant sans profil (sans jeton) n'est pas compté (`referral_token_for`).
- **Mesure** : inscriptions et cohorte excluent les comptes en attente ou refusés ; la conversion par partage et le *c* de la cohorte ne comptent que les parrainages **par lien** (k = i × c) ; les parrainages par garant restent dans « dont parrainées » ; le classement ignore les établissements non actifs.

## Amendement du 2026-09-28 — décision du porteur sur la saturation (M1)

- **La limite de 5 demandes en attente par établissement est gardée.** Le risque est connu : les codes nationaux sont publics et le numéro n'est pas vérifié, donc un tiers peut occuper les 5 places d'un établissement (5 par minute et par IP au rythme de la limite de débit).
- **Parade prévue, hors de ce chantier** : vérifier le numéro par WhatsApp via un hook n8n avant qu'une demande n'entre dans la file. Elle fera l'objet de son propre chantier et de son ADR.

## Amendement du 2026-10-02 — validation en pause (ADR-0073)

*Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- Une inscription sans code crée la demande **et la valide aussitôt** (`decided_via: "auto"`, sans décideur) : l'enseignant est rattaché et arrive sur la sélection de ses classes. Les demandes encore en attente ont été validées de la même façon au déploiement. Voir l'[ADR-0073](0073-validation-des-enseignants-en-pause.md).
