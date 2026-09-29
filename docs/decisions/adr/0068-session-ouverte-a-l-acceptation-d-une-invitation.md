# ADR-0068 : L'acceptation d'une invitation ouvre la session de la personne invitée

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-29 |
| **Chantier** | [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md) — réponse n° 4 du porteur (2026-09-29), critères FU-30 à FU-33 |
| **Complète** | [ADR-0050](./0050-authentification-et-session.md) (points d'entrée d'une session) |
| **Amende** | [ADR-0065](./0065-espace-direction-simple-en-lecture-seule.md) (« Connexion » de la direction) · [UDR-0019](../udr/0019-invitation-equipe.md) §2.4 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Un compte `team` (ADR-0038) ou `school_admin` (ADR-0065) naît seulement d'une invitation. Aujourd'hui, la personne invitée ouvre le lien, choisit son nom et son PIN, puis `Identity::InvitationsController#accept` la **renvoie vers « Se connecter »** sans ouvrir de session (UDR-0019 §2.4). Elle doit alors ressaisir son numéro — qu'on ne lui a jamais montré, puisque la page d'acceptation ne le demande pas — et le PIN qu'elle vient de choisir. Vérifié le 2026-09-29 dans le code : `accept` fait `redirect_to new_session_path` et le use case `UseCases::Identity::AcceptInvitation` ne crée aucune session.

Le porteur a décidé le 2026-09-29 que la validation du formulaire **connecte immédiatement**. L'inscription enseignant (`RegisterTeacher`) et l'inscription élève (`JoinWithCode`) ouvrent déjà leur session dans la même transaction que la création du compte ; l'acceptation d'une invitation est le seul parcours de création qui ne le fait pas.

Deux contraintes restent : le second facteur est obligatoire pour l'équipe (ADR-0031), et l'identifiant de session est régénéré à chaque ouverture (ADR-0050).

## 2. Moteurs de décision

1. Aucune ressaisie : la personne vient de prouver qu'elle détient le lien et de choisir son PIN.
2. Le second facteur de l'équipe ne doit pas être contourné.
3. Un seul motif d'ouverture de session pour tous les parcours de création de compte.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Statu quo : « Se connecter » après l'acceptation | Aucun changement d'architecture | Contredit la décision du porteur ; la personne ressaisit un numéro qu'on ne lui a pas montré |
| B — Pré-remplir le numéro sur « Se connecter » (flash chiffré ou cookie éphémère) | Ne change pas l'authentification | Garde une ressaisie du PIN ; fait transiter le numéro hors de la page ; ne répond pas à « connexion immédiate » |
| **C — Ouvrir la session dans le use case d'acceptation**, comme `RegisterTeacher` | Motif déjà en place ; aucune nouvelle table ni nouveau port ; le second facteur reste exigé par `ResolveSession` | Retenue — voir coûts consentis |

## 4. Décision

> **Nous ouvrons la session de la personne invitée dans la transaction qui accepte l'invitation. Pour un compte `team`, la session naît sans second facteur vérifié : elle ne mène qu'à l'enrôlement, exactement comme après une connexion par PIN.**

