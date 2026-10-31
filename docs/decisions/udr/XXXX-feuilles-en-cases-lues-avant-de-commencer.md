# UDR-XXXX : Les feuilles « Prépare interros » et « Prépare devoirs » en cases, lues avant de commencer
<!-- index
titre: Feuilles en cases, lues avant de commencer
statut: Accepté
adr-lie: —
problematique: Sur la page d'une leçon et dans « Ma classe », les feuilles sont empilées et déjà prêtes à remplir ; l'élève ne voit ni combien il y en a ni le sujet en entier avant de commencer.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-31 |
| **Chantier** | `docs/chantiers/sujet-avant-de-commencer` |
| **ADR lié** | — (ADR-0121 pour les feuilles et les sujets) |
| **Remplacé par** | — |

Amende l'UDR-0149 §3 (« Structure » et « Devoirs reçus par l'élève ») : la feuille elle-même ne change pas, elle quitte la page de la leçon et « Ma classe » pour sa propre page.

---

## 1. Contexte

Thalès porte huit feuilles (trois notions, « Toute la leçon », quatre sujets). Empilées sur la page de la leçon, prêtes à remplir, elles font une page très longue où l'élève ne voit pas ce qui l'attend. Un vrai devoir se lit en entier avant d'écrire.

## 2. Décision

Chaque feuille devient une **case** sur la page qui l'accueillait. La case mène à la **page de la feuille**, qui montre d'abord le sujet complet **en lecture** (énoncés, figures, questions, propositions des QCM, cases vides), puis, en bas, « Commencer » (ou « Continuer »). Ce bouton mène à la **feuille à remplir**, la feuille d'aujourd'hui, inchangée. Pages séparées plutôt que case dépliée sur place (choix du pilote) : une adresse par feuille, le retour du navigateur marche, et la page de résultat peut ramener à la feuille remplie.

## 3. Règles d'implémentation

**Pages et adresses**

| Page | Adresse | Qui |
|---|---|---|
| Leçon (catalogue) | `/courses/:slug` (inchangée) | tous ceux qui la lisent aujourd'hui |
| Feuille, lecture | `/courses/:course_slug/feuilles/:sheet` | idem |
| Feuille, à remplir | `/courses/:course_slug/feuilles/:sheet/remplir` | élève et visiteur ; enseignant et équipe : redirigés vers la lecture |
| Leçon dans la classe (enseignant) | `/classrooms/:classroom_public_id/courses/:course_slug` (inchangée) | enseignant de la classe |
| Feuille dans la classe | `/classrooms/:classroom_public_id/courses/:course_slug/feuilles/:sheet` | idem ; ses bascules d'envoi limitées à cette classe, comme aujourd'hui |
| Ma classe | `/students/classroom` (inchangée) | élève |
| Devoir reçu, lecture | `/students/classroom/devoirs/:sheet` | élève |
| Devoir reçu, à remplir | `/students/classroom/devoirs/:sheet/remplir` | élève |

`:sheet` est l'ancre de la feuille d'aujourd'hui (`dom_id` des requêtes : `notion-<slug>`, `toute-la-lecon`, `sujet-<n>` ; celui du devoir reçu). Une feuille introuvable (sujet retiré, ancre inconnue, devoir d'une autre classe) : redirection `303` vers la page d'accueil de la feuille (leçon ou « Ma classe ») avec le flash `alert` « Cette feuille n'existe plus. » ; jamais de 500. Les autorisations sont celles de la page d'accueil (`ReadPublishedPolicy` pour la leçon, `ReadClassroomPolicy` pour la classe, la requête des devoirs reçus de l'élève connecté pour « Ma classe »).

**Case** (`app/views/catalog/courses/sheets/_card.html.erb`, une seule pour les trois pages hôtes)
- Un `<a>` qui couvre toute la case, vers la page de lecture. `id` : l'ancre de la feuille (`notion-<slug>`, `toute-la-lecon`, `sujet-<n>`), pour que les liens existants vers `#notion-<slug>` tombent sur la case.
- Contenu, du haut vers le bas, dans le style des feuilles (`.ps-card`, police Source Serif 4, bordure noire 2 px, fond blanc, rayon 0) :
  1. « PRÉPARE INTERROS N°1 » / « PRÉPARE DEVOIRS N°2 » (gras, capitales, même clé que le titre de la feuille) ;
  2. le titre de la feuille (nom de la notion, « Toute la leçon », titre du sujet, « Devoir du <date> ») ;
  3. « n exercices » (`n exercice` au singulier) ;
  4. élève seulement : la progression « x / n exercices réussis » (même clé que la feuille) ; pour un devoir reçu, « À rendre le <date> » ou « Rendu » quand tous ses exercices le sont ;
  5. à droite, une flèche `chevron-right` (`aria-hidden="true"`).
