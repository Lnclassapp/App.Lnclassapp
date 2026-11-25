# PRD — Paramétrage et confirmation des notifications par l’équipe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le chantier `notifications-push` (PR #652) envoie seul six motifs (un septième, « nouveaux exercices », s'ajoute ici) de notification aux élèves dès que l'interrupteur d'environnement est ouvert. Le porteur veut que l'équipe décide de ce qui part : deux motifs liés à une échéance peuvent être mis en automatique par un admin, les autres partent seulement si l'équipe les valide, et aucun élève ne reçoit plus de dix notifications par jour. Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team `admin` | Voir l'écran « Notifications » ; cocher ou décocher « Automatique » pour **interro demain**, **devoir à rendre** et **nouveaux exercices** ; valider un motif du plan du jour ; cocher « Prévenir les élèves » sur une annonce | Rendre automatique une relance (commencé, résultat, inactif) ou l'annonce ; valider après la fermeture de la dernière fenêtre du jour |
| Team `content`, `field` | Voir l'écran ; valider un motif du plan du jour ; cocher « Prévenir les élèves » sur une annonce | Changer une case « Automatique » |
| Teacher, SchoolStaff, Parent | — | Voir l'écran ; voir ou cocher « Prévenir les élèves » (absente de leur formulaire d'annonce) |
| Student | Reçoit au plus 10 notifications par jour d'Abidjan, une par passage de la tâche | — |

Deux règles d'accès du contexte `communication` : **régler les motifs** (équipe `admin`) et **valider le plan du jour** (toute l'équipe). « Prévenir les élèves » suit la règle de publication existante (équipe seulement, audience `all` ou `students`).

## 3. Parcours utilisateur

### Chemin nominal