- `UseCases::Identity::AcceptInvitation` reçoit le port de sessions existant (`Repositories::Identity::SessionRepository`, déjà injecté dans `RegisterTeacher`) et prend `ip:` et `user_agent:` dans `#call`.
- `#call` renvoie `success(Accepted(user:, token:))` au lieu de `success(User)`. Les échecs (`:not_found`, `:expired`, `:invalid`, `:conflict`) sont inchangés. `#check` est inchangé.
- La session est créée **après** l'écriture du compte, du rattachement (direction) et du marquage de l'invitation, dans la même transaction : un échec n'ouvre aucune session.
- `Identity::InvitationsController#accept`, au succès : `start_session(accepted.token)` (reset de la session Rails, nouveau cookie, rechargement du document pour le nonce CSP), puis `redirect_to_home` avec le toast du rôle. Équipe : `current_actor` est `nil` tant que le TOTP n'est pas vérifié, donc `redirect_to_home` mène à `new_identity_second_factor_enrollment_path`. Direction : « Travail des élèves ».
- Une personne déjà connectée sur l'appareil (autre compte) : sa session est remplacée, comme à l'inscription enseignant. Le journal d'audit garde `invitation.accepted` ; aucune nouvelle action d'audit (une session ouverte par inscription n'en écrit pas non plus).
- Le débit reste limité à 5 requêtes par minute et par adresse (inchangé).

## 5. Conséquences

### 🟢 Positives

- Le parcours de la personne invitée perd une page et une ressaisie ; le numéro, montré en lecture seule sur le formulaire (UDR-0054 §3.8), sert au gestionnaire de mots de passe.
- Tous les parcours de création de compte ouvrent leur session de la même façon.
- Le second facteur de l'équipe reste exigé par le même garde (`require_verified_second_factor`), sans code nouveau.

### 🔴 Coûts consentis

- **Un lien intercepté donne une session directement**, sans connaître le numéro. Avant, l'intercepteur devait aussi deviner le numéro invité pour se connecter. Pour l'équipe, la session s'arrête à l'enrôlement du second facteur, que l'intercepteur peut toutefois mener à bien avec son propre téléphone : le risque est celui du lien lui-même (72 h, montré une fois, `no-store`), inchangé en nature. Pour la direction (sans second facteur, ADR-0065), l'intercepteur lit l'établissement ; il le pouvait déjà en se connectant après avoir accepté, à condition de connaître le numéro.
- **Le numéro invité apparaît sur la page d'acceptation** : un lien qui fuit révèle aussi un numéro de téléphone.
- Le contrat de retour d'`AcceptInvitation` change : ses tests et le contrôleur changent dans le même lot.

## 6. Notes d'implémentation

Motif repris de `app/domain/use_cases/identity/register_teacher.rb` :

```ruby
# app/domain/use_cases/identity/register_teacher.rb (existant, à reprendre tel quel)
def open_session(user, ip, user_agent, now)
  token = Entities::Identity::SecretDigest.generate_token
  @sessions.create(user_id: user.id, token_digest: Entities::Identity::SecretDigest.hmac(token, key: @digest_key),
                   ip:, user_agent:, at: now)
  token
end
```

Contrôleur, au succès (motif de `Identity::TeacherRegistrationsController#create`) :

```ruby
# app/controllers/identity/invitations_controller.rb (cible)
success: lambda { |accepted|
  start_session(accepted.token)
  redirect_to_home notice: t(accepted.user.role == "school_admin" ? ".accepted_school_admin" : ".accepted"), status: :see_other
}
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/identity/accept_invitation_test.rb` : au succès, une session est créée pour le compte créé et le jeton est renvoyé ; en échec (`:invalid`, `:conflict`, `:expired`), aucune session n'est créée.
- `test/controllers/identity/invitations_controller_test.rb` : l'identifiant de session Rails change ; une invitation `team` mène à l'enrôlement du second facteur, une invitation de direction à `school_admin_classrooms_path` ; un accès à `/teams` avant l'enrôlement redirige vers l'enrôlement.
- `test/system/identity/team_invitation_test.rb` : de l'ouverture du lien à la page d'enrôlement, sans passer par « Se connecter ».

## 8. Remplace, complète, amende

- **Complète** l'ADR-0050 : l'acceptation d'une invitation est un point d'entrée de session, au même titre que la connexion et les inscriptions.
- **Amende** l'ADR-0065, section « Connexion » : la première session d'une direction s'ouvre à l'acceptation ; les suivantes, par téléphone et PIN.
- **Amende** l'UDR-0019 §2.4 (« aucune session n'est ouverte »), par son amendement du 2026-09-29.
