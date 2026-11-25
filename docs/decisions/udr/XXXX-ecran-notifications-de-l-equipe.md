# UDR-XXXX : Écran « Notifications » de l'équipe et case « Prévenir les élèves » des annonces
<!-- index
titre: Écran Notifications de l'équipe
statut: Accepté
adr-lie: ADR-XXXX-envois-de-notifications-regles-par-l-equipe
problematique: L'équipe doit régler quels motifs partent seuls, valider chaque jour les autres et décider à la publication si une annonce prévient les élèves, sans voir de nom d'élève.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-25 |
| **Chantier** | `docs/chantiers/parametrage-notifications` |
| **ADR lié** | ADR-XXXX-envois-de-notifications-regles-par-l-equipe · ADR-0146 · UDR-0186 (§3.4, tuile du Pilotage) |
| **Remplacé par** | — |

---

## 1. Contexte

Depuis le chantier `notifications-push`, l'équipe ne voit des notifications que des nombres de la semaine écoulée (tuile du Pilotage). Elle ne peut ni empêcher ni déclencher un envoi. Le porteur veut que l'équipe décide de ce qui part : chaque matin, elle doit savoir en moins d'une minute qui recevrait quoi, et valider ou laisser passer la journée.

## 2. Décision

Une page unique de l'espace équipe, **« Notifications »**, en trois cartes empilées : **Réglages**, **Plan du jour**, **Historique**. C'est une page, pas une modale : elle se consulte chaque jour et doit pouvoir être mise en favori. Chaque geste (case, validation) est un formulaire autonome, envoyé en Turbo Stream, qui remplace seulement sa ligne : pas de bouton « Enregistrer » global, pas de rechargement. Sans JavaScript, chaque formulaire répond par une redirection vers la page.

La case « Prévenir les élèves » vit dans le formulaire d'annonce existant, pas sur cette page : l'annonce se décide au moment de sa rédaction.

## 3. Règles d'implémentation

### 3.1 Accès et navigation

- Route : `GET /teams/notifications` → `teams/push_settings#show`, nom `teams_push_settings_path`. `content_for :nav_key, "push_settings"`.
- `NavigationHelper::SECONDARY_DESTINATIONS[:team]` : ajouter `[ :push_settings, :teams_push_settings_path, "bell" ]` **entre** `:billing` et `:announcements`. Libellé `shared.navigation.destinations.push_settings` : « Notifications ».
- Tuile du Pilotage `teams/dashboards/_push_tile` : sous la liste par motif (ou sous « 0 élève abonné »), un lien `ui_button t(".configure"), variant: :ghost, size: :sm, href: teams_push_settings_path, icon: "adjustments-horizontal"` ; texte « Paramétrer ».
- Titre : `ui_page_header title: "Notifications", subtitle: "Ce qui part aujourd'hui vers les élèves, et ce qui part seul."`.

### 3.2 Bandeau d'environnement (au-dessus des cartes)

Rendu seulement si l'envoi ne peut pas partir. Un seul bandeau, le premier cas qui s'applique :

| Cas | Texte | `id` |
|---|---|---|
| `PUSH_DELIVERY_ENABLED` faux | « L'envoi est coupé sur cet environnement : rien ne part, même validé. » | `push_settings_switch_off` |
| Clés VAPID absentes | « L'envoi n'est pas configuré sur cet environnement : rien ne part. » | `push_settings_not_configured` |

Classes : `rounded-ln border border-line bg-mist px-4 py-3 text-sm text-ink`, icône `exclamation-triangle` `size-5 text-warning` à gauche ; `role="status"`. Jamais la valeur d'une clé.

### 3.3 Carte « Réglages » (`id="push_settings_modes"`)

`ui_card title: "Réglages", subtitle: "Une case cochée fait partir le motif seul, chaque jour.", icon: "adjustments-horizontal"`.

Liste `<ul class="divide-y divide-line">`, une ligne `<li id="push_motive_<motive>" class="flex items-center justify-between gap-4 py-3">` par motif, dans l'ordre de `PushMotive::PRIORITY` :

| Motif | Libellé | Exemple (texte de la notification, `text-sm text-mute`) | À droite |
|---|---|---|---|
| `quiz_prep` | Interro demain | « Prépare ton interro de Maths de demain : 2 exercices. » | case « Automatique » |
| `assignment_due` | Devoir à rendre demain | « Un devoir de Maths est à rendre demain. » | case « Automatique » |
| `assignment_new` | Nouveaux exercices | « Ton prof de Maths t'a donné 3 exercices. » | case « Automatique » |
| `announcement` | Annonce de l'équipe | « Nouvelle annonce de Lnclass. » | badge `ui_badge "À la publication", tone: :neutral` |
| `unfinished` | Exercice commencé | « Tu as commencé un exercice de Maths. Termine-le ! » | badge `ui_badge "À valider chaque jour", tone: :neutral` |
| `result` | Résultat ou médaille | « Ta copie de Maths est corrigée. » | badge idem |
| `inactive` | Élève inactif (3, 7, 14 jours) | « Ta classe avance. Un exercice t'attend sur Lnclass. » | badge idem |

