# ADR-XXXX : Un seul réglage de l'offre ouvre l'accès complet gratuit pendant la bêta

<!-- index
titre: Accès bêta, réglage unique
statut: Accepté
problematique: rendre l'accès élève gratuit et sans blocage pendant la bêta, réversible en un seul point
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-12 |
| **Chantier** | `docs/chantiers/acces-beta` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0126 (contexte billing) donne à l'élève 7 jours gratuits à partir du plus tard de la création de son compte et du 9 novembre 2026, puis le bloque : `UseCases::Assessment::StartExerciseSession` et `UseCases::Catalog::CheckPractice` refusent avec `:subscription_required`, et l'accueil affiche un bandeau « Il te reste N jours… Abonne-toi ». Le porteur lance une bêta : pendant la bêta, l'élève a l'accès complet gratuit. Il faut pouvoir revenir à l'offre payante sans réécrire de code.

## 2. Moteurs de décision

- Un seul point à changer pour rallumer l'abonnement, sans code supprimé.
- Le domaine reste en Ruby pur (pas de lecture de l'environnement).
- Le plus petit diff : aucun port, aucune table, aucun contrôleur touché.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Constante `Offer::BETA_OPEN_ACCESS`, lue par `Access.for` | une ligne, à côté des 7 jours gratuits ; testable par argument | — retenue |
| B — Variable d'environnement (Railway) | basculer sans déploiement | le domaine lirait `ENV`, ou cinq contrôleurs passeraient le drapeau ; une variable oubliée sur un environnement de PR change le comportement en silence |
| C — Retirer le bandeau et les deux refus | le plus direct | du code supprimé à réécrire après la bêta, trois points au lieu d'un |
| D — `FREE_DAYS` porté à 10 000 | aucune ligne nouvelle | le bandeau afficherait « Il te reste 9 990 jours » ; détournement d'une valeur métier |

## 4. Décision

> **Nous ajoutons `Entities::Billing::Offer::BETA_OPEN_ACCESS = true`. Tant qu'il vaut `true`, `Access.for` rend le statut `:beta` à tout élève non abonné : jamais bloqué, jamais invité à s'abonner. Un élève abonné reste `:subscribed` avec sa date. Après la bêta, on passe la constante à `false` et on déploie : la règle d'ADR-0126 revient telle quelle.**

## 5. Conséquences

### 🟢 Positives

- Un seul point de bascule ; le bandeau, les refus et la carte de Mon abonnement suivent le statut.
- Aucun port, contrôleur ou use case modifié : leur contrat (`blocked?`) est intact.

### 🔴 Coûts consentis

- Rouvrir l'abonnement exige un déploiement (pas de bascule à chaud).
- À la fermeture, les élèves inscrits pendant la bêta sont bloqués aussitôt, sauf si l'on déplace aussi `Offer::LAUNCH_ON` (écrit dans `## À trancher` du journal).
- Un statut de plus (`:beta`) que toute vue lisant `Access#status` doit traiter ; `subscription_pending?` le cache pour le bandeau.
- Les tests d'après-bêta ferment le réglage par échange de constante (`BillingBetaHelper`), sûr parce que la suite tourne en processus, pas en threads.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/billing/offer.rb
BETA_OPEN_ACCESS = true

# app/domain/entities/billing/access.rb
def self.for(account_created_on:, today:, subscribed_until:, beta: Offer::BETA_OPEN_ACCESS)
  return new(status: :subscribed, days_left: nil, subscribed_until:) if subscribed_until && subscribed_until >= today
  return new(status: :beta, days_left: nil, subscribed_until: nil) if beta
  # … règle d'ADR-0126 inchangée
end

def subscription_pending? = status == :free || status == :blocked
```

## 7. Comment vérifier que la décision est respectée

- `test/integration/billing/free_period_test.rb` : `BillingBetaAccessTest` vérifie que le réglage livré est ouvert, que l'accueil n'a ni bandeau ni lien, que séance et entraînement passent, et qu'en refermant le réglage le même élève est de nouveau bloqué.
- `test/domain/entities/billing/access_test.rb` : statut `:beta`, abonné prioritaire, `subscription_pending?`.
- Les tests d'après-bêta (`BillingFreePeriodTest`, contrôleurs billing, `StudentAccessQueryTest`) ferment le réglage : ils échouent si la règle d'origine dérive.
