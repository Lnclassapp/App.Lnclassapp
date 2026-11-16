# PRD — Notifications poussées aux élèves

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Aucun élève n'a fait plus de deux exercices, et l'application ne peut joindre personne en dehors d'une visite. Ce chantier ouvre le premier canal sortant, qui est gratuit : des notifications **Web Push** envoyées aux **élèves seuls**, dans le navigateur et le PWA installé. Elles couvrent six motifs, sont proposées après la première réussite, et partent dans des fenêtres horaires d'Abidjan avec un garde-fou contre la rafale. La coque Android ne reçoit pas le Web Push ; elle relèvera d'un chantier FCM séparé (ADR-0070).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Activer les notifications sur chacun de ses navigateurs, les couper d'un geste dans son profil, recevoir les six motifs | Choisir motif par motif |
| Teacher, SchoolStaff | Rien ici : ses assignations alimentent des motifs sans qu'il le voie | Recevoir des notifications ; voir qui est abonné |
| Team | Voir dans le pilotage des **nombres agrégés** : élèves abonnés, abonnements, envois de la semaine par motif et par statut | Voir un élève nominativement ; envoyer une notification à la main |
| Parent | Rien : ce rôle n'existe pas en base | — |

Règles d'autorisation : `Policies::Communication::PushSubscriptionPolicy`. L'acteur doit être un élève non anonymisé, et il n'agit que sur lui-même. L'abonnement est rattaché à la session de connexion courante, jamais à un `user_id` envoyé par le client.

## 3. Parcours utilisateur

### 3.1 Les six motifs, définis

Fenêtres d'envoi (heure d'Abidjan, `Africa/Abidjan`) : **lundi à samedi 12 h–14 h et 17 h–20 h ; dimanche 9 h–20 h**. Rien hors fenêtre : rien la nuit, rien pendant les heures de classe (8 h–12 h et 14 h–17 h en semaine). Un envoi prévu hors fenêtre part à l'ouverture de la suivante s'il est encore valable, sinon il expire.

Les motifs sont **lus au moment de l'envoi** par une tâche récurrente ; aucun use case existant n'émet d'événement (il n'y a pas de bus d'événements). Chaque motif a une **clé d'objet** qui interdit le doublon.

