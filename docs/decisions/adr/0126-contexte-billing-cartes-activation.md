# ADR-0126 : L'abonnement passe par des cartes à code dans un contexte borné `billing`
<!-- index
titre: Contexte billing et cartes d'activation
statut: Proposé
problematique: Réserver l'usage aux élèves qui ont payé en espèces chez un point relais, sans paiement en ligne, et tenir les comptes des points relais.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-07 |
| **Chantier** | `docs/chantiers/cartes-activation` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Lnclass doit encaisser avant le 20 novembre 2026. Le paiement Wave dans l'application (`abonnement-mobile-money`) n'a ni compte marchand, ni clés, ni code : il est mis en pause. Les élèves de la DRENA de Tiassalé paient en espèces chez des **points relais** partenaires, qui reversent sur le Wave du porteur deux fois par jour. Il faut donc une preuve d'achat que l'élève apporte lui-même dans l'application : une **carte** portant un code à usage unique. Il faut aussi tenir les comptes : ce que chaque point relais doit, ce que Lnclass doit en commissions (200 F au point relais chaque vendredi, 1 000 F à l'école de l'élève, cumulés), et bloquer le démarrage des exercices après 7 jours gratuits.

Aucun contexte existant ne porte l'argent : `identity` porte les comptes, `school` la structure, `assessment` les séances. Mettre l'abonnement dans l'un d'eux y ferait entrer des points relais, des versements et des commissions qui ne le concernent pas.

## 2. Moteurs de décision

1. Livrable en 4 jours (saisie du code le 11 novembre, blocage le 16).
2. Un code ne doit pas se deviner ni se rejouer : un code deviné est un abonnement volé.
3. L'équipe doit pouvoir réimprimer une planche et retrouver une carte par son numéro.
4. Le domaine ne connaît pas l'ORM ; la garde d'accès ne crée pas de dépendance d'`assessment` vers les tables de `billing`.
5. Rien ne s'efface dans la caisse : une erreur se corrige par une écriture inverse.
6. Les jeux de test (jeu standard, recette, tests système) ne doivent pas casser parce que leurs élèves ont plus de 7 jours.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Activation à la main par l'équipe (chercher l'élève, cocher « payé ») | Aucun code | L'équipe devient le goulot ; impossible de savoir quel point relais a vendu ; aucune dette calculable |
| B — Codes stockés en empreinte (HMAC) seulement, montrés une fois à la création | Une fuite de la base ne livre aucun code | Une planche perdue avant impression ne se réimprime pas ; le lot entier doit être annulé |
| C — **Codes chiffrés de façon déterministe (`encrypts :code, deterministic: true`, clés existantes ADR-0031)** | Recherche par égalité, réimpression possible, illisibles dans une copie de la base sans les clés | Retenue |
| D — Abonnement dans `identity` | Moins de fichiers | `identity` recevrait points relais, versements et commissions |
| E — **Nouveau contexte `billing`** | Frontière nette ; prêt pour Wave plus tard | Retenue |
| F — Une table `subscriptions` séparée des cartes | Prête pour d'autres moyens de paiement | Pour le lancement, la carte activée *est* l'abonnement ; une table de plus à tenir cohérente. À créer quand un 2e moyen de paiement arrive |

## 4. Décision

> **Nous créons le contexte borné `billing`. Une carte d'activation, créée par lot pour un point relais, porte un numéro lisible et un code de 12 caractères chiffré de façon déterministe ; activée par un élève, elle *est* son abonnement jusqu'à la fin fixée par l'offre. L'accès d'un élève (gratuit, abonné, bloqué) se lit par un port de `billing` que `StartExerciseSession` et `CheckPractice` reçoivent en dépendance. La caisse se calcule à la lecture, à partir des cartes et des versements, sans état stocké.**

1. **Tables** (préfixe `billing_`) :
   - `billing_relay_points` : `public_id`, `name`, `location`, `phone`, `active`, horodatages.
   - `billing_relay_point_schools` : `relay_point_id`, `school_id`, index unique sur la paire.
   - `billing_card_batches` : `public_id`, `relay_point_id`, `quantity`, `unit_price_xof` (0 = offert), `valid_until` (date), `created_by_id`, `created_at`.
   - `billing_activation_cards` : `public_id`, `batch_id`, `relay_point_id`, `serial` (entier unique, séquence), `code` (chiffré déterministe, index unique), `price_xof`, `valid_until`, `state` (`issued` · `activated` · `cancelled`, contrainte `CHECK`), `student_id`, `school_id`, `activated_at`, `cancelled_at`, `cancelled_by_id`, `cancel_reason`. Index unique partiel `(student_id, valid_until) WHERE state = 'activated'` : un élève, une carte par année.
   - `billing_remittances` : `public_id`, `relay_point_id`, `amount_xof` (entier signé, ≠ 0), `received_at`, `reference`, `reason`, `recorded_by_id`, `created_at`. Jamais modifiée ni supprimée.
