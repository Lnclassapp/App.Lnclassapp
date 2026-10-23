# UDR-XXXX : Inscription élève en trois étapes — code de classe d'abord, passage automatique, lien qui saute l'étape 1
<!-- index
titre: Inscription élève en trois étapes avec code de classe
statut: Proposé
adr-lie: XXXX-code-de-classe-a-six-caracteres
problematique: L'inscription élève tient sur une page longue en trois rubriques et ne connaît que la cascade DRENA → classe et le lien ; l'élève dont le prof écrit un code au tableau n'a pas de voie directe. Elle devient trois écrans courts, ouverts par le code de classe, qui avancent seuls.
-->

| | |
|---|---|
| **Statut** | Proposé (choix du porteur le 2026-10-23, écran par écran) |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | ADR-XXXX-code-de-classe-a-six-caracteres (le code revient en base) |
| **Amende** | [UDR-0088](0088-connexion-et-inscription-eleve-carte-bleue-et-rubriques-numerotees.md) (une page, rubriques numérotées) · [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) (cascade, lien de classe) · [UDR-0091](0091-choix-de-classe-eleve-trois-etapes-pastilles-et-cases.md) (choix de classe) |
| **S'appuie sur** | UDR-XXXX-palette-froide-et-texte-sans-gras (jetons) |
| **Remplacé par** | — |

---

## 1. Contexte

Le pilote du 27 octobre passe par les contacts du porteur : un enseignant écrit un code au tableau ou partage un lien sur WhatsApp. Aujourd'hui l'élève sans lien doit traverser quatre listes (DRENA, établissement, niveau, classe) sur une page longue qui demande aussi ses informations et son code secret. Sur un petit téléphone, il fait défiler sans savoir où il en est.

## 2. Décision

