# ADR-0031 : Second facteur TOTP pour les comptes `team`, avec codes de secours à usage unique

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-07**, bloque la V1 (Lot 0b) |
| **Complète** | [ADR-0025](./0025-pin-a-4-chiffres-comme-secret-d-authentification.md), compensation 5 |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0025 conserve le PIN à 4 chiffres à la condition d'un second facteur pour les rôles privilégiés, sans en fixer le moyen. Un compte `team` peut modifier tout le contenu et anonymiser n'importe quel compte. Le PRD cadre exige qu'un compte `team` sans second facteur n'accède à aucune page. L'ADR-0010 ne prévoit aucune infrastructure SMS (C-08).

## 2. Moteurs de décision

1. Aucun coût par connexion.
2. Aucun fournisseur externe.
3. Une perte de téléphone ne bloque pas définitivement l'équipe.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Code SMS | Familier | Coût par message, fournisseur à choisir, SIM clonable |
| B — WebAuthn | Le plus robuste | Mal supporté sur les Android d'entrée de gamme (ADR-0051) |
| C — **TOTP (RFC 6238)** | Gratuit, hors ligne, applications courantes | L'utilisateur doit installer une application |

## 4. Décision

> **Nous exigeons un second facteur TOTP à chaque ouverture de session d'un compte `team`, avec dix codes de secours à usage unique, et nous refusons toute page de l'espace équipe tant qu'il n'est pas vérifié.**

**Table `totp_credentials`** (contexte `identity`) :

| Colonne | Contrainte |
|---|---|
| `user_id` | `NOT NULL`, FK `users`, index unique |
| `secret` | chiffré par Active Record Encryption (`encrypts :secret`) |
| `confirmed_at` | `datetime NULL` ; le second facteur n'est actif qu'une fois ce champ posé |
| `last_used_step` | `bigint NULL` ; refuse le rejeu d'un code dans la même fenêtre de 30 s |

**Table `backup_codes`** : `user_id` (FK `users`), `code_digest` (HMAC-SHA256), `used_at` (`datetime NULL`). Index `(user_id) WHERE used_at IS NULL`.

- On en génère 10 à l'activation, de 10 caractères base58.
- Ils ne sont affichés qu'une fois.
- En générer de nouveaux invalide les anciens.

**Parcours** :

1. Après le PIN, un compte `team` dont `confirmed_at` est vide ne voit que la page d'activation : un QR code en SVG en ligne, sans ressource externe (CSP de l'[ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md)).
2. Sinon, il saisit un code TOTP ou un code de secours.
3. Tolérance : ±1 pas de 30 s.
4. Le succès pose `sessions.second_factor_verified_at` (ADR-0050).

**Garde** : `Teams::BaseController` ([ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md)) exige `second_factor_verified_at` présent ; sinon, il redirige vers la vérification. Mission Control (`/teams/jobs`) hérite de cette garde.

**Échecs** :

- `rate_limit to: 5, within: 1.minute` sur la vérification ;
- chaque échec est écrit dans `login_attempts` et compte pour le verrouillage de l'ADR-0050 ;
- use case `Identity::VerifySecondFactor`, erreurs `:invalid` ou `:locked`.

**Perte du téléphone** : un autre membre `team` (sous-rôle `admin` à partir de la V4, ADR-0038) réinitialise le second facteur par `Identity::ResetSecondFactor`. Cela supprime la ligne `totp_credentials`, les codes de secours et les sessions ouvertes, et journalise l'action. Personne ne réinitialise son propre second facteur.

**Journal** (`audit_events`, ADR-0050) : `totp.enrolled`, `totp.reset`, `backup_code.used`.

**Dépendances** : gemmes `rotp` et `rqrcode` (MIT, sans service externe).

## 5. Conséquences

### 🟢 Positives

- La compensation 5 de l'ADR-0025 est tenue sans coût récurrent.
- Le rejeu d'un code intercepté est refusé.

### 🔴 Coûts consentis

- Deux gemmes de plus.
- Le dernier membre de l'équipe qui perd son téléphone et ses codes de secours ne peut être débloqué que par la console Rails en production. La procédure est écrite dans le runbook de la V0.
- Le secret TOTP repose sur la clé d'Active Record Encryption : la perdre invalide tous les seconds facteurs.

## 6. Notes d'implémentation

```ruby
# 🌐 DELIVERY · Teams::BaseController
# Rôle : socle de l'espace équipe — rôle team et second facteur vérifié
# ADR  : 0031, 0052
module Teams
  class BaseController < ApplicationController
    before_action :require_team_role
    before_action :require_verified_second_factor

    private

    def require_verified_second_factor
      redirect_to new_identity_second_factor_path unless Current.session.second_factor_verified_at
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test d'intégration : un compte `team` connecté par PIN seul reçoit une redirection sur **chaque** route `Teams::` (test paramétré sur `Rails.application.routes`).
- Test de use case : un code déjà utilisé au même pas est refusé ; un code de secours ne sert qu'une fois.
- Test de policy : `ResetSecondFactor` refuse la réinitialisation de soi-même.

## 8. Remplace, complète, amende

- **Complète** l'ADR-0025, compensation 5 : moyen fixé, activation, secours, réinitialisation.
- Le cas de `school_admin` (C-20) est tranché par l'ADR-0044.

## 9. Points à confirmer par le porteur

- Le second facteur est demandé à chaque nouvelle session, sans « se souvenir de cet appareil ».

## Amendement du 2026-09-28 — la direction (ADR-0044, ADR-0066, accepté)

*Chantier [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md). Statut : **accepté** par le porteur le 2026-09-28 (avec ses retours), avec l'[ADR-0066](./0066-espace-direction-droits-et-gestes.md). Le texte ci-dessus reste ; en cas d'écart, cette section fait foi.*

- Le régime de cet ADR s'applique **aussi au rôle `school_admin`** (C-20, déjà décidé par l'ADR-0044) : `SessionState#privileged?` (équipe ou direction) remplace `team?` dans `ResolveSession` et `SecondFactorPolicy`. Même activation, même vérification, mêmes codes de secours.
- **Perte du téléphone** : un membre de l'équipe réinitialise le second facteur d'un `school_admin` par `Identity::ResetSecondFactor` (écran « Débloquer un compte », UDR-0020 amendée par l'UDR-0053). Aucun membre de la direction ne réinitialise un second facteur.
- La garde de l'espace direction est celle d'`Authentication` (acteur absent tant que la session n'est pas vérifiée), comme pour `Teams::BaseController`.
