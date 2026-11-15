# UDR-XXXX : Écrans minimalistes, style Wave — un écran, une chose de valeur (accueil, matière, leçon de l'élève)
<!-- index
titre: Écrans minimalistes, style Wave
statut: Accepté
adr-lie: —
problematique: L'accueil, la vue d'une matière et la page d'une leçon empilaient cartes, raccourcis en double et sections vides ; l'élève doit voir une seule chose de valeur par écran, comme dans l'app Wave.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-14 : maquettes validées, `docs/chantiers/simplification-ecrans-eleve/maquettes/`) |
| **Date** | 2026-11-14 |
| **Chantier** | [`docs/chantiers/simplification-ecrans-eleve`](../../chantiers/simplification-ecrans-eleve/maquettes/README.md) |
| **ADR lié** | — |
| **Remplacé par** | — |

Remplace : UDR-0144 (carte « Prochain exercice » dans la matière et la leçon), et dans UDR-0132 / UDR-0058 la carte « Prochain exercice », l'« Exercice du jour » et la 7ᵉ case « Inviter ». Complète : UDR-0005 (tokens), UDR-0071 (annonces, mêmes cartes). Les maquettes font foi pour le rendu ; cette UDR est la règle qu'on applique à tout nouvel écran de l'élève.

---

## 1. Contexte

L'accueil élève portait cinq blocs qui se répétaient (carte du prochain exercice, exercice du jour, « À faire », « Inviter » en case et en bandeau) ; la vue d'une matière et la page d'une leçon répétaient la même carte « Prochain exercice », un lien « Tous les exercices » et un cadre noir. Sur Android d'entrée de gamme, l'élève lisait 460 mots avant son premier clic utile.

## 2. Décision

Les écrans de l'élève suivent le style de l'app Wave : **un écran, une chose de valeur**. Le reste est retiré, pas déplacé. Huit règles, valables pour tout écran élève à venir :

1. **Un écran, une chose de valeur.** Accueil : la classe et « Entrer en classe ». Matière : ses leçons. Leçon : réviser et s'entraîner.
2. **Jamais de section vide.** Une section sans élément est masquée (titre compris), jamais remplie d'une phrase « rien à faire ».
3. **Pas de raccourci en double.** Une action n'a qu'une porte par écran (plus de « Prochain exercice », d'« Exercice du jour », de case « Inviter » à côté du bandeau d'invitation, de « Tous les exercices »).
4. **Pas de barre de navigation sur les écrans intérieurs** (matière, leçon) : une flèche retour et un grand titre. La barre du haut et le menu de gauche n'y paraissent à aucune largeur. L'accueil garde son bandeau bleu.
5. **Fond gris clair, groupes dans des cartes blanches arrondies**, avec un libellé de section gris au-dessus de chaque groupe.
6. **Recherche dans un champ gris plein**, sans bordure ni bouton « Filtrer » visible.
7. **Listes plates à valeur alignée à droite** (« 0/4 ») : une ligne = un titre, une ligne de détail, une valeur.
8. **Au plus 3 éléments par section, puis « Voir plus (n) »** (n = les éléments cachés), sans requête.

Pourquoi plutôt qu'un onglet ou une barre du bas : la valeur de l'écran est dite en une seule place, et l'élève n'a plus à choisir entre deux chemins qui mènent au même exercice.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement ; aucun nom de couleur, rayon ou espacement hors tokens.

