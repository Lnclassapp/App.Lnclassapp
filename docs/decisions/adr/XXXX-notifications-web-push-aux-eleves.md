# ADR-XXXX : Notifications aux élèves par Web Push — clés VAPID en environnement, un port d'envoi, des abonnements à durée de vie bornée
<!-- index
titre: Notifications Web Push aux élèves — VAPID, port d'envoi, abonnements bornés, programme d'arrière-plan partagé
statut: Proposé
problematique: Premier envoi sortant de l'application. Web Push (VAPID, gem `web-push`) derrière `PushGatewayPort` (contexte `communication`) ; tables `push_subscriptions`, `push_preferences`, `push_deliveries` ; un abonnement se supprime à la désinscription, à la déconnexion, au refus 404/410, après 60 jours sans succès et à l'anonymisation ; écouteurs `push`/`notificationclick` ajoutés au programme d'arrière-plan de `hors-connexion` sans toucher ses caches. Chantier `notifications-push`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-16 |
| **Chantier** | [`docs/chantiers/notifications-push`](../../chantiers/notifications-push/memo.md) |
| **Amende** | [ADR-0045](./0045-annonces-publication-programmee-et-audience.md) (« Hors périmètre : notifications ») · [ADR-0036](./0036-suppression-archivage-et-anonymisation.md) (ce que l'anonymisation efface) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Au 2026-11-16, aucun élève n'a fait plus de deux exercices, et l'application ne peut joindre personne en dehors d'une visite. Il n'y a ni courriel ni SMS, et WhatsApp est payant. Le porteur veut un canal pour faire revenir les élèves : six motifs, élèves seulement, des horaires mais pas de plafond (PRD §3.1).

L'état du code :

- le programme d'arrière-plan (`app/views/pwa/service-worker.js`, portée « / ») a quatre écouteurs : `install`, `activate`, `message` et `fetch`. Il gère les caches du chantier `hors-connexion` (`lnclass-offline-v3`, `lnclass-assets-v1`), et son `activate` purge les anciennes versions ;
- aucun `push`, `notificationclick`, `pushManager` ni `Notification` n'existe dans le code ; aucune table ne porte d'abonnement ;
- il n'y a aucun bus d'événements : l'attribution d'une médaille n'est connue que du contrôleur qui clôt la session ;
- l'ADR-0049 interdit tout script tiers et exige un ADR pour tout nouvel outil.

La coque Android (Hotwire Native) ne reçoit pas le Web Push ; elle relèvera d'un chantier FCM séparé (ADR-0070).

## 2. Moteurs de décision

1. **Coût nul** : aucun fournisseur payant.
2. **Aucun script tiers** dans les pages (ADR-0049) et une CSP inchangée.
3. **Un seul endroit pour le métier** : motifs, horaires et garde-fou anti-rafale vivent dans le domaine ; le transport n'est qu'un adaptateur, remplaçable ou doublé plus tard (FCM).
4. **Données minimales et bornées dans le temps** : on ne garde d'un abonnement que ce qu'il faut pour envoyer, tant qu'il sert.
5. **Ne rien casser du hors-connexion** : ses caches et sa purge restent intacts.

## 3. Options envisagées

### 3.1 Transport

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — **Web Push standard (RFC 8030, 8291, 8292) avec la gem `web-push`** | Gratuit ; aucun script tiers (l'API Push est native au navigateur) ; charge chiffrée de bout en bout ; serveur seul détenteur de la clé privée | Retenue |
| B — Firebase Cloud Messaging sur le site (SDK JS) | Le même outil que celui que voudra la coque | Il faut un script tiers dans les pages, contraire à l'ADR-0049, et un compte Google |
| C — Fournisseur agrégateur (OneSignal…) | Tableau de bord tout fait | Payant au-delà d'un seuil, script tiers, données d'élèves chez un tiers de plus |
| D — Polling ou Turbo Streams à la visite | Rien à installer | Ne joint pas l'élève absent, qui est tout le problème |

### 3.2 Déclenchement

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Événements émis par les use cases (clôture de session, publication d'annonce, assignation) | Immédiat | Il n'existe aucun bus. Il faudrait toucher `CloseExerciseSession`, les annonces et les assignations, dans trois contextes, pour des envois qui de toute façon attendent une fenêtre |
| B — **Une tâche récurrente qui lit les motifs au moment de l'envoi** | Aucun contexte existant modifié ; un motif est relu juste avant l'envoi, donc une copie rendue ou une annonce retirée ne part pas ; horaires et anti-rafale en un seul point | Retenue. Coût : un envoi part au passage suivant (15 min au plus dans une fenêtre) |

## 4. Décision

> **Nous envoyons les notifications aux élèves par Web Push (VAPID), derrière un port d'envoi du contexte `communication`. Les clés vivent dans les variables d'environnement. Une tâche récurrente lit les six motifs, applique les fenêtres d'Abidjan et le garde-fou anti-rafale, puis envoie. Nous ne gardons d'un abonnement que son adresse et ses deux clés. Il est supprimé à la désinscription, à la déconnexion, au premier refus du service, après 60 jours sans envoi réussi et à l'anonymisation. Le programme d'arrière-plan gagne deux écouteurs, sans toucher aux caches du hors-connexion.**

### 4.1 Ce qu'on stocke, et combien de temps

| Table (contexte `communication`) | Colonnes | Durée de vie |
|---|---|---|
| `push_subscriptions` | `user_id`, `session_id` (nullable, `ON DELETE SET NULL`), `endpoint` (unique), `p256dh`, `auth`, `created_at`, `last_success_at`, `failure_count` | Supprimée : à « Couper » sur le profil ; à la **déconnexion** de la session qui l'a créée (et quand un changement de PIN ou de numéro ferme les sessions, ADR-0055) ; au premier **404 ou 410** du service push ; après **60 jours sans envoi réussi** ; à l'**anonymisation** |
| `push_preferences` | `user_id` (unique), `turned_off_at`, `invitation_postponed_until` | Tant que le compte existe ; supprimée à l'anonymisation |
| `push_deliveries` | `user_id`, `motive`, `object_key`, `sent_at`, `status` (`delivered`, `gone`, `retry`, `failed`, `disabled`, `not_configured`), index unique (`user_id`, `motive`, `object_key`) | **90 jours** (anti-doublon, intervalle, pilotage), purgés chaque jour ; supprimés à l'anonymisation |

On ne stocke ni agent utilisateur, ni adresse IP, ni modèle d'appareil. Une **expiration** de session (30 jours, ADR-0050) garde l'abonnement (`session_id` passe à `NULL`) : l'élève décroché reste joignable, et toucher la notification le ramène à la connexion. Une adresse déjà connue qu'un autre compte envoie change de propriétaire : sur un navigateur partagé, c'est le dernier compte connecté qui reçoit.

### 4.2 Port et adaptateur

```ruby
# app/domain/ports/communication/push_gateway_port.rb
module Ports
  module Communication
    # Envoie une notification déjà rédigée à un abonnement. Ne connaît ni l'élève ni le motif.
    # message : Entities::Communication::PushMessage (title, body, url, tag), texte issu d'un gabarit fermé.
    # → :delivered | :gone (abonnement à supprimer) | :retry | :not_configured
    module PushGatewayPort
      def deliver(subscription:, message:) = raise NotImplementedError
    end
  end
end
```

- L'adaptateur `Gateways::Communication::WebPushGateway` vit dans `app/infrastructure/gateways/communication/web_push_gateway.rb`. Il utilise la gem `web-push`, avec `ttl: 12 h`, `urgency: "normal"` et `topic` = le motif.
- Il ne lève pas d'exception : 201 donne `:delivered`, 404 et 410 `:gone`, 429 et 5xx ou un délai dépassé `:retry`, et l'absence de clé `:not_configured`.
- Un futur adaptateur FCM implémentera le même port, sans toucher au domaine.

### 4.3 Secrets et configuration

Ces variables d'environnement ne sont jamais dans le dépôt :

- `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` : générées une fois par environnement (recette, production) ;
- `VAPID_SUBJECT` : adresse de contact `mailto:` ou URL.

La clé **publique** est servie à la page dans un attribut `data-` (elle n'est pas secrète, mais elle suit son environnement). Deux réglages complètent :

- `PUSH_DELIVERY_ENABLED` : faux par défaut. Il sert à la mise en service progressive : les abonnements s'enregistrent, mais les envois sont notés `disabled` ;
- `PUSH_MIN_INTERVAL_HOURS` : 4 par défaut.

Changer la paire VAPID invalide tous les abonnements : on ne la change pas, sauf fuite.

### 4.4 Cohabitation avec le programme d'arrière-plan de `hors-connexion`

- On ajoute les écouteurs `push` et `notificationclick`. On ne modifie ni `install`, ni `activate`, ni `fetch`, ni `message`, ni les noms de caches. Il n'y a donc **pas de changement de version de cache** pour ce chantier.
- `push` lit `{ title, body, url, tag }` (JSON) et appelle `showNotification` avec l'icône `icon-192.png`, déjà dans `OFFLINE_FILES`.
- `notificationclick` ferme la notification. Il ouvre l'URL **seulement si elle est de la même origine**, et met au premier plan un onglet déjà ouvert sur elle plutôt que d'en ouvrir un second.
- La fusion suit l'ordre du chantier `hors-connexion` : le lot qui touche ce fichier rebase sur `Develop` avant sa PR.
- Changer l'abonnement côté navigateur (`pushsubscriptionchange`) est hors V1 : un abonnement perdu est remplacé à la prochaine visite par le contrôleur Stimulus, qui compare `getSubscription()` à ce que le serveur connaît.

### 4.5 Anonymisation et sessions

- `UseCases::Identity::AnonymizeUser` (ADR-0036) supprime `push_subscriptions`, `push_preferences` et `push_deliveries` de l'élève, dans sa transaction, à côté de l'effacement des résultats.
- `SignOut`, `ChangeOwnPin` et `ChangeOwnContact` suppriment les abonnements des sessions qu'ils ferment.
- Quand l'ADR-0093 sera migré (désactivation), un compte désactivé est ignoré par la tâche d'envoi, et ses abonnements sont supprimés.

## 5. Conséquences

### 🟢 Positives

- C'est le premier canal pour faire revenir un élève, et il est gratuit.
- Les règles de métier (motifs, fenêtres, anti-rafale) existent en un seul point. Un second transport (FCM pour la coque) se branche sur le même port.
- Aucun use case existant d'`assessment`, de `classroom` ni des annonces n'est modifié.

### 🔴 Coûts consentis

- **Une partie des élèves n'est pas joignable** : la coque Android, l'iPhone sans PWA installé, et les navigateurs sans API Push.
- **Un service tiers par navigateur** (Google, Mozilla, Apple) reçoit une adresse d'abonnement. Le texte lui reste illisible, car il est chiffré.
- **Une gem et un client HTTP sortant** de plus, et une paire de clés à ne jamais perdre ni changer.
- **Un envoi est en retard de 15 minutes au plus**, et un motif prêt hors fenêtre attend des heures. C'est voulu.
- **Le programme d'arrière-plan devient partagé** par deux chantiers, d'où un ordre de fusion à tenir.
- **Un abonnement silencieusement supprimé par le navigateur** ne se voit qu'au refus suivant ou à 60 jours.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/communication/deliver_push_notifications.rb (extrait prévu)
return :turned_off  if @preferences.turned_off?(user_id:)
return :closed      unless @window.open?(@clock.now)            # Africa/Abidjan
return :duplicate   if @deliveries.sent?(user_id:, motive:, object_key:)
return :too_soon    if (last = @deliveries.last_sent_at(user_id:)) && last > @clock.now - @min_interval
```

```js
// app/views/pwa/service-worker.js (ajout prévu, après les écouteurs du hors-connexion)
self.addEventListener("push", (event) => {
  const { title, body, url, tag } = event.data?.json() ?? {}
  event.waitUntil(self.registration.showNotification(title, { body, tag, icon: "/icon-192.png", data: { url } }))
})
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/use_cases/communication/deliver_push_notifications_test.rb` : aucun appel au port si l'élève a coupé, si l'interrupteur est fermé, hors fenêtre, en cas de doublon, ou avant 4 h.
- `test/domain/entities/communication/push_message_test.rb` : aucun gabarit ne contient de nom, de numéro, de note, de niveau de médaille ni de titre d'annonce.
- `test/domain/use_cases/identity/anonymize_user_test.rb` (amendé) : zéro ligne `push_*` après l'anonymisation.
- `test/infrastructure/gateways/communication/web_push_gateway_test.rb` : 404 et 410 donnent `:gone`, et des clés absentes `:not_configured`.
- `test/domain/use_cases/communication/purge_push_data_test.rb` : un abonnement de 61 jours sans succès est supprimé, de même qu'un envoi de 91 jours.
- `git grep -n "VAPID_PRIVATE_KEY" -- app config` ne trouve que des lectures de `ENV`.
