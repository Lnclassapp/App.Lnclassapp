# UDR-0189 : Connexion et inscription « numéro d'abord » — `/login`, `/student`, inscription enseignant
<!-- index
titre: Connexion numéro d'abord, code tapé une fois, inscription enseignant comme l'élève
statut: Accepté
adr-lie: 0148-connexion-revele-un-numero-inscrit
problematique: la connexion demandait numéro et code ensemble et laissait l'inscrit et le nouveau devant le même refus ; l'enseignant s'inscrivait dans un autre ordre que l'élève
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-26 |
| **Chantier** | `docs/chantiers/connexion-numero-d-abord` |
| **ADR lié** | ADR-0148 |
| **Remplacé par** | — (amende UDR-0176 §3.1, §3.2, §3.5 ; UDR-0180 §3.2 ; UDR-0135 et UDR-0079 pour l'ordre des étapes enseignant) |
| **Amendement** | 2026-11-27, retours du porteur après test sur Develop : §3.6 (4 cases partout), §3.7 (chiffres seuls), §3.8 (`/teacher`) ; remplacent ce qui les contredit plus haut |

---

## 1. Contexte

Le porteur (2026-11-26) : la connexion demande d'abord **seulement le numéro** ; un compte → le champ du code ; pas de compte → la création du compte, numéro repris. Le code d'un nouveau compte se tape une fois (« Entre ton code secret »). L'enseignant s'inscrit comme l'élève, en étapes numérotées.

## 2. Décision

Un écran = une question. Le numéro d'abord, affiché ensuite en gros (groupé par deux chiffres) avec « Ce n'est pas mon numéro » à chaque écran qui le reprend. Jamais le numéro redemandé. Jamais le code dans la page.

## 3. Règles d'implémentation

Cadre commun de `/login` et `/student` : inchangé (`shared/auth_welcome` panneau ≥ lg et carte < lg, `shared/auth_help`, `main` centré, colonne `max-w-110`, `ui_card padding: :lg`, un seul `h1`). Lien de texte : `inline-flex min-h-tap items-center font-medium text-brand-strong underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-brand`. Numéro affiché : `div#…-number` `rounded-ln bg-paper px-4 py-3`, libellé `text-sm text-mute`, numéro `mt-1 font-mono text-xl font-medium tracking-wider text-ink`. Tout lien « Ce n'est pas mon numéro » porte `?fresh=1` et `data-turbo-prefetch="false"` (le GET efface l'entrée).

### 3.1 `/login`, étape numéro (`@stage = :contact`, au « vous »)

- `ui_card` « Connexion » (`h1`), `form#session-form` (`scope: :session`, `POST /session`), `identity--phone-digits`.
- Seul champ : `ui_field :contact, as: :tel`, `maxlength=10`, `inputmode="numeric"`, `autocomplete="username"`, `autofocus`, aide « 10 chiffres, par ex. 0701020304. ».
- `ui_button` primaire `full` « Continuer », `turbo_submits_with` « Un instant… ».
- Erreurs : format → sur le champ ; 429 et refus de coque → alerte `role="alert"` en tête (inchangé) ; envoi groupé raté → alerte « Numéro ou code secret incorrect. ».
- Plus de lien « Créer mon compte élève » : le numéro y mène.

### 3.2 `/login`, étape code (`@stage = :pin`)

- `ui_card` « Connexion » (`h1`) ; `div#session-number` « Votre numéro » + numéro ; `a#session-fix-number` « Ce n'est pas mon numéro » → `new_session_path(fresh: 1)`.
- `form#session-pin-form` (`POST /session`, seul `session[pin]`) : `ui_field :pin, as: :password, reveal: true`, `maxlength=4`, `inputmode="numeric"`, `autocomplete="current-password"`, `autofocus`, aide et infobulle actuelles ; champ caché `session[contact]` **absent**, mais `input type=text autocomplete=username hidden` non nommé portant le numéro, pour les gestionnaires de mots de passe.
- « Se connecter » primaire `full` ; sous le bouton « Code secret oublié ? » (`new_identity_pin_reset_path`).
- Code faux : 422, « Code secret incorrect. » sur le champ (`aria-invalid`). Verrouillage, 429 : alerte en tête.

### 3.3 `/login`, pas de compte (`@stage = :no_account`)

