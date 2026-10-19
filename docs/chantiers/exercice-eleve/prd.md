# PRD — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les trois écrans de l'exercice (page de l'exercice, séance, résultat) prennent la langue visuelle de l'accueil ; la séance passe en mode concentré, sans en-tête ni menus, avec une confirmation pour quitter. Quatre types de questions s'ajoutent (texte à trous, réponse en nombre, remettre dans l'ordre, relier), saisis par l'équipe ou importés, notés tout juste ou faux. L'élève ne voit jamais la bonne réponse, ni à l'écran ni dans la page.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir la page d'un exercice de son niveau, faire une séance, quitter et reprendre, voir son résultat et « Ton choix » | Voir ou déduire la bonne réponse (`RevealAnswersPolicy`), ni dans le HTML |
| Team (équipe) | Créer et modifier des questions des huit types, importer des fichiers qui en contiennent | — |
| Teacher | Voir les bonnes réponses sur la page de l'exercice et le résultat, comme aujourd'hui | Créer des questions (inchangé) |

Règles inchangées : `StartSessionPolicy`, la policy de `SubmitQuestionAttempt`, `RevealAnswersPolicy`, `ManageContentPolicy`.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre un exercice : présentation, « Ta progression », « Commencer l'exercice », aperçu des questions.
2. Il commence : l'en-tête et les menus disparaissent ; en haut, la croix, la barre de progression et « 1/5 ».
3. Il répond (une question de chaque type possible), touche « Valider » : « Bonne réponse » ou « Mauvaise réponse », « Ton choix », l'explication, « Question suivante ».
4. À la question 3, il touche la croix : « Quitter la séance ? » ; il choisit « Quitter » et revient à la page de l'exercice, qui propose « Reprendre ».
5. Il reprend à la question 3, finit, touche « Voir mon résultat » : badge, « Félicitations ! » ou « Courage ! », note /20, maîtrise, phrase de progrès, « Recommencer », « Revoir l'exercice », correction.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Réponse en nombre illisible (« 3,,5 ») | Erreur de saisie sous le champ, la question n'est pas comptée |
| Texte à trous avec majuscules, accents ou espaces en trop | Juste si le texte normalisé égale une réponse acceptée (ADR-0091 §4.3) |
| Texte à trous avec une faute de frappe | Mauvaise réponse |
| Nombre dans la marge de l'enseignant | Juste |
| Ordre ou relier avec une seule erreur | Mauvaise réponse, rien n'est marqué juste ou faux dans « Ton choix » |
| 20/20 | Pas de « Recommencer » |
| « Continuer l'exercice » dans la confirmation | La fenêtre se ferme, la séance continue |
| Sans JavaScript | Ordre et relier par des listes de choix ; la croix mène directement à la page de l'exercice |
| Deux onglets, la même question validée deux fois | Comportement actuel (conflit, toast, rechargement) |
| Fichier d'import v1 existant | S'importe sans changement |
| Question mal formée à la saisie ou à l'import (pas de `___`, 2 étapes, nombre illisible) | Erreur de structure, comme aujourd'hui |
| App Android | Mode concentré : la coque masque déjà ses barres pendant un exercice |

## 4. Critères d'acceptation