| # | Motif (`motive`) | Se déclenche quand… (tout est vrai au moment de l'envoi) | Clé d'objet (anti-doublon) | Texte (gabarit fermé, exemple) | Lien |
|---|---|---|---|---|---|
| 1 | `inactive` — élève inactif depuis N jours | La **dernière activité** de l'élève (la plus récente de : lecture d'une notion, session d'exercice commencée ou terminée, réponse à une question — définition de l'entonnoir) date de **3, 7 ou 14 jours** (N ∈ {3, 7, 14}, une relance par palier). Après le palier 14, plus rien jusqu'à une nouvelle activité | `inactive:<date de la dernière activité>:<N>` | « Ta classe avance. Un exercice t'attend sur Lnclass. » | Accueil |
| 2 | `assignment_due` — devoir à rendre bientôt | Une feuille **« Prépare devoirs »** de sa classe principale active (un envoi de **3 exercices ou plus**, assignations actives) a son échéance `due_on` **demain** (date d'Abidjan), et au moins un de ses exercices n'est pas rendu par l'élève | `assignment_due:<batch ou public_id de l'assignation>` | « Un devoir de Maths est à rendre demain. » | La feuille dans « Ma classe » |
| 3 | `quiz_prep` — préparer une interrogation | Une feuille **« Prépare interros »** de sa classe principale active (un envoi de **1 ou 2 exercices** assignés, même seuil que l'écran « Ma classe ») a son échéance **demain** — c'est-à-dire la prochaine séance de l'enseignant, ADR-0072 — et au moins un exercice n'est pas rendu | `quiz_prep:<batch ou public_id>` | « Prépare ton interro de Maths de demain : 2 exercices. » | La feuille |
| 4 | `announcement` — annonce de l'équipe | Une annonce **publiée par un compte de l'équipe**, que l'élève a le droit de lire (règle de lecture de l'ADR-0078 §4.3), publiée depuis moins de 48 h, ni retirée, ni archivée, ni terminée, ni masquée par l'élève | `announcement:<public_id de l'annonce>` | « Nouvelle annonce de Lnclass. » (jamais le titre) | Annonces |
| 5 | `result` — résultat ou médaille obtenue | (a) Une copie **rendue hors ligne** a été reçue et corrigée (`received_at` posé) depuis moins de 24 h et l'élève n'est pas revenu depuis ; ou (b) une **médaille** a été obtenue ou améliorée et l'élève n'est pas revenu depuis au moins 2 h | `result:<public_id de la session>` | « Ta copie de Maths est corrigée. » · « Bravo ! Une nouvelle médaille en Maths. » (jamais la note ni le niveau) | La copie |
| 6 | `unfinished` — terminer un exercice commencé | Une **session d'exercice ouverte** (`started`) depuis plus de **24 h**, sans réponse depuis 24 h, commencée il y a moins de 7 jours, dont l'exercice n'a pas été terminé par l'élève depuis | `unfinished:<public_id de la session>` | « Tu as commencé un exercice de Maths. Termine-le ! » | La session |

**Pourquoi ces définitions de 3 et 6.** Aucune table ne porte la date d'une interrogation. Le code a déjà la distinction : un envoi de 1 ou 2 exercices s'affiche « Prépare interros » pour l'élève, 3 ou plus « Prépare devoirs » ; et l'échéance est la prochaine séance de l'enseignant dans la classe (ADR-0072). « Préparer une interro » = la veille de la séance pour laquelle l'enseignant a donné une feuille « Prépare interros ». Une interrogation que l'enseignant n'a pas annoncée par une feuille n'existe pas pour Lnclass ; en créer la saisie est hors périmètre. Un « exercice commencé » est une session ouverte jamais close : il n'y en a qu'une par élève et par exercice.

**Priorité quand plusieurs motifs sont prêts** : `quiz_prep` > `assignment_due` > `announcement` > `unfinished` > `result` > `inactive`.

### 3.2 Garde-fou contre la rafale (n'est pas un plafond)

Le porteur ne veut pas de plafond hebdomadaire. Les fenêtres horaires ne protègent pas d'une rafale : un dimanche, une échéance, une interro, une annonce, une médaille et un exercice en plan peuvent tomber ensemble. Retenu, sans compter les envois de la semaine :

1. **Pas de doublon** : une clé d'objet n'est envoyée qu'une fois par élève, quel que soit le nombre d'appareils.
2. **Intervalle minimal de 4 h** entre deux envois au même élève ; à chaque passage, **un seul** motif part, le plus prioritaire.
3. Les autres motifs restent candidats et partent au passage suivant s'ils sont encore valables (un devoir pour demain l'est jusqu'à 20 h la veille ; une médaille l'est 24 h).

Effet : au plus 2 envois un jour de semaine (fenêtre de midi, fenêtre du soir), au plus 3 le dimanche. Ce n'est pas un plafond : aucun motif n'est abandonné tant qu'il reste valable, il attend. Valeurs en configuration (`PUSH_MIN_INTERVAL_HOURS`, 4 par défaut).

### 3.3 Chemin nominal

1. L'élève termine un exercice avec **au moins la moyenne** pour la **première fois**. La moyenne est 10/20 arrondi, la règle d'activation.
2. Sous son résultat, une carte l'invite : « Être prévenu de tes devoirs et de tes interros ? ». Elle dit en trois puces quoi, quand, et rien de personnel sur l'écran du téléphone. Deux boutons : « Oui, me prévenir » et « Plus tard ».
3. « Oui » déclenche la demande de permission du navigateur. Il n'y a jamais de demande sans ce clic.
4. Si la permission est accordée, le navigateur crée un abonnement. Il est envoyé au serveur et rattaché à la session courante. La carte affiche « C'est noté. »
5. La veille d'une séance où l'enseignant a donné une feuille « Prépare interros », le soir, l'élève reçoit « Prépare ton interro de Maths de demain ». Il la touche, et l'application s'ouvre sur la feuille.
6. Sur son profil, la ligne « Notifications : activées » porte l'action « Couper ». Elle supprime l'abonnement de ce navigateur et marque l'élève « coupé » : aucun envoi ne part, et la carte ne revient plus. « Réactiver » refait le parcours.