**Tokens** (ajoutés au `@theme`, UDR-0005 §« Ajouter ou modifier ») : `--radius-wave: 1.75rem` (28 px, haut du blanc sous le bandeau) · `--spacing-wave-band: 11.6875rem` (187 px, bandeau de l'accueil) · `--spacing-wave-lap: 1.75rem` (28 px, recouvrement du blanc sur le bandeau : le blanc commence à 187 − 28 = **159 px**, soit 30 % plus bas que la maquette d'origine) · `--spacing-wave-card: 4.5625rem` (73 px, la carte de classe remonte sur la jonction). Graisse : **exception écrite à l'UDR palette froide §3.2** : les écrans de l'élève suivent les maquettes validées, en 600 (`font-semibold` : libellés de section, titre d'une ligne « À faire », « Voir plus ») et 700 (`font-bold` : titre de l'écran, nom de la classe, valeur « 0/4 », titre d'annonce) ; le garde `design_tokens_test` ne les autorise que dans les fichiers de `WAVE_WEIGHT_SCREENS`. Aucune autre couleur : fond de page `bg-mist`, cartes `bg-white`, champ de recherche `bg-line`, libellés `text-mute`, valeurs `text-ink`, liens `text-brand-strong`. Le sombre est celui des tokens (UDR-0065), rien de plus.

**Shell** (`layouts/shell.html.erb`) :
- `content_for :wave_home` (accueil) : la page rend sa propre colonne, sans le conteneur du shell. Le bandeau reste `content_for :home_band` (sous lg).
- `content_for :inner` (matière, leçon) : ni en-tête, ni menu de gauche, ni barre du bas, à toutes les largeurs ; fond `bg-mist` sur toute la fenêtre à toutes les largeurs ; la page rend `shared/screens/inner_header` puis sa colonne `mx-auto max-w-180`.

**Composants** (`app/views/shared/screens/`) :
- `_inner_header` (locals `title:`, `back_href:`, `subtitle: nil`) : lien flèche ≥ 48 px (`aria-label` I18n « Retour »), `h1` 2xl `font-medium`, sous-titre `text-sm text-mute` sous le titre.
- `_group` (rendu avec `layout:` et un bloc ; locals `id:`, `title:`, `total:`) : `<section aria-labelledby>`, libellé `text-sm font-medium text-mute`, carte `rounded-card bg-white`, lignes dans `ul` ; au-delà de `ComponentsHelper::REVEAL_LIMIT` (3), les lignes en trop sont `hidden` (contrôleur `reveal`, UDR-0057 R3) et la dernière ligne de la carte est « Voir plus (n) » (`text-brand-strong`, centré, ≥ 48 px). Le contrôleur `reveal` révèle les lignes ; c'est le comportement des listes de l'UDR-0057.
- `_row` (locals `title:`, `href:`, `detail: nil`, `value: nil`, `icon:`) : ligne entière cliquable ≥ 48 px, pastille d'icône 40 px `rounded-ln`, titre `text-base font-medium`, détail `text-sm text-mute`, valeur `font-medium tabular-nums` alignée à droite.

**Accueil** (`/students`, ordre fixe) :
1. Bandeau bleu 187 px : avatar à gauche, aide en **icône seule** à droite (`aria-label` « Besoin d'aide ? », cible 48 px).
2. Le blanc commence à 159 px, coins hauts `rounded-t-wave`.
3. **Carte de classe**, à cheval sur la jonction (`-top-wave-card`) : étiquette « Ta classe », nom de la classe (`h2`), établissement ; à droite **le sigle de l'établissement en pastille ronde** (`size-20 rounded-full bg-brand-soft`). Sigle : celui de la base ; sinon **dérivé des initiales du nom** de l'établissement (mots de 3 lettres et plus, hors « de », « du », « des », « la », « le », « les », « et », 4 lettres au plus ; « Lycée Moderne de Treichville » → « LMT »). Le petit logo Lnclass en bas à droite. Bouton **« Entrer en classe »** (`ui_button`, `Ma classe`). Sans classe : la carte « Choisis ta classe » (code de classe) prend sa place, inchangée.
4. **Mes matières** : libellé gris, grille 4 colonnes de ronds teintés (`illustration.tint`). Aucun compteur ; le point ambre d'un exercice en retard reste. Pas de case « Inviter ».
5. **Annonces** : le carrousel existant (`communication/messages/_card`, `_carousel`) sur une bande `bg-mist`, cartes `rounded-card` de 300 px (≈ 11/12 sous 640 px), illustration, **audio** et **croix** (masquage, UDR-0071) ; masqué s'il n'y a aucune annonce lisible.
6. **À faire** : liste plate (`_row`), titre, matière, **sans pastille** : titre en `text-brand-strong` 600, détail « matière · échéance », valeur **« répondu/total »** (« 1/5 », nombre de questions de l'exercice et réponses déjà données dans sa session commencée ; masquée sans question) alignée à droite, **seulement s'il y a un exercice assigné non commencé** (la carte ne le retire plus). **Historique** : même règle ; le titre est rendu avec ses lignes par le cadre différé, donc jamais seul.
7. **Bannière d'invitation** « Ton enseignant n'est pas sur Lnclass ? » + « Inviter » (partage WhatsApp, ADR-0089 §4.3) : `bg-brand-soft`, croix de masquage mémorisée sur l'appareil (contrôleur `dismissible`, `localStorage`, sans compte) ; seule porte « Inviter » de l'écran.
- **Supprimé** : « Exercice du jour » (carte et bloc), carte « Prochain exercice », case « Inviter ».

**Matière** (`/courses?material=<slug>`) : `inner_header` (titre = nom de la matière, retour vers l'accueil) ; recherche : champ `bg-line rounded-ln`, icône loupe, `search_field_tag q`, cherché pendant la frappe (contrôleur `search`) ; libellé de groupe = le sous-titre commun aux leçons (« Progression DPFC 2026-2027 ») ; **grille de 4 colonnes** de tuiles : pastille pastel 48 px `rounded-ln` + pictogramme, **libellé court** (2 lignes au plus), « Leçon n » `text-xs text-mute`, **coche verte** en coin si la leçon est faite. Toute la tuile mène à `/courses/<slug>`. Plus de pastilles de matières, de barre ni de « Prochain exercice ». Au-delà de 24 leçons, la page suivante se charge au défilement (inchangé).
- **Icône d'une leçon : calculée, jamais saisie** (aucune colonne). `Catalog::LessonTileHelper` : un jeu fini de 22 pictogrammes (`LESSON_ICONS`), des règles par mots-clés (`LESSON_ICON_RULES`, sur le titre sans accents, en minuscules, **dans l'ordre**, par matière), puis **l'icône de la matière** en repli. Une règle ne cite qu'un pictogramme du jeu (test). Ajouter un mot ou un pictogramme : une ligne dans le helper, un exemple dans son test ; pas de migration.
- **Libellé court** : le titre coupé au premier « et », « ou », « : », « — », « , » s'il reste 4 lettres ou plus avant la coupe ; le titre entier reste en `title` et lu aux lecteurs d'écran.

**Leçon** (`/courses/<slug>`) : `inner_header` (titre = nom de la leçon, sous-titre « Leçon n · Matière · Niveau », retour vers la matière) ; trois groupes, dans l'ordre : **« Réviser »** (une ligne « Fiche de révision » qui ouvre la fiche, ancre `#fiche-de-revision`, la fiche elle-même est dans la page mais **cachée** (`hidden target:block`) tant que la ligne ou l'adresse `#fiche-de-revision` ne la désigne pas : rien sous les groupes ; toute notion garde son ancre `notion-<slug>`), **« Prépare interros »**, **« Prépare devoirs »** (valeur `passés/total`, « 0/4 ») ; chaque groupe applique la règle 8. Un groupe sans ligne est masqué. Pour l'enseignant et l'équipe, la page de la leçon est inchangée. **Supprimé** : navbar, carte « Prochain exercice », lien « Tous les exercices », cadre noir et étiquette « PRÉPARE DEVOIRS N°x ».

**États** : *vide* : section masquée (règle 2) ; seule exception, la matière sans leçon (« Aucune leçon pour l'instant », hors recherche) ; recherche sans résultat : « Aucun résultat » + « Effacer la recherche » ; *chargement* : cadre différé, sans squelette qui annoncerait une section peut-être vide ; *erreur* : `ui_error_state` du contrôleur `search` ; *hors ligne* : inchangé (`keep_offline`, UDR hors-connexion).

**Accessibilité** : cibles ≥ 48 px ; le titre de la page reste un `h1` (sr-only sur l'accueil) ; l'aide en icône seule a son `aria-label` ; la coche d'une leçon faite est dite (« Terminée », sr-only) ; la croix d'une bannière a son nom ; focus visible `outline-brand` ; `prefers-reduced-motion` respecté ; aucune information portée par la seule couleur.

**Thème sombre** : tokens seulement ; les pastilles pastel utilisent les `tint-*` (ils ont leur valeur sombre) ; contrôlé en capture, clair et sombre, 390 px et ordinateur.

## 4. Conséquences

- La règle d'or : **ce qu'on ajoute à un écran de l'élève en retire un autre**. Toute nouvelle carte d'accueil passe par cette UDR.
- Le chemin grille → exercice passe de 2 clics (carte) à 3 (matière → leçon → sujet) ; le porteur l'accepte pour la lisibilité (maquettes validées). La carte « Prochain exercice » n'existe plus nulle part ; **Le code de la carte est conservé, hors des écrans** : `NextExerciseQuery`, la partial `_next_exercise`, les états `next_step/` et leurs clés I18n restent (non affichés), pour le guidage d'activation après l'inscription (issue « Réutiliser « Prochain exercice » dans l'activation après l'inscription »). Seul l'affichage sur l'accueil, la matière et la leçon est retiré. La skill `.claude/skills/ecrans-wave` est le mode d'emploi de cette UDR.
- « Voir plus (n) » ne fait aucune requête : les lignes en trop sont déjà dans la page, masquées (`hidden`), et révélées par `reveal` (même limite et même contrôleur que l'UDR-0057 R3).
- Les écrans enseignant, direction et équipe ne changent pas : la barre et la carte d'accueil de l'enseignant restent celles de l'UDR enseignant.
- La charte `lnclass-design-system` (skill hors dépôt) impose encore la carte « Prochain exercice » : elle est périmée sur ce point, voir le journal du chantier.
