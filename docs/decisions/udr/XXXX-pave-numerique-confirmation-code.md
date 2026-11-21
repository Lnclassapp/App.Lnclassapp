# UDR-XXXX : Entrée et inscription de l'élève allégées — pavé numérique pour confirmer le code secret
<!-- index
titre: Pavé numérique de « Nouveau sur Lnclass », entrée et inscription allégées
statut: Accepté
adr-lie: [0141](../adr/0141-entree-eleve-revele-un-numero-inscrit.md)
problematique: l'élève retape son code secret dans un champ ordinaire, sans savoir s'il a bien tapé, et lit des phrases qui n'aident pas
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-21 |
| **Chantier** | `docs/chantiers/entree-et-accueil-eleve-allegees` |
| **ADR lié** | ADR-0141 (inchangé), ADR-XXXX-adresse-publique-etablissement |
| **Amende** | UDR-0176 §3.1, §3.2, §3.6 · UDR-0135 §3.2 (le code de classe quitte l'inscription) |
| **Remplacé par** | — |

---

## 1. Contexte

Retours terrain (porteur, 2026-11-21). Sur `/student`, deux phrases d'explication précèdent le formulaire ; à l'étape « Nouveau sur Lnclass », l'élève retape son code secret dans un champ texte, le clavier du téléphone couvre la moitié de l'écran, et l'erreur n'arrive qu'après l'envoi. L'inscription garde un lien « J'ai le code de ma classe » que le lien de classe et la recherche d'établissement ont remplacé, et, après l'entrée, rappelle un numéro que l'élève vient de taper.

## 2. Décision

1. Les phrases `welcome_text` et `lead` de l'entrée disparaissent (la carte de bienvenue garde son titre).
2. « Nouveau sur Lnclass » devient un **pavé de paiement mobile** : 4 cases qui se remplissent seules, un pavé numérique à l'écran, « Créer mon compte » **gris tant que 4 chiffres ne sont pas tapés**. Au 4e chiffre, l'envoi part seul : identiques, une coche verte puis l'inscription ; différents, « Les deux codes sont différents. » et les cases se vident.
3. Le premier code n'est jamais dans la page (ADR-0141 §4.3 : l'entrée vit en session) : la comparaison est faite par le serveur, sur l'envoi automatique. « Tout de suite » = le temps d'un aller-retour.
4. Sans JavaScript : le champ et le bouton actuels, actifs ; le serveur juge, même message.
5. L'inscription perd le lien « J'ai le code de ma classe › » **et** le champ du code (sinon visible sans JavaScript). Le lien `/c/<jeton>` et la recherche d'établissement restent.
6. Après l'entrée, l'étape « Toi » n'a plus le bloc « Ton numéro » ; il ne revient qu'en état d'erreur (numéro pris entre-temps).
7. L'établissement gardé par l'adresse du QR (ADR-XXXX-adresse-publique-etablissement) est préchoisi à l'étape « Ta classe ».

Pourquoi un pavé à l'écran plutôt que le clavier du téléphone : 10 grandes touches fixes, aucune lettre, l'écran ne saute pas ; c'est le geste que l'élève connaît des applications de paiement.

## 3. Règles d'implémentation

### 3.1 Entrée — `identity/student_entries/new`

