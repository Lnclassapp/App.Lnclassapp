# UDR-0140 : La feuille d'un devoir et le résultat corrigé comme en classe
<!-- index
titre: Feuille d'un devoir et résultat corrigé comme en classe
statut: Accepté
adr-lie: [0115](../adr/0115-correction-complete-note-en-points-et-types-de-questions.md)
problematique: La feuille ne sait pas poser un devoir de 3e et le résultat ne dit ni la bonne réponse ni quoi revoir
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-28 |
| **Chantier** | `docs/chantiers/correction-comme-en-classe` |
| **ADR lié** | ADR-0115 |
| **Remplace** | UDR-0023 sur « jamais les bonnes réponses à l'élève » ; UDR-0138 sur le nom du bouton (« Rendre ma copie ») |
| **Remplacé par** | — |

---

## 1. Contexte

Sur son téléphone, l'élève fait un exercice, rend sa copie et lit « Courage ! », un « Faux » et une explication, sans la
bonne réponse. Les maquettes de Konan montrent la feuille d'un vrai devoir : une liste de mots dans la phrase, l'unité à côté
du champ, un tableau de mesures, une question à rédiger, une construction sur le cahier, des points. Elles montrent aussi
des boutons « Vérifier » par exercice et une durée, que le porteur écarte (D5, D8).

## 2. Décision

- **Un seul bouton, « Vérifier ma copie »**, en bas de la feuille, avec une phrase juste au-dessus : la copie part d'un seul
  envoi, comme aujourd'hui. Le mot « Vérifier » dit que la correction arrive tout de suite ; la phrase dit qu'on ne revient
  pas en arrière.
- **Le choix dans une liste est un `<select>` natif**, placé dans la phrase à la place du trou. Un menu natif marche sans
  JavaScript, s'ouvre en plein écran sur un téléphone et se lit au lecteur d'écran, mieux qu'une liste dessinée à la main.
- **Les choix courts restent les choix d'aujourd'hui** (décision du porteur, question 4) : aucune pastille en ligne nouvelle.
- **L'association garde son interaction actuelle** (toucher à gauche, puis à droite ; listes de choix sans JavaScript).
- **Le résultat se lit comme une copie corrigée** : l'appréciation en titre, la note et ses points, « À revoir », puis
  chaque question avec la réponse de l'élève, la bonne réponse et l'explication, ou le corrigé type.

## 3. Règles d'implémentation

**Structure de la feuille** (`app/views/assessment/exercise_sessions/show.html.erb`)
- Sujet : le texte (`simple_format`, inchangé), puis les blocs du sujet rendus par
  `render "catalog/course_sheets/blocks/#{block["type"]}"` pour `paragraph`, `box` et `table`. Le tableau défile dans son
  propre conteneur (`overflow-x-auto`), jamais la page.
- Points : quand au moins une question n'est pas à 1 point, chaque légende de question finit par
  `t(".points", count:)` (« (2 points) », « (1,5 point) », nombre au format `fr`). Sinon, aucun point.
