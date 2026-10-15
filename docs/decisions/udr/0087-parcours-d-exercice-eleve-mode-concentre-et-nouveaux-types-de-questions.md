# UDR-0087 : Parcours d'exercice de l'élève — page de l'exercice, séance en mode concentré, quatre nouveaux types de questions, résultat
<!-- index
titre: Parcours d'exercice de l'élève : mode concentré, nouveaux types
statut: Proposé
adr-lie: [0091](../adr/0091-quatre-nouveaux-types-de-questions-sur-les-tables-existantes.md)
problematique: Élève : page de l'exercice et résultat dans le cadre de l'accueil (deux colonnes dès 1 024 px), séance sans en-tête ni menus (croix, barre, « 3/5 », bouton collé en bas), confirmation pour quitter (feuille puis fenêtre), saisie des types trous, nombre (bouton ±), ordre (flèches) et relier (toucher-toucher), « Ton choix » sans jamais la bonne réponse. Amende UDR-0021, 0022, 0023, 0006, 0017, 0040
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/exercice-eleve`](../../chantiers/exercice-eleve/memo.md) |
| **ADR lié** | [ADR-0091](../adr/0091-quatre-nouveaux-types-de-questions-sur-les-tables-existantes.md) (types, notation, rien de la solution dans la page) |
| **Amende** | [UDR-0021](0021-page-exercice.md) · [UDR-0022](0022-session-d-exercice.md) · [UDR-0023](0023-resultat-de-session.md) · [UDR-0006](0006-shell-applicatif-par-role.md) (mode concentré du shell) · [UDR-0017](0017-formulaire-exercice.md) (champs par type) · [UDR-0040](0040-import-d-exercices.md) (aide de l'import) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menus) · [UDR-0086](0086-page-ma-classe-eleve-redessinee-et-invitation-de-l-enseignant.md) §3.5 (palier 700 px) |
| **Remplacé par** | — |

---

## 1. Contexte

Le parcours a été redessiné sur la toile https://claude.ai/artifact/NTPyZWmFK4oK9z9jMgvWL5 : 17 écrans au téléphone, 5 sur tablette, 7 sur ordinateur. Elle montre la page de l'exercice (nouveau, en cours), une question de chaque type, les bonnes et mauvaises réponses, la confirmation pour quitter, le résultat (« Félicitations ! », « Courage ! ») et le thème sombre. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- un mode concentré pendant la séance ;
- une confirmation pour quitter ;
- « Recommencer » caché à 20/20 ;
- quatre nouveaux types de questions et leurs règles de notation.

## 2. Décision

> **La page de l'exercice et le résultat prennent le cadre de l'accueil. La séance retire tout le cadre et ne garde que la question, la progression et le bouton d'action. Les nouveaux types se répondent au doigt sans glisser-déposer, et l'élève ne voit jamais la bonne réponse.**

## 3. Règles d'implémentation

### 3.1 Page de l'exercice (`assessment/exercises/show`, élève)

- **Cadre** : en-tête et menus d'UDR-0084.
- **Haut de page** : un lien vers la fiche, puis le cours, le titre, la matière, le type et le nombre de questions.
- **« Ta progression »** : meilleure note (verte à partir de 14/20), maîtrise, badge et nombre de sessions. Les quatre cases s'empilent par deux au téléphone et tiennent sur une ligne dès 700 px.
- **Action principale**, une seule :

| Situation | Action principale | Autre action |
|---|---|---|
| Exercice jamais commencé | « Commencer l'exercice » | — |
| Session en cours | « Reprendre » | « Recommencer » en `secondary` |
| Exercice déjà fait | « Refaire l'exercice » | — |

- **Aperçu des questions** : 3 questions puis « Voir plus », sans la bonne réponse. Pour les nouveaux types, l'aperçu montre l'énoncé et le type, sans valeur ni ordre.
- **Mise en page** : une colonne de 720 px dès 700 px. Dès 1 024 px, deux colonnes : la présentation et « Ta progression » à gauche, l'aperçu à droite.

### 3.2 Mode concentré (séance, `assessment/exercise_sessions/show`)

- **Shell** : `content_for :focus, true`. Le shell ne rend alors ni l'en-tête, ni le menu de gauche, ni le menu de l'avatar, ni la barre du bas, pour tous les rôles. L'app Android masque déjà ses barres pendant un exercice (UDR-0080 §3.3).
- **Haut de l'écran**, collé en haut : une croix « Quitter la session » (bouton icône `x-mark`, nom accessible « Quitter la session »), la barre de progression sur toute la largeur, puis « 3/5 ».
- **Zone de la question** : pleine largeur au téléphone, 640 px au centre dès 700 px.
- **Bouton d'action** : « Valider », « Question suivante » ou « Voir mon résultat ». Il est collé en bas (`sticky bottom-0`, `pb-[env(safe-area-inset-bottom)]`) et désactivé tant que la réponse est incomplète.

### 3.3 Quitter la séance

- La croix ouvre `ui_modal` :
  - sous 700 px, en feuille en bas (`placement: :sheet`) ;
  - dès 700 px, en fenêtre au centre.
- **Contenu** :
  - le titre « Quitter la séance ? » ;
  - le texte « Ta progression est gardée. Tu pourras reprendre à la question %{n}. », où `n` est `answered_count + 1` ;
  - « Continuer l'exercice » (`brand`, ferme la fenêtre) et « Quitter » (`secondary`, lien vers la page de l'exercice).
- La session reste `started`. Il n'y a pas de nouvelle route.
- Sans JS, la croix est un lien direct vers la page de l'exercice.

### 3.4 Saisie par type (`_question_card` → `kinds/_<type>`)

| Type | Saisie | Prêt à valider quand |
|---|---|---|
| Vrai / Faux, choix unique | boutons radio en grandes cartes | une carte choisie |
| 2 ou 3 propositions correctes | cases en grandes cartes, « Choisis 2 réponses » | le bon nombre coché |
| Texte à trous | la phrase avec un champ à la place de `___`, largeur à la taille du texte attendu moyen ; `autocapitalize="off"`, `autocomplete="off"`, `spellcheck="false"` | champ non vide |
| Réponse en nombre | grand champ centré `inputmode="decimal"`, bouton « ± » à gauche (le clavier Android n'a pas toujours le moins) ; la virgule est acceptée | champ lisible comme un nombre |
| Remettre dans l'ordre | liste numérotée ; chaque étape a « Monter » et « Descendre » (icônes `chevron-up` / `chevron-down`, 44 px), désactivés aux extrémités ; pas de glisser-déposer | toujours (l'ordre de départ est une réponse) |
| Relier | deux colonnes ; toucher un élément à gauche puis un à droite les relie par un même numéro dans une pastille ; toucher une paire la défait | tous les éléments de gauche sont reliés |

- **Stimulus** : un contrôleur par type nouveau, `assessment--fill-blank`, `assessment--numeric`, `assessment--ordering` et `assessment--matching`. Chacun écrit les champs cachés (indices d'affichage, ADR-0091 §4.4).
- **Sans JS** :
  - ordre : un `select` de rang par étape ;
  - relier : un `select` par élément de gauche ;
  - trous et nombre : des champs simples.

### 3.5 Retour après « Valider » (`_feedback_card`)

- **Verdict** :
  - « Bonne réponse », avec `check-circle` en `text-success` ;
  - ou « Mauvaise réponse », avec `x-circle` en `text-warning`. Le rouge n'est jamais utilisé.
- **« Ton choix »** :
  - les propositions cochées ;
  - le texte ou le nombre saisi ;
  - les étapes dans l'ordre de l'élève, numérotées ;
  - les paires de l'élève.

  Pour l'ordre et relier, en cas d'erreur, aucun élément n'est marqué juste ou faux : on ne révèle rien.
- **« Explication »** : elle reste si l'enseignant l'a écrite.
- **Bouton** : « Question suivante » ou « Voir mon résultat », collé en bas.

### 3.6 Résultat (`assessment/session_results/show`)

- **Cadre** : en-tête et menus d'UDR-0084 (fin du mode concentré).
- **Haut** :
  - le badge ;
  - le titre : « Félicitations ! » à partir de 14/20, « Courage ! » en dessous ;
  - la note /20 en grand, verte à partir de 14/20 ;
  - la maîtrise ;
  - la phrase de progrès (UDR-0073).
- **Actions** :
  - « Recommencer » (`brand`), caché à 20/20 ;
  - « Revoir l'exercice » (`secondary`), vers la page de l'exercice.
- **Correction** : question par question, « Ton choix » comme en §3.5, sans la bonne réponse pour l'élève.
- **Mise en page** : une colonne de 720 px dès 700 px. Dès 1 024 px, deux colonnes : la note et les boutons à gauche, la correction à droite.

### 3.7 Équipe et import

- **Formulaire de l'équipe** (`teams/exercises/_question_fields`) : le choix du type affiche ses champs, dans `teams/exercises/kinds/_<type>_fields`.
  - **Trous** : l'énoncé avec `___` et l'aide « Écris ___ là où l'élève répond », puis 1 à 5 réponses acceptées.
  - **Nombre** : la valeur attendue et la marge (facultative).
  - **Ordre** : les étapes dans le bon ordre, 3 à 6.
  - **Relier** : les paires gauche–droite, 3 à 5.
- **Aide de l'import** (`teams/imports/kinds/*`) : un exemple par nouveau type, avec `tolerance` et `match`.

### 3.8 Tokens

Aucun nouveau token.

| Usage | Tokens |
|---|---|
| Couleurs | `paper`, `white`, `ink`, `mute`, `line`, `brand`, `brand-soft`, `brand-strong`, `success`, `warning` |
| Rayons, ombres | `rounded-card`, `rounded-sheet`, `shadow-card`, `shadow-pop` |
| Cibles tactiles | `spacing-tap` |

### 3.9 États obligatoires

- **Page de l'exercice** : nouveau, en cours, déjà fait.
- **Séance** : une question de chacun des huit types ; la bonne et la mauvaise réponse (dont l'ordre faux et le relier juste) ; la confirmation pour quitter ; le thème sombre.
- **Résultat** : « Félicitations ! », « Courage ! », 20/20 sans « Recommencer », le thème sombre.

### 3.10 Accessibilité

- **Mode concentré** : la croix est le premier élément focalisable. La barre de progression est un `role="progressbar"` (`aria-valuenow`, `aria-valuemax`).
- **Trous** : le champ a pour nom l'énoncé, avec « blanc » à la place de `___`.
- **Nombre** : le bouton « ± » a pour nom « Changer le signe ».
- **Ordre** : chaque flèche a pour nom « Monter l'étape %{n} » ou « Descendre l'étape %{n} ». Après un déplacement, le focus suit l'étape, et une annonce `aria-live` dit « Étape déplacée en position %{n} ».
- **Relier** : chaque élément est un bouton `aria-pressed`. Le numéro de paire est lu (« relié à %{x} »). On peut tout faire au clavier.
- **Verdict** : il est annoncé (`aria-live="polite"`), et le focus passe sur son titre.

## 4. Conséquences

- **Shell** : il gagne un mode concentré (`content_for :focus`), utilisable plus tard par la révision.
- **Tests à réécrire** :
  - `test/system/assessment/{exercise_page,exercise_session,session_result}_test.rb` : le cadre, la croix, la confirmation ;
  - `test/system/teams/exercise_form_test.rb` : les champs par type.
- **UDR-0021 à 0023** : elles valent toujours pour les rôles qui voient les bonnes réponses. Pour l'élève, celle-ci les remplace.