```gherkin
# CA-1 Mode concentré
Étant donné un élève en séance sur un écran de 390 px
Alors la page n'a ni en-tête, ni menu de l'avatar, ni menu de gauche, ni barre du bas
Et elle montre une croix « Quitter la session », la barre de progression et « 1/5 »
Et le bouton « Valider » est collé en bas et désactivé tant qu'il n'a pas répondu

# CA-2 Quitter
Étant donné un élève qui a répondu à 2 questions sur 5
Quand il touche la croix
Alors une feuille dit « Tu pourras reprendre à la question 3. »
Quand il touche « Quitter »
Alors il revient sur la page de l'exercice, qui propose « Reprendre »
Et la session est toujours ouverte

# CA-3 Continuer
Quand il touche « Continuer l'exercice »
Alors la feuille se ferme sur la même question

# CA-4 Texte à trous
Étant donné la question « La capitale économique de la Côte d'Ivoire est ___ . » avec la réponse acceptée « Abidjan »
Quand l'élève écrit « ABIDJAN  »
Alors la réponse est juste
Quand l'élève écrit « Abidjn »
Alors la réponse est fausse

# CA-5 Nombre
Étant donné une question dont la valeur attendue est 3,5 avec une marge de 0,1
Quand l'élève écrit « 3.45 »
Alors la réponse est juste
Quand il écrit « 3,,5 »
Alors il voit une erreur de saisie et la question n'est pas comptée

# CA-6 Signe moins
Étant donné une question dont la valeur attendue est -2
Quand l'élève tape 2 puis touche « ± »
Alors le champ montre « -2 » et la réponse est juste

# CA-7 Ordre
Étant donné une question de 4 étapes
Quand l'élève les remet dans le bon ordre avec « Monter » et « Descendre » et valide
Alors la réponse est juste
Et si une seule étape est mal placée, la réponse est fausse

# CA-8 Relier
Étant donné une question de 3 paires
Quand l'élève relie les trois paires justes
Alors la réponse est juste
Et le bouton « Valider » reste désactivé tant qu'un élément de gauche n'est pas relié

# CA-9 Rien de la solution dans la page
Étant donné une question de chacun des quatre nouveaux types
Alors le HTML de la séance ne contient ni la valeur attendue, ni une réponse acceptée, ni un id de proposition

# CA-10 Ton choix
Étant donné une mauvaise réponse à une question d'ordre
Alors « Ton choix » montre les étapes dans l'ordre de l'élève
Et ne montre pas le bon ordre

# CA-11 Résultat
Étant donné une séance finie à 16/20
Alors le résultat dit « Félicitations ! » et la note est verte
Étant donné une séance finie à 20/20
Alors « Recommencer » n'apparaît pas

# CA-12 Note inchangée
Étant donné une séance de 5 questions dont 4 justes, de types mélangés
Alors la note est 16/20, comme avec le calcul actuel

# CA-13 Saisie par l'équipe
Étant donné un membre de l'équipe qui crée une question « Relier » de 3 paires
Alors la question est enregistrée et jouable
Et une question « Texte à trous » sans « ___ » est refusée

# CA-14 Import
Étant donné un fichier v1 d'aujourd'hui
Alors il s'importe sans changement
Étant donné un fichier avec une question « numeric » et « tolerance »: 0.1
Alors la question est créée avec sa marge

# CA-15 Page de l'exercice sur ordinateur
Étant donné un élève sur un écran de 1 280 px
Alors la présentation et « Ta progression » sont à gauche et l'aperçu des questions à droite

# CA-16 Enseignant
Étant donné un enseignant sur la page d'un exercice
Alors il voit toujours les bonnes réponses, y compris pour les nouveaux types
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Assessment::QuestionKinds::{Choice, FillBlank, Numeric, Ordering, Matching}` ; `Entities::Assessment::AnswerShuffle` (déplacé de la query) ; `Question` délègue à son type ; `AttemptInput` gagne `response_text`, `display_order` ; `QuestionInput` / `AnswerInput` gagnent `numeric_tolerance`, `match_content` ; `SubmitQuestionAttempt` reconstitue les ids. |
| Infrastructure | Migration ADR-0091 §4.1 ; `ExerciseRepository` et `ExerciseSessionRepository` lisent et écrivent les nouvelles colonnes ; `SessionPlayQuery` et `SessionResultQuery` par type, sans fuite ; les trois schémas JSON et les trois imports (`tolerance`, `match`) ; `ContentTreeWriter` (COPY) avec les nouvelles colonnes. |
| Delivery | `QuestionAttemptsController` : nouveaux paramètres ; `Teams::ExercisesController` : nouveaux attributs permis. Pas de nouvelle route. |
| UI | Shell : `content_for :focus` ; page de l'exercice, séance, résultat redessinés ; `kinds/_<type>` pour la séance, le retour et la correction ; quatre contrôleurs Stimulus ; formulaire de l'équipe `kinds/_<type>_fields` ; aide de l'import. |

## 6. Décisions rattachées

- [ADR-0091](../../decisions/adr/0091-quatre-nouveaux-types-de-questions-sur-les-tables-existantes.md) : quatre types sur les tables existantes, notation, rien de la solution dans la page.
- [UDR-0087](../../decisions/udr/0087-parcours-d-exercice-eleve-mode-concentre-et-nouveaux-types-de-questions.md) : page de l'exercice, mode concentré, confirmation pour quitter, saisie par type, résultat.
- Dépend d'[UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menus), livrée par `accueil-eleve`.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de `POST /sessions/:id/attempts` | 22 (choix unique, mesuré au Lot 0) | ≤ avant + 1 | 23 (la lettre affichée de « Ton choix ») |
| Poids JS ajouté (4 contrôleurs) | 0 | ≤ 8 Ko minifiés (budget ADR-0051) | 4,0 Ko pour 6 contrôleurs (les 4 types, `answer`, `verdict`, `teams--question-kind`) |
