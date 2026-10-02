# UDR-0060 : Connexion et récupération du PIN — un titre, un formulaire, une action, pour tous les rôles

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/memo.md) — grill Q3, Q4, Q8, Q9, Q11, Q12 ; [plan](../../chantiers/interface-epuree/plan.md), Lot F |
| **ADR lié** | [ADR-0050](../adr/0050-authentification-et-session.md) (connexion, verrouillage) · [ADR-0032](../adr/0032-recuperation-assistee-du-pin.md) (code de récupération) · [ADR-0031](../adr/0031-second-facteur-totp-pour-l-equipe.md) (second facteur de l'équipe) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (CSP stricte) · [UDR-0057](0057-ecrans-eleve-epures.md) (règle R1 à R6) · [UDR-0005](0005-design-system-fondateur.md) (tokens, composants) · [UDR-0051](0051-afficher-le-code-pin.md) (bouton œil) · [UDR-0054](0054-finitions-d-interface.md) (logo, retour, focus, infobulle) · [UDR-0059](0059-homepage-telephone-et-tablette.md) (écran de bienvenue) |
| **Remplacé par** | — |

---

## 1. Contexte

Aucune UDR ne décrit ces deux écrans. Ils ont été construits par petites touches (ADR-0050, ADR-0032, UDR-0051, UDR-0054). Ce sont des écrans d'entrée : l'élève, l'enseignant, la direction et l'équipe y passent tous (grill Q9). L'UDR-0057 les soumet à la règle de sobriété, pour tous les rôles.

### 1.1 Connexion, aujourd'hui

`GET /login` (`new_session_path`), vue `identity/sessions/new`, layout `application`, sans shell.

- **Sous 768 px (`md`)**, une colonne, de haut en bas :
  - le logo, lien vers l'accueil public ;
  - la phrase « Connectez-vous avec votre numéro de téléphone et votre PIN à 4 chiffres. » ;
  - une carte, avec un `h2` « Connexion » centré et la ligne « Élève · Enseignant · Équipe » ;
  - le formulaire.
- **À partir de 768 px**, deux colonnes :
  - à gauche, sur `bg-brand-soft` : le logo, un `h1` « Heureux de vous revoir », puis la même phrase ;
  - à droite : la même carte.
- **Le formulaire** :
  - « Numéro de téléphone », exemple « 07 00 00 00 00 » ;
  - « PIN », avec le bouton œil (UDR-0051) et l'aide « 4 chiffres. » sous le champ ;
  - une infobulle : « Code secret de 4 chiffres, choisi à l'inscription. Oublié ? Utilisez « PIN oublié ». » ;
  - le bouton `brand` « Se connecter », pleine largeur ;
  - le lien « PIN oublié ? ».

Ce qui charge l'écran :

- **« 4 chiffres » est dit trois fois** : dans la phrase, dans l'aide du champ et dans l'infobulle (R6).
- **La phrase répète les libellés** « Numéro de téléphone » et « PIN ». Elle reste affichée en permanence (R4, R6).
- **« Élève · Enseignant · Équipe » est un texte permanent** qui n'apprend rien (R4). Il est aussi inexact : la direction se connecte ici.
- **L'infobulle renvoie à « PIN oublié »**, que le lien juste en dessous dit déjà (R6).
- **Sous 768 px, l'écran n'a pas de `h1`** : il est dans la colonne de gauche, masquée.
- **Les deux colonnes basculent à `md`.** L'UDR-0057 fait de `lg` la seule frontière de mise en page.

### 1.2 Récupération du PIN, aujourd'hui

`GET /identity/pin-reset` (`new_identity_pin_reset_path`), vue `identity/pin_resets/new`, layout `application`, sans shell.

- Une colonne centrée, de haut en bas :
  - le logo, lien vers l'accueil public ;
  - le lien de retour « Se connecter » ;
  - une carte `ui_card` : icône « clé », `h2` « PIN oublié », sous-titre « Saisissez le code de récupération remis par votre enseignant ou par l'équipe. » ;
  - le formulaire.
- **Le formulaire** :
  - « Numéro de téléphone » ;
  - « Code de récupération », avec l'aide « 8 chiffres, valable 15 minutes. » ;
  - « Nouveau PIN », avec le bouton œil et l'aide « 4 chiffres. » ;
  - « Confirmation du PIN », avec le bouton œil ;
  - le bouton `brand` « Enregistrer le nouveau PIN », pleine largeur.

Ce qui charge l'écran :

- **Deux aides restent affichées en permanence** (R4).
- **L'écran n'a pas de `h1`** : le titre de la carte est un `h2`.
- **Sa carte n'a pas le style de celle de la connexion** : icône et titre à gauche ici, titre centré sans icône là-bas. Le grill Q9 refuse deux styles côte à côte sur le parcours d'entrée.

Les deux écrans respectent déjà R1 (une seule action `brand`), R2, R3 (aucune liste) et R5.

## 2. Décision

1. **Une seule version pour tous les rôles** (grill Q9). Aucune variante par rôle : l'écran ne connaît pas encore la personne.
2. **Une seule structure pour les deux écrans** : logo, retour s'il y en a un, carte, formulaire, une action `brand`. Le titre de la carte est le `h1` de la page, par `ui_card(heading: :h1)`, sans icône.
3. **On retire ce qui est dit deux fois ou affiché en permanence.** Une contrainte de format passe dans un `ui_info_tip`. Le message d'erreur du champ, qui existe déjà, la redit au besoin.
4. **La connexion garde ses deux colonnes à partir de `lg`** : c'est sa mise en page actuelle, que le porteur garde sur grand écran (grill Q11). Le seuil passe de `md` à `lg` (UDR-0057 §3). La tablette prend donc la colonne unique, comme le téléphone (grill Q12). On ne supprime pas la colonne de gauche : elle porte le logo et l'accueil, sans rien répéter.
5. **La récupération garde son sous-titre.** Ce n'est pas une aide sur un champ. C'est la seule phrase qui dit d'où vient le code. Sans elle, une personne sans code est dans une impasse. C'est l'unique exception à R4 sur ces deux écrans.
6. **Aucun garde-fou de sécurité ne change** (§3.8). Seuls la mise en page et les textes d'aide changent.

### Ce qui change

**Connexion**

| Élément | Aujourd'hui | Après | Règle | Où va l'information |
|---|---|---|---|---|
| Phrase « Connectez-vous avec votre numéro de téléphone et votre PIN à 4 chiffres. » | sous le logo (sous `md`) et dans la colonne de gauche (à partir de `md`) | retirée | R4, R6 | Les libellés « Numéro de téléphone » et « PIN » la disent. « 4 chiffres » est dans l'infobulle du PIN. |
| Ligne « Élève · Enseignant · Équipe » | sous le titre de la carte | retirée | R4 | Nulle part : elle ne porte aucune donnée. L'écran sert à tous les rôles. |
| Aide du PIN « 4 chiffres. » | sous le champ, en permanence | retirée | R4, R6 | Infobulle du PIN. Message d'erreur « Le PIN compte 4 chiffres. ». |
| Infobulle du PIN | « Code secret de 4 chiffres, choisi à l'inscription. Oublié ? Utilisez « PIN oublié ». » | « Code secret de 4 chiffres, choisi à l'inscription. » | R6 | Le lien « PIN oublié ? », juste en dessous. |
| Titre « Connexion » | `h2` centré, dans un bloc propre à la vue | `h1`, en-tête de `ui_card` | Accessibilité ; grill Q9 (un seul style) | — |
| « Heureux de vous revoir » | `h1` de la colonne de gauche, absente sous `md` | paragraphe de la colonne de gauche, à partir de `lg` | Accessibilité (le `h1` est le titre de la carte) | — |
| Seuil des deux colonnes | `md` (768 px) | `lg` (1 024 px) | UDR-0057 §3 (une seule frontière) | — |
| Lien « PIN oublié ? » | texte simple, sans hauteur minimale | même texte, cible de 48 px | UDR-0005 (cibles tactiles) | — |

**Récupération du PIN**

| Élément | Aujourd'hui | Après | Règle | Où va l'information |
|---|---|---|---|---|
| Icône « clé » de la carte | à gauche du titre | retirée | Grill Q9 (un seul style) | Le titre « PIN oublié » nomme l'écran. |
| Titre « PIN oublié » | `h2` | `h1` | Accessibilité | — |
| Aide du code « 8 chiffres, valable 15 minutes. » | sous le champ, en permanence | dans un `ui_info_tip`, sous le champ | R4 | Infobulle du code. Messages « Le code de récupération compte 8 chiffres. » et « Ce code a expiré. Demandez-en un nouveau. ». |
| Aide du nouveau PIN « 4 chiffres. » | sous le champ, en permanence | dans un `ui_info_tip` : « Code secret de 4 chiffres, que vous choisissez. » | R4 | Infobulle du nouveau PIN. Message « Le PIN compte 4 chiffres. ». |
| Sous-titre « Saisissez le code de récupération remis par votre enseignant ou par l'équipe. » | sous le titre | inchangé | R4, exception motivée (§2.5) | — |
| Logo, retour « Se connecter », champs, bouton | — | inchangés | — | — |

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Cadre commun

- Les deux vues gardent le layout `application`, sans shell. Elles appellent `page_title` comme aujourd'hui (« Connexion · Lnclass », « PIN oublié · Lnclass »).
- Le contrôleur, les routes, les DTO et les use cases ne changent pas. Le lot ne touche que les deux vues et leurs deux fichiers de libellés.
- La carte du formulaire est `ui_card(title:, heading: :h1, padding: :lg)`, sans `icon:`. C'est le seul `h1` de la page.
- L'alerte d'erreur reste en tête du formulaire, sans changement : `div[role="alert"]`, `rounded-ln bg-error-soft px-4 py-3 text-sm font-medium text-error`, icône `exclamation-circle` (`mini`, `sm`), puis `@form.errors[:base].to_sentence`.
- Une infobulle de champ suit toujours le même motif : un `div` qui contient `ui_field`, puis `ui_info_tip(texte, label: <libellé du champ>)`. Le libellé vient de `human_attribute_name` du DTO, jamais d'une chaîne recopiée.
- Aucun champ ne garde d'option `hint:`.

### 3.2 Connexion — `app/views/identity/sessions/new.html.erb`

Hiérarchie, du conteneur à l'élément :

1. `main.grid.min-h-dvh.bg-paper.lg:grid-cols-2`.
2. **Colonne d'accueil** : `section.hidden.items-center.justify-center.bg-brand-soft.p-10.lg:flex`. Elle n'existe qu'à partir de `lg`.
   - `div.max-w-sm.text-center` ;
   - le lien du logo : `link_to root_path`, `aria-label: t(".logo_home")`, classes actuelles (`mx-auto mb-6 flex w-fit min-h-tap items-center rounded-card focus-visible:outline-2 focus-visible:outline-brand`) ;
   - dans le lien, `image_tag "logo/lnclass.jpeg", alt: ""`, `size-16 rounded-card object-cover shadow-card` ;
   - `p.font-display.text-2xl.font-extrabold.text-ink` : `t(".welcome")` (« Heureux de vous revoir »). Ce n'est plus un titre.
   - Plus aucun autre texte.
3. **Colonne du formulaire** : `section.flex.flex-col.items-center.justify-center.px-gutter.py-10`.
   - `div.mb-8.text-center.lg:hidden` : le même lien du logo, image `size-14`. Plus aucun texte.
   - `div.w-full.max-w-sm`, puis `ui_card title: t(".title"), heading: :h1, padding: :lg`.
4. **Formulaire** : `form_with model: @form, scope: :session, url: session_path, id: "session-form", class: "space-y-5"`. Dans l'ordre :
   1. l'alerte d'erreur (§3.1) ;
   2. `ui_field form, :contact`, inchangé : `as: :tel`, `required: true`, `value: @form.raw_contact`, `maxlength: 15`, `placeholder: t(".contact_placeholder")`, `inputmode: "tel"`, `autocomplete: "username"`, `autofocus: !@prefilled` ;
   3. un `div` qui contient :
      - `ui_field form, :pin, as: :password, reveal: true, required: true, maxlength: 4, inputmode: "numeric", autocomplete: "current-password", autofocus: @prefilled`, **sans `hint:`** ;
      - `ui_info_tip t(".pin_info_tip"), label: Dtos::Identity::CredentialsInput.human_attribute_name(:pin)` ;
   4. `ui_button t(".submit"), type: :submit, variant: :brand, full: true` ;
   5. `p.text-center.text-sm`, puis le lien `t(".forgot_pin")` vers `new_identity_pin_reset_path`, classes `inline-flex min-h-tap items-center font-medium text-brand-strong underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-brand`.

### 3.3 Récupération du PIN — `app/views/identity/pin_resets/new.html.erb`

Hiérarchie, du conteneur à l'élément :

1. `main.flex.min-h-dvh.flex-col.items-center.justify-center.bg-paper.px-gutter.py-10`, inchangé.
2. `div.w-full.max-w-sm`, puis, dans l'ordre :
   - `div.mb-6.text-center` : le lien du logo, inchangé (image `size-14`) ;
   - `ui_back_link t(".back"), href: new_session_path`, inchangé ;
   - `ui_card title: t(".title"), subtitle: t(".subtitle"), heading: :h1, padding: :lg`. **Sans `icon:`.**
3. **Formulaire** : `form_with model: @form, scope: :pin_reset, url: identity_pin_reset_path, id: "pin-reset-form", class: "space-y-5"`. Dans l'ordre :
   1. l'alerte d'erreur (§3.1) ;
   2. `ui_field form, :contact`, inchangé : `as: :tel`, `required: true`, `maxlength: 15`, `placeholder: t("identity.sessions.new.contact_placeholder")`, `inputmode: "tel"`, `autocomplete: "tel"` ;
   3. un `div` qui contient :
      - `ui_field form, :code, required: true, value: "", maxlength: 9, inputmode: "numeric", autocomplete: "one-time-code"`, **sans `hint:`** ;
      - `ui_info_tip t(".code_info_tip"), label: Dtos::Identity::PinResetInput.human_attribute_name(:code)` ;
   4. un `div` qui contient :
      - `ui_field form, :pin, as: :password, reveal: true, required: true, maxlength: 4, inputmode: "numeric", autocomplete: "new-password"`, **sans `hint:`** ;
      - `ui_info_tip t(".pin_info_tip"), label: Dtos::Identity::PinResetInput.human_attribute_name(:pin)` ;
   5. `ui_field form, :pin_confirmation, as: :password, reveal: true, required: true, maxlength: 4, inputmode: "numeric", autocomplete: "new-password"`, inchangé ;
   6. `ui_button t(".submit"), type: :submit, variant: :brand, full: true`, inchangé.

### 3.4 Libellés

`config/locales/identity/sessions.fr.yml`, sous `identity.sessions.new` :

| Clé | Après |
|---|---|
| `welcome_hint` | supprimée |
| `audience` | supprimée |
| `pin_hint` | supprimée |
| `pin_info_tip` | « Code secret de 4 chiffres, choisi à l'inscription. » (le commentaire « À valider par le porteur » part avec l'ancien texte) |
| `page_title`, `logo_home`, `welcome`, `title`, `contact_placeholder`, `submit`, `forgot_pin` | inchangées |
| `create.signed_in`, `destroy.signed_out` | inchangées |