Les exemples sont rendus par `PushMessage.for` avec la matière « Maths » et les nombres ci-dessus, jamais écrits en dur dans la vue.

**Case « Automatique »** (interro, devoir, nouveaux exercices) :
- Un formulaire par ligne : `form_with url: teams_push_motive_setting_path(motive), method: :patch`, champ `automatic` ; interrupteur natif `<input type="checkbox" role="switch">` de 48 × 28 px (cible tactile : le `<label>` entier, au moins 48 × 48 px), `aria-describedby="push_motive_<motive>_state"`.
- Envoi au changement : nouveau contrôleur Stimulus `push-switch` (`app/javascript/controllers/push_switch_controller.js`), posé sur le formulaire, `data-action="change->push-switch#submit"` sur la case ; `submit()` appelle `this.element.requestSubmit()` et pose `aria-busy="true"` jusqu'à `turbo:submit-end`. (Le contrôleur `autosubmit` existant ne convient pas : il attend un motif de saisie.) Sans JS, un bouton « Enregistrer » `ui_button variant: :secondary, size: :sm` est rendu dans `<noscript>`.
- Sous le libellé : `<p id="push_motive_<motive>_state" class="text-xs text-mute">` « Automatique depuis le 25 nov., par Awa K. » ou « Décoché : à valider chaque jour. ».
- Pour un rôle `content` ou `field` : la case est rendue `disabled` avec `aria-disabled="true"` et la ligne d'état ajoute « Seul un admin peut changer ce réglage. ».
- Réponse : Turbo Stream `replace` de `push_motive_<motive>` **et** de `push_plan` (le motif entre ou sort du plan du jour) ; toast `ui_toast "Réglage enregistré.", type: :success`.
- Erreur (403, motif non automatisable) : toast `type: :error` « Ce réglage n'a pas été enregistré. », la ligne revient à l'état serveur.

### 3.4 Carte « Plan du jour » (`turbo_frame_tag "push_plan"`, chargée en différé)

`ui_card title: "Plan du jour", subtitle: "<jour, date> · part dans la prochaine fenêtre (12 h–14 h, 17 h–20 h ; dimanche 9 h–20 h)", icon: "calendar-days"`.

- Chargement : `turbo_frame_tag "push_plan", src: teams_push_plan_path, loading: :lazy` (route `GET /teams/notifications/plan` → `teams/push_plans#show`), contenu initial `ui_loading_state variant: :skeleton, lines: 3`.
- Une ligne `<section id="push_plan_<motive>" class="rounded-ln bg-mist p-4">` par motif **non automatique** ayant des élèves, dans l'ordre de priorité, contenant :
  1. Libellé (`font-medium text-ink`) et nombre : « 42 élèves » (`tabular-nums`, `font-display text-2xl`).
  2. Texte exact de la notification, entre guillemets français, `text-sm text-ink` ; si plusieurs textes (matières différentes), le premier et « + 3 autres matières ».
  3. Répartition par établissement : `<ul aria-label="Par établissement" class="mt-2 text-sm">`, une ligne « Lycée X — 12 », les 5 premiers puis `<details>` « Voir plus (n) ». Jamais de nom d'élève.
  4. Action : `button_to "Valider l'envoi", teams_push_approvals_path(motive:), method: :post, form: { data: { turbo_confirm: "Envoyer « <libellé> » à 42 élèves aujourd'hui ?" } }`, `ui_button` `variant: :primary`, pleine largeur sous 640 px.
- Motif déjà validé aujourd'hui : l'action est remplacée par `ui_badge "Validé", tone: :success, icon: "check"` et « par Awa K. à 10 h 12 — 42 élèves » ; le nombre affiché est celui enregistré.
- Motifs non automatiques sans élève : une ligne compacte « Exercice commencé — aucun élève concerné aujourd'hui » (`text-sm text-mute`), sans bouton.
- Après 20 h (ou dimanche après 20 h) : boutons retirés, mention « Les envois du jour sont terminés. » en tête de carte.
- Réponse à la validation : Turbo Stream `replace` de `push_plan_<motive>` (état « Validé ») et `prepend` d'une ligne dans `push_history_list` ; toast succès « Envoi validé : 42 élèves. ».
- « Déjà validé » (validation concurrente) : même rendu « Validé » avec l'auteur réel, toast `type: :info` « Déjà validé par Awa K. à 10 h 12. ».
- Validation après 20 h : toast `type: :error` « Les envois du jour sont terminés. », ligne inchangée.

