# UDR-0179 : Accueil de l'élève — QR de l'établissement, fenêtre « Ton premier exercice », tuile « Inviter »
<!-- index
titre: Accueil élève : QR de l'établissement, fenêtre du premier exercice, tuile « Inviter »
statut: Accepté
adr-lie: [0145](../adr/0145-adresse-publique-etablissement.md)
problematique: la carte du premier exercice pousse la classe hors de l'accueil, le sigle ne sert à rien, et inviter un camarade est au bas de l'écran
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-21 |
| **Chantier** | `docs/chantiers/entree-et-accueil-eleve-allegees` |
| **ADR lié** | ADR-0145 |
| **Amende** | UDR-0173 §3 (carte de classe, grille) · UDR-0174 §2.1, §2.3 et §3 « Structure » (la carte devient une fenêtre) · UDR-0178 §3.3 (la bannière devient une tuile) · UDR-0078 (l'invitation à installer attend) |
| **Remplacé par** | — |

---

## 1. Contexte

Porteur, 2026-11-21, et précision de l'orchestrateur le même jour. L'accueil doit dire une chose : la classe. La carte « Ton premier exercice » (UDR-0174) la repousse ; le sigle de l'établissement n'aide personne, alors qu'un QR permettrait au camarade assis à côté de s'inscrire ; l'invitation de la classe est une bannière en bas de page.

## 2. Décision

1. **QR** : le sigle de la carte de classe devient le QR de l'adresse publique de l'établissement de la classe principale (ADR-XXXX).
2. **Fenêtre** : « Ton premier exercice » quitte l'accueil et devient une fenêtre, ouverte **sur chaque écran de l'élève** (accueil compris, juste après l'inscription) **tant qu'il n'a rendu aucune copie**. Fermée, elle revient au chargement de l'écran suivant — une fois par écran chargé, sans boucle. Jamais sur un écran d'exercice (mode concentré). Elle disparaît pour de bon dès la première copie rendue (quelle que soit la note).
3. **Tuile « Inviter »** : un bloc « Invite tes camarades », sous « Mes matières », au format de ses tuiles (rond teinté 64 px, icône, libellé court « Inviter ») ; il envoie au partage de classe (POST `class_invite_path`, WhatsApp, #667). Il remplace la bannière `_invite_classmates` (une porte par action).

Pourquoi une fenêtre différée plutôt que rendue dans la page : elle doit vivre sur tous les écrans ; la calculer dans chaque page coûterait la requête de l'accueil partout. Un cadre Turbo différé ne coûte qu'aux élèves concernés, et rien du tout après la première copie (drapeau de session).

## 3. Règles d'implémentation

### 3.1 Carte de classe — `classroom/student_homes/_class_card`

- Le `span#student_school_sigle` est remplacé par `div#student_school_qr` : `size-24 shrink-0 rounded-ln bg-white p-1 ring-1 ring-line`, `role="img"`, `aria-label` `classroom.student_homes.class_card.qr_label` « QR code de %{school} : à scanner pour s'inscrire ». Contenu : le SVG de `school_signup_qr_svg(home.school_public_id)` (helper à côté de `Classroom::JoinQrHelper`, même réglages RQRCode : niveau `:m`, `viewbox: true`, `use_path: true`, noir sur blanc), en `aria-hidden`, sa taille donnée par le conteneur (classe utilitaire existante du projet pour qu'un SVG remplisse son parent, celle de l'affiche si elle existe, sinon `size-full` sur un conteneur `*:size-full`).
- L'URL encodée est `school_signup_link_url(school_public_id)` : absolue, sans autre paramètre.
- Le SVG est mis en cache par identifiant public (`Rails.cache.fetch(["school_signup_qr", public_id])`).
- La requête de l'accueil rend `school_public_id` dans sa ligne ; `school_sigle` n'est plus lu par la carte.

### 3.2 Fenêtre — cadre dans `layouts/shell`, page `classroom/student_first_exercises#show`

**Où** : dans `layouts/shell`, juste après `</main>`, si `first_exercise_prompt?` (helper de contrôleur) : rôle `student`, pas `focus`, et la session ne porte pas `:first_exercise_done`. Alors :
`turbo_frame_tag "student_first_exercise_prompt", src: student_first_exercise_path, loading: :eager, data: { turbo_permanent: false }`.
Jamais non plus sur la page d'un exercice (`assessment/exercises#show`), ni sur la copie : ces contrôleurs rendent `first_exercise_prompt?` faux.

**La page** (`GET /students/first-exercise`, `allow_roles :student`, Turbo Frame seul, `layout false` ou partial) :
- L'élève a rendu au moins une copie (`status: completed`) → pose `session[:first_exercise_done] = true` et rend le cadre **vide**.
- Sinon, le premier exercice d'UDR-0174 §2.2 (`Queries::Classroom::ActivationQuery#call`, avec la ligne de l'accueil) ; aucun → cadre vide (pas de drapeau : un exercice peut venir).
- Sinon, le cadre contient `ui_modal title: t("catalog.courses.next_exercise.first"), id: "student_first_exercise_modal", open: true, size: :sm, placement: :center` (feuille du bas sous `sm` si le composant le fait déjà) avec :
  - le titre de l'exercice (`h3`, `font-display text-base font-medium text-ink`) et le détail `text-sm text-mute` (« matière · leçon » ou « matière · Donné par ta classe ») comme la carte d'UDR-0174 ;
  - le bouton `classroom/student_homes/next_step/_start` (« Commencer l'exercice » ou « Reprendre à la question N »), pleine largeur, `#student_first_exercise_start`, `data-turbo-frame="_top"` ;
  - « Plus tard » (`ui_button variant: :ghost`, ferme la fenêtre, `#student_first_exercise_later`) ; la croix du composant et Échap ferment aussi.
- La fermeture n'écrit rien côté serveur : le prochain écran chargé redemande le cadre.

**Accueil** (`classroom/student_homes/show`) : le bloc `@first_exercise` et sa carte sont retirés ; « À faire » reçoit tous les devoirs (plus d'exclusion du premier exercice) ; l'historique montre toutes les copies (plus d'exclusion de la copie de la carte). `StudentHomesController` ne lit plus `ActivationQuery`.

**Invitation à installer** (`shared/navigation/_install_banner`, accueil) : rendue seulement si `first_exercise_prompt?` est faux — les deux fenêtres ne s'empilent jamais.

### 3.3 Tuile « Inviter » — `classroom/student_homes/_invite_tile`

- Rendue dans `show`, juste après `_subjects`, dans le même bloc blanc, branche « avec classe » seulement.
- `section#student_invite_classmates aria-labelledby="student_invite_classmates_title"` ; titre `h2#student_invite_classmates_title` au style de « Mes matières » (`px-1 pb-3 text-sm font-semibold text-mute`) : « Invite tes camarades ».
- Une grille `grid grid-cols-4 lg:grid-cols-8` à une tuile : `button_to class_invite_path, method: :post, form: { target: "_blank", data: { turbo: false } }`, classe de tuile identique à `_subjects`, `aria-label` `invite_tile.action_label` « Inviter tes camarades de %{classroom} sur WhatsApp » ; rond `size-16 rounded-full bg-brand-soft text-brand-strong` avec `ui_icon "user-plus"` ; libellé « Inviter ».
- `_invite_classmates.html.erb` et son rendu en bas de page sont supprimés (clés I18n mortes retirées) ; la bannière de l'enseignant (`_invite_banner`) reste.

### États obligatoires

- Vide : pas de classe → ni QR ni tuile ; rien à proposer, copie rendue, hors ligne → cadre de fenêtre vide.
- Chargement : le cadre de fenêtre est invisible tant qu'il charge (aucun indicateur).
- Erreur : réponse en échec ou cadre manquant → rien n'est affiché (`turbo:frame-missing` empêché, le cadre reste vide).
- Succès : fenêtre ouverte, focus sur « Commencer l'exercice ».

### Accessibilité

- Fenêtre : `<dialog>` modale du composant (piège du focus, Échap, titre lié) ; « Plus tard » ≥ 48 px.
- QR : `role="img"` + `aria-label` ; tuile « Inviter » nommée par son `aria-label`.
- Tokens seulement ; graisse ≤ 500 hors classes déjà en place ; textes en `t(".clé")`.

## 4. Conséquences

- UDR-0174 : la carte « Ton premier exercice » n'existe plus sur l'accueil ; la règle de choix de l'exercice (§2.2) reste ; le critère d'apparition devient « aucune copie rendue ».
- La skill `ecrans-wave` (§ Hors périmètre) est mise à jour en conséquence.
- Interdit : ouvrir la fenêtre pendant un exercice, ou la rouvrir sur le même écran chargé.
