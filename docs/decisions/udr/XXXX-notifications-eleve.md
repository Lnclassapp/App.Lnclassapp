# UDR-XXXX : Notifications de l'élève — la carte d'invitation après la première réussite, la ligne du profil, le texte des notifications, la tuile du pilotage
<!-- index
titre: Notifications de l'élève — invitation, profil, textes, pilotage
statut: Proposé
adr-lie: XXXX-notifications-web-push-aux-eleves
problematique: proposer les notifications au bon moment, sans demande de permission à froid, laisser l'élève les couper dans l'application, et ne rien montrer de personnel sur un écran verrouillé
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-16 |
| **Chantier** | `docs/chantiers/notifications-push` |
| **ADR lié** | ADR-XXXX-notifications-web-push-aux-eleves |
| **Amende** | écrans de résultat d'exercice (une carte de plus, une seule fois) · « Mes informations » du profil (une ligne de plus) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève qui ferme l'application n'est plus jamais joint. Lui demander la permission de notifier à froid, dès la première visite, donne un refus que le navigateur rend **définitif** : il ne redemande plus jamais. Le porteur a choisi le moment de la demande : **juste après le premier exercice réussi**, quand l'élève a une raison de revenir. Comme le navigateur ne redemande plus après un refus, il faut aussi une sortie, et une entrée, dans l'application.

## 2. Décision

- **Une carte sous le résultat**, pas une fenêtre modale. L'élève voit d'abord sa note, puis l'invitation. Une modale masquerait le résultat et ferait cliquer « Autoriser » sans lire.
- **La boîte du navigateur n'apparaît qu'après le clic « Oui »**, jamais à l'ouverture d'une page.
- **Une ligne « Notifications » dans « Mes informations »** : un état lisible et une action, couper ou réactiver.
- **Des textes sobres** : pas de nom, pas de note, pas de niveau de médaille, pas de titre d'annonce.
- **Le style Wave** (skill `ecrans-wave`) : une carte blanche, une action principale, aucune section vide.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Carte d'invitation

**Où** : `app/views/communication/push_subscriptions/_invitation.html.erb`, rendue par `app/views/assessment/session_results/show.html.erb` **sous** le bloc de note, et par le retour de rendu d'une feuille (`app/views/assessment/sheet_checks/create.turbo_stream.erb`) sous le résultat.

**Quand elle s'affiche** — le serveur décide d'abord, par `Queries::Communication::PushInvitationQuery#show?(student_id:)`. Toutes ces conditions doivent être vraies :

- l'acteur est un élève ;
- sa copie est terminée et atteint la moyenne (`Grading.reaches?`) ;
- il n'a aucun abonnement ;
- il n'a pas coupé les notifications (`push_preferences.turned_off_at`) ;
- il n'a pas répondu « Plus tard » depuis moins de 7 jours (`push_preferences.invitation_postponed_until`). Cette date est gardée côté serveur, rien n'est écrit dans le navigateur ;
- la page ne tourne pas dans la coque Android : son agent utilisateur est reconnu comme dans `install_controller.js`.

Le contrôleur Stimulus décide ensuite, dans le navigateur : la carte ne s'affiche que si `"PushManager" in window` et `Notification.permission !== "denied"`.

Si une seule condition manque, rien n'est rendu : ni titre, ni phrase « indisponible ».