- `ui_card` « Ce numéro n'a pas encore de compte » (`h1`) ; `div#session-number` « Votre numéro » + numéro.
- `p` `text-sm text-mute` « Créez votre compte : vous êtes… ».
- `div#session-new-account` colonne `gap-3` : `#session-new-student` primaire `lg full` « Élève » → `new_student_entry_path` ; `#session-new-teacher` secondaire `lg full` « Enseignant(e) » → `new_teacher_registration_path(confirmed: 1)`. Deux liens, sans JavaScript.
- `a#session-fix-number` « Ce n'est pas mon numéro » centré sous les boutons.

### 3.4 `/student` (au « tu »)

- `@stage = :contact` : titre « Je suis élève », `form#student-entry-form` avec le **seul** numéro (UDR-0176 §3.2 sans le code), « Continuer ». Focus : aucun sur `/c/<jeton>` (inchangé).
- `@stage = :pin` (numéro inscrit) : titre « Entre ton code secret » ; `div#student-entry-number` « Ton numéro » ; `form#student-entry-pin-form` : `ui_field :pin` 4 chiffres (`minlength=4 maxlength=4 pattern="[0-9]{4}"`, `autocomplete="current-password"`, `autofocus`), « Continuer » ; code faux → « Code secret incorrect. » + `a#student-entry-forgot-pin` (UDR-0176 §3.3 inchangé) ; `a#student-entry-fix-number`.
- `@stage = :new_account` (numéro sans compte) : titre « Nouveau sur Lnclass » ; `div#student-entry-number` « Ce numéro n'a pas encore de compte : » ; `form#student-entry-confirm-form`, champ `student_entry[pin]` et pavé UDR-0180 (mêmes cibles et ids), consigne « Entre ton code secret : 4 chiffres, que tu retiendras. » ; coche au 4e chiffre « Code secret choisi. » ; bouton « Créer mon compte » ; `a#student-entry-fix-number`. Plus de confirmation ni de message d'écart.
- Le bandeau de classe `/c/<jeton>` et le champ caché `link_token` restent sur les trois étapes.

### 3.5 Inscription enseignant (`/teacher-signup?confirmed=1`, `/i/<jeton>`, au « vous »)

Trois étapes, `classroom--signup-steps`, compteur « Étape N sur 3 », barre en trois segments, carte de bienvenue et « Déjà un compte ? » sur le premier écran seulement (inchangés).

1. `fieldset#teacher-registration-section-contact` `data-step=1 data-continue` : légende « Votre numéro », aide « Pour vous connecter, sans mot de passe à retenir. » ; `ui_field :contact, as: :tel` (règles actuelles, `autofocus`) ; bouton primaire `lg full` « Continuer » (`#teacher-registration-continue-1`, `type=button`, `data-action=classroom--signup-steps#continue`). Le sponsor d'un lien de parrainage s'affiche ici.
2. `fieldset#teacher-registration-section-security` `data-step=2 data-continue` : légende « Entrez votre code secret », aide « 4 chiffres, que vous seul connaissez. » ; `ui_field :pin, as: :password, reveal: true`, `minlength=4 maxlength=4 pattern="[0-9]{4}"`, `autocomplete="new-password"` ; **pas** de confirmation ; « Continuer » (`#teacher-registration-continue-2`).
3. `fieldset#teacher-registration-section-you` `data-step=3` : légende « Votre profil » ; l'établissement (rappel `_school_preview` d'un lien valable, sinon la recherche, qui ne fait plus avancer d'étape) ; matière ; nom ; prénoms ; genre ; « Créer mon compte » et la ligne des conditions. Aucun champ de code d'établissement.

