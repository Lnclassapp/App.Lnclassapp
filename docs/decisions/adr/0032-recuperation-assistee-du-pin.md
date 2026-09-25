# ADR-0032 : Récupération assistée du PIN par un code à usage unique de 15 minutes

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-08**, bloque la V1 (Lot 0b) |
| **Complète** | [ADR-0025](./0025-pin-a-4-chiffres-comme-secret-d-authentification.md), compensation 6 |
| **Amende** | [ADR-0002](./0002-authentification-native-contact-telephonique-sans-devise.md) §4 (récupération par SMS) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0002 §4 prévoit une récupération par SMS ; l'ADR-0025 la rend obligatoire sans en fixer le moyen ; l'ADR-0010 n'a aucune infrastructure SMS (**C-08**).

Dans l'ancien dépôt, un PIN oublié est un compte perdu. Un secret court est oublié plus souvent, pas moins.

## 2. Moteurs de décision

1. Un élève récupère son compte sans e-mail, sans SMS et sans coût.
2. Le code de récupération ne se devine pas et ne se rejoue pas.
3. Chaque récupération laisse une trace.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — SMS | Autonome | Coût, fournisseur à choisir (C-08) |
| B — Question secrète | Autonome | Réponses devinables entre camarades |
| C — **Réinitialisation assistée** | Gratuite ; l'enseignant connaît l'élève | Dépend d'un tiers disponible |

## 4. Décision

> **Nous faisons générer par l'enseignant de la classe, ou par l'équipe, un code de récupération à usage unique valable 15 minutes, que l'élève saisit avec un nouveau PIN.**

**Table `pin_recovery_codes`** (contexte `identity`) :

| Colonne | Contrainte |
|---|---|
| `user_id` | `NOT NULL`, FK `users` : le compte à récupérer |
| `issued_by_id` | `NOT NULL`, FK `users` |
| `code_digest` | `NOT NULL`, HMAC-SHA256 du code, clé tirée de `secret_key_base` |
| `expires_at` | `NOT NULL` ; création + 15 min |
| `failed_attempts` | `integer NOT NULL DEFAULT 0` |
| `used_at`, `revoked_at` | `datetime NULL` |

Index unique partiel `(user_id) WHERE used_at IS NULL AND revoked_at IS NULL` : un seul code actif par compte. En émettre un nouveau révoque le précédent.

**Émission** (`Identity::IssuePinRecoveryCode`, policy `Identity::IssuePinRecoveryCodePolicy`) :

| Émetteur | Comptes récupérables |
|---|---|
| `teacher` | les élèves d'une classe `active` qu'il enseigne (`teacher_classrooms`) |
| `team` | tout compte `student`, `teacher` ou `school_admin` ; un autre compte `team`, jamais le sien |

Le code fait 8 chiffres et n'est affiché qu'une fois à l'émetteur, qui le transmet de vive voix.

**Utilisation** (`Identity::ResetPinWithCode`, use case anonyme) : l'élève saisit son contact, le code, puis deux fois le nouveau PIN (`/\A\d{4}\z/`, ADR-0050).

Contact inconnu, code faux ou révoqué : `:invalid`, même message dans tous les cas. Code périmé : `:expired`. 5 échecs sur un code le révoquent. `rate_limit to: 5, within: 1.minute` par IP.

**Succès**, dans une seule transaction : PIN mis à jour, `used_at` posé, toutes les `sessions` du compte supprimées, verrouillage remis à zéro (ADR-0050).

**Journal** (`audit_events`) : `pin.recovery_code_issued` (acteur : l'émetteur), `pin.reset` (acteur : le compte).

**SMS** : reporté à une vague ultérieure, quand un fournisseur sera choisi par ADR. Le parcours assisté restera le recours.

## 5. Conséquences

### 🟢 Positives

- Plus aucun compte perdu, sans coût ni fournisseur.
- 10⁸ codes possibles, 5 essais, 15 minutes : la force brute est hors de portée.
- Toutes les sessions sont coupées : un camarade qui connaissait l'ancien PIN est déconnecté.

### 🔴 Coûts consentis

- L'élève dépend d'un enseignant ou de l'équipe : aucune récupération le soir, en autonomie.
- Un enseignant peut prendre le contrôle du compte d'un élève de sa classe. Le journal rend l'abus visible, sans l'empêcher.
- Un élève sans classe active passe par l'équipe.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · UseCases::Identity::IssuePinRecoveryCode (extrait de `call`)
# Rôle : émet un code de récupération du PIN, à usage unique, valable 15 minutes
# ADR  : 0032
def call(actor:, target_public_id:)
  target = @user_repository.find_by_public_id(target_public_id) or return Shared::Result.failure(:not_found)
  decision = @policy.call(actor:, target:)
  return decision if decision.failure?

  code = @code_generator.call # 8 chiffres
  @recovery_code_repository.replace_active(user_id: target.id, issued_by_id: actor.user_id, code:, expires_at: @clock.now + TTL)
  @audit_log.record(actor_id: actor.user_id, action: "pin.recovery_code_issued", subject: target)
  Shared::Result.success(code)
end
```

## 7. Comment vérifier que la décision est respectée

- Tests de use case : un code périmé donne `:expired` ; un code déjà utilisé et un cinquième échec donnent `:invalid` ; un succès vide les sessions.
- Tests de policy : un enseignant refusé pour l'élève d'une autre classe ; `team` refusé pour son propre compte.
- Test de repository : deux codes actifs pour un même compte lèvent `RecordNotUnique`.

## 8. Remplace, complète, amende

- **Complète** l'ADR-0025, compensation 6.
- **Amende** l'ADR-0002 §4 : le SMS n'est plus le moyen de la V1 (C-08).

## 9. Points à confirmer par le porteur

- Le code fait 8 chiffres, pour être dicté facilement.
- L'enseignant peut récupérer le compte de tout élève d'une classe qu'il a déclarée.