### 3.4 Coût du canal

| | Web Push |
|---|---|
| Argent | Gratuit |
| Secrets | Une paire de clés VAPID générée une fois : `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`, en variables d'environnement |
| Dépendance | Gem `web-push` |
| Code | Deux écouteurs dans le programme d'arrière-plan, à côté des caches de `hors-connexion` ; un contrôleur Stimulus d'abonnement |
| Qui reçoit | Chrome, Edge, Firefox et Samsung Internet sur Android ; les ordinateurs ; l'iPhone **seulement** avec le PWA installé (iOS 16.4 et plus). **Pas la coque Android** |
| Ce que voit le service push | Une adresse d'abonnement. Le texte est chiffré de bout en bout |
| Limites connues | Chrome sur Android a besoin des services Google. Un navigateur peut supprimer un abonnement sans prévenir, d'où la purge à 60 jours sans envoi réussi |

### 3.5 Élèves sur la coque Android

La coque n'affiche pas l'invitation : son agent utilisateur est reconnu, comme le fait déjà le contrôleur d'installation. Ces élèves ne reçoivent rien jusqu'au chantier FCM.

### 3.6 Tension n° 1 — la permission après la première réussite contre la relance des inactifs

Le choix du porteur (demander après le premier exercice réussi) est **appliqué**. Il a un coût, qu'on chiffre avec l'entonnoir :

- **Aujourd'hui** : « élèves ayant réussi un exercice : 0 » (PRD `activation-eleve`, constat du porteur du 2026-11-16). Le jour de la mise en ligne, **aucun élève n'est abonnable** ; le motif « inactif » ne touchera que des élèves qui auront réussi un exercice puis décroché.
- **Formule** à lire dans l'entonnoir (`bin/rails entonnoir:brut`, pas encore lancé en production) : abonnés possibles = *réussi ≥ 1* × taux d'acceptation × taux de permission accordée. Les élèves *commencé ≥ 1 mais jamais réussi* sont exactement ceux que la règle exclut ; leur nombre est le manque à gagner du motif « inactif ».
- **Alternatives** (décision réversible, dans `## À trancher`) : (a) demander après le **premier exercice commencé** — touche tous les élèves qui ont essayé, au prix d'une demande avant toute réussite ; (b) demander **dès la première visite** de « Ma classe » — portée maximale, demande la plus froide, taux de refus le plus haut ; un refus du navigateur est définitif. **Recommandé : (a)**, à appliquer si, deux semaines après l'ouverture, *commencé sans réussite* dépasse *réussi*.

### 3.7 Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| `PUSH_DELIVERY_ENABLED` faux (mise en service progressive) | Les abonnements s'enregistrent mais aucun envoi ne part. Le pilotage compte les envois `disabled` |
| « Plus tard » sur la carte | La carte revient après une réussite suivante, au plus une fois tous les 7 jours |
| Permission refusée par le navigateur | Pas d'abonnement. La carte ne revient pas. Le profil affiche « Bloquées par ton navigateur » avec le mode d'emploi |
| Navigateur sans API Push, ou coque Android | Pas de carte |
| Abonnement refusé par le service (404, 410) | Ligne supprimée au premier refus, envoi noté `gone` |
| Erreur réseau ou 5xx du service | Envoi noté `retry`. Nouvelle tentative au passage suivant, 3 au plus, puis `failed` |
| Clés absentes | `not_configured`, sans erreur pour l'élève |
| Déconnexion, ou changement de PIN ou de numéro qui ferme les sessions | Les abonnements de ces sessions sont supprimés |
| Session expirée (30 jours) | L'abonnement reste. Toucher la notification mène à la connexion |
| Anonymisation | Abonnements, préférence et envois sont supprimés |
| Deux comptes dans le même navigateur | L'abonnement (même adresse) passe au dernier compte connecté |
| Devoir archivé, copie rendue ou annonce retirée entre la sélection et l'envoi | Le motif n'est plus vrai à la relecture : rien ne part |
| Élève sans classe principale | Les motifs 2 et 3 sont sans objet. Les autres s'appliquent |