**Structure**
```erb
<section id="push_invitation" class="rounded-card border border-line bg-white p-5 shadow-card"
         data-controller="push-subscription"
         data-push-subscription-vapid-key-value="<%= vapid_public_key %>"
         data-push-subscription-preference-url-value="<%= push_preference_path %>"
         data-push-subscription-subscriptions-url-value="<%= push_subscriptions_path %>"
         aria-labelledby="push_invitation_title" hidden>
  <h2 id="push_invitation_title" class="text-lg font-medium text-ink"><%= t("communication.push_subscriptions.invitation.title") %></h2>
  <p class="mt-1 text-sm text-mute"><%= t("communication.push_subscriptions.invitation.body") %></p>
  <ul class="mt-3 space-y-1 text-sm text-ink"><!-- 3 puces : quoi, quand, rien de personnel --></ul>
  <div class="mt-4 flex flex-col gap-2 sm:flex-row">
    <%= ui_button t("communication.push_subscriptions.invitation.accept"), data: { action: "push-subscription#accept" } %>
    <%= button_to t("communication.push_subscriptions.invitation.later"), push_preference_path, method: :patch, params: { intent: "postpone" },
                  class: "min-h-tap text-sm font-medium text-brand-strong", form: { data: { turbo_frame: "_self" } } %>
  </div>
  <p class="mt-3 text-xs text-mute" data-push-subscription-target="status" role="status" aria-live="polite"></p>
</section>
```
La carte est rendue `hidden` ; le contrôleur la montre si l'appareil peut s'abonner (sans JS : elle reste cachée, rien n'est perdu).

**Textes** (`config/locales/communication/push_subscriptions.fr.yml`, clés `communication.push_subscriptions.invitation.*`) :
- titre : « Être prévenu de tes devoirs et de tes interros ? »
- corps : « Lnclass t'envoie un rappel la veille d'un devoir ou d'une interro, quand l'équipe publie une annonce, quand tu gagnes une médaille ou laisses un exercice en plan. »
- puces : « Jamais la nuit ni pendant les cours. » · « Ni ton nom ni tes notes sur l'écran du téléphone. » · « Tu arrêtes quand tu veux, dans ton profil. »
- boutons : « Oui, me prévenir » · « Plus tard »

**Comportement** (`app/javascript/push/push_subscription_controller.js`)

- `connect()` montre la carte si `"PushManager" in window` et que `Notification.permission` ne vaut pas `"denied"`.
- `accept()` appelle d'abord `Notification.requestPermission()`.
- Si la réponse est `granted`, il appelle `(await navigator.serviceWorker.ready).pushManager.subscribe({ userVisibleOnly: true, applicationServerKey })`, puis `POST subscriptions-url` avec `{ endpoint, keys: { p256dh, auth } }` et le jeton CSRF.
- Sur une page du profil, `connect()` compare aussi `pushManager.getSubscription()` à l'état rendu par le serveur. Si le navigateur a un abonnement inconnu du serveur, il le renvoie. Si le serveur en connaît un que le navigateur a perdu, il en crée un nouveau, seulement quand la permission vaut déjà `granted`.
- Pendant l'appel, le bouton « Oui » passe `aria-busy="true"` et `disabled`.

**États obligatoires**
- **Vide** : conditions non remplies → rien rendu.
- **Chargement** : bouton « Oui » désactivé, libellé « Un instant… ».
- **Erreur** : réseau ou 5xx → statut « Ça n'a pas marché. Réessaie plus tard. » (`text-error`), bouton réactivé. Si la permission est refusée, le statut affiche « Ton navigateur a bloqué les notifications. Tu peux les autoriser dans ses réglages. », et la carte reste, sans bouton.
- **Succès** : la carte est remplacée par une ligne `text-sm text-ink` « C'est noté. Tu seras prévenu. » avec l'icône `check-circle` (`aria-hidden`).

**Accessibilité** : boutons ≥ 48 px (`min-h-tap`) ; statut en `role="status"` ; l'ordre de tabulation suit l'ordre visuel ; rien porté par la couleur seule.

### 3.2 Ligne « Notifications » du profil

**Où** : dans `app/views/identity/profiles/_student_information.html.erb`, en dernière ligne de la liste. Elle passe par `identity/profiles/student_row`, avec l'icône `bell` et le libellé « Notifications ». La partial `app/views/identity/profiles/_push_row.html.erb` porte l'id `profile_notifications_row`.

**Quand elle s'affiche** : la ligne est affichée **seulement** si l'élève a déjà touché « Oui » une fois, c'est-à-dire s'il a ou a eu un abonnement ou une préférence. Sinon, il n'y a pas de ligne (règle « pas de section vide »). L'invitation se fait après une réussite, pas au profil. La ligne n'apparaît pas non plus dans la coque Android.

| État (calculé côté serveur, précisé par le contrôleur dans le navigateur) | Valeur affichée | Action |
|---|---|---|
| Abonnement sur ce navigateur, pas coupé | « Activées » | « Couper » : `PATCH push_preference_path` avec `intent=turn_off`, sans confirmation. Supprime l'abonnement de ce navigateur et pose `turned_off_at` |
| Pas coupé, abonnement sur un autre navigateur seulement | « Activées sur un autre appareil » | « Activer ici » : même contrôleur, `accept()` |
| Permission `denied` dans ce navigateur | « Bloquées par ton navigateur » | Aucune. Détail en `text-xs text-mute` : « Autorise-les dans les réglages du navigateur. » |
| Coupées | « Coupées » | « Réactiver » : efface `turned_off_at`, puis `accept()` |

Le retour est un Turbo Stream qui remplace `#profile_notifications_row`. Sans JS, c'est une redirection vers le profil avec un message flash.

### 3.3 Texte des notifications

Gabarits fermés, `config/locales/communication/push.fr.yml`, clés `communication.push.messages.<motive>.title|body`. Titre : toujours « Lnclass ». Corps : ceux du PRD §3.1. Seules variables permises : le **nom de la matière** et le **nombre d'exercices**. Icône : l'icône de l'app (`icon-192.png`) ; badge Android : silhouette monochrome à fournir. `tag` = le motif (une nouvelle notification du même motif remplace l'ancienne).

`notificationclick` : ferme la notification ; ouvre l'URL seulement si elle est de la **même origine** ; focalise un onglet déjà ouvert sur cette URL plutôt que d'en ouvrir un second.

### 3.4 Tuile du pilotage de l'équipe

La tuile « Notifications » prend place dans le pilotage de l'équipe (ADR-0062), au format des tuiles existantes :

- en grand : « N élèves abonnés » ;
- dessous, en `text-sm text-mute` : « a abonnements · b ont coupé » ;
- puis « Cette semaine : x envoyées · y échouées », et le détail par motif en liste plate, valeur à droite.

Si aucun élève n'est abonné, la tuile affiche « 0 élève abonné » sans liste. Elle ne montre aucun nom.

## 4. Conséquences

- Les écrans de résultat gagnent une carte, une fois dans la vie de l'élève (ou tous les 7 jours après « Plus tard »).
- La skill `ecrans-wave` n'est pas contredite : la carte n'existe que lorsqu'elle a une action utile.
- Interdit : demander la permission du navigateur sans clic « Oui » ; une bannière de relance sur l'accueil ; un texte de notification qui contient une donnée de l'élève.
- La coque Android n'affiche ni la carte ni la ligne du profil tant que le chantier FCM n'existe pas.
- Si le porteur choisit de demander après le premier exercice **commencé** (`## À trancher`), seule la condition d'affichage de §3.1 change, et la carte se rend aussi sur l'écran de la session.
