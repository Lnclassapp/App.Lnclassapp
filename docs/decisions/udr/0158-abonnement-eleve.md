# UDR-0158 : Mon abonnement et bandeau des jours gratuits de l'élève
<!-- index
titre: Abonnement de l'élève
statut: Proposé
adr-lie: XXXX-contexte-billing-cartes-activation
problematique: Dire à l'élève combien de jours gratuits il lui reste, où acheter sa carte quand il est bloqué, et lui faire saisir son code sans friction sur téléphone.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-07 |
| **Chantier** | `docs/chantiers/cartes-activation` |
| **ADR lié** | ADR-0126 |
| **Remplacé par** | — |

---

## 1. Contexte

Un élève de Tiassalé, sur un téléphone d'entrée de gamme, utilise Lnclass 7 jours gratuits. Au 8e jour, « Commencer » ne démarre plus rien. S'il ne comprend pas pourquoi, ni où acheter, il abandonne : c'est un abonnement perdu. Quand il a sa carte, il doit pouvoir taper 12 caractères sans se tromper.

## 2. Décision

- **Une seule page, Mon abonnement** (`/abonnement`), qui sert à la fois d'invitation (élève bloqué), de saisie du code et de reçu (élève abonné). Pas de modale : l'élève y arrive par redirection depuis « Commencer », et la page doit tenir seule, partageable par capture d'écran au parent.
- **Le point relais est nommé** sur la page (memo Q12) : c'est ce qui transforme le blocage en achat.
- **Un bandeau discret sur l'accueil** pendant la période gratuite, plus visible les 3 derniers jours ; rien pour l'abonné sinon une ligne dans Mon abonnement.

## 3. Règles d'implémentation

**Structure — page Mon abonnement** (`app/views/billing/subscriptions/show.html.erb`, contrôleur `Billing::SubscriptionsController#show`, rôle `student` seulement)
1. `ui_page_header title: t(".title")` (« Mon abonnement »), sans sous-titre, `back:` vers l'accueil élève.
2. Colonne unique `mx-auto w-full max-w-180 space-y-6`.
3. **Carte d'état** (`ui_card`) selon l'accès :
   - `free` : icône `gift`, titre « Il te reste N jours gratuits » (`t(".free.title", count:)`), texte « Ensuite, l'abonnement coûte 10 000 F jusqu'au 31 juillet 2027. »
   - `blocked` : icône `lock-closed` sur `bg-warning-soft text-warning`, titre « Ta période gratuite est terminée », texte « Tu vois toujours tes cours et tes exercices. Pour recommencer à t'entraîner, abonne-toi : 10 000 F jusqu'au 31 juillet 2027. »
   - `subscribed` : icône `check-badge` sur `bg-success-soft text-success`, titre « Ton abonnement est actif », texte « Jusqu'au 31 juillet 2027. » ; **aucun formulaire ni point relais** en dessous.
4. **Où acheter** (`free` et `blocked`) : `ui_card` titré « Où acheter ta carte ». Liste `ul` des points relais rattachés à l'école de l'élève, triés par nom : par ligne, le nom en `font-semibold text-ink`, le lieu en `text-sm text-mute`, le téléphone en lien `tel:` (`text-brand`, icône `phone`). Sans école ou sans point relais : `ui_empty_state` icône `chat-bubble-left-right`, titre « Écris-nous pour trouver un point relais », bouton `ui_button` « Écrire sur WhatsApp » vers `whatsapp_url` du numéro équipe (`t("billing.team_whatsapp")`).
5. **Saisie du code** (`free` et `blocked`) : `ui_card` titré « J'ai ma carte ». `form_with url: billing_activation_path, id: "activation-form"` ; un `ui_field :code` libellé « Code de ta carte », `placeholder: "XXXX-XXXX-XXXX"`, `autocomplete: "off"`, `autocapitalize: "characters"`, `spellcheck: false`, `inputmode: "text"`, `maxlength: 20`, aide « 12 lettres et chiffres, au dos de ta carte » ; bouton plein largeur sous 640 px « Activer mon abonnement ».

**Structure — bandeau de l'accueil** (`app/views/billing/subscriptions/_home_notice.html.erb`, rendu dans `classroom/student_homes/show.html.erb` juste avant `render "next_step"`)
- `free` et `days_left > 3` : une ligne `rounded-ln bg-info-soft text-info text-sm px-4 py-3`, icône `gift`, « Il te reste N jours gratuits », lien « Mon abonnement ».
- `free` et `days_left ≤ 3` : même ligne en `bg-warning-soft text-warning`, « Plus que N jours gratuits. Abonne-toi pour 10 000 F », lien « M'abonner ».
- `blocked` : `bg-warning-soft text-warning`, « Ta période gratuite est terminée », lien « M'abonner ».
- `subscribed` ou acteur non élève : rien.

**Tokens**
- Couleurs : `ink`, `mute`, `brand`, `info(-soft)`, `warning(-soft)`, `success(-soft)`, `error(-soft)`, `line` ; aucune valeur en dur.
- Rayons et ombres : `rounded-card`, `shadow-card` (cartes), `rounded-ln` (bandeau, alertes).
- Montants toujours écrits « 10 000 F » (espace insécable fine `number_to_currency` non utilisé : `t` avec la chaîne figée par l'offre).

**Comportement**
- Pas de Turbo Frame : le formulaire poste en Turbo Drive. Succès → `redirect_to billing_subscription_path` avec `flash[:notice]` « Ton abonnement est actif jusqu'au 31 juillet 2027 » (toast) ; si l'élève venait d'un exercice (`return_to` signé en session par la redirection de blocage), redirection vers cet exercice.
- Échec → `render :show, status: :unprocessable_content` avec l'erreur sous le champ.
- Freinage (`rate_limit`) → `render :show, status: :too_many_requests`, alerte « Trop de tentatives. Réessaie dans quelques minutes. ».
- Redirection de blocage : `ExerciseSessionsController`, `SheetChecksController`, `PracticeChecksController` → `redirect_to billing_subscription_path, alert: t("billing.subscription_required")` (« Ta période gratuite est terminée. Abonne-toi pour continuer. ») ; en Turbo Stream (vérification de fiche), réponse `turbo_stream.action(:redirect, …)` comme la pause existante, ou `redirect_to` avec `status: :see_other`.

**États obligatoires**
- Vide : sans point relais → état vide WhatsApp (§3.4).
- Chargement : bouton « Activer » désactivé avec `ui_spinner` pendant l'envoi (`data-turbo-submits-with`).
- Erreur : `role="alert"` sous le champ, messages du PRD §3 (code inconnu, déjà utilisée, annulée, déjà abonné, trop de tentatives) ; la saisie reste dans le champ.
- Succès : carte d'état `subscribed` + toast.

**Accessibilité**
- Champ et bouton ≥ 48 px de haut ; `aria-describedby` du champ vers l'aide et l'erreur ; `aria-invalid="true"` en erreur.
- L'icône d'état est `aria-hidden` ; le titre de la carte d'état est un `h2`.
- Le bandeau est un `p` dans une `section aria-label="Abonnement"` ; son lien a un libellé explicite.

## 4. Conséquences

- L'accueil élève reçoit une ligne de plus au-dessus de la carte du prochain exercice.
- Aucune autre vue élève ne cache ses boutons : le blocage s'apprend en touchant « Commencer », jamais par des boutons grisés.
- Tout futur moyen de paiement s'ajoute comme une carte de plus sur Mon abonnement.
