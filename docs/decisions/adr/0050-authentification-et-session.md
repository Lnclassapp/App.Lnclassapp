# ADR-0050 : Contact à 10 chiffres normalisé, authentification par un use case, sessions en base régénérées, verrouillage progressif et journal d'audit
<!-- index
titre: Contact à 10 chiffres normalisé, authentification par un use case, sessions en base régénérées, verrouillage progressif et journal d'audit
statut: Accepté — *remplace 0002 §3.2, §3.3, §5*
problematique: Préfixes `01/05/07`, normalisation `225`/`00225` ; `Identity::Authenticate` ; `reset_session` + table `sessions` ; verrouillage 5/10/20 ; `audit_events`. F-28.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-28**, bloque la V1 (Lot 0b) |
| **Remplace** | [ADR-0002](./0002-authentification-native-contact-telephonique-sans-devise.md) §3.2, §3.3 et §5 ; §1 pour la mention de Wave |
| **Complète** | [ADR-0025](./0025-pin-a-4-chiffres-comme-secret-d-authentification.md), compensations 1 à 4 |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0002 §5 accepte un contact de 10 à 15 chiffres, et son §1 cite Wave, qui n'a pas de préfixe propre. Le code exige exactement 10 chiffres et trois préfixes (**C-22**). L'ADR-0002 §3.3 annonce une rotation de session que le code ne fait pas ; le PRD cadre exige `reset_session` (**C-23**). `/teachers/prepa_acquisitions` crée des comptes dont le PIN est le contact, et la page de connexion affiche le PIN en clair (**C-21**). Le contrôleur de connexion lit l'ORM directement. L'ADR-0025 exige limitation de débit, verrouillage progressif journalisé, validation serveur du PIN et aucune dérivation depuis le contact. Le PRD : « 6 connexions échouées → refus ».

## 2. Moteurs de décision

1. Un seul format de contact, le même partout.
2. Une session volée ou partagée se coupe côté serveur.
3. Une attaque par force brute est lente et visible.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Session en cookie seul | Natif | Impossible de déconnecter un appareil (après une récupération de PIN, ADR-0032) |
| B — **Table `sessions` (générateur d'authentification Rails 8) + `reset_session`** | Révocable, traçable | Une écriture par connexion |

## 4. Décision

> **Nous normalisons le contact en 10 chiffres, nous authentifions par `Identity::Authenticate`, nous stockons les sessions en base avec un cookie régénéré à chaque connexion et déconnexion, et nous verrouillons progressivement après des échecs journalisés.**

**Contact** : `Entities::Identity::Contact.normalize` retire tout ce qui n'est pas un chiffre, puis un préfixe `00225` (15 chiffres) ou `225` (13 chiffres), et exige `/\A0[157]\d{8}\z/`.

Colonne `users.contact` : `string(10)`, index unique partiel `WHERE contact IS NOT NULL` (ADR-0036).

**PIN** : `/\A\d{4}\z/`, validé par `Dtos::Identity::CredentialsInput` et par l'entité. Stocké par `has_secure_password :pin` (bcrypt), jamais en clair.

Un PIN vide est une erreur de validation ; aucun parcours ne le dérive du contact ; aucune page ne l'affiche, connexion comprise (`type="password"`, `inputmode="numeric"`).

**Authentification** : `Identity::SessionsController#create` construit le DTO et appelle `UseCases::Identity::Authenticate`, qui renvoie `success(user)`, `failure(:invalid)` (même message pour un contact inconnu et un PIN faux) ou `failure(:locked, errors: { retry_after: })`.

Le contrôleur, au succès : `reset_session`, création d'une ligne `sessions`, cookie signé `session_token` (`httponly`, `secure`, `same_site: :lax`). À la déconnexion : suppression de la ligne, puis `reset_session`.

**Table `sessions`** : `user_id` (FK `cascade`), `token_digest` (index unique), `ip_address`, `user_agent`, `created_at`, `last_seen_at`, `second_factor_verified_at` (ADR-0031).

Expiration : 30 jours d'inactivité ; 12 h d'ancienneté pour `team` et `school_admin`.

**Limitation et verrouillage** :

- `rate_limit to: 5, within: 1.minute` par IP sur la connexion.
- Table `login_attempts` : `contact` normalisé ou brut, `user_id NULL`, `ip_address`, `succeeded`, `kind` (`pin` ou `second_factor`), `created_at`. Index `(contact, created_at)`.
- Les échecs **consécutifs** depuis le dernier succès du contact verrouillent : 5 échecs → 15 min ; 10 → 1 h ; 20 → verrouillé jusqu'à récupération assistée (ADR-0032).
- La 6ᵉ tentative, même juste, est refusée par `:locked`.

**Journal d'audit** : table `audit_events` (contexte `identity`) avec `actor_id` (FK `users` `NULL`), `action` (liste fermée dans `Entities::Identity::AuditAction`), `subject_type`, `subject_id`, `metadata` (`jsonb`, sans secret), `ip_address`, `created_at`. Index `(subject_type, subject_id)` et `(actor_id, created_at)`. Écrit par `Ports::Identity::AuditLogPort`. Action propre à cet ADR : `login.locked`.

## 5. Conséquences

### 🟢 Positives

- C-21, C-22 et C-23 sont fermées ; les compensations 1 à 4 de l'ADR-0025 sont tenues.
- Toute session se révoque côté serveur : récupération de PIN, anonymisation, départ de la direction.
- Premier journal d'audit du projet, commun à tous les ADR de fondation.

### 🔴 Coûts consentis

- Une écriture en base par connexion et par échec.
- Un attaquant peut verrouiller le compte d'un élève dont il connaît le numéro : c'est le prix du verrouillage, compensé par la récupération assistée.
- Les numéros étrangers et Wave sans préfixe ivoirien sont refusés.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Identity::Contact
# Rôle : normalise un numéro ivoirien en 10 chiffres, ou renvoie nil
# ADR  : 0050
module Entities
  module Identity
    module Contact
      FORMAT = /\A0[157]\d{8}\z/

      def self.normalize(raw)
        digits = raw.to_s.gsub(/\D/, "")
        digits = digits.delete_prefix("00225") if digits.length == 15
        digits = digits.delete_prefix("225") if digits.length == 13
        digits if digits.match?(FORMAT)
      end
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test unitaire : `+225 07 12 34 56 78` et `002250712345678` donnent `0712345678` ; `0212345678` donne `nil`.
- Test d'intégration du PRD : 5 échecs, puis le bon PIN à la 6ᵉ tentative, donnent un refus.
- Test d'intégration : l'identifiant de session Rails change à la connexion.
- `test/system/no_pin_displayed_test.rb` : aucune page ne contient le PIN saisi.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0002 §3.2, §3.3, §5 et la mention de Wave au §1 (C-22, C-23).
- **Complète** l'ADR-0025, compensations 1 à 4 (C-21).

## 9. Points à confirmer par le porteur

- Paliers de verrouillage : 5, 10 et 20 échecs.
- Durées de session : 30 jours, et 12 h pour les rôles privilégiés.
