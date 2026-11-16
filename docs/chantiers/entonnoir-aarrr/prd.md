# PRD — Entonnoir AARRR des élèves

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le porteur constate une activation et une rétention nulles chez les élèves sans pouvoir dire où ils décrochent ([memo](memo.md)). Ce chantier livre, sans nouvelle table ni traceur (ADR-0049, ADR-0062), une tâche de production en lecture seule qui imprime l'entonnoir brut par semaine, puis les cinq étages AARRR sur la page « Croissance » de l'équipe. Le moment « aha » est le **premier exercice réussi**.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (tout sous-rôle autorisé par la page Croissance) | Lire l'entonnoir des élèves sur `/teams/growth` | Voir un élève nommé : l'écran n'a que des comptes |
| Teacher, SchoolStaff, Student | — | Ouvrir la page (refus inchangé de la page Croissance) |
| Opérateur en production (console Railway) | Lancer `bin/rails entonnoir:brut` | Écrire en base par la tâche : transaction `READ ONLY` |

Règle d'autorisation : `Policies::Identity::ReadGrowthPolicy`, inchangée.

## 3. Définitions (chacune testée)

| Terme | Définition |
|---|---|
| Élève inscrit | Compte `role = student`, non anonymisé, dont `created_at` tombe dans la période (ou la semaine). |
| Voie d'arrivée | `joined_via` de la **première** adhésion créée de l'élève (plus petit `classroom_students.id`). `standard` → **seul** ; `link` ou `code` → **amené par sa classe** ; aucune adhésion → **sans classe**. |
| A ouvert une notion | Au moins une ligne `essential_reads`. |
| A commencé un exercice | Au moins une `exercise_sessions`, quel qu'en soit le statut (même définition que « élève actif » d'ADR-0062). |
| Exercice réussi | Session `completed` dont le score atteint `Grading::PASS_THRESHOLD` au sens de `Grading.reaches?` (note sur 20, ADR-0106) : 48 % et plus. Les remédiations comptent. |
| Réussi ≥ n exercices | Au moins n `exercise_id` **distincts** réussis (une reprise ne compte pas deux fois). |
| **Activé** | Réussi ≥ 1 exercice (moment « aha »). Taux d'activation = activés / inscrits. |
| Délai d'activation | Médiane, sur les activés, de `premier completed_at réussi − created_at`, en jours (borné à 0). |
| Dernière activité | La plus récente de : `essential_reads.last_read_at`, `exercise_sessions.started_at` / `completed_at`, `question_attempts.answered_at`. |
| **Actif à Jn** (rétention) | Dernière activité ≥ `created_at + n jours` : l'élève est **revenu** à J+n ou plus tard (rétention non bornée). n ∈ {1, 7, 30}. |
| Mesurable à Jn | `created_at + n jours ≤ maintenant`. Taux de rétention Jn = actifs à Jn / mesurables à Jn ; « — » si aucun mesurable. |
| Revenu | Cartes `billing_activation_cards` à l'état `activated` dont `activated_at` tombe dans la période : nombre et somme de `price_xof` ; élèves abonnés aujourd'hui (carte activée, `valid_until ≥ aujourd'hui`). |
| Referral | Inchangé : `GrowthMetricsQuery` (k, conversion, cycle viral). |

Pourquoi la rétention non bornée : `essential_reads.last_read_at` est écrasé et `sessions` est purgée ; seule la **dernière** date est sûre. « Actif le jour 7 pile » ne se calcule pas honnêtement (option écrite dans `journal.md` § À trancher).

## 4. Parcours utilisateur

### Premier lot — la tâche brute

1. L'opérateur lance `bin/rails entonnoir:brut` en production.
2. La tâche ouvre une transaction en lecture seule, lit l'entonnoir par semaine (lundi) depuis la première inscription d'élève, et imprime un tableau : semaine, inscrits, notion, exercice commencé, réussi ≥ 1, ≥ 2, ≥ 5 ; puis la même ligne par voie (`standard`, `link`, `code`, `sans classe`), et un total.
3. Aucune donnée personnelle : que des nombres et des dates de semaine.

### L'écran

1. Un membre de l'équipe ouvre « Croissance » (période 7 / 30 / 90 jours inchangée).
2. Sous le sélecteur de période, une section **« Élèves : entonnoir AARRR »** :
   - **Acquisition** : inscrits de la période, total puis seul / par sa classe / sans classe (cette dernière seulement si non vide) ;
   - **Activation** : les étages notion → exercice commencé → réussi ≥ 1 → ≥ 2 → ≥ 5, chacun en nombre et en part des inscrits, par voie ; délai médian d'activation ;
   - **Rétention** : tableau par semaine d'inscription de la période : inscrits, J1, J7, J30 (« part · effectif »), « — » si pas encore mesurable ;
   - **Referral** : renvoi vers le bloc k existant (pas de doublon) ;
   - **Revenu** : cartes activées, montant, abonnés aujourd'hui ; mention « bêta ouverte » tant que `Offer::BETA_ENDS_ON` est vide ;
   - **Non mesuré** : la liste de ce que la base ne permet pas de compter.
