# PRD — Cartes d'activation vendues au point relais

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass doit encaisser avant le 20 novembre 2026 sans paiement en ligne. L'élève utilise l'application 7 jours gratuitement, puis achète 10 000 F en espèces, chez un point relais partenaire, une carte portant un code qui l'abonne jusqu'au 31 juillet 2027. L'équipe crée les cartes, les remet aux points relais, saisit les versements reçus sur Wave et lit ce que chacun doit et ce qu'elle doit en commissions (200 F au point relais chaque vendredi, 1 000 F à l'école de l'élève, cumulés). Détail et grill : [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir ses jours gratuits restants ou la fin de son abonnement ; saisir un code ; voir les points relais de son école | Démarrer une séance d'exercice ni une vérification de fiche après sa période gratuite sans carte activée ; activer une 2e carte pour la même année ; activer une carte annulée ou déjà activée |
| Team | Créer et modifier les points relais et leurs écoles ; créer un lot de cartes pour un point relais (payant ou offert) ; imprimer un lot ; annuler une carte non activée ; saisir un versement ; lire la caisse (dû, commissions) | Annuler une carte activée ; modifier ou supprimer un versement (on saisit un versement correctif négatif) |
| Teacher, SchoolStaff | Rien de nouveau : ils ne sont jamais bloqués et ne voient pas qui a payé (memo Q10) | — |
| Parent | Hors périmètre (memo Q13) | — |

Règles d'autorisation : `Policies::Billing::ManageBillingPolicy` (rôle `team`, second facteur déjà exigé par `Teams::BaseController`) ; `Policies::Billing::ActivateCardPolicy` (rôle `student`).

## 3. Parcours utilisateur

### Chemin nominal

1. L'équipe crée le point relais « Boutique Awa », rattaché au Collège Saint Michel, puis un lot de 20 cartes à 10 000 F. Elle imprime la planche : chaque carte porte un **numéro** (`N° 000021`) et un **code** (`K7QH-M3XP-9TRA`).
2. Un élève de Saint Michel crée son compte le 9 novembre. Son accueil affiche « Il te reste 7 jours gratuits ». Il fait des exercices.
3. Le 16 novembre (8e jour), il touche « Commencer » sur un exercice donné par son enseignant : il arrive sur **Mon abonnement**, qui dit « Ta période gratuite est terminée » et « Achète ta carte à 10 000 F chez Boutique Awa (près du marché, 07 00 00 00 00) ».
4. Il paie à la Boutique Awa, reçoit sa carte, saisit le code : « Ton abonnement est actif jusqu'au 31 juillet 2027 ». Il revient à l'exercice et le démarre.
5. À 18 h, la Boutique Awa verse 10 000 F sur le Wave du porteur ; l'équipe saisit le versement (montant, référence Wave).
6. Le vendredi, la caisse affiche : Boutique Awa, 1 carte activée cette semaine → 200 F à lui payer ; Collège Saint Michel → 1 000 F cumulés ; reste dû par Boutique Awa : 0 F ; 19 cartes en circulation.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code inconnu, mal tapé | « Ce code n'existe pas. Vérifie-le sur ta carte. » ; rien ne change |
| Code avec espaces, tirets, minuscules | Accepté : le code est normalisé avant la recherche |
| Code d'une carte déjà activée (par lui ou un autre) | « Cette carte a déjà été utilisée. » |
| Code d'une carte annulée | « Cette carte n'est plus valable. Rapporte-la au point relais. » |
| Élève déjà abonné pour l'année qui saisit une 2e carte | « Tu es déjà abonné jusqu'au 31 juillet 2027. Garde cette carte pour un camarade. » ; la carte reste disponible |
| Plus de 5 essais de code en 10 minutes | « Trop de tentatives. Réessaie dans quelques minutes. » ; la saisie est refusée sans être évaluée |
| Élève sans école, ou école sans point relais | Mon abonnement affiche « Écris-nous sur WhatsApp au <numéro équipe> pour trouver un point relais » |
| Élève bloqué qui ouvre une leçon ou la liste des exercices | Il voit tout ; seuls « Commencer », « Recommencer » et la vérification d'une fiche mènent à Mon abonnement |
| Compte créé avant la mise en ligne (9 novembre 2026) | Ses 7 jours partent du 9 novembre |
| L'équipe annule une carte remise et non activée | Elle sort du dû du point relais ; son code est refusé à jamais ; l'annulation garde qui, quand, pourquoi |
| L'équipe tente d'annuler une carte activée | Refus : « Une carte activée ne s'annule pas. » |
| Lot offert (prix 0) | Les cartes activent l'abonnement ; elles ne comptent ni dans le dû ni dans les commissions |
| Versement saisi par erreur | L'équipe saisit un versement correctif négatif, avec un motif ; rien ne s'efface |

## 4. Critères d'acceptation

Chacun devient un test. « Mise en ligne » = 9 novembre 2026 ; « fin d'abonnement » = 31 juillet 2027 ; heure de référence : Africa/Abidjan (UTC).

```gherkin
# --- Période gratuite et blocage (Lot B)
Étant donné un élève dont le compte a été créé le 2026-11-09
Quand il démarre un exercice le 2026-11-15
Alors la séance démarre
Et son accueil affiche « Il te reste 1 jour gratuit »

Étant donné un élève dont le compte a été créé le 2026-11-09, sans carte activée
Quand il démarre un exercice le 2026-11-16
Alors la séance ne démarre pas
Et il est redirigé vers Mon abonnement

Étant donné un élève dont le compte a été créé le 2026-10-01, sans carte activée
Quand il démarre un exercice le 2026-11-15
Alors la séance démarre

Étant donné un élève bloqué et un exercice que son enseignant a donné à sa classe
Quand il démarre cet exercice
Alors la séance ne démarre pas et il est redirigé vers Mon abonnement

Étant donné un élève bloqué
Quand il vérifie ses réponses dans une fiche de leçon
Alors la vérification est refusée et il est redirigé vers Mon abonnement

Étant donné un élève bloqué
Quand il ouvre une leçon ou la liste de ses exercices
Alors la page s'affiche normalement

Étant donné un élève bloqué qui avait des séances terminées
Quand il ouvre son historique
Alors ses séances terminées sont toujours là

Étant donné un enseignant dont le compte a plus de 7 jours
Quand il ouvre un exercice de sa classe
Alors rien ne le bloque

# --- Activation (Lot A)
Étant donné une carte remise au point relais « Boutique Awa », à 10 000 F
Et un élève inscrit au Collège Saint Michel
Quand il saisit son code en minuscules avec des espaces
Alors son abonnement est actif jusqu'au 2027-07-31
Et la carte est activée par lui, à cette date, pour le Collège Saint Michel
Et un élève bloqué qui vient d'activer peut démarrer un exercice

Étant donné une carte déjà activée par un élève
Quand un autre élève saisit le même code
Alors l'activation est refusée avec « Cette carte a déjà été utilisée. »

Étant donné une carte annulée
Quand un élève saisit son code
Alors l'activation est refusée avec « Cette carte n'est plus valable. Rapporte-la au point relais. »

Étant donné un élève déjà abonné jusqu'au 2027-07-31
Quand il saisit le code d'une 2e carte
Alors l'activation est refusée
Et la 2e carte reste remise, activable par un autre élève

Étant donné un élève qui a saisi 5 codes faux en 10 minutes
Quand il saisit un 6e code, même juste
Alors la saisie est refusée avec « Trop de tentatives »

Étant donné un élève rattaché à aucun établissement
Quand il active une carte
Alors son abonnement est actif
Et la carte n'est rattachée à aucune école

Étant donné un élève du Collège Saint Michel et la Boutique Awa rattachée à Saint Michel
Quand il ouvre Mon abonnement
Alors il voit le nom, le lieu et le téléphone de la Boutique Awa

Étant donné un élève dont l'école n'a aucun point relais
Quand il ouvre Mon abonnement
Alors il voit le numéro WhatsApp de l'équipe

Étant donné un enseignant
Quand il ouvre Mon abonnement ou saisit un code
Alors l'accès est refusé (403)

# --- Points relais et lots (Lot A)
Étant donné un membre de l'équipe
Quand il crée le point relais « Boutique Awa » rattaché à deux écoles
Alors le point relais apparaît avec ses deux écoles
Et le journal d'audit garde la création

Étant donné un point relais
Quand l'équipe crée un lot de 20 cartes à 10 000 F
Alors 20 cartes remises existent, chacune avec un numéro unique et un code unique de 12 caractères sans 0, O, 1, I ni L
Et la planche d'impression du lot montre les 20 numéros et codes

Étant donné un élève ou un enseignant
Quand il ouvre une page de l'équipe sur les points relais, les lots ou la caisse
Alors l'accès est refusé

# --- Caisse (Lot C)
Étant donné la Boutique Awa avec 20 cartes remises à 10 000 F, 3 activées et 2 annulées
Et 20 000 F de versements saisis
Quand l'équipe ouvre la caisse
Alors la Boutique Awa doit 10 000 F (3 × 10 000 − 20 000)
Et 15 cartes sont en circulation

Étant donné une carte remise et non activée
Quand l'équipe l'annule avec le motif « perdue »
Alors la carte est annulée et sort de la circulation
Et le dû de la Boutique Awa ne change pas : il ne compte que les cartes activées, une carte annulée n'y a jamais été
Et le journal d'audit garde l'auteur, la date et le motif

Étant donné une carte activée
Quand l'équipe tente de l'annuler
Alors l'annulation est refusée avec « Une carte activée ne s'annule pas. »

Étant donné 2 cartes payantes de la Boutique Awa activées le jeudi 2026-11-12 et 1 le vendredi 2026-11-13
Quand l'équipe ouvre la caisse le vendredi 2026-11-13
Alors la semaine du 2026-11-06 au 2026-11-12 doit 400 F à la Boutique Awa
Et la semaine en cours compte 1 activation

Étant donné 3 cartes payantes activées par des élèves du Collège Saint Michel, et 1 carte offerte
Quand l'équipe ouvre la caisse
Alors le Collège Saint Michel cumule 3 000 F de commission

Étant donné un versement de 10 000 F saisi par erreur
Quand l'équipe saisit un versement de −10 000 F avec un motif
Alors le total versé revient à son montant d'avant
Et les deux lignes restent visibles
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Contexte borné **`billing`** (nouveau, ADR-0126). Entités : `Offer` (prix, fin d'abonnement, mise en ligne, jours gratuits, commissions), `Access` (gratuit · abonné · bloqué, jours restants), `ActivationCode` (génération, normalisation, format), `ActivationCard`, `CardBatch`, `RelayPoint`, `Remittance`, `CommissionWeek`. Ports : `RelayPointRepositoryPort`, `CardRepositoryPort`, `RemittanceRepositoryPort`, `StudentAccessPort`. Use cases : `SaveRelayPoint`, `CreateCardBatch`, `ActivateCard`, `CancelCard`, `RecordRemittance`. Policies : `ManageBillingPolicy`, `ActivateCardPolicy`. Garde ajoutée à `UseCases::Assessment::StartExerciseSession` et `UseCases::Catalog::CheckPractice` (dépendance `access:`). |
| Infrastructure | Migrations : `billing_relay_points`, `billing_relay_point_schools`, `billing_card_batches`, `billing_activation_cards` (code chiffré déterministe), `billing_remittances`. ORM `Orm::Billing::*`, repositories, queries `Queries::Billing::StudentAccessQuery`, `CashboxQuery`, `RelayPointsForSchoolQuery`. |
| Delivery | Élève : `Billing::SubscriptionsController#show`, `Billing::ActivationsController#create` (`rate_limit`). Équipe : `Teams::Billing::RelayPointsController`, `CardBatchesController` (dont `show` imprimable), `CardCancellationsController`, `RemittancesController`, `CashboxesController#show`. Redirection « abonnement requis » dans `Assessment::ExerciseSessionsController`, `Assessment::SheetChecksController`, `Catalog::PracticeChecksController`. |
| UI | Élève : page Mon abonnement, bandeau de l'accueil élève. Équipe : points relais, lots et planche d'impression, caisse, versements, annulation. UDR-0158, UDR-0159. |

## 6. Décisions rattachées

- ADR-0126 — nouveau contexte `billing`, cinq tables, code chiffré déterministe, garde d'accès par port, freinage des essais.
- UDR-0158 — page Mon abonnement et bandeau des jours gratuits.
- UDR-0159 — écrans de l'équipe : points relais, lots, planche, caisse, versements, annulation.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves abonnés payants au 20 novembre 2026 | 0 | 100 (idéal 1 000) | |
| Délai entre le paiement au point relais et l'abonnement actif | — | moins d'une minute (saisie du code) | |