`config/locales/identity/pin_resets.fr.yml`, sous `identity.pin_resets.new` :

| Clé | Après |
|---|---|
| `code_hint` | supprimée |
| `pin_hint` | supprimée |
| `code_info_tip` | nouvelle : « 8 chiffres, valable 15 minutes. » |
| `pin_info_tip` | nouvelle : « Code secret de 4 chiffres, que vous choisissez. » |
| `page_title`, `logo_home`, `title`, `subtitle`, `submit`, `back` | inchangées |
| `create.pin_changed` | inchangée |

Les messages d'erreur de `config/locales/shared/common.fr.yml` ne changent pas.

Les deux écrans vouvoient : ils servent à tous les rôles.

### 3.5 Tokens

- Tokens du `@theme` uniquement (UDR-0005) : `bg-paper`, `bg-brand-soft`, `text-ink`, `text-mute`, `text-brand-strong`, `bg-error-soft`, `text-error`, `rounded-card`, `rounded-ln`, `shadow-card`, `px-gutter`, `min-h-tap`, `max-w-sm`.
- Aucun token nouveau.
- Aucun `#hex`, aucun `style=`, aucune valeur entre crochets, aucun `dark:`. Pas de mode sombre.
- Une seule couleur d'accent : `brand` (bouton, lien « PIN oublié ? », contour de focus). `error` ne sert qu'aux erreurs.

