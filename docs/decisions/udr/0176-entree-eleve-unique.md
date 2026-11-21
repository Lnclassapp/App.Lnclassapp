# UDR-0176 : Entrée élève unique — numéro et code secret, puis « pas encore de compte »
<!-- index
titre: Entrée élève unique et question enseignant
statut: Accepté
adr-lie: 0141-entree-eleve-revele-un-numero-inscrit
problematique: l'élève choisissait entre « se connecter » et « créer un compte » avant tout geste, et prenait le mauvais chemin
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-21 |
| **Chantier** | `docs/chantiers/entree-eleve-unifiee` |
| **ADR lié** | ADR-0141 |
| **Remplacé par** | — |

---

## 1. Contexte

À Tiassalé, sur téléphone, en classe : la fenêtre « Je suis élève » proposait « Se connecter » et « Créer mon compte ». Des élèves sans compte touchaient « Se connecter » et restaient devant « Numéro ou code secret incorrect » ; d'autres, inscrits, recommençaient une inscription ; d'autres prenaient « Enseignant(e) » et créaient un compte enseignant.

## 2. Décision

Un seul formulaire, numéro et code secret, derrière « Je suis élève » ; c'est le numéro qui décide de la suite (D2). Un numéro inconnu passe par un écran qui **montre le numéro** et demande de **retaper le code** : une faute de frappe sur l'un ou l'autre se voit avant que le compte existe. L'inscription qui suit ne redemande ni numéro ni code. L'inscription enseignant publique commence par une question, deux boutons, sans JavaScript (D1).

Une page plutôt qu'une fenêtre (modale) : le formulaire doit survivre à un 422, au rechargement et au retour arrière, et `/c/<jeton>` l'affiche tel quel.

## 3. Règles d'implémentation

### 3.1 Accueil

- `app/views/homepage/_role_modal.html.erb` : pour le rôle `student`, `ui_button` en **lien** (`href: new_student_entry_path`, `id: "role-entry-student-<placement>"`), même variante et même taille que les deux autres boutons ; plus de `aria-haspopup`, plus de fenêtre. Enseignant(e) et Établissement inchangés.
- `/login` : le lien « Créer mon compte élève » mène à `new_student_entry_path`.

### 3.2 Écran d'entrée — `GET /student` (`identity/student_entries/new`, `@stage = :credentials`)

- Cadre de la connexion : `shared/auth_welcome` (panneau bleu ≥ lg, carte au-dessus du formulaire < lg), `shared/auth_help`, `main` centré, colonne `max-w-110`.
- `ui_card` titre « Je suis élève » (`h1`), phrase d'accroche `text-sm text-mute`.
- `form#student-entry-form`, `scope: :student_entry`, `POST /student`, contrôleur Stimulus `identity--phone-digits` sur le numéro.
- Numéro : `ui_field :contact, as: :tel`, `inputmode="numeric"`, `autocomplete="username"`, `maxlength=20`, aide « 10 chiffres, par ex. 0701020304. ».
- Code secret : `ui_field :pin, as: :password, reveal: true`, **exactement 4 chiffres** : `minlength=4 maxlength=4 pattern="[0-9]{4}" inputmode="numeric"`, `autocomplete="current-password"`, aide « 4 chiffres. ».
- Bouton `ui_button` primaire `lg full` « Continuer », `data-turbo-submits-with` « Un instant… ».
- Focus d'arrivée : le numéro s'il est vide, le code s'il est rempli et sans erreur ; **aucun** sur `/c/<jeton>` (le clavier ne doit pas cacher le bandeau de la classe, FU-19).

### 3.3 Code faux sur un numéro inscrit

- Re-rendu 422, numéro gardé, code vide ; erreur du champ code « Code secret incorrect. » (`aria-invalid`, `aria-describedby` par `ui_field`).
- Sous le champ, `a#student-entry-forgot-pin` « Code secret oublié ? » → `new_identity_pin_reset_path`, **seulement** pour cette erreur-là.
- Numéro verrouillé : message de verrouillage de `/login` en alerte de base.

### 3.4 Lien de classe `/c/<jeton>`, visiteur

- La même page d'entrée, rendue par `Classroom::JoinsController#new`, avec au-dessus de la carte `div#student-entry-classroom` (`rounded-ln border-brand/30 bg-brand-soft`) : « Tu rejoins » puis « <classe> · <établissement> ».
- Chaque formulaire porte `student_entry[link_token]` en champ caché (sans `id`).
- Entrée déjà confirmée pour ce lien : `/c/<jeton>` affiche directement l'inscription (§3.6).

