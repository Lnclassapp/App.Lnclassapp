# UDR-0051 : Afficher le code PIN — bouton œil dans chaque champ de PIN

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/afficher-pin`](../../chantiers/afficher-pin/prd.md) — critères AP-01 à AP-10 |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (CSP stricte) · [ADR-0050](../adr/0050-authentification-et-session.md) (PIN, verrouillage) · [UDR-0005](0005-design-system-fondateur.md) (amendée) · [UDR-0041](0041-page-profil.md) · [UDR-0009](0009-rejoindre-une-classe.md) · [UDR-0019](0019-invitation-equipe.md) · [UDR-0024](0024-inscription-enseignant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Le PIN se tape à l'aveugle : quatre points, sans moyen de vérifier ce qu'on a tapé. Au téléphone, sur un clavier numérique serré, une faute ne se voit qu'au 422 ; à la connexion, chaque erreur rapproche du verrouillage (ADR-0050). Le porteur demande, le 2026-09-28, « l'option affichage du code PIN » sur la connexion, les inscriptions et le profil.

## 2. Décision

1. **Une option du composant champ**, `ui_field(form, :pin, as: :password, reveal: true)`, plutôt qu'un nouveau composant : libellé, aide, erreur et `aria-describedby` restent ceux de `ui_field` ; seul le contrôle gagne un bouton. L'option est refusée hors `as: :password`.
2. **Un bouton œil dans le champ, à droite** : le geste est connu de tous les téléphones, il ne prend aucune ligne de plus.
3. **Masqué par défaut, toujours** : à chaque chargement, au retour arrière, avant chaque envoi. Rien n'est mémorisé.
4. **Amélioration progressive** : le bouton est rendu `hidden` ; seul le contrôleur Stimulus le montre. Sans JavaScript, le champ reste celui d'aujourd'hui.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure** (`components/_field.html.erb`, branche `reveal`)
- `div.relative[data-controller=password-reveal]` → le contrôle `input[type=password]` (`data-password-reveal-target="input"`, classe en plus `pr-14`) → `button`.
- Le bouton : `type="button"`, `hidden`, `aria-controls="<id du champ>"`, `aria-pressed="false"`, `aria-label="Afficher le code"`, `data-password-reveal-target="toggle"`. Il contient deux `span` : `[data-icon=eye]` (visible) et `[data-icon=eye-slash][hidden]`.
- Icônes : `ui_icon "eye"` et `ui_icon "eye-slash"`, variante **outline**, taille **`md`** (`size-5`, celle des autres icônes de champ), décoratives (`aria-hidden`). **Masqué → `eye` et « Afficher le code » ; affiché → `eye-slash` et « Masquer le code ».**
- Libellés : `components.field.reveal.show` / `hide` (I18n, `t(".reveal.show")` dans `components/_field`), passés au contrôleur par `data-password-reveal-show-label-value` et `-hide-label-value`.

**Tokens**
- Bouton : `absolute inset-y-0 right-0 flex w-tap items-center justify-center rounded-ln text-mute hover:text-ink`, focus `focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand`. Le champ fait déjà 48 px de haut (`min-h-tap`) : la cible est de 48 × 48 px.
- Aucune couleur, aucun espacement nouveau.

**Comportement** — contrôleur `password-reveal` (`app/javascript/controllers/password_reveal_controller.js`)
- `connect` : remasque (`type="password"`, `aria-pressed="false"`, libellé « Afficher le code », icône `eye`), retire `hidden` du bouton, écoute `submit` du formulaire du champ.
- Clic (`toggle`) : bascule `password` ↔ `text`, `aria-pressed`, `aria-label` et l'icône. La sélection du champ est conservée.
- Focus : au pointeur (souris, doigt), le bouton n'attrape pas le focus (`mousedown` annulé) et le focus revient au champ, curseur à sa place. Au clavier (Tab depuis le champ, puis Entrée ou Espace), le focus reste sur le bouton pour pouvoir rebasculer ; Maj+Tab ramène au champ.
- `submit` du formulaire : remasque avant l'envoi (le navigateur ne voit jamais un PIN en clair, le type d'origine revient au 422).
- `turbo:before-cache@document` : remasque avant l'instantané du cache.
- **Morphing du 422** (connexion, inscriptions : page rafraîchie sur la même adresse) : le contrôleur annule `turbo:before-morph-attribute` pour l'attribut `hidden` de son bouton. Le type, `aria-pressed`, le libellé et les icônes reviennent à l'état masqué rendu par le serveur.
- Aucune mémorisation (ni `localStorage`, ni cookie), aucun script en ligne (ADR-0049).
- Edge : son œil natif (`::-ms-reveal`) est masqué dès que le bouton est visible (`application.tailwind.css`) ; sans JavaScript, Edge garde le sien.

**Attributs conservés** : `autocomplete` (`current-password` pour le PIN actuel, `new-password` pour un nouveau PIN), `inputmode="numeric"`, `maxlength="4"`, `required`, `aria-describedby`, `aria-invalid`.

**Champs couverts** : connexion (PIN) ; invitation, inscription enseignant, inscription élève, PIN oublié (PIN et confirmation) ; profil « Changer mon PIN » (PIN actuel, nouveau, confirmation) et « Changer mon numéro » (PIN actuel). Tout nouveau champ de PIN prend `reveal: true`.

**États obligatoires**
- Masqué (par défaut, au chargement, après envoi) · Affiché · Erreur (422 : champ vidé, masqué, bouton visible, message sous le champ inchangé) · Sans JavaScript (bouton absent).

**Accessibilité**
- Bouton bascule : `aria-pressed` et libellé qui suit l'état ; `aria-controls` vers le champ ; placé juste après le champ dans l'ordre de tabulation.
- Cible de 48 × 48 px, focus visible, contraste `mute` sur `white` (AA).

## 4. Conséquences

- Tout champ de PIN s'écrit `ui_field … as: :password, reveal: true`. Un champ de PIN sans bouton œil est un écart à cette UDR.
- Le champ mot de passe de `/design` le montre ; `test/system/design_system_test.rb` et `test/system/identity/pin_reveal_test.rb` le vérifient.
- Interdit : mémoriser l'état affiché, démasquer par défaut, envoyer un formulaire avec un PIN en `type="text"`.