### 3.6 Comportement

- Aucun Turbo Frame, aucun Turbo Stream, aucun contrôleur Stimulus nouveau.
- Le formulaire part par Turbo Drive, comme aujourd'hui :
  - un échec est re-rendu dans la page, en 422 (saisie invalide, code périmé) ;
  - un compte verrouillé et la limitation de débit sont re-rendus en 429 ;
  - un succès redirige en 303.
- Le focus suit l'UDR-0054 §3.3, sans changement :
  - connexion : le numéro, ou le PIN quand une invitation a pré-rempli le numéro (`@prefilled`) ;
  - récupération : aucun champ désigné ; après un échec, le premier champ en erreur.
- Le bouton œil (`password-reveal`, UDR-0051) et l'infobulle (`info-tip`, UDR-0054 §3.4) gardent leurs contrôleurs.
- Sans JavaScript, les deux formulaires fonctionnent : le bouton œil reste caché, l'infobulle s'ouvre par le `<details>` natif.
- Aucun script ni style en ligne (ADR-0049).

### 3.7 États obligatoires

- **Vide** :
  - à l'ouverture, les champs sont vides ;
  - exception : après une invitation acceptée, la connexion pré-remplit le numéro une fois (`session[:login_contact]`, UDR-0054 §3.8).
- **Chargement** : sans objet. La page est rendue par le serveur. Le bouton garde son comportement actuel.
- **Erreur** :
  - une erreur générale s'affiche dans l'alerte `role="alert"`, en tête du formulaire ;
  - une erreur de champ s'affiche sous le champ, reliée par `aria-describedby` (`ui_field`) ;
  - le numéro saisi est conservé ;
  - les champs PIN et le code de récupération reviennent toujours vides.
