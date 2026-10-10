# UDR-0083 : Menu ⋮ d'archivage de la classe et du niveau, confirmation, archives masquées après 7 jours
<!-- index
titre: Menu ⋮ d'archivage de la classe et du niveau, confirmation, archives masquées après 7 jours
statut: Accepté
adr-lie: [0088](../adr/0088-archivage-d-une-classe-sans-blocage-et-reversible.md)
problematique: Où et comment la direction et l'équipe archivent et restaurent une classe ou un niveau, avec quelle confirmation, et comment s'affichent les classes archivées.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-10 |
| **Chantier** | [`docs/chantiers/archivage-classes`](../../chantiers/archivage-classes/memo.md) |
| **ADR lié** | [ADR-0088](../adr/0088-archivage-d-une-classe-sans-blocage-et-reversible.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un établissement importé a toutes les classes de la 6ème à la Tle. Sa direction (ou l'équipe) doit écarter celles qui n'existent pas, vite (jusqu'à une cinquantaine) et sans risque d'erreur silencieuse.

## 2. Décision

- Les actions vivent dans le menu ⋮ existant (`ui_dropdown`) : sur la carte de la classe pour la classe, à droite du titre du niveau pour le niveau.
- Une confirmation dans une `<dialog>` (comme la suppression d'une série, `dialog:`), qui chiffre l'impact. Pas de saisie du nom : l'action est réversible.
- Une classe archivée reste visible 7 jours, puis se masque ; un bouton « Afficher les archives » les montre toutes.

## 3. Règles d'implémentation

**Structure**
- Carte de classe (équipe : `teams/schools/_classroom_group` ; direction : carte de classe de l'écran du niveau) : en haut à droite, un `ui_dropdown` dans un conteneur `relative z-10` (au-dessus du lien étiré de la carte). Sur l'écran de la direction, la carte est un seul lien : la restructurer en carte + lien étiré comme `teams/schools/_classroom_group`.
- En-tête du niveau : `ui_dropdown` aligné à droite, après le badge du nombre de classes.
- Un id unique par menu : `classroom-menu-<public_id>`, `level-menu-<slug>`. Libellé accessible : « Actions de la classe 6ème 1 » / « Actions du niveau 6ème ».

**Entrées du menu**
- Classe active : « Archiver la classe » (icône `archive-box`, `tone: :danger`, `dialog:`).
- Classe archivée : « Restaurer la classe » (icône `arrow-uturn-left`, ton par défaut, lien `method: :patch`, sans confirmation).
- Niveau : « Archiver le niveau » (`tone: :danger`, `dialog:`), proposé seulement s'il reste au moins une classe active ; sinon le menu du niveau n'existe pas.

**Confirmation** (`<dialog>`, titre, deux boutons)
- Classe : « Archiver la classe 6ème 1 ? » · « 12 élèves et 1 enseignant ne la verront plus. Rien n'est supprimé : vous pouvez la restaurer à tout moment. » · [Annuler] [Archiver la classe].
- Niveau : « Archiver les 5 classes de 6ème ? » · « 142 élèves et 4 enseignants ne les verront plus… » · [Annuler] [Archiver le niveau].
- Pluriel et zéro gérés par i18n (`count`). Le bouton de confirmation est un `button_to` PATCH, ton danger.
- Focus d'ouverture sur [Annuler].

**Classe archivée dans la liste**
- Badge « Archivée » (déjà présent), effectif grisé, hors des totaux ; la carte n'est plus un lien (la page d'une classe archivée n'existe pas : sa lecture renvoie 404), la restauration se fait depuis son menu ⋮.
- Rangée en fin de son niveau ; son badge « Archivée » passe sous son nom (le titre ne se coupe pas) ; l'en-tête du niveau ajoute « N archivée(s) » au compteur des actives.
- Visible 7 jours après la date d'archivage ; au-delà, masquée. Un bouton « Afficher les archives (N) » sous la liste de **chaque niveau** (état vide compris ; ancre `#level_<slug>`), taille `sm` dont la zone tactile est portée à 48 px (convention des boutons) (lien `?archives=1`, Turbo, `aria-expanded`) les montre toutes ; « Masquer les archives » les remasque. N compte les archives masquées ; le bouton n'existe pas à 0.

**Comportement Turbo**
- Archiver et restaurer répondent par un `turbo_stream` qui remplace la carte (`classroom_<public_id>`) ou le groupe du niveau (`level_<slug>`) et émet un toast de succès.
- Sans JavaScript : redirection vers la même page avec un message flash.

**États obligatoires**
- Vide : niveau sans aucune classe visible → message « Aucune classe » + « Afficher les archives » s'il y en a.
- Chargement : bouton de confirmation désactivé avec spinner pendant la requête.
- Erreur : refus (droit) → toast d'erreur ; « déjà archivée » → toast neutre et rafraîchissement de la carte.
- Succès : toast « 6ème 1 archivée » avec lien « Annuler » (restaure) pendant le toast ; « 5 classes archivées » pour un niveau.

**Accessibilité**
- Cibles tactiles ≥ 48×48 px pour le ⋮ et les boutons de la confirmation ; 390 px : menu et dialog utilisables au pouce.
- `<dialog>` avec `aria-labelledby` (titre) et `aria-describedby` (corps, option `described_by:` de `ui_modal`) ; focus piégé, Échap = Annuler.
- En-tête de la page d'un niveau (direction) : le ⋮ reste à droite du titre sous `sm` (`ml-auto`).
- Le toast de succès est annoncé par la région `aria-live="polite"` des toasts (convention UDR-0006/0071 ; pas de `role="status"` en plus, qui doublerait l'annonce).
- Le bouton ⋮ et son menu portent le même libellé (convention du composant `ui_dropdown`, UDR-0042).

**Côté élève (UDR existantes)**
- Un élève sans classe active voit l'écran « Choisis ta classe » existant ; son en-tête n'affiche plus le nom de la classe archivée.
- Lien d'une classe archivée : bandeau « Cette classe est archivée », pas de « Rejoindre » ; l'élève connecté a le bouton « Choisir ma classe » (`#choose-classroom`) ; le visiteur est renvoyé vers l'inscription standard avec l'alerte « Ce lien n'est plus valable » (IL-09 : rien de la classe ne lui est révélé).

## 4. Conséquences

Toute nouvelle action sur une classe passe par ce menu ⋮. La carte de classe de l'écran de la direction n'est plus un lien unique. Aucune suppression définitive de classe n'est proposée.