### 3.5 « Nouveau sur Lnclass » — `@stage = :confirm`

- `ui_card` titre « Nouveau sur Lnclass » (`h1`) ; `div#student-entry-number` : « Ce numéro n'a pas encore de compte : » puis le numéro en `font-mono text-xl`, groupé par deux chiffres.
- `form#student-entry-confirm-form` : `ui_field :pin_confirmation` (mêmes contraintes 4 chiffres, `autofocus`, `autocomplete="new-password"`), aide « Retape ton code secret pour être sûr de t'en souvenir. », bouton primaire « Créer mon compte » (`#student-entry-confirm-submit`).
- `a#student-entry-fix-number` « Ce n'est pas mon numéro » → `new_student_entry_path(fresh: 1, link: <jeton>)`, **`data-turbo-prefetch="false"`** (le GET efface l'entrée ; un préchargement au survol l'effacerait sans clic).
- Confirmation différente : 422, « Les deux codes secrets ne sont pas identiques. » sur le champ.
- Alertes de base (`_base_errors`, `div#student-entry-alert role="alert"`) : trop d'envois (429, « Trop de tentatives »), compte d'une autre coque Android, entrée expirée (toast au retour sur `/student`).
- Le code secret n'apparaît jamais dans la page : ni valeur de champ, ni champ caché.

### 3.6 Inscription en mode entrée (`classroom/student_registrations/new`, `@entry` présent)

- Deux étapes au lieu de trois : « Ta classe » (sautée si le lien de classe est gardé) et « Toi ». Compteur `step_counter_entry` « Étape %{n} sur 2 », segments et panneau limités à 2.
- Pas de bloc « Déjà un compte ? » (le numéro vient d'être reconnu sans compte), pas de fieldset « Sécurité ».
- Dans « Toi » : `#signup-entry-number` (libellé « Ton numéro », numéro groupé) et `a#signup-entry-fix-number` « Ce n'est pas mon numéro » (`fresh: 1`, `data-turbo-prefetch="false"`), puis le bouton d'envoi (`_submit`) ; champ caché `entry_mode=1`.
- « Ce n'est pas ta classe ? » (`#other-classroom`, `#panel-other-classroom`) → `new_student_registration_path(other_classroom: 1)`, `data-turbo-prefetch="false"` : la classe du lien est oubliée, numéro et code restent.
- Entrée expirée à l'envoi : retour à `/student` avec « Ton entrée a expiré… », aucun compte créé.

### 3.7 Question enseignant — `GET /teacher-signup` sans `confirmed=1` ni `drena`

- Même cadre que la connexion ; `ui_card` titre « Êtes-vous bien enseignant(e) ? » (`h1`), une phrase au « vous ».
- `div#teacher-signup-confirm` en colonne `gap-3` : `#teacher-signup-confirm-yes` primaire « Oui, je suis enseignant(e) » → `new_teacher_registration_path(confirmed: 1)` ; `#teacher-signup-confirm-no` secondaire « Non, je suis élève » → `new_student_entry_path`. Deux liens, sans JavaScript.
- Les invitations `/i/<jeton>` et l'inscription direction ne posent pas la question.

### États

| Écran | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Entrée | champs vides, focus numéro | « Un instant… » sur le bouton | 422 par champ, 429 en alerte | connecté → accueil du rôle (ou retour au lien pour un élève) ; inconnu → §3.5 |
| Confirmation | champ vide, focus | « Un instant… » | 422 sur la confirmation | inscription §3.6 |
| Inscription entrée | — | inchangé | 422 du formulaire existant ; entrée expirée → `/student` | accueil élève, toast de bienvenue |
| Question enseignant | — | — | — | formulaire enseignant ou entrée élève |

### Accessibilité

- Cibles ≥ 48 px (`min-h-tap`, boutons `lg`) ; un seul `h1` par écran ; erreurs liées par `aria-describedby`, `aria-invalid` ; alertes `role="alert"` ; focus visible `outline-brand`.

## 4. Conséquences

- La fenêtre « Je suis élève » disparaît ; la clé `role-modal-student-entry` n'est plus rendue.
- Tout lien en GET qui modifie l'entrée gardée en session porte `data-turbo-prefetch="false"`.
- `/student-signup` direct (pages publiques d'établissement) garde ses trois étapes, « Déjà un compte ? » compris.
