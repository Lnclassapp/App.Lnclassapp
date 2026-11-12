# ADR-XXXX : Une date de fin de bêta, seul réglage de l'offre, ouvre l'accès gratuit et redonne 7 jours à la fermeture

<!-- index
titre: Accès bêta, réglage unique
statut: Accepté
problematique: rendre l'accès élève gratuit et sans blocage pendant la bêta, réversible en un seul point, sans bloquer d'un coup les inscrits de la bêta
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

L'ADR-0126 (contexte billing) donne à l'élève 7 jours gratuits à partir du plus tard de la création de son compte et du 9 novembre 2026, puis le bloque : `UseCases::Assessment::StartExerciseSession` et `UseCases::Catalog::CheckPractice` refusent avec `:subscription_required`, et l'accueil affiche un bandeau « Il te reste N jours… Abonne-toi ». Le porteur lance une bêta : pendant la bêta, l'élève a l'accès complet gratuit. Il faut pouvoir revenir à l'offre payante sans réécrire de code. Décision du porteur du 2026-11-12 : à la fermeture, la mise en ligne de l'offre (`LAUNCH_ON`) est reportée à la fin de la bêta, pour que chaque élève inscrit pendant la bêta reçoive ses 7 jours gratuits au lieu d'être bloqué aussitôt. La date de fin n'est pas encore connue.

## 2. Moteurs de décision

- Un seul point à changer pour rallumer l'abonnement, sans code supprimé.
- Le domaine reste en Ruby pur (pas de lecture de l'environnement).
- Le plus petit diff : aucun port, aucune table, aucun contrôleur touché.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Constante `Offer::BETA_ENDS_ON` (date de fin, `nil` tant qu'elle n'est pas fixée), lue par `Access.for` | une ligne ; elle ferme la bêta et reporte le départ des 7 jours en même temps ; posable à l'avance | — retenue |
| A′ — Booléen `BETA_OPEN_ACCESS` (première version de la PR) | une ligne | à la fermeture il fallait aussi déplacer `LAUNCH_ON` : deux points à changer ensemble, ou des inscrits bloqués d'un coup |
| B — Variable d'environnement (Railway) | basculer sans déploiement | le domaine lirait `ENV`, ou cinq contrôleurs passeraient le drapeau ; une variable oubliée sur un environnement de PR change le comportement en silence |
| C — Retirer le bandeau et les deux refus | le plus direct | du code supprimé à réécrire après la bêta, trois points au lieu d'un |
| D — `FREE_DAYS` porté à 10 000 | aucune ligne nouvelle | le bandeau afficherait « Il te reste 9 990 jours » ; détournement d'une valeur métier |

## 4. Décision

> **Nous ajoutons `Entities::Billing::Offer::BETA_ENDS_ON = nil`. Tant qu'il vaut `nil`, ou avant la date qu'il porte, `Access.for` rend le statut `:beta` à tout élève non abonné : jamais bloqué, jamais invité à s'abonner. Un élève abonné reste `:subscribed` avec sa date. Pour fermer la bêta, on y écrit la date de fin et on déploie (au plus tard ce jour-là) : la règle d'ADR-0126 revient, les 7 jours gratuits partant du plus tard de la création du compte, de `LAUNCH_ON` et de `BETA_ENDS_ON`.**

## 5. Conséquences

### 🟢 Positives

- Un seul point de bascule ; le bandeau, les refus et la carte de Mon abonnement suivent le statut.
- Aucun port, contrôleur ou use case modifié : leur contrat (`blocked?`) est intact.

### 🔴 Coûts consentis

- Rouvrir l'abonnement exige un déploiement (pas de bascule à chaud) ; la date peut être posée à l'avance, la bêta se ferme alors seule ce jour-là.
- À la fermeture, tous les élèves non abonnés passent ensemble en période gratuite : le bandeau « Il te reste 7 jours » apparaît pour tous le même jour.
- Un statut de plus (`:beta`) que toute vue lisant `Access#status` doit traiter ; `subscription_pending?` le cache pour le bandeau.
- Les tests d'après-bêta ferment la bêta au jour de `LAUNCH_ON` (règle d'ADR-0126 exacte) par échange de constante (`BillingBetaHelper`), sûr parce que la suite tourne en processus, pas en threads.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/billing/offer.rb
BETA_ENDS_ON = nil # fermer la bêta : Date.new(AAAA, M, J)

# app/domain/entities/billing/access.rb
def self.for(account_created_on:, today:, subscribed_until:, beta_ends_on: Offer::BETA_ENDS_ON)
  return new(status: :subscribed, days_left: nil, subscribed_until:) if subscribed_until && subscribed_until >= today
  return new(status: :beta, days_left: nil, subscribed_until: nil) if beta_ends_on.nil? || today < beta_ends_on

  starts_on = [ account_created_on, Offer::LAUNCH_ON, beta_ends_on ].max
  # … règle d'ADR-0126 inchangée
end

def subscription_pending? = status == :free || status == :blocked
```

## 7. Comment vérifier que la décision est respectée

- `test/integration/billing/free_period_test.rb` : `BillingBetaAccessTest` vérifie que le réglage livré est ouvert, que l'accueil n'a ni bandeau ni lien, que séance et entraînement passent, qu'une fin de bêta posée redonne 7 jours à partir d'elle puis bloque, et qu'en refermant le réglage le même élève est de nouveau bloqué.
- `test/domain/entities/billing/access_test.rb` : statut `:beta`, abonné prioritaire, `subscription_pending?`, 7 jours à partir de la fin de bêta pour un compte ancien ou créé pendant la bêta.
- Les tests d'après-bêta (`BillingFreePeriodTest`, contrôleurs billing, `StudentAccessQueryTest`) ferment le réglage : ils échouent si la règle d'origine dérive.