- **Succès** :
  - connexion : redirection vers l'accueil du rôle, toast « Connexion réussie » ;
  - connexion d'un compte de l'équipe : redirection vers son second facteur (ADR-0031), sans changement ;
  - récupération : redirection vers `/login`, toast « Votre nouveau PIN est enregistré. Connectez-vous. ».
- **Session déjà ouverte** : `/login` renvoie vers l'accueil du rôle, comme aujourd'hui.

### 3.8 Garde-fous de sécurité, inchangés

Ce lot ne touche à aucun d'eux. Un test existant qui les vérifie doit rester vert sans modification.

- **Limitation de débit** : 5 envois par minute et par adresse IP, sur `POST /session` comme sur `POST /identity/pin-reset`. Au-delà : 429 et « Trop de tentatives en une minute. Patientez un instant, puis réessayez. ».
- **Verrouillage progressif** (ADR-0050) :
  - 5 échecs consécutifs bloquent 15 minutes ;
  - 10 échecs bloquent 1 heure ;
  - 20 échecs bloquent jusqu'à une récupération assistée ;
  - la 6ᵉ tentative est refusée, même avec le bon PIN.
  
  Les messages restent « Trop de tentatives. Réessayez à %{time}. » et « Trop de tentatives. Demandez un code de récupération à votre enseignant ou à l'équipe. ».