## 4. Critères d'acceptation

```gherkin
# Invitation et abonnement
Étant donné un élève qui vient de réussir son premier exercice (12/20)
Quand la page de résultat s'affiche dans un navigateur qui gère l'API Push
Alors la carte d'invitation aux notifications est visible

Étant donné un élève qui a déjà un abonnement actif
Quand il réussit un autre exercice
Alors la carte d'invitation n'est pas affichée

Étant donné un élève qui a touché « Plus tard » il y a 3 jours
Quand il réussit un autre exercice
Alors la carte d'invitation n'est pas affichée

Étant donné la page de résultat ouverte dans la coque Android
Alors la carte d'invitation n'est pas rendue

Étant donné un élève dont le navigateur envoie un abonnement
Alors l'abonnement est rattaché à sa session courante, jamais à un identifiant envoyé par le client

Étant donné une adresse d'abonnement déjà enregistrée pour un autre élève
Quand un second élève, connecté sur le même navigateur, l'envoie
Alors la ligne passe au second élève et le premier n'a plus d'abonnement sur ce navigateur

Étant donné un élève abonné sur deux navigateurs
Quand il touche « Couper » sur son profil
Alors l'abonnement de ce navigateur est supprimé
Et l'élève est marqué « coupé » et ne reçoit plus rien sur l'autre navigateur

Étant donné un élève abonné qui se déconnecte
Alors l'abonnement de ce navigateur est supprimé

Étant donné un enseignant connecté
Quand il envoie un abonnement
Alors la requête est refusée et rien n'est enregistré

# Envoi : conditions
Étant donné un élève abonné marqué « coupé »
Quand la tâche d'envoi passe
Alors aucun appel au port d'envoi n'a lieu pour lui

Étant donné l'interrupteur PUSH_DELIVERY_ENABLED à faux
Quand un motif est prêt pour un élève abonné
Alors aucun appel au port n'a lieu et l'envoi est noté « disabled »

Étant donné un motif prêt à 22 h un mardi, heure d'Abidjan
Alors rien ne part avant 12 h le mercredi

Étant donné un motif prêt à 10 h un mercredi
Alors rien ne part avant 12 h

Étant donné un élève à qui une notification est partie à 12 h 05
Quand un autre motif est prêt à 13 h
Alors rien ne part avant 16 h 05, donc à l'ouverture de 17 h

Étant donné un élève pour qui « devoir à rendre » et « préparer une interro » sont prêts au même passage
Alors seule la notification « préparer une interro » part

Étant donné une notification déjà envoyée pour une clé d'objet
Quand le motif est encore vrai au passage suivant
Alors elle ne repart pas

# Motifs
Étant donné une feuille de 2 exercices assignée à la classe principale de l'élève, échéance demain, aucun rendu
Quand la tâche passe dans la fenêtre du soir
Alors l'élève reçoit le motif « préparer une interro »

Étant donné une feuille de 3 exercices, échéance demain, un exercice non rendu
Alors l'élève reçoit le motif « devoir à rendre bientôt »

Étant donné une feuille d'échéance demain dont l'élève a rendu tous les exercices
Alors aucun des deux motifs ne part

Étant donné une feuille assignée dans une classe que l'élève a quittée
Alors aucun motif ne part pour elle

Étant donné un élève dont la dernière activité date de 3 jours
Alors il reçoit le motif « inactif » une fois
Et le même palier ne repart pas le lendemain
Et après le palier de 14 jours, plus aucun motif « inactif » ne part sans nouvelle activité

Étant donné une annonce de l'équipe publiée pour les élèves il y a 1 h
Alors chaque élève abonné qui peut la lire reçoit le motif « annonce » une fois
Et une annonce publiée par un enseignant ne déclenche rien
Et une annonce retirée avant l'envoi ne déclenche rien

Étant donné une copie hors ligne reçue et corrigée il y a 2 h, l'élève n'est pas revenu depuis
Alors il reçoit le motif « résultat »

Étant donné une médaille obtenue il y a 3 h et aucune visite depuis
Alors il reçoit le motif « résultat » une fois

Étant donné une session d'exercice ouverte depuis 30 h sans réponse depuis 26 h
Alors l'élève reçoit le motif « exercice commencé » une fois
Et rien ne part si la session a été terminée entre-temps

# Données et sobriété
Étant donné chaque gabarit de notification rendu pour un élève fictif
Alors le texte ne contient ni son nom, ni son numéro, ni une note, ni un niveau de médaille, ni le titre d'une annonce

Étant donné un élève anonymisé
Alors il n'a plus ni abonnement, ni préférence, ni envoi enregistré

Étant donné un service d'envoi qui répond 410 pour un abonnement
Alors l'abonnement est supprimé

Étant donné un abonnement sans envoi réussi depuis 61 jours
Quand la purge quotidienne passe
Alors il est supprimé
Et les envois de plus de 90 jours sont supprimés

# Pilotage de l'équipe
Étant donné 3 élèves abonnés, dont un sur deux navigateurs
Quand un membre de l'équipe ouvre le pilotage
Alors il lit « 3 élèves abonnés · 4 abonnements » et les envois de la semaine par motif, sans aucun nom
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Entités `Communication::PushSubscription`, `PushMessage`, `PushMotive` (6 valeurs, priorité), `SendingWindow` (fenêtres, Abidjan), `PushCandidate`. Ports `PushGatewayPort`, `PushSubscriptionRepositoryPort`, `PushPreferenceRepositoryPort`, `PushDeliveryRepositoryPort`, `PushCandidatesPort`. Use cases `RegisterPushSubscription`, `TurnOffPush`, `PostponePushInvitation`, `DeliverPushNotifications` (un passage), `PurgePushData`. Policy `PushSubscriptionPolicy` |
| Infrastructure | Migration `push_subscriptions`, `push_preferences`, `push_deliveries`. Modèles `Orm::Communication::Push*` et leurs repositories. Requêtes de candidats par motif (`Queries::Communication::PushCandidates::*`). Passerelle `WebPushGateway`. Jobs `Communication::DeliverPushNotificationsJob` (toutes les 15 min dans les fenêtres) et `Communication::PurgePushDataJob` (quotidien), dans `config/recurring.yml`. Amendement de `AnonymizeUser` et de la fermeture des sessions |
| Delivery | `resources :push_subscriptions` (create, destroy), `resource :push_preference` (update : couper, réactiver, plus tard) dans l'espace élève. Clé publique VAPID dans un attribut `data-` |
| UI | Carte d'invitation sur le résultat d'exercice, ligne « Notifications » du profil, écouteurs `push` et `notificationclick` du programme d'arrière-plan, contrôleur Stimulus `push-subscription`, tuile du pilotage de l'équipe |

## 6. Décisions rattachées

- **ADR-XXXX-notifications-web-push-aux-eleves** : choix du Web Push, clés VAPID, ce qu'on stocke et sa durée de vie, port et adaptateur, cohabitation avec le programme d'arrière-plan de `hors-connexion`. Exigé par l'ADR-0049 pour tout nouvel outil. Amende l'ADR-0045 (« Hors périmètre : notifications ») et l'ADR-0036 (ce que l'anonymisation efface).
- **UDR-XXXX-notifications-eleve** : carte d'invitation, ligne du profil, texte des notifications, tuile du pilotage.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves ayant réussi au moins 1 exercice (invitables) | 0 (porteur, 2026-11-16) | — | |
| Taux d'acceptation (« Oui » / cartes affichées) | — | ≥ 50 % | |
| Taux de permission accordée (abonnements / « Oui ») | — | ≥ 70 % | |
| Élèves abonnés ayant fait au moins 3 exercices, 30 jours après | 0 | > 0, puis à fixer | |
| Élèves qui coupent / abonnés, par mois | — | < 10 % | |
| Abonnements supprimés `gone` / envois | — | suivi | |