1. Un membre de l'équipe ouvre « Notifications » (menu « Plus » de l'espace équipe, ou lien « Paramétrer » de la tuile Notifications du Pilotage).
2. Bloc **Réglages** : les sept motifs, chacun avec son mode — « Automatique » (case, interro, devoir et nouveaux exercices seulement, modifiable par un admin), « À valider chaque jour » (commencé, résultat, inactif), « À la publication de l'annonce » (annonce).
3. Bloc **Plan du jour** : pour chaque motif « à valider » (et chaque motif automatique **décoché**), le texte exact de la notification, le nombre d'élèves concernés maintenant et la répartition par établissement (nom, nombre ; aucun nom d'élève). Bouton « Valider l'envoi ».
4. Il valide « Élève inactif » : la liste des couples élève × objet affichée est figée ; le motif passe à « Validé par <nom> à <heure> — 42 élèves ». Les notifications partent au passage suivant de la tâche dans une fenêtre ouverte.
5. Un admin coche « Automatique » sur « Devoir à rendre » : à chaque passage, ce motif part seul, sans plan ; la ligne disparaît du plan du jour et affiche « Automatique depuis le <date>, par <nom> ».
6. Un membre de l'équipe publie une annonce à « Tous » ou « Élèves » avec « Prévenir les élèves » coché : les élèves lecteurs la reçoivent dans la fenêtre suivante.
7. Bloc **Historique** (14 derniers jours) : réglages changés et validations, avec qui, quand, combien d'élèves.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun élève concerné par un motif aujourd'hui | Ligne du plan « Aucun élève concerné aujourd'hui », sans bouton |
| Aucun motif à valider (tout coché, rien à proposer) | Plan du jour : état vide « Rien à valider aujourd'hui » |
| Validation après 20 h (dimanche aussi : dernière fenêtre close) | Refus : « Les envois du jour sont terminés. » ; rien n'est enregistré |
| Deux validations simultanées du même motif | Une seule est enregistrée ; la seconde reçoit « Déjà validé par <nom> à <heure> » |
| Un `content` ou `field` envoie un réglage forgé | 403, rien ne change |
| Un élève concerné par deux motifs ouverts (automatique, validé ou annonce) | Un motif par passage, le plus urgent d'abord (ordre des motifs) ; les suivants partent aux passages suivants, dans la limite de 10 par jour |
| L'élève a déjà reçu 10 notifications aujourd'hui | Rien ne part avant le lendemain |
| Objet retiré après la validation (devoir, annonce) | Relu avant l'envoi : rien ne part pour lui |
| Élève devenu concerné après la validation | Ne reçoit rien de ce motif aujourd'hui (liste figée) ; il figure au plan du lendemain si le motif vaut encore |
| Interrupteur `PUSH_DELIVERY_ENABLED` fermé | Bandeau « L'envoi est coupé sur cet environnement : rien ne part. » ; réglages et validations s'enregistrent ; envois notés `disabled` comme aujourd'hui |
| Clés VAPID absentes | Bandeau « Envoi non configuré » ; même comportement que ci-dessus |
| Le calcul du plan échoue | État d'erreur du bloc « Plan du jour » avec « Réessayer » ; les réglages restent lisibles |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: régler et valider les notifications

  Scénario: rien ne part sans réglage ni validation
    Étant donné que l'interrupteur d'envoi est ouvert
    Et qu'aucune case « Automatique » n'est cochée et qu'aucun motif n'est validé aujourd'hui
    Et qu'un élève abonné a un devoir à rendre demain et est inactif depuis 7 jours
    Quand la tâche d'envoi passe dans une fenêtre ouverte
    Alors aucune notification ne part

  Scénario: un motif automatique part seul
    Étant donné qu'un admin a coché « Automatique » pour « Devoir à rendre »
    Et qu'un élève abonné a un devoir à rendre demain
    Quand la tâche d'envoi passe dans une fenêtre ouverte
    Alors l'élève reçoit la notification du devoir

  Scénario: une relance validée part, figée à la validation
    Étant donné que 2 élèves abonnés sont inactifs depuis 7 jours à 10 h
    Et qu'un membre de l'équipe valide « Élève inactif » à 10 h
    Et qu'un 3e élève devient inactif depuis 7 jours après 10 h
    Quand la tâche d'envoi passe à 12 h
    Alors les 2 premiers élèves reçoivent la notification
    Et le 3e ne reçoit rien

  Scénario: un motif par passage, le plus urgent d'abord
    Étant donné que « Devoir à rendre » est automatique et « Élève inactif » validé aujourd'hui
    Et qu'un élève est concerné par les deux
    Quand la tâche passe à 12 h puis à 12 h 15
    Alors l'élève reçoit la notification du devoir à 12 h, puis celle d'inactivité à 12 h 15

  Scénario: dix notifications au plus par jour et par élève
    Étant donné qu'un élève a reçu 10 notifications aujourd'hui
    Et qu'un motif ouvert le concerne encore
    Quand la tâche passe dans une fenêtre ouverte
    Alors rien ne part pour lui avant le lendemain

  Scénario: le lendemain, le motif encore valable repart
    Étant donné qu'un élève a reçu « Devoir à rendre » hier et qu'un exercice commencé lui reste
    Et que « Exercice commencé » est validé aujourd'hui
    Quand la tâche passe aujourd'hui dans une fenêtre ouverte
    Alors l'élève reçoit la notification de l'exercice commencé

  Scénario: nouveaux exercices assignés
    Étant donné qu'un admin a coché « Automatique » pour « Nouveaux exercices »
    Et qu'un enseignant a assigné il y a 2 h 3 exercices de Maths à la classe principale d'un élève abonné
    Quand la tâche d'envoi passe dans une fenêtre ouverte
    Alors l'élève reçoit « Ton prof de Maths t'a donné 3 exercices. »

  Scénario: nouveaux exercices déjà rendus ou trop anciens
    Étant donné que « Nouveaux exercices » est automatique
    Et qu'un envoi a été assigné il y a 30 h, ou que l'élève a rendu tous ses exercices
    Quand la tâche d'envoi passe dans une fenêtre ouverte
    Alors aucune notification « nouveaux exercices » ne part pour cet envoi

  Scénario: un rôle non admin ne change pas un réglage
    Étant donné un membre de l'équipe de rôle « content »
    Quand il envoie le réglage « Automatique » pour « Devoir à rendre »
    Alors il reçoit un refus et le réglage ne change pas

  Scénario: une relance ne peut pas devenir automatique
    Étant donné un admin
    Quand il envoie le réglage « Automatique » pour « Élève inactif »
    Alors le réglage est refusé

  Scénario: un rôle non équipe ne voit pas l'écran
    Étant donné un enseignant connecté
    Quand il ouvre l'écran des notifications de l'équipe
    Alors il est refusé

  Scénario: validation refusée après la dernière fenêtre
    Étant donné qu'il est 20 h 05 un mardi à Abidjan
    Quand un membre de l'équipe valide « Élève inactif »
    Alors la validation est refusée et rien n'est enregistré

  Scénario: double validation
    Étant donné que « Élève inactif » a été validé aujourd'hui par un admin
    Quand un autre membre de l'équipe le valide
    Alors une seule validation existe et il lit « Déjà validé par »

  Scénario: annonce avec « Prévenir les élèves »
    Étant donné qu'un membre de l'équipe publie une annonce aux élèves avec « Prévenir les élèves » coché
    Quand la tâche passe dans une fenêtre ouverte
    Alors les élèves abonnés qui lisent l'annonce la reçoivent

  Scénario: annonce sans « Prévenir les élèves »
    Étant donné qu'une annonce de l'équipe est publiée sans « Prévenir les élèves »
    Quand la tâche passe dans une fenêtre ouverte
    Alors aucune notification d'annonce ne part

  Scénario: la case n'existe pas hors équipe
    Étant donné un enseignant ou une direction qui rédige une annonce
    Alors la case « Prévenir les élèves » n'est pas affichée
    Et une valeur forgée « prévenir » est ignorée

  Scénario: le plan du jour montre ce qui partirait
    Étant donné que 3 élèves de deux établissements sont inactifs depuis 7 jours
    Quand un membre de l'équipe ouvre l'écran
    Alors la ligne « Élève inactif » montre le texte de la notification, « 3 élèves » et la répartition par établissement
    Et aucun nom d'élève

  Scénario: interrupteur fermé
    Étant donné que l'interrupteur d'envoi est fermé
    Quand un membre de l'équipe ouvre l'écran
    Alors le bandeau « L'envoi est coupé sur cet environnement » s'affiche

  Scénario: historique tracé
    Étant donné qu'un admin a coché « Automatique » pour « Interro demain »
    Et qu'un membre de l'équipe a validé « Résultat ou médaille »
    Quand on ouvre l'écran
    Alors l'historique montre les deux gestes, avec leur auteur, leur heure et le nombre d'élèves validés
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Entité `PushMotiveSetting` (motif, automatique, par qui, quand) ; entité `PushApproval` (date, motif, validé par, quand, couples élève × objet) ; `PushMotive` gagne le motif `assignment_new` (priorité 3), `AUTOMATABLE = %w[quiz_prep assignment_due assignment_new]` et `PLANNABLE` (tous sauf `announcement`) ; ports `PushMotiveSettingRepositoryPort`, `PushApprovalRepositoryPort` ; use cases `UpdatePushMotiveSetting`, `ApprovePushMotive` ; `DeliverPushNotifications` filtre les candidats ouverts (automatique, validé, annonce demandée) et applique le plafond de 10 par jour ; policies `ManagePushSettingsPolicy` (admin), `ApprovePushPolicy` (équipe) ; `PushDeliveryRepositoryPort#last_sent_at` reste, la règle devient « même jour d'Abidjan » |
| Infrastructure | Migrations : `push_motive_settings` (motif unique, `automatic`, `updated_by_id`), `push_approvals` (`on_date`, motif, `approved_by_id`, `approved_at`, unique `on_date`+motif), `push_approval_recipients` (approbation, `user_id`, `object_key`, unique), `messages.push_requested` (booléen, faux par défaut), contrainte de motif de `push_deliveries` élargie à `assignment_new` ; requête `PushCandidates::AssignmentNew` ; repositories des deux ports ; query `PushDailyPlanQuery` (candidats du jour par motif, comptes par établissement, déjà envoyés exclus) ; `PushCandidates::Announcement` ne retient que `push_requested` ; job : plus de `PUSH_MIN_INTERVAL_HOURS` |
| Delivery | `teams/push_settings#show`, `teams/push_motive_settings#update`, `teams/push_approvals#create` ; paramètre `push_requested` du formulaire d'annonce (équipe seulement) |
| UI | `teams/push_settings/show` et ses partials (réglages, plan du jour, historique, bandeau) ; case « Prévenir les élèves » du formulaire d'annonce ; entrée « Notifications » du menu « Plus » de l'équipe ; lien « Paramétrer » de la tuile Notifications du Pilotage |

## 6. Décisions rattachées

- ADR-XXXX-envois-de-notifications-regles-par-l-equipe ([fichier](../../decisions/adr/XXXX-envois-de-notifications-regles-par-l-equipe.md)) — amende ADR-0146 §3.2 et §4 (déclenchement, plafond de dix par jour)
- UDR-XXXX-ecran-notifications-de-l-equipe ([fichier](../../decisions/udr/XXXX-ecran-notifications-de-l-equipe.md)) — écran « Notifications » de l'équipe, case « Prévenir les élèves »
- ADR-0146, UDR-0186 — chantier `notifications-push`

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Notifications reçues par élève et par jour (max) | jusqu'à 2 (4 h d'écart) | 10 au plus | |
| Élèves prévenus le jour où leur enseignant assigne des exercices | 0 | suivi après ouverture | |
| Envois partis sans réglage ni validation de l'équipe | tous | 0 | |
| Jours avec plan validé, sur les 14 premiers jours d'ouverture | — | suivi (pas de cible) | |