- **Messages génériques** :
  - connexion : « Numéro ou PIN incorrect. », pour un numéro inconnu comme pour un PIN faux ;
  - récupération : « Numéro ou code de récupération incorrect. », pour un numéro inconnu, un code faux ou un code révoqué.
  
  Aucun texte ne dit si un numéro existe.
- **Code de récupération** (ADR-0032) : 8 chiffres, à usage unique, valable 15 minutes. 5 échecs le révoquent. Le champ est toujours rendu vide (`value: ""`), avec `autocomplete="one-time-code"` et `maxlength="9"`.
- **PIN** : jamais affiché, jamais renvoyé dans la page. Le champ reste `type="password"`. Le bouton œil le montre seulement à la demande, et le remasque avant chaque envoi (UDR-0051).
- **Second facteur de l'équipe** (ADR-0031) : il reste demandé après le PIN, à chaque nouvelle session. Ses écrans ne font pas partie de cette UDR et ne changent pas.
- **Succès de la récupération** : il ferme toutes les sessions du compte et lève le verrouillage (ADR-0032), sans changement.
- **Attributs `autocomplete`** inchangés : `username` et `current-password` à la connexion ; `tel`, `one-time-code` et `new-password` à la récupération.

### 3.9 Accessibilité

- Un seul `h1` visible à toute largeur : le titre de la carte.
- La colonne d'accueil est `hidden` sous `lg`. Elle sort donc de l'arbre d'accessibilité (UDR-0057 §3).
- Chaque champ garde son libellé visible et son astérisque `aria-hidden`.
- Sans `hint:`, `aria-describedby` ne pointe plus que vers l'erreur, quand elle existe. `ui_field` le gère.
- Chaque infobulle annonce « Aide : <libellé du champ> » (`sr-only`), par exemple « Aide : PIN » ou « Aide : Code de récupération ».
- Cibles ≥ 48 px (`min-h-tap`, `size-tap`) : logo, retour, bouton, bouton œil, infobulle, lien « PIN oublié ? ».
- Focus visible : `focus-visible:outline-2 focus-visible:outline-brand` sur chaque lien.
- Ordre de tabulation, connexion : logo, numéro, PIN, bouton œil, infobulle, « Se connecter », « PIN oublié ? ».
- Ordre de tabulation, récupération : logo, « Se connecter », numéro, code, infobulle du code, nouveau PIN, bouton œil, infobulle du PIN, confirmation, bouton œil, « Enregistrer le nouveau PIN ».

