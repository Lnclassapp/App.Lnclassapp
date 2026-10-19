# UDR-0102 : « Changer de classe » — la cascade à trois étapes, puis une page de confirmation qui dit ce qui change
<!-- index
titre: « Changer de classe » : cascade puis confirmation
statut: Accepté *(porteur, 2026-10-16)*
adr-lie: [0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md)
problematique: Élève à classe active : page « Changer de classe » qui reprend la cascade d'UDR-0091 (établissement actuel replié, sa classe marquée « Ta classe »), puis page « Confirmer le changement » (de → vers, ce qui suit l'élève, ce qu'il quitte) avec « Oui, changer de classe » ; le lien /c/<jeton> d'une autre classe mène à la même confirmation ; sans JS en GET puis POST
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16)* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/changement-etablissement-eleve`](../../chantiers/changement-etablissement-eleve/memo.md) |
| **ADR lié** | [ADR-0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md) |
| **Dépend de** | [UDR-0091](0091-choix-de-classe-eleve-trois-etapes-pastilles-et-cases.md) (cascade), [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (cadre de l'accueil), [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) (alertes) |
| **Remplacé par** | — |

---

## 1. Contexte

Changer de classe est un geste rare et lourd : l'élève quitte ses camarades, ses devoirs en cours et, souvent, son établissement. Il doit pouvoir **choisir** sans risque (la cascade d'UDR-0091, qu'il connaît depuis son inscription) puis **comprendre** ce qui se passe avant d'écrire quoi que ce soit (ADR-0095 §4.4). Aujourd'hui, ouvrir le lien d'une autre classe se termine par « Tu es déjà inscrit dans une classe », sans issue.

## 2. Décision

> **Deux pages. « Changer de classe » reprend la cascade d'UDR-0091, l'établissement actuel déjà choisi et replié, et ne fait qu'aller à la confirmation. « Confirmer le changement » montre la classe quittée et la classe rejointe, dit ce qui suit l'élève et ce qu'il quitte, et seul son bouton « Oui, changer de classe » change la classe. Le lien d'une autre classe mène directement à la confirmation.**

Pourquoi une page de confirmation plutôt qu'une modale : elle marche sans JavaScript (GET puis POST), elle se partage avec le lien `/c/<jeton>`, et elle laisse la place d'expliquer les conséquences au téléphone.

## 3. Règles d'implémentation

### 3.1 Page « Changer de classe » (`classroom/student_classroom_changes/new`)

- **Accès** : élève à classe active. Un élève sans classe active est redirigé vers « Choisis ta classe » (`new_student_classroom_choice_path`).
- **Cadre et largeur** : ceux de « Choisis ta classe » (UDR-0091 §3.3) : en-tête et menus d'UDR-0084, formulaire de 640 px au plus, `grid-cols-1`.
- **En-tête** : `ui_page_header` avec le titre « Changer de classe » et un lien retour « Profil » (`profile_path`).
- **Rappel** sous le titre, `text-sm text-mute` : « Tu es en %{classe} · %{établissement}. »
- **Cascade** : `render "classroom/student_registrations/class_picker", scope: :student_classroom_change, framed: true` avec :
  - étape 1 repliée sur l'établissement **actuel**, bouton « Changer » (UDR-0091 §3.1) : changer d'établissement passe par ce bouton ;
  - étape 3 : la case de la classe actuelle est `disabled`, avec le badge « Ta classe » (`ui_badge tone: :neutral, size: :sm`), à la place du badge « Complète ».
- **Formulaire** : `method: :get`, `url: confirm_student_classroom_change_path`. Rien n'est écrit.
- **Bouton** : « Continuer » (`brand`, `lg`, pleine largeur, `icon_end: "arrow-right"`), désactivé par `classroom--class-picker` tant qu'aucune case n'est cochée ; jamais désactivé sans JS.
- **Alertes en tête** (bloc `role="alert"` d'UDR-0081 §3.5) : un refus renvoyé par la confirmation ou l'envoi (classe complète, retiré de cette classe, même classe).

### 3.2 Page « Confirmer le changement » (`classroom/student_classroom_changes/confirm`)

- **Entrées** : soit les champs de la cascade (`school_public_id`, `level_slug`, `classroom_public_id`), soit `link_token`. La page **relit** la classe d'arrivée côté serveur ; une classe invalide renvoie à `new` avec l'erreur (422), un lien mort à `new` avec l'alerte « lien plus valable » d'UDR-0081 §3.4.
- **Titre** : « Changer de classe ? ».
- **Bloc « de → vers »** : une `ui_card` blanche avec deux lignes, séparées par une icône `arrow-down` centrée (`text-mute`, `aria-hidden`) :
  - « Tu quittes » : nom de la classe actuelle (`font-display font-bold`), puis « %{niveau} · %{établissement} » (`text-sm text-mute`) ;
  - « Tu rejoins » : même forme, sur fond `bg-brand-soft`, nom en `text-brand-strong`.
  - Établissement différent : un badge « Autre établissement » (`ui_badge tone: :brand, size: :sm`) sur la ligne « Tu rejoins ».
- **Ce qui suit l'élève** : une liste de trois lignes avec l'icône `check-circle` (`text-success`) :
  - « Ton historique et tes résultats te suivent. »
  - « Tes exercices à revoir te suivent. »
  - « Ton compte, ton numéro et ton code secret ne changent pas. »
- **Ce qu'il quitte** : une liste de deux lignes avec l'icône `information-circle` (`text-mute`) :
  - « Tu ne verras plus les devoirs ni les annonces de %{classe_actuelle}. »
  - « Ton enseignant de %{classe_actuelle} ne te verra plus dans sa classe. »
- **Actions** :
  - `button_to` « Oui, changer de classe » (`brand`, `lg`, pleine largeur au téléphone), `POST student_classroom_change_path`, avec les champs reçus en `hidden` (cascade ou `link_token`) ;
  - lien « Annuler » (`ghost`) vers `new_student_classroom_change_path` (cascade) ou `student_home_path` (lien).
- **Succès** : redirection `303` vers `student_home_path`, toast « Bienvenue en %{classe} ! » (même forme que « Choisis ta classe »).
- **Refus à l'envoi** (classe devenue complète, archivée, lien changé entre-temps) : rendu de `new` en 403/422 avec la raison en tête, la cascade sur l'établissement visé.

### 3.3 Lien `/c/<jeton>` d'un élève à classe active

- `Classroom::JoinsController#new` ne renvoie plus l'élève à classe active vers l'accueil : il le redirige (`303`) vers `confirm_student_classroom_change_path(link_token:)`.
- Lien de **sa propre** classe : redirection vers `student_home_path`, comme aujourd'hui.
- Lien mort ou classe archivée : comportements actuels (UDR-0081 §3.4, ADR-0088).
- Confirmation venue d'un lien : la ligne « Tu rejoins » porte la mention « par le lien de la classe » (`text-xs text-mute`).

