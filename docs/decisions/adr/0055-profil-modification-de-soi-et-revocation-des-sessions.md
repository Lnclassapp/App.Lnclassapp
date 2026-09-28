# ADR-0055 : Chaque utilisateur modifie son propre compte sous PIN actuel, et un changement de PIN ou de numéro ferme ses autres sessions

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-27 |
| **Chantier** | `docs/chantiers/profil-utilisateur` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La page profil (décision du porteur du 2026-09-27) permet à chaque compte de modifier son nom, son numéro et son PIN. Le numéro est l'identifiant de connexion, le PIN le secret (ADR-0025) ; aucun SMS ne vérifie un numéro. Un téléphone est parfois partagé ou prêté. Le domaine a déjà `UpdateSelfPolicy` (sans appelant), `UserRepositoryPort#update_pin`, `SessionRepositoryPort#destroy_all_for` et un journal d'audit à liste fermée d'actions.

## 2. Moteurs de décision

1. Un appareil resté connecté ne doit pas suffire à détourner un compte.
2. Une faute de frappe dans le nouveau numéro ne doit pas enfermer l'utilisateur hors de son compte.
3. Ne jamais révéler qu'un numéro a un compte (même règle que la connexion).
4. Aucune table nouvelle ; réutiliser les ports existants.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Modifier sans revérifier le PIN | Plus rapide | Un téléphone prêté suffit à changer le numéro et le PIN : prise de compte |
| B — PIN actuel exigé, double saisie, autres sessions fermées | Répond aux trois premiers moteurs | Retenue |
| C — Vérification du numéro par SMS | La plus sûre pour le numéro | Pas de fournisseur SMS en V1 ; coût par envoi ; hors périmètre du memo |

## 4. Décision

> **Nous exigeons le PIN actuel et une double saisie pour changer de numéro ou de PIN ; un échec de PIN compte comme un échec de connexion ; un changement réussi ferme toutes les autres sessions du compte et renouvelle la session en cours ; le nom se modifie librement mais chaque changement est tracé.**

- Trois use cases du contexte `identity` : `UpdateOwnName`, `ChangeOwnContact`, `ChangeOwnPin`. Chacun appelle `UpdateSelfPolicy` en premier et rend un `Shared::Result` (ADR-0026, ADR-0028).
- Méthodes ajoutées aux ports existants :
  - `UserRepositoryPort#update_name(user_id:, first_name:, last_name:)` → true ;
  - `UserRepositoryPort#update_contact(user_id:, contact:)` → `Result` ; `:conflict` si le numéro appartient à un autre compte (index unique existant) ;
  - `SessionRepositoryPort#destroy_all_except(user_id:, keep_id:)` → Integer.
- La vérification du PIN actuel passe par `UserRepositoryPort#authenticate` et `LoginAttemptRepositoryPort` : même comptage, même verrouillage que la connexion (ADR-0025, ADR-0050).
- Nouvelles actions d'audit : `profile.name_changed` (ancien et nouveau nom), `contact.changed` (ancien et nouveau numéro masqués sauf les deux derniers chiffres), `pin.changed` (aucune donnée). Aucun PIN n'entre jamais dans les métadonnées.
- Un numéro déjà pris donne `:conflict` dans le domaine, mais le message affiché est neutre : « Ce numéro ne peut pas être utilisé. ».
- Après un changement de numéro ou de PIN, le contrôleur rouvre la session par `start_session` (nouveau jeton, nouveau nonce CSP, rechargement de la page d'arrivée, ADR-0049).

## 5. Conséquences

### 🟢 Positives

- Un compte ne se détourne pas avec un appareil resté connecté : il faut le PIN, et l'ancien appareil perd l'accès.
- Aucune migration ; trois méthodes de port, testées par leurs adaptateurs.
- Le journal d'audit permet à l'équipe de retrouver qui était qui après un changement de nom ou de numéro.

### 🔴 Coûts consentis

- Sans SMS, rien ne prouve que le nouveau numéro appartient à l'utilisateur : une faute sur deux saisies identiques reste possible ; le recours est le déblocage par l'équipe (lot B8).
- Un élève peut se renommer librement : l'enseignant voit le nouveau nom sans validation ; seul l'audit en garde la trace.
- Un utilisateur qui change son PIN sur un appareil est déconnecté de tous les autres, y compris ceux qu'il voulait garder.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/identity/change_own_pin.rb (esquisse)
allowed = @policy.call(actor:, target: user)
return allowed if allowed.failure?
return invalid unless dto.valid?
return wrong_pin unless @users.authenticate(contact: user.contact, pin: dto.current_pin)
@users.update_pin(user_id: user.id, pin: dto.new_pin)
@sessions.destroy_all_except(user_id: user.id, keep_id: session.id)
@audit_log.record(action: "pin.changed", actor_id: user.id, at: @clock.now)
```

## 7. Comment vérifier que la décision est respectée

- Tests de domaine des trois use cases : refus de la policy, PIN faux compté, double saisie, numéro pris, numéro ou PIN inchangé, succès et appel de `destroy_all_except`.
- Tests d'adaptateur : `update_contact` rend `:conflict` sur un numéro pris ; `destroy_all_except` garde la session donnée et elle seule.
- Test de contrôleur : aucun PIN dans le journal d'audit ni dans la réponse ; message neutre sur un numéro pris.
- Test système : changement de PIN dans un navigateur, puis l'ancienne session d'un second navigateur ramène à la connexion.

## Amendement du 2026-09-28 — le matricule de l'élève (ADR-0065, accepté)

*Chantier [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md). Statut : **accepté** par le porteur le 2026-09-28 (avec ses retours), avec l'[ADR-0065](./0065-matricule-de-l-eleve.md). Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- L'élève modifie aussi son **matricule** depuis son profil (`Identity::ChangeOwnStudentNumber`), sous son **PIN actuel** vérifié comme ici (un PIN faux compte comme un échec de connexion). Personne d'autre ne modifie un matricule.
- Le matricule n'est pas un secret d'authentification : son changement **ne ferme pas** les autres sessions et ne renouvelle pas la session en cours. Il est tracé (`student_number.changed`, matricules masqués) et borné à 10 tentatives par heure et par compte.