- Grille `.ps-cards` : 1 colonne sous 640 px, 2 colonnes de 640 à 1 023 px, 3 colonnes dès 1 024 px ; écart 16 px. Hauteur minimale de la case 112 px.
- Sections inchangées : titre « Prépare interros » puis ses cases (notions dans l'ordre, puis « Toute la leçon ») ; « Prépare devoirs » puis ses cases, seulement s'il y a un sujet. « Ma classe » : une case par devoir reçu, le plus récent en premier.

**Page de lecture**
- En haut, le lien retour « ← <titre de la leçon> » (ou « ← Ma classe »), vers la page hôte, à l'ancre de la case.
- Puis la feuille (`_sheet`) en `mode: :reading` :
  - cartouche, titre numéroté, sous-titre, progression (élève), encadré « À retenir » / « Notions mobilisées » : inchangés ;
  - chaque exercice : « Exercice n », énoncé, figure, chaque question avec son étiquette et ses champs **désactivés** (un `<fieldset disabled>` par exercice : les propositions d'un QCM se lisent, les cases restent vides) ;
  - absents : statut de l'exercice, marques ✓ / ✗, barre de boutons (« Vérifier ma réponse », « Indice », « Refaire l'exercice », « Voir ma correction »), boîte de l'indice, lien « Recommencer », brouillon du navigateur (pas de contrôleur `prepare-sheet`).
- Sous la feuille, élève et visiteur : un bouton noir pleine largeur sur téléphone (`.ps-start`, hauteur 48 px) vers la page à remplir : « Commencer Prépare interros » / « Commencer Prépare devoirs » ; « Continuer Prépare interros » / « Continuer Prépare devoirs » dès qu'un exercice de la feuille a une copie terminée.
- Enseignant : pas de bouton ; la feuille est en `mode: :teacher` (ses bascules et la case « Choisir » sous chaque exercice, le bandeau d'envoi `_batch_bar`), comme aujourd'hui sur la leçon. Équipe : `mode: :team`, pas de bouton.

**Page à remplir**
- Le lien retour vers la page de lecture (« ← Lire le sujet »), puis la feuille d'aujourd'hui (`mode: :student` ou `:visitor`, `hand_ins` pour un devoir reçu), inchangée : champs, « Vérifier ma réponse » / « Rendre à l'enseignant », indice, « Recommencer ».
- La page de résultat (`session_results#show`) ramène à cette page, à l'ancre `#sheet-exercise-<public_id>` : le formulaire de la feuille poste `sheet` (l'ancre de la feuille) avec `return_to`, que la vérification transmet à la page de résultat ; `sheet` n'est lu que s'il correspond à `\A[a-z0-9-]{1,120}\z`, sinon l'ancien retour (la leçon) s'applique.
- Le lien « Ce devoir est à rendre : ouvre-le dans Ma classe. » mène à « Ma classe » (inchangé).

**Tokens**
- Exception assumée de l'UDR-0149 : `.ps-card`, `.ps-cards`, `.ps-start` dans `app/assets/stylesheets/prepare_sheet.css`, mêmes valeurs que la feuille (`#000`, `#fff`, `#f5f5f5` au survol de la case, rayon 0). Aucun style en ligne.

**États obligatoires**
- Vide : leçon sans exercice, l'état vide d'aujourd'hui (« exercises_empty »), aucune case ; « Ma classe » sans devoir, l'état vide d'aujourd'hui.
- Chargement : navigation Turbo ordinaire (barre de progression Turbo) ; la case n'a pas de préchargement au survol (`data-turbo-prefetch="false"` sur la section, comme aujourd'hui).
- Erreur : feuille introuvable, redirection avec le flash « Cette feuille n'existe plus. » ; un refus de vérification reste dans l'exercice (inchangé).
- Succès : la case montre la progression à jour au retour sur la page hôte.

**Accessibilité**
- La case : un seul lien, nom accessible = son texte (`aria-label` absent) ; cible ≥ 48 px ; focus visible (`outline: 3px solid #000; outline-offset: 2px`).
- Page de lecture : `<h1>` = le titre numéroté de la feuille ; les `fieldset disabled` gardent les champs lisibles par un lecteur d'écran.
- Le bouton « Commencer » est un `<a>` (navigation), pas un `<button>`.

## 4. Conséquences

- La page de la leçon, la page de la classe et « Ma classe » ne rendent plus aucune feuille : seulement des cases. Tout lien qui visait `#sheet-exercise-<id>` sur la page de la leçon vise désormais la page à remplir de sa feuille.
- Interdit désormais : remettre une feuille à remplir directement sur une page hôte.
