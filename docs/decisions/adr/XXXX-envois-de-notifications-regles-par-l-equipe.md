# ADR-XXXX : Les notifications aux élèves ne partent que sur un réglage ou une validation de l'équipe, dix par jour et par élève au plus
<!-- index
titre: Notifications réglées et validées par l'équipe
statut: Accepté
problematique: La tâche d'envoi du chantier notifications-push envoie seule les six motifs ; le porteur veut que l'équipe décide de ce qui part et qu'aucun élève ne reçoive plus d'une notification par jour.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-25 |
| **Chantier** | `docs/chantiers/parametrage-notifications` |
| **Remplace** | — *(amende ADR-0146 §3.2 et §4 : déclenchement et garde-fou anti-rafale)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0146 a retenu une tâche récurrente qui lit six motifs toutes les 15 minutes et envoie dès que `PUSH_DELIVERY_ENABLED` est vrai. Le garde-fou laisse 4 h entre deux envois : un élève peut en recevoir deux le même jour. Le 2026-11-25, le porteur a refusé tout envoi automatique non décidé par l'équipe et a coupé l'interrupteur sur Develop, Staging et production. La fonctionnalité est donc livrée et muette.

Le grill du chantier `parametrage-notifications` a fixé le modèle (memo, réponses 2, 3, 6 et 7) :

- un septième motif, **nouveaux exercices** (`assignment_new`) : un envoi d'exercices assigné à la classe principale de l'élève depuis moins de 24 h, pas entièrement rendu (memo, réponse 8) ;
- **interro demain**, **devoir à rendre** et **nouveaux exercices** peuvent être mis en automatique par un admin (une case, décochée au départ) ;
- **exercice commencé**, **résultat ou médaille**, **élève inactif**, et les deux précédents quand leur case est décochée, ne partent que si l'équipe les valide dans le plan du jour ;
- **annonce** part seulement si l'équipe coche « Prévenir les élèves » en la publiant ;
- dix notifications au plus par jour d'Abidjan et par élève ; un motif par passage de la tâche, le plus urgent d'abord (porteur, après présentation du plan : il a refusé « dix par jour »).

## 2. Moteurs de décision

1. Rien ne part sans un geste de l'équipe : une case cochée, une validation du jour ou une case d'annonce.
2. Ce que l'équipe a vu est ce qui part : pas d'élève ajouté après la validation.
3. Ne pas toucher aux six requêtes de motifs existantes ni à la passerelle d'envoi : elles sont testées et en place. Le septième motif s'ajoute comme une requête de plus, sur le même contrat.
4. Une trace de chaque geste (qui, quand, combien) : un envoi de masse doit pouvoir s'expliquer.

## 3. Options envisagées

### 3.1 Où filtrer

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Chaque requête de motif lit le réglage et les validations | Filtrage au plus près des données | Six requêtes à modifier ; la règle « ouvert ou fermé » serait copiée six fois |
| B — **Le use case d'envoi filtre les candidats ouverts** | Un seul point ; les requêtes restent inchangées ; testable en Ruby pur avec des ports en mémoire | Retenue. Coût : les requêtes calculent aussi les candidats des motifs fermés (même coût qu'aujourd'hui) |

### 3.2 Comment figer une validation

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Le motif est ouvert toute la journée | Aucune table de destinataires | Des élèves que l'équipe n'a pas vus recevraient la notification (moteur 2) |
| B — **Les couples élève × objet affichés sont enregistrés avec la validation** | Ce qui part est exactement ce qui a été montré, puis relu avant l'envoi | Retenue. Coût : une table de destinataires (quelques centaines de lignes par jour), purgée avec les envois |
| C — Ne garder que l'heure de validation et ne retenir que les objets antérieurs | Pas de liste | Les candidats ne portent pas l'heure de leur événement ; il faudrait modifier les six requêtes |