2. **Code** : 12 caractères tirés par `SecureRandom` dans `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (31 signes, sans 0, O, 1, I, L), affiché `XXXX-XXXX-XXXX`, soit 31¹² ≈ 7,9 × 10¹⁷ codes. Saisie normalisée : majuscules, espaces et tirets retirés. Collision à la création : on retire un code.
3. **Activation** dans une transaction, ligne de carte verrouillée (`SELECT … FOR UPDATE`) : refus si `cancelled` (`:invalid`, `:card_cancelled`), `activated` (`:conflict`, `:card_used`), élève déjà abonné pour ce `valid_until` (`:conflict`, `:already_subscribed`). L'école est celle de la classe principale active de l'élève à cet instant (`Queries::School::StudentSchoolQuery`), ou aucune.
4. **Freinage** : `rate_limit to: 5, within: 10.minutes, by: -> { current_user.id }` sur `Billing::ActivationsController#create`, comme `Identity::SessionsController` ; avec 31¹² codes, 5 essais par 10 minutes rendent la devinette impossible.
5. **Accès** : `Entities::Billing::Access.for(account_created_on:, today:, subscribed_until:)` rend `free` (avec `days_left`), `subscribed` ou `blocked`. La période gratuite commence au plus tard de la création du compte et de `Offer::LAUNCH_ON` (2026-11-09) et dure `Offer::FREE_DAYS` (7) jours. Seul le rôle `student` est concerné.
6. **Garde** : `StartExerciseSession` et `CheckPractice` reçoivent `access:` (un `Ports::Billing::StudentAccessPort`) et rendent `Result.failure(:locked, errors: { base: [:subscription_required] })` avant toute écriture quand l'accès est `blocked`. Les contrôleurs appelants redirigent vers Mon abonnement sur ce motif, comme `redirect_paused`.
7. **Caisse** (lecture seule, `Queries::Billing::CashboxQuery`) : par point relais, `dû = Σ price_xof des cartes activées − Σ amount_xof des versements` ; `en circulation = cartes issued`. Commission point relais : 200 F par carte payante activée, par semaine de vendredi 00:00 à jeudi 23:59 (Africa/Abidjan = UTC). Commission école : 1 000 F par carte payante activée avec `school_id`, cumulée. Les montants vivent dans `Entities::Billing::Offer`.
8. **Offre** : `Entities::Billing::Offer` porte `PRICE_XOF = 10_000`, `VALID_UNTIL = Date.new(2027, 7, 31)`, `LAUNCH_ON = Date.new(2026, 11, 9)`, `FREE_DAYS = 7`, `RELAY_COMMISSION_XOF = 200`, `SCHOOL_COMMISSION_XOF = 1_000`. Le prix d'une carte est figé sur la carte à sa création.
9. **Jeux de test** : un lot offert (prix 0) pour un point relais « Lnclass — interne » abonne les élèves du jeu standard ; les fixtures de test fixent `created_at` à « maintenant », donc les élèves des tests sont en période gratuite sauf test explicite.
10. **Journal d'audit** : nouvelles actions `billing.relay_point_saved`, `billing.card_batch_created`, `billing.card_activated`, `billing.card_cancelled`, `billing.remittance_recorded` dans `Entities::Identity::AuditAction::ALL`.

## 5. Conséquences

### 🟢 Positives

- Aucun prestataire de paiement : le lancement ne dépend pas de Wave Business.
- La dette d'un point relais et les commissions se lisent sans saisie de l'élève ni rapprochement manuel.
- Le jour où le paiement Wave arrive, il ajoute un moyen d'abonnement dans `billing` sans toucher la garde.

### 🔴 Coûts consentis

- **La dette ne compte que les cartes activées.** Une carte vendue mais jamais saisie par l'élève reste « en circulation » : l'équipe ne voit pas qu'elle a été vendue. Le rapprochement se fait au retour du stock invendu (annulation, Q11 du memo).
- **Q11 laisse une fraude possible** : un point relais peut vendre une carte puis la déclarer perdue. L'annulation garde l'auteur, la date et le motif ; l'élève lésé se signale. Choix du porteur contre l'avis de Claude.
- Les codes sont lisibles par quiconque a la base **et** les clés de chiffrement.
- La fin d'abonnement est une constante : l'offre de l'année suivante demandera un changement de code.
- Une séance déjà ouverte avant le blocage continue (le blocage porte sur le démarrage, pas sur la réponse).

## 6. Notes d'implémentation

```ruby
# app/domain/entities/billing/access.rb
module Entities
  module Billing
    Access = Data.define(:status, :days_left, :subscribed_until) do
      def self.for(account_created_on:, today:, subscribed_until:)
        return new(status: :subscribed, days_left: nil, subscribed_until:) if subscribed_until && subscribed_until >= today

        starts_on = [ account_created_on, Offer::LAUNCH_ON ].max
        days_left = Offer::FREE_DAYS - (today - starts_on).to_i
        days_left.positive? ? new(status: :free, days_left:, subscribed_until: nil) : new(status: :blocked, days_left: 0, subscribed_until: nil)
      end

      def blocked? = status == :blocked
    end
  end
end
```

```ruby
# app/domain/use_cases/assessment/start_exercise_session.rb — début de #call, après la policy
return Shared::Result.failure(:locked, errors: { base: [ :subscription_required ] }) if @access.call(student_id: actor.id, at: @clock.now).blocked?
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/billing/access_test.rb` : bornes du 7e et du 8e jour, compte antérieur à la mise en ligne, abonné.
- `test/domain/use_cases/assessment/start_exercise_session_test.rb` et `test/domain/use_cases/catalog/check_practice_test.rb` : un accès `blocked` rend `:locked` / `:subscription_required` sans rien écrire.
- `test/infrastructure/repositories/billing/card_repository_test.rb` : index unique du code, de `(student_id, valid_until)` actif, contrainte `CHECK` de l'état.
- `test/controllers/billing/activations_controller_test.rb` : le 6e essai en 10 minutes est refusé.
- Le pre-commit et la CI refusent tout `Orm::` dans `app/domain/billing`.