### 3.10 Contrôle de la règle (UDR-0057), après

| # | Connexion | Récupération du PIN |
|---|---|---|
| R1 | Une action `brand` : « Se connecter ». « PIN oublié ? » est un lien texte. | Une action `brand` : « Enregistrer le nouveau PIN ». « Se connecter » est un lien de retour. |
| R2 | À 390 × 844, un seul enfant du `main` est visible : la colonne du formulaire (logo, carte). | À 390 × 844, un seul enfant du `main` : la colonne (logo, retour, carte). |
| R3 | Aucune liste. | Aucune liste. |
| R4 | Aucun texte d'aide permanent. L'aide du PIN est une infobulle. | Les deux aides sont des infobulles. Le sous-titre reste, exception motivée (§2.5). |
| R5 | `brand` seul ; `error` pour les erreurs. | `brand` seul ; `error` pour les erreurs. |
| R6 | « 4 chiffres » dit une fois (infobulle). « PIN oublié » dit une fois (lien). Plus de phrase qui redit les libellés. | « 8 chiffres » et « 4 chiffres » dits une fois chacun, dans leur infobulle. |

## 4. Conséquences

- **Tous les rôles voient les nouveaux écrans** (grill Q9). L'enseignant, la direction et l'équipe se connectent comme avant : même adresse, mêmes champs, mêmes messages.
- **Les tests de vue suivent** :
  - `test/controllers/identity/sessions_controller_test.rb` attend un `h1` « Connexion », et non plus un `h2` ;
  - il vérifie l'absence de « Élève · Enseignant · Équipe » et de `#session_pin_hint` ;
  - les deux liens du logo restent (`assert_select … , 2`) ;
  - l'infobulle garde le texte « Code secret de 4 chiffres, choisi à l'inscription » ;
  - pour la récupération, le lot vérifie le `h1` « PIN oublié », l'absence de `#pin_reset_code_hint` et de `#pin_reset_pin_hint`, et les deux infobulles. `test/controllers/identity/pin_resets_controller_test.rb` n'est pas dans la liste du Lot F : le lot le signale à l'orchestrateur s'il doit y écrire.
- **Les garde-fous de §3.8 restent prouvés par leurs tests actuels**, sans modification : `sign_in_test.rb`, `sessions_controller_test.rb` (verrouillage, limitation, message générique), `pin_resets_controller_test.rb`, `pin_reveal_test.rb`.
- **D'autres pages publiques ont la même mise en page à deux colonnes** : l'inscription enseignant et l'acceptation d'une invitation. Elles ne sont pas des écrans d'entrée au sens du grill Q9. Elles gardent leur seuil `md` et leurs textes. Leur tour viendra avec le chantier des autres rôles.
- **L'écran de bienvenue** (homepage) relève de l'UDR-0059, pas de celle-ci.
- **Aucune nouvelle aide** n'est ajoutée en texte permanent sur ces deux écrans. Une explication future passe par `ui_info_tip`.