- Aucune durée, nulle part.
- Pied : `<p class="text-sm text-mute">` « Une fois ta copie vérifiée, tu ne pourras plus changer tes réponses. », puis le
  bouton principal « Vérifier ma copie » (texte d'attente : « Vérification… »).

**Partiels de la feuille** (`exercise_sessions/kinds/`)
- `_select` : la phrase coupée sur `___` comme `_fill_blank` ; à la place du trou, un `select` (`min-h-tap`, bordure
  `border-brand-strong`, fond `bg-brand-soft`, mêmes classes que le champ de `_fill_blank`), première option vide
  « — choisir — ». Sans trou : la phrase, puis le `select` en pleine largeur dessous. L'ordre des propositions suit
  `AnswerShuffle`, comme les choix. `aria-label` : la phrase avec « blanc » à la place du trou.
- `_numeric` : quand la question a une unité, un `<span class="text-ink">` après le champ, lié par `aria-describedby`.
- `_written` : un `textarea` de 6 lignes, `maxlength="2000"`, `placeholder` = le début de phrase, un compteur
  « 1 234 / 2 000 » en `text-sm text-mute` (Stimulus `assessment--counter` ; sans JavaScript, pas de compteur).
- `_notebook` : la consigne, puis une ligne `text-sm text-mute` avec l'icône `pencil` et « À faire sur ton cahier ». Aucun
  champ.

**Structure du résultat** (`app/views/assessment/session_results/show.html.erb`)
1. Titre `h1` : l'appréciation (« Très bien », « Bien », « Assez bien », « À retravailler »). « Félicitations ! » et
   « Courage ! » disparaissent.
2. La phrase d'encouragement (élève seulement), inchangée.
3. La note en grand, puis `text-sm text-mute` : « 8 points sur 11 corrigés automatiquement » quand l'exercice n'est pas tout à
   1 point ; « 9 points à comparer au corrigé » quand il a des réponses rédigées ou du cahier.
4. « À revoir » : une carte `rounded-card border border-line bg-white p-4`, avec la notion et les questions en cause (liens
   vers `#q2`, `#q4`), ou « dans la leçon » avec un lien vers `#toute-la-lecon`. Absente s'il n'y a rien à revoir.
5. La pause, quand elle s'applique : « Tu pourras recommencer à 21 h 14. » à la place de « Refaire l'exercice ».
6. La correction, question par question (`_question_review`).

**Partiels du résultat** (`session_results/kinds/`)
- Tous les types corrigés automatiquement : « Ta réponse » puis « Bonne réponse », l'explication dessous. Pour l'élève, ils
  s'affichent seulement si `RevealCorrectionPolicy` accepte.
- `_select_review` : la proposition choisie, puis la correcte.
- `_numeric_review` : valeurs suivies de l'unité.
- `_written_review` : pastille « À comparer au corrigé » (ton neutre, jamais rouge ni vert) ; « Ta réponse » dans un bloc
  `whitespace-pre-line`, échappé (jamais `raw`, jamais `html_safe`) ; vide : « Tu n'as rien écrit. » ; puis « Corrigé » ; puis
  la grille.
- Grille : un `fieldset` « Grille de vérification », une case à cocher native par critère (`min-h-tap`), jamais envoyée.
- `_notebook_review` : pastille « À comparer au corrigé », puis « Corrigé ».

**Tokens**
- Couleurs, rayons et espacements : uniquement ceux du design system (`brand`, `ink`, `mute`, `line`, `mist`, `rounded-card`,
  `rounded-ln`). Le juste et le faux gardent leurs couleurs actuelles ; « À comparer au corrigé » prend le ton neutre
  `bg-mist text-ink`.

**Comportement**
- Pas de Turbo Frame nouveau. La copie part en un `POST` (inchangé).
- Pendant la pause, la page de l'exercice remplace son bouton par la même phrase que le résultat.

**États obligatoires**
- Feuille : question non répondue (aucune option choisie, zone vide) ; erreur de champ (réponse rédigée trop longue,
  réponse chiffrée mal formée) avec le message sous le champ.
- Résultat : sans faute (pas d'« À revoir », pas de « Refaire l'exercice ») ; copie vide ; réponse rédigée vide ; pause.

**Accessibilité**
- Cibles ≥ 48 px (`min-h-tap`) pour le `select`, la zone de texte et chaque case de la grille.
- Le `select` dans la phrase garde un `aria-label` qui lit toute la phrase.
- Le tableau a un `caption` (son titre) et des `th scope="col"`.
- À 390 px : aucune page plus large que l'écran ; le tableau défile seul.

## 4. Conséquences

- La feuille et le résultat ne montrent jamais de durée.
- Aucun bouton ne vérifie une question seule.
- Un texte d'élève n'est jamais rendu en HTML.
- Les captures d'écran de chaque lot qui touche l'interface se font à 390 px et sur ordinateur, sur l'exercice Thalès
  « Devoir » et « Lentilles » de démonstration.