- `shared/auth_welcome` (panneau et carte) : appelés **sans** `text:` ; si la partial exige `text:`, le rendre optionnel (rien n'est rendu quand il est absent).
- Étape « credentials » : le `<p>` du `lead` est supprimé ; le reste ne change pas.
- Clés `identity.student_entries.new.welcome_text` et `.lead` supprimées du fichier de locale.

### 3.2 Étape « Nouveau sur Lnclass » (`@stage == :confirm`)

Dans `#student-entry-confirm-form`, `data-controller="identity--pin-pad"`, dans cet ordre :

1. `#student-entry-number` (inchangé : « Ce numéro n'a pas encore de compte : » et le numéro).
2. Les erreurs (`base_errors`, inchangé).
3. `#student-entry-pin-field` : le `ui_field :pin_confirmation` actuel (type password, `inputmode numeric`, `pattern [0-9]{4}`, `maxlength 4`, `autocomplete new-password`), `data-identity--pin-pad-target="field"`. Le contrôleur, à la connexion, cache ce bloc (`hidden`) et ôte `autofocus` ; l'`input` reste dans le formulaire (sa valeur est posée par le contrôleur). Le message d'erreur du champ reste celui du serveur.
4. `#student-entry-pin-pad`, rendu avec `hidden`, `data-identity--pin-pad-target="pad"`, dévoilé à la connexion :
   - Libellé visible `p.text-sm.text-mute` : `confirm_hint` (« Retape ton code secret pour être sûr de t'en souvenir. »).
   - `#student-entry-pin-boxes` : `div.flex.justify-center.gap-3`, `aria-hidden="true"`, 4 `span[data-identity--pin-pad-target="box"]` de `size-14 rounded-ln border-2 border-line bg-white grid place-items-center text-2xl text-ink` ; case remplie : un point `●` et `border-brand` ; case courante : `border-brand`. Jamais le chiffre en clair.
   - `#student-entry-pin-status` : `p.sr-only[aria-live=polite]`, `data-identity--pin-pad-target="status"`, « %{count} chiffres sur 4 » (`pin_pad.progress`) à chaque frappe.
   - `#student-entry-pin-check` : `hidden`, `data-identity--pin-pad-target="check"`, `role="status"`, icône `check-circle` (taille `lg`, `text-success`) + `pin_pad.match` « Les deux codes sont identiques. », `flex items-center justify-center gap-2 text-sm font-medium text-success`.
   - `#student-entry-keypad` : `div.grid.grid-cols-3.gap-3`, `role="group"`, `aria-label` `pin_pad.keypad_label` « Pavé numérique ». Touches 1 à 9, puis une case vide, 0, « Effacer ». Chaque touche : `button type=button`, `min-h-14 rounded-ln bg-mist text-2xl font-medium text-ink active:bg-line focus-visible:outline-2 focus-visible:outline-brand`, `data-action="identity--pin-pad#press"`, `data-digit="N"`. « Effacer » : icône `backspace` (`ui_icon`), `aria-label` `pin_pad.erase` « Effacer », `data-action="identity--pin-pad#erase"`.
5. `ui_button confirm_submit` (« Créer mon compte »), `#student-entry-confirm-submit`, `data-identity--pin-pad-target="submit"`. Rendu actif (sans JavaScript) ; le contrôleur le pose `disabled` (gris, `aria-disabled`) tant que moins de 4 chiffres.

**Contrôleur `app/javascript/controllers/identity/pin_pad_controller.js`**
- `connect` : cache `field`, montre `pad`, vide la valeur, `disabled` sur `submit`, écoute `keydown` sur `document` (chiffres 0-9 et `Backspace`, ignorés si une touche de modification est enfoncée), écoute `turbo:submit-end` sur le formulaire.
- `press` / touche chiffre : si moins de 4, ajoute le chiffre, met à jour cases, statut et bouton ; au 4e, `submit.disabled = false` puis `form.requestSubmit(submit)`, et le pavé est verrouillé (`aria-busy="true"` sur `pad`) jusqu'à la réponse.
- `erase` / `Backspace` : retire le dernier chiffre.
- `turbo:submit-end` : `detail.success` → montrer `check`, garder le pavé verrouillé (la redirection suit) ; échec → la page est re-rendue par le serveur (422), le contrôleur se reconnecte vide ; échec **sans re-rendu serveur** (`detail.error`, ou pas de `fetchResponse` : hors ligne) → montrer `#student-entry-pin-offline` (`role="alert"`, rendu `hidden`, `pin_pad.offline` « Pas de connexion. Réessaie. », `text-sm text-error`), garder les 4 chiffres, déverrouiller le pavé et réactiver le bouton pour renvoyer ; le message se cache à la frappe suivante et au renvoi.
- `disconnect` : retire les écouteurs.

**Serveur** : inchangé, sauf le message `activemodel.errors.models.dtos/identity/student_entry_input.attributes.pin_confirmation.confirmation` → « Les deux codes sont différents. ». Le 422 rend la page avec ce message dans `base_errors` ou sous le champ (là où il s'affiche aujourd'hui) **et** le contrôleur le laisse visible au-dessus du pavé : si le message est sous le champ caché, le déplacer dans `base_errors` pour ce cas (`role="alert"`).

### 3.3 Inscription — `classroom/student_registrations/_form` et `new`

- Supprimer `have_code` (lien `#signup-have-code`) et tout le bloc `#signup-code-field` (champ `join_code`, frame de vérification, gabarit d'échec, lien « Je n'ai pas de code »). `after_school:` n'est plus passé à `_class_picker` (le rendre optionnel s'il ne l'est pas).
- `signup_steps_controller.js` : retirer `showCode`, `showCascade`, `checkCode`, `codeChecked`, `codeCheckFailed`, et les cibles et valeurs du code (`code`, `codeField`, `codeFrame`, `checking`, `checkFailed`, `codeOpen`, `codeUrl`, `announceCode`, `announceCascade`) ; `new.html.erb` cesse de les passer. Le rappel de classe d'un lien (`@preview`) reste.
- Les clés I18n devenues mortes (`have_code`, `no_code`, `code_hint`, `checking`, `check_failed`, `announce_code`, `announce_cascade`, du fichier de `student_registrations` seulement) sont supprimées.
- Le serveur garde `join_code` dans `FIELDS` (un ancien formulaire en cache peut encore l'envoyer) ; aucune règle ne change.
- Mode entrée (`@entry`) : le bloc `#signup-entry-number` n'est rendu **que** si `@form.errors[:contact]` est non vide (état d'erreur : message `role="alert"` + « Ce n'est pas mon numéro »). Le champ caché `entry_mode` reste. `entry_number_label` est supprimé de la locale.
- Mode entrée avec établissement gardé : `@form.school_public_id` vaut `@entry.school_public_id` quand la requête n'en porte pas ; la cascade s'ouvre établissement choisi, niveaux proposés (comportement du repli GET existant).
- Sans entrée (`/student-signup` en direct) : trois étapes, numéro et code, inchangés.

### États obligatoires

- Vide : 4 cases vides, bouton gris.
- Chargement : 4 chiffres, pavé verrouillé (`aria-busy`), bouton « Un instant… » (`turbo_submits_with`).
- Erreur : « Les deux codes sont différents. » (`role="alert"`), cases vides, bouton gris ; entrée expirée : retour à l'entrée (inchangé). Hors ligne : « Pas de connexion. Réessaie. » (`role="alert"`), les 4 chiffres gardés, pavé déverrouillé, bouton actif pour renvoyer.
- Succès : coche verte + « Les deux codes sont identiques. », puis l'inscription.

### Accessibilité

- Touches ≥ 56 px de haut ; « Effacer » nommée ; cases `aria-hidden`, progression dite par `#student-entry-pin-status`.
- Le focus va à la première touche (« 1 ») à la connexion ; le clavier physique fonctionne.
- Rien n'est porté par la couleur seule : la coche a son texte, l'erreur son texte.

## 4. Conséquences

- Le code de six caractères n'existe plus à l'inscription ; il reste dans « Choisis ta classe » (élève connecté).
- Le pavé ne sert qu'à la confirmation ; la saisie du premier code (étape « credentials ») garde son champ.
- Interdit : mettre le code de l'entrée, ou une empreinte, dans la page pour comparer côté navigateur.