### 3.3 Le garde-fou

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Garder 4 h entre deux envois | Déjà en place | Avec les fenêtres de 12 h–14 h et 17 h–20 h, plafonne de fait à deux par jour, en dessous de ce que veut le porteur |
| B — Une par jour d'Abidjan | Lisible, aucune fatigue | Refusée par le porteur |
| C — **Dix par jour d'Abidjan, un motif par passage (15 min)** | Le plafond du porteur ; l'écart minimal de 15 min vient du rythme de la tâche, sans réglage de plus | Retenue. `PUSH_MIN_INTERVAL_HOURS` n'est plus lue ; le port d'envois gagne `sent_count(user_id:, on_date:)` (additif) |

## 4. Décision

> **Nous n'envoyons un motif à un élève que si le motif est ouvert pour lui aujourd'hui : case « Automatique » cochée (interro demain, devoir à rendre, nouveaux exercices seulement), validation du jour qui le contient (élève × objet figés à la validation), ou annonce publiée avec « Prévenir les élèves ». Le use case d'envoi applique ce filtre aux candidats des sept requêtes, puis envoie à chaque élève, à chaque passage, le plus urgent de ses motifs ouverts, tant qu'il a reçu moins de dix notifications ce jour d'Abidjan. L'interrupteur `PUSH_DELIVERY_ENABLED` reste un coupe-tout au-dessus de ces règles.**

### 4.1 Ce qu'on stocke