1. **Trois écrans à la suite : 1. Ta classe → 2. Toi → 3. Ton code secret**, avec « Étape N sur 3 » et une barre en trois segments.
2. **Le code de classe ouvre l'étape 1.** La case « Je n'ai pas de code » déplie la cascade actuelle, qui reste la voie de secours.
3. **Le lien de classe saute l'étape 1** : l'élève arrive à l'étape 2 avec sa classe chargée.
4. **Passage automatique aux étapes 1 et 2, sans bouton « Continuer »** (choix du porteur, contre la recommandation de garder « Continuer » à l'étape 2). La création du compte reste un geste volontaire : bouton « Créer mon compte » à l'étape 3.
5. **Un seul formulaire découpé dans le navigateur**, sans nouvelle route : on avance et on recule sans rien perdre, l'envoi se fait à l'étape 3. C'est ce qui rend ce découpage tenable avant le 27.

## 3. Règles d'implémentation

### 3.1 Structure

- Vue : `classroom/student_registrations/new.html.erb` et `_form.html.erb` (formulaire unique), `classroom/joins/new.html.erb` (même formulaire, classe chargée). Le formulaire contient trois `fieldset` `data-signup-steps-target="step"`, un seul visible à la fois.
- Contrôleur Stimulus nouveau : `classroom/signup_steps_controller.js`.
  - `data-signup-steps-start-value` : `1` (inscription), `2` (lien de classe valide).
  - Actions : `next`, `back`, `goTo(step)`. Il met à jour « Étape N sur 3 », la barre et le titre, remet le focus sur le titre de l'étape, et annonce le changement dans une région `aria-live="polite"`.
  - Sans JavaScript, les trois `fieldset` restent visibles l'un sous l'autre (page actuelle) : le formulaire marche toujours.
- Haut de chaque écran : logo Lnclass à gauche, lien « Besoin d'aide ? » (`text-brand-strong`) à droite, puis la rangée « ‹ Retour » (étapes 2 et 3, sauf arrivée par lien) et « Étape N sur 3 » à droite, puis la barre.
- **Carte « Bienvenue sur Lnclass »** (`bg-brand-strong`, texte blanc, 5,29:1) et titre « Créer ton compte élève » : seulement sur le premier écran que voit l'élève, l'étape 1, ou l'étape 2 quand il arrive par le lien. « Déjà un compte ? Se connecter » : même règle.

### 3.2 Étape 1 — Ta classe

- Titre « Ta classe » (16 px, graisse 500) ; sous le titre, 13 px `text-mute` : « Tu passes à la suite dès que ta classe est trouvée. »
- Champ « Code de ta classe » : 6 caractères, majuscules automatiques, police mono, aide « 6 caractères, donnés par ton enseignant. », `autocomplete="off"`, `inputmode="text"`, `autocapitalize="characters"`.
- Au 6ᵉ caractère : vérification serveur (route de vérification à débit limité, ADR du code). Pendant l'appel, l'indication « Vérification… » sous le champ.
  - **Code reconnu** : on passe à l'étape 2 (voir §3.3, rappel de classe).
  - **Code inconnu** : on reste, message sous le champ « Ce code ne correspond à aucune classe. Vérifie-le avec ton enseignant. » (`aria-describedby`, `aria-invalid="true"`).
  - **Trop d'essais** : « Trop d'essais. Attends une minute, ou coche « Je n'ai pas de code ». »
- Case « Je n'ai pas de code » : déplie la cascade actuelle (`class_picker_controller`, frames `picker_classrooms`), le champ code se masque. Toucher une classe disponible passe à l'étape 2. Une classe complète reste désactivée.

### 3.3 Étape 2 — Toi

- Titre « Toi » ; sous le titre : « Tu passes à la suite dès que tout est rempli. »
- Si la classe vient du code ou du lien : carte de rappel en tête, « TA CLASSE » (12 px) · « 3e B » · « Collège Moderne 1 de Tiassalé », et le lien « Ce n'est pas ta classe ? › » qui ramène à l'étape 1 (code vidé, case décochée).
- Champs inchangés : Nom, Prénom(s), Genre (deux boutons), Numéro de téléphone (10 chiffres, `phone_digits_controller`).
- **Passage automatique** quand les quatre champs sont valides côté navigateur, **environ 1 s après la dernière frappe** (anti-rebond), jamais au milieu d'une saisie. Le clavier se ferme ; le focus va sur le titre de l'étape 3.
- Arrivée par le lien : pas de « ‹ Retour » (aucune étape 1 derrière) ; carte de bienvenue et « Déjà un compte ? ».

### 3.4 Étape 3 — Ton code secret

- Titre « Ton code secret » ; champs Code secret (4 chiffres, œil) et Confirmation (`pin_match_controller`), puis `ui_button variant: :primary` « Créer mon compte », pleine largeur, 44 px.
- « ‹ Retour » rend l'étape 2 avec ses champs intacts.

### 3.5 Erreurs renvoyées par le serveur

Le serveur renvoie la page en 422 comme aujourd'hui (`render_form`). Le contrôleur Stimulus ouvre **la première étape qui contient un champ en erreur** (classe → 1, nom/genre/numéro → 2, code secret → 3). Le refus général (`#student-registration-refusal`) s'affiche en haut de l'étape ouverte. 429 : message « Trop d'essais » à l'étape 1. Lien de classe invalide, archivé ou régénéré : la page s'ouvre à l'étape 1, jamais sur une erreur.

### 3.6 Jetons

Uniquement les jetons de l'UDR-XXXX-palette-froide-et-texte-sans-gras ; bordures de champ `line-strong`, focus `brand-strong`. Graisse 500 au plus. Minimum 12 px.

### 3.7 États obligatoires

- **Vide** : étape 1, champ code vide.
- **Chargement** : « Vérification… » sous le champ code ; bouton « Créer mon compte » désactivé avec « Création… » après l'envoi.
- **Erreur** : code inconnu, trop d'essais, erreurs de champ rouvrant leur étape (§3.5).
- **Succès** : compte créé, redirection vers l'accueil (comportement actuel).

### 3.8 Accessibilité

- Chaque étape est un `fieldset` avec `legend` (le titre). L'étape cachée porte `hidden`, pas seulement une classe.
- Le passage automatique est **annoncé avant** (phrase sous le titre) et **après** (région `aria-live`) ; il ne déplace jamais le focus pendant une frappe. Le retour arrière ne perd aucune saisie.
- Cibles ≥ 44 px (« ‹ Retour », case à cocher, tuiles de classe). Contrastes de l'UDR palette.

## 4. Conséquences

- Le code de classe à 6 caractères revient : colonne, génération, affichage côté enseignant et vérification à débit limité font l'objet de l'ADR-XXXX-code-de-classe-a-six-caracteres et d'une revue de sécurité (vérification énumérable, ID-07).
- La même vérification de code sert à l'état « Choisis ta classe » de l'accueil élève (élève connecté sans classe).
- Interdit : un bouton « Continuer » aux étapes 1 et 2, une création de compte sans geste de l'élève, une route par étape.