### 3.4 Tokens

- Couleurs : `ink`, `mute`, `brand`, `brand-strong`, `brand-soft`, `success`, `error-soft`, `warning-soft`, `line` ; aucune valeur en dur.
- Rayons et ombres : `rounded-card`, `shadow-card` des cartes existantes ; `rounded-ln` pour les alertes.
- Typographie : `font-display` pour les noms de classe, `text-sm` pour les détails.

### 3.5 Comportement

- Pas de Turbo Frame propre : les cadres `picker_schools`, `picker_levels`, `picker_classrooms` d'UDR-0091 sont réutilisés tels quels.
- Contrôleur Stimulus : `classroom--class-picker`, sans nouvelle action ; il sait déjà désactiver une case.
- Sans JavaScript : la cascade fonctionne par les boutons « Continuer » de chaque étape (UDR-0091 §3.2) ; la confirmation est une page GET, l'envoi un POST.

### 3.6 États obligatoires

- « Changer de classe » : établissement actuel replié ; après « Changer » (listes DRENA et établissement) ; niveau choisi sans classe disponible ; classe actuelle marquée ; erreur de chargement d'une étape (« Réessayer ») ; refus en tête.
- « Confirmer le changement » : même établissement ; autre établissement ; venue d'un lien ; refus à l'envoi.
- Succès : accueil de la nouvelle classe avec le toast.
- Thème sombre ; 390 px et 1 280 px.

### 3.7 Accessibilité

- Cibles ≥ 48 × 48 px ; focus visible `outline-brand`.
- La case de la classe actuelle est `disabled` et son nom accessible inclut « Ta classe ».
- Le bloc « de → vers » est une liste `<dl>` : `<dt>` « Tu quittes », « Tu rejoins » ; la flèche est `aria-hidden`.
- Après un refus, le focus va à l'alerte (`data-autofocus-target`, comme « Choisis ta classe »).
- Le bouton de confirmation dit l'action entière : « Oui, changer de classe ».

## 4. Conséquences

- Le partial `_class_picker` gagne un local `current_classroom_public_id:` (défaut `nil`) pour marquer la classe actuelle ; l'inscription et « Choisis ta classe » ne le passent pas et ne changent pas. Les classes étant chargées par le cadre public `picker_classrooms` (`school/level_classrooms#index`), le partial ajoute `current=<public_id>` à l'URL du cadre ; la lecture publique s'en sert seulement pour désactiver la case et n'en révèle rien de plus. Le refus `same_classroom` du use case reste la garde.
- `JoinsController#new` change de comportement pour l'élève à classe active : `test/system/classroom/join_test.rb` est à relire.
- Interdit désormais : changer la classe d'un élève sans passer par la page de confirmation.