| Table | Colonnes | Règles |
|---|---|---|
| `push_motive_settings` | `motive` (unique, `quiz_prep`, `assignment_due` ou `assignment_new`), `automatic` (faux), `updated_by_id`, `updated_at` | Absence de ligne = décoché. Contrainte : motif dans `AUTOMATABLE` |
| `push_motive_setting_changes` | `motive`, `automatic`, `changed_by_id`, `changed_at` | Historique des réglages ; jamais modifié ; purgé après 90 jours |
| `push_approvals` | `on_date` (jour d'Abidjan), `motive`, `approved_by_id`, `approved_at`, `recipients_count` | Unique (`on_date`, `motive`) : la seconde validation simultanée échoue sur l'index et répond « déjà validé » |
| `push_approval_recipients` | `push_approval_id` (cascade), `user_id`, `object_key` | Unique (`push_approval_id`, `user_id`, `object_key`) ; purgé avec son approbation après 90 jours |
| `push_deliveries` (existante) | contrainte `push_deliveries_motive_check` | Élargie à `assignment_new` |
| `messages.push_requested` | booléen, faux par défaut, non nul | Posé seulement par l'équipe, audience `all` ou `students` ; ignoré pour tout autre auteur |

Les clés étrangères vers `users` sont `ON DELETE RESTRICT` (comme `push_deliveries`), sauf `push_approval_recipients.user_id`, `ON DELETE CASCADE` : l'anonymisation d'un élève (ADR-0146 §4.5) supprime ses lignes via le port d'effacement existant.

### 4.2 Ports

`PushDeliveryRepositoryPort` gagne `sent_count(user_id:, on_date:)` (nombre d'envois `delivered` de ce jour), changement additif.

```ruby
# app/domain/ports/communication/push_motive_setting_repository_port.rb
def automatic_motives = …                       # → Set["assignment_due", …]
def all = …                                     # → [Entities::Communication::PushMotiveSetting]
def update(motive:, automatic:, by:, at:) = …   # écrit le réglage ET sa ligne d'historique, dans une transaction

# app/domain/ports/communication/push_approval_repository_port.rb
def approved_keys(on_date:) = …                 # → Set[[user_id, motive, object_key]]
def for_date(on_date:) = …                      # → [Entities::Communication::PushApproval]
def create(on_date:, motive:, by:, at:, recipients:) = … # → :created | :already_approved
def history(since:) = …
def purge_before(before:) = …
```

### 4.3 Règle d'ouverture, dans `DeliverPushNotifications`

```ruby
# app/domain/use_cases/communication/deliver_push_notifications.rb (extrait prévu)
def open?(candidate, automatic, approved)
  case candidate.motive
  when "announcement" then true # la requête ne lit que les annonces push_requested
  else automatic.include?(candidate.motive) || approved.include?([ candidate.user_id, candidate.motive, candidate.object_key ])
  end
end

DAILY_LIMIT = 10

def daily_limit_reached?(user_id, now)
  @deliveries.sent_count(user_id:, on_date: now.utc.to_date) >= DAILY_LIMIT # jour d'Abidjan = jour UTC
end
```

`min_interval:` disparaît de la signature ; le job ne lit plus `PUSH_MIN_INTERVAL_HOURS`.

### 4.4 Plan du jour

Une query de lecture (`PushDailyPlanQuery`) appelle `PushCandidates#for(now:)`, retire les candidats déjà envoyés, expirés, et ceux des motifs automatiques ou de l'annonce, puis groupe par motif : nombre d'élèves distincts, répartition par établissement de la classe principale, texte de `PushMessage.for`. `ApprovePushMotive` recalcule la liste du motif au moment de la validation (et non celle affichée dans le navigateur, qui peut dater) et l'enregistre ; la confirmation affiche le nombre réellement enregistré.

## 5. Conséquences

### 🟢 Positives

- Aucun envoi sans geste de l'équipe : la décision du porteur du 2026-11-25 est tenue par le code, pas seulement par l'interrupteur.
- Les six requêtes de motifs et la passerelle ne changent pas.
- Chaque envoi s'explique : réglage ou validation, avec son auteur.

### 🔴 Coûts consentis

- Le plan du jour relance les six requêtes à chaque affichage (une dizaine de lectures par motif) ; acceptable pour un écran ouvert quelques fois par jour par l'équipe.
- Un motif validé à 10 h ne touche pas l'élève devenu concerné à 11 h : il attend le plan du lendemain, et les motifs d'un jour (interro demain, inactif au palier) sont alors perdus pour lui.
- Si personne ne valide, les relances ne partent pas : la rétention dépend de la présence de l'équipe.
- Dix notifications par jour, à 15 minutes d'écart au plus court, est un plafond haut : un élève concerné par beaucoup de motifs peut en recevoir plusieurs en une heure. Les chiffres « ont coupé » de la tuile du Pilotage sont à suivre dès l'ouverture.

## 6. Notes d'implémentation

- `Entities::Communication::PushMotive::PRIORITY = %w[quiz_prep assignment_due assignment_new announcement unfinished result inactive]` ; `AUTOMATABLE = %w[quiz_prep assignment_due assignment_new]` ; `PLANNABLE = PRIORITY - %w[announcement]`.
- `Queries::Communication::PushCandidates::AssignmentNew` : mêmes lectures que `AssignmentDue` (classe principale, niveau de l'élève, exercices publiés, copies rendues), filtre `assigned_at` dans les 24 h au lieu de l'échéance ; `object_key` `assignment_new:<envoi>`, `valid_until` = `assigned_at` + 24 h ; texte `communication.push.messages.assignment_new.body` (« Ton prof de %{material} t'a donné %{count} exercice(s). »).
- `PushCandidates::Announcement#messages` ajoute `.where(push_requested: true)`.
- `PushDataEraser` (ADR-0146 §4.5) supprime aussi les `push_approval_recipients` de l'élève ; `PurgePushData` purge approbations et historique de plus de 90 jours.
- `test/architecture/use_case_policies_test.rb` : `UpdatePushMotiveSetting` et `ApprovePushMotive` ont chacun leur policy (pas d'exemption).

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/communication/deliver_push_notifications_test.rb` : « rien ne part sans réglage ni validation », « dix par jour », « liste figée ».
- Contraintes de base : `push_motive_settings_motive_check` refuse `inactive` ; index unique (`on_date`, `motive`).
- `grep -rn PUSH_MIN_INTERVAL_HOURS app config` ne rend rien.