3. Le reste de la page est inchangé.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun élève inscrit dans la période | Étages à 0, taux « — », phrase vide « Aucun élève inscrit sur la période. » ; rétention : même phrase |
| Cohorte trop récente pour Jn | « — » dans la case, jamais 0 % |
| Aucune carte activée | « 0 » réel, avec la mention bêta si elle court |
| Élève non connecté / non équipe | Refus inchangé de la page (redirection ou 403 selon la politique) |
| Tâche sur base vide | « Aucun élève inscrit. », sortie 0 |
| Tâche qui tenterait d'écrire | Erreur PostgreSQL `read-only transaction` (garde testée) |

## 5. Critères d'acceptation

```gherkin
Fonctionnalité: Entonnoir brut en production

  Scénario: comptes par semaine et par voie
    Étant donné un élève seul inscrit lundi qui a lu une notion et réussi deux exercices distincts
    Et un élève amené par lien inscrit la même semaine qui a commencé un exercice sans le réussir
    Et un élève amené par code la semaine suivante sans aucune activité
    Quand l'opérateur lance entonnoir:brut
    Alors la première semaine montre 2 inscrits, 1 notion, 2 commencés, 1 réussi ≥ 1, 1 réussi ≥ 2, 0 réussi ≥ 5
    Et la ligne « standard » de cette semaine montre 1 inscrit et 1 réussi ≥ 2
    Et la seconde semaine montre 1 inscrit en « code »
    Et la sortie ne contient ni nom, ni prénom, ni numéro

  Scénario: lecture seule
    Quand la tâche s'exécute
    Alors elle tourne dans une transaction READ ONLY et aucun compte de table ne change

Fonctionnalité: Définitions de l'entonnoir

  Scénario: seuil de réussite lu sur la note sur 20
    Étant donné un exercice terminé à 47 % et un autre à 48 %
    Alors seul le second compte comme réussi

  Scénario: reprises
    Étant donné trois sessions réussies du même exercice
    Alors l'élève a réussi 1 exercice, pas 3

  Scénario: élève anonymisé
    Étant donné un élève anonymisé inscrit dans la période
    Alors il n'est compté à aucun étage

  Scénario: voie d'arrivée = première adhésion
    Étant donné un élève arrivé en « standard » puis ajouté à une seconde classe par lien
    Alors il est compté « seul », une seule fois

  Scénario: délai médian d'activation
    Étant donné trois élèves activés 1, 2 et 10 jours après leur inscription
    Alors le délai médian est de 2 jours

  Scénario: rétention non bornée et cohorte non mesurable
    Étant donné un élève inscrit il y a 10 jours dont la dernière activité date de 8 jours après l'inscription
    Alors il est actif à J1 et à J7
    Et J30 n'est pas mesurable pour sa cohorte (« — »)

  Scénario: nombre de requêtes fixe
    Étant donné 1 élève puis 20 élèves
    Alors l'entonnoir émet le même nombre de requêtes SQL

Fonctionnalité: Écran

  Scénario: l'équipe voit les cinq étages
    Étant donné un membre de l'équipe connecté
    Quand il ouvre « Croissance »
    Alors il voit les sections Acquisition, Activation, Rétention, Referral, Revenu et « Non mesuré »
    Et les colonnes « Seul » et « Par sa classe »

  Scénario: revenu en bêta
    Étant donné qu'aucune carte n'est activée et que la bêta est ouverte
    Alors le revenu affiche 0 et la mention « bêta ouverte »

  Scénario: période vide
    Étant donné aucun élève inscrit dans la période
    Alors l'écran affiche « Aucun élève inscrit sur la période. » et aucun pourcentage

  Scénario: refus
    Étant donné un enseignant connecté
    Quand il ouvre « Croissance »
    Alors l'accès est refusé comme aujourd'hui
```

## 6. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Rien de nouveau : `Entities::Assessment::Grading` fournit le seuil, `Entities::Billing::Offer` la bêta. Aucun port (lecture CQRS). |
| Infrastructure | `Queries::Identity::StudentFunnelQuery` (nouvelle, à côté de `GrowthMetricsQuery`) : `weekly(from:, to:)` et `call(from:, to:, now:)`, 3 requêtes SQL au plus. |
| Delivery | `Teams::GrowthController#show` appelle aussi la nouvelle query. Aucune route nouvelle. `lib/tasks/entonnoir.rake` (`entonnoir:brut`). |
| UI | `app/views/teams/growth/show.html.erb` + partial `_funnel.html.erb` ; clés dans `config/locales/teams/growth.fr.yml`. |

## 7. Décisions rattachées

- **ADR** : aucun nouveau. Pas de port, pas de table, pas de dépendance, pas de contrat modifié : une query de lecture de plus sous ADR-0049 (indicateurs côté serveur, « activation, exercices terminés, rétention ») et ADR-0062 (lecture en direct, nombre de requêtes fixe, définitions d'une phrase — elles sont au §3 ci-dessus). La table d'événements éventuelle est dans `journal.md` § À trancher.
- **UDR** : [UDR-XXXX-entonnoir-aarrr](../../decisions/udr/XXXX-entonnoir-aarrr.md) — section « Élèves : entonnoir AARRR » de la page Croissance. Prolonge UDR-0050.

## 8. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL ajoutées à `/teams/growth` | 0 | ≤ 3, fixe | voir journal |
| Taux d'activation élève | inconnu | mesuré | sortie de `entonnoir:brut` en production (orchestrateur) |