### 3.5 Carte « Historique » (`id="push_history"`)

`ui_card title: "Historique", subtitle: "14 derniers jours", icon: "clock"`. Liste `<ol id="push_history_list" class="divide-y divide-line text-sm">`, du plus récent au plus ancien, 20 lignes puis « Voir plus (n) » (`<details>`) :
- validation : « 25 nov. 10 h 12 · Awa K. a validé Élève inactif — 42 élèves » ;
- réglage : « 24 nov. 18 h 03 · Moussa D. a rendu Devoir à rendre automatique » / « … a décoché Devoir à rendre ».

### 3.6 Case « Prévenir les élèves » du formulaire d'annonce

- Dans `communication/authored_messages/_form`, branche `when :team` seulement, **après** le choix d'audience : `ui_field f, :push_requested, as: :checkbox, label: "Prévenir les élèves par notification", hint: "Une notification part dans la prochaine fenêtre, une seule par élève et par jour."`.
- Contrôleur Stimulus `push-request` sur le formulaire : la case est `disabled` et décochée quand l'audience est « Enseignants » ou « Directions » ; réactivée pour « Tous » ou « Élèves ». Sans JS, le serveur ignore la case pour ces audiences.
- Branches `school_admin` et enseignant : rien n'est rendu ; le paramètre est filtré par le contrôleur.
- Ligne de l'annonce (`_row`) : si `push_requested`, une icône `bell` `size-4 text-mute` avec `aria-label="Élèves prévenus par notification"`.

### 3.7 États obligatoires

| Bloc | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Réglages | — (toujours sept lignes) | — (rendu serveur) | toast d'erreur, ligne remise à l'état serveur | toast « Réglage enregistré. » |
| Plan du jour | `ui_empty_state title: "Rien à valider aujourd'hui", description: "Les motifs automatiques partent seuls ; aucun autre élève n'est concerné.", icon: "check-circle"` | `ui_loading_state variant: :skeleton` | `ui_error_state message: "Le plan du jour n'a pas pu être calculé.", retry_href: teams_push_plan_path` dans le frame | badge « Validé » + toast |
| Historique | `ui_empty_state title: "Aucun réglage ni envoi validé ces 14 derniers jours", icon: "clock"` | — | — | — |

### 3.8 Tokens et mise en page

- Fond de page et cartes : ceux de `ui_card` (aucune couleur en dur) ; `grid grid-cols-1 gap-5`, largeur max `max-w-3xl` sur ordinateur.
- Texte : `text-ink` (principal), `text-mute` (secondaire), `text-warning` (icône du bandeau), `text-success` via `ui_badge tone: :success`.
- Nombres : `tabular-nums`.
- 390 px : les lignes de « Réglages » restent sur une ligne (libellé à gauche, case à droite), l'exemple passe sous le libellé ; boutons pleine largeur.

### 3.9 Accessibilité

- Chaque case a un `<label>` lisible (« Interro demain : automatique ») ; `role="switch"` et `aria-checked` suivent l'état.
- Le frame `push_plan` porte `aria-busy="true"` pendant le chargement.
- Les toasts sont annoncés (`role="status"`, déjà dans `ui_toast`).
- Ordre de tabulation : bandeau → cases des réglages → boutons « Valider l'envoi » dans l'ordre des motifs → historique.
- Focus visible : celui des composants (`focus-visible:ring`), jamais retiré.

### 3.10 Textes

Tous dans `config/locales/teams/push_settings.fr.yml` (`teams.push_settings.*`, `teams.push_plans.*`, `teams.push_approvals.*`, `teams.push_motive_settings.*`) ; libellés de motif partagés avec la tuile : `teams.dashboards.push_tile.motives.<motive>` (ajouter `assignment_new: "Nouveaux exercices"`).

## 4. Conséquences

- Toute nouvelle notification aux élèves passe par cet écran : un motif ajouté plus tard y prend une ligne dans « Réglages » et, s'il n'est pas automatisable, dans le plan du jour.
- Interdit : afficher un nom ou un identifiant d'élève sur cet écran ; un bouton « Envoyer maintenant » qui contournerait les fenêtres ; une case « Automatique » sur une relance sans nouvelle décision du porteur.
- La tuile du Pilotage reste en lecture seule ; elle ne fait que pointer vers cet écran.
