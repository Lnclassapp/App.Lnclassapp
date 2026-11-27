# PRD — Notifications envoyées dès l'événement

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les notifications aux élèves partent aujourd'hui dans deux fenêtres par jour, et les relances attendent une validation quotidienne de l'équipe ([memo](memo.md)). Le porteur veut une case par motif qui fait foi, l'envoi des événements dès qu'ils arrivent, à toute heure, et les rappels de 6 h à 21 h (Abidjan). Le plafond de dix par jour et par élève reste.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (admin) | Cocher ou décocher la case de chacun des sept motifs | Valider un motif pour la journée (retiré) |
| Team (autre rôle) | Voir les cases et l'historique | Changer une case (policy existante `UpdatePushMotiveSetting`, inchangée) |
| Team (auteur d'annonce) | Cocher « Prévenir les élèves » à la publication | La changer après publication (ADR-0147, amendement du 2026-11-27) |
| Student | Recevoir les notifications des motifs cochés ; couper les siennes (inchangé) | Choisir ses motifs ou ses heures |
| Teacher, SchoolStaff | Déclencher, par leurs gestes (assigner des exercices), une notification à leurs élèves | Voir ou changer les réglages |

## 3. Parcours utilisateur

### Chemin nominal

1. Un admin de l'équipe ouvre « Notifications » et coche « Exercice assigné ».
2. Un professeur assigne deux exercices à sa classe principale à 15 h 02.
3. L'assignation enregistrée demande un passage d'envoi ; il tourne dans la minute.
4. Chaque élève abonné de la classe, de ce niveau, reçoit « Ton prof de … t'a donné 2 exercices. », dans la limite de dix par jour.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Case du motif décochée | Rien ne part, à aucune heure |
| Événement à 2 h du matin, case cochée | Part tout de suite |
| Rappel prêt à 22 h | Ne part pas avant 6 h le lendemain ; perdu s'il a expiré |
| Annonce publiée sans « Prévenir les élèves », case « Annonce » cochée | Rien ne part |
| Annonce publiée avec « Prévenir les élèves », case « Annonce » décochée | Rien ne part |
| Élève à dix notifications ce jour | Rien de plus ce jour d'Abidjan |
| La demande de passage échoue (file indisponible) | L'événement est enregistré quand même ; il part au passage de 15 min suivant ; l'échec est signalé |
| Interrupteur `PUSH_DELIVERY_ENABLED` faux | Rien ne part (inchangé) |
| Ancienne URL du plan du jour ou de validation | 404 |

## 4. Critères d'acceptation

```gherkin
Scénario: un motif coché part, un motif décoché ne part jamais
  Étant donné la case « Résultat » cochée et la case « Inactif » décochée
  Quand un passage tourne à 15 h avec un candidat de chaque motif pour deux élèves
  Alors l'élève du résultat le reçoit
  Et l'élève inactif ne reçoit rien

Scénario: tous les motifs ont une case
  Étant donné un admin de l'équipe
  Quand il ouvre « Notifications »
  Alors il voit sept cases, une par motif, décochées au départ
  Et il peut cocher « Inactif » ; la base l'accepte

Scénario: un événement part à toute heure
  Étant donné la case « Exercice assigné » cochée
  Quand un passage tourne à 2 h du matin avec un candidat « Exercice assigné »
  Alors il part

Scénario: un rappel attend la journée
  Étant donné la case « Devoir à rendre » cochée
  Quand un passage tourne à 5 h 59 puis à 21 h
  Alors rien ne part
  Et à 6 h il part

Scénario: l'assignation demande un passage
  Quand un professeur assigne des exercices à sa classe
  Alors un passage d'envoi est demandé une fois, après l'enregistrement
  Et si l'assignation est refusée, aucun passage n'est demandé

Scénario: l'annonce et la médaille demandent un passage
  Quand une annonce paraît (publiée tout de suite ou à son heure programmée) avec « Prévenir les élèves »
  Alors un passage est demandé
  Quand un élève ferme une session avec une médaille ou qu'une copie hors ligne est reçue
  Alors un passage est demandé

Scénario: l'annonce part si ses deux cases sont cochées
  Étant donné une annonce publiée avec « Prévenir les élèves »
  Quand la case « Annonce » est décochée
  Alors elle ne part pas
  Quand la case « Annonce » est cochée
  Alors elle part

Scénario: le plafond tient la nuit
  Étant donné un élève qui a reçu dix notifications aujourd'hui
  Quand un exercice lui est assigné à 23 h
  Alors rien ne part

Scénario: la validation n'existe plus
  Quand l'équipe ouvre « Notifications »
  Alors il n'y a ni plan du jour ni bouton « Valider l'envoi »
  Et l'historique montre encore les validations passées
  Et POST /teams/notifications/approvals répond 404
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `PushMotive` : `EVENTS`, `REMINDERS`, `AUTOMATABLE = ALL` ; `ReminderHours` (6 h–21 h) à la place de `SendingWindow` ; `DeliverPushNotifications` : case seule + heures des rappels, sans validations ; port `PushPassPort#request` ; use cases d'événement qui l'appellent après succès ; `ApprovePushMotive` retiré |
| Infrastructure | Migration : contrainte des sept motifs sur `push_motive_settings` et `push_motive_setting_changes` ; adaptateur `PushPass` (enfile le job) ; `PushDailyPlanQuery` retiré ; `config/recurring.yml` sans le passage de 12 h 20 |
| Delivery | Routes du plan et des validations retirées ; contrôleurs retirés ; câblage du port dans les contrôleurs et jobs d'événement |
| UI | Carte « Réglages » à sept cases ; carte « Plan du jour » retirée ; libellé « Exercice assigné » |

## 6. Décisions rattachées

- ADR-0147 — amendement du 2026-11-27 (II) : une case par motif, événements à toute heure, rappels de 6 h à 21 h, passage demandé à l'événement, validations retirées.
- UDR-0187 — amendement : carte « Réglages » à sept cases, carte « Plan du jour » retirée.