- Numéro repris de `/login` (entrée « pas de compte » en session) : l'étape 1 n'est pas rendue (étape 2 d'abord, « Retour » caché), et l'étape 2 commence par `div#teacher-registration-number` « Votre numéro » + `a#teacher-registration-fix-number` « Ce n'est pas mon numéro » → `new_session_path(fresh: 1)`.
- « Continuer » : si un champ de l'étape est invalide, `reportValidity` et focus sur lui ; sinon étape suivante. « Entrée » fait de même aux étapes 1 et 2.
- Erreur serveur : l'étape de la première erreur s'ouvre (`contact` 1, `pin` 2, le reste 3). « Ce numéro est déjà utilisé » : étape 1, sous le champ.
- Sans JavaScript : les trois fieldsets visibles, un seul envoi.

### 3.6 Amendement du 2026-11-27 : le code en 4 cases partout où l'on se connecte ou crée son compte

- Partiel `shared/_pin_pad` (locaux `prefix`, `field`, `hint`, `error`, `match`, `offline`) : `#<prefix>-pin-field` (le `ui_field :pin` natif, seul visible sans JavaScript), `#<prefix>-pin-pad[hidden]` avec 4 cases `#<prefix>-pin-boxes`, statut `sr-only aria-live` « N chiffres sur 4 », coche `#<prefix>-pin-check`, alerte hors ligne `#<prefix>-pin-offline[role=alert][hidden]`, pavé `#<prefix>-keypad` (`role=group`, « Pavé numérique », touches ≥ 56 px, « Effacer »). L'erreur serveur du code (`error`) s'affiche au-dessus des cases (`#<prefix>-pin-error[role=alert]`).
- Contrôleur `identity--pin-pad` (texte hérité d'UDR-0180) : mode `submit` (défaut) envoie le formulaire au 4e chiffre ; mode `step` remplit le champ et clique le bouton d'étape (« Continuer »). Le clavier physique ne nourrit que le pavé visible, jamais un autre champ en cours de saisie.
- Remplace le champ simple de §3.2 (`/login` et `/teacher` étape code, ainsi que l'envoi groupé refusé `:both`), §3.4 (`/student` étape code ; « Nouveau sur Lnclass » inchangé) et §3.5 étape 2 de l'inscription enseignant (mode `step`). Le choix n°4 du journal (champ simple pour un numéro inscrit) est retiré.
- Hors champ (inchangés, à trancher) : code + confirmation de l'inscription élève sans entrée, de l'invitation enseignant et de la direction ; code oublié ; changement du code.

### 3.7 Amendement du 2026-11-27 : chiffres seuls

- Tout `ui_field as: :tel`, et tout `ui_field as: :password, inputmode: "numeric"`, porte le contrôleur `digits-only` : à chaque saisie (frappe, collage), tout ce qui n'est pas un chiffre est retiré et la longueur bornée à `maxlength`. `inputmode="numeric"` ouvre le pavé du téléphone. Le serveur garde ses propres règles sans JavaScript.

### 3.8 Amendement du 2026-11-27 : `/teacher`, l'entrée enseignant

- Accueil : « Enseignant(e) » est un lien `#role-entry-teacher-entry` → `new_teacher_entry_path` (comme « Je suis élève ») ; la fenêtre « Vous êtes enseignant ? » est retirée.
- `GET /teacher` (`Identity::TeacherEntriesController`, sous-classe de la connexion, mêmes compteurs et refus) rend l'écran de `/login` titré « Je suis enseignant(e) » (`title`, `h1`), formulaires vers `POST /teacher`, « Ce n'est pas mon numéro » → `/teacher?fresh=1`. Numéro inscrit → étape code (§3.6), puis l'accueil du rôle. Numéro sans compte → `new_teacher_registration_path(confirmed: 1)` : l'inscription s'ouvre à l'étape 2, numéro rappelé ; son « Ce n'est pas mon numéro » → `/teacher?fresh=1`.
- `/teacher-signup` sans `confirmed=1` ni recherche renvoyée → 303 vers `/teacher` (la question « Êtes-vous bien enseignant(e) ? » d'UDR-0176 §3.7 est retirée). `/teacher-signup?confirmed=1`, `/i/<jeton>` et « Ce n'est pas votre établissement ? » (`?confirmed=1`) gardent le parcours.

### États

| Écran | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Numéro (`/login`, `/student`) | champ vide, focus | « Un instant… » | 422 champ ; 429 alerte | étape code ou « pas de compte » |
| Code (`/login`, `/student`) | champ vide, focus | « Un instant… » | 422 « Code secret incorrect » ; verrouillage/429 alerte | accueil du rôle (second facteur d'abord s'il y a lieu) |
| Pas de compte (`/login`) | — | — | — | inscription élève ou enseignant |
| Nouveau sur Lnclass (`/student`) | pavé vide | coche, pavé verrouillé | 422/429 alerte | inscription élève |
| Enseignant | étape 1 | « Création… » | étape de l'erreur | accueil enseignant |

### Accessibilité

- Cibles ≥ 48 px ; un `h1` par écran ; erreurs `aria-invalid` + `aria-describedby` (`ui_field`) ; alertes `role="alert"` ; légende d'étape focalisable (`tabindex=-1`) et annonce `aria-live` (inchangé).

## 4. Conséquences

- `pin_confirmation` disparaît des vues élève et enseignant ; le contrôleur `identity--pin-match` n'est plus branché sur l'inscription enseignant.
- Les tests système se connectent en deux écrans (`sign_in_as`).
