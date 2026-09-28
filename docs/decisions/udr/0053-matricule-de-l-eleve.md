# UDR-0053 : Le matricule de l'élève — un champ de plus à l'inscription, une ligne au profil que l'élève corrige lui-même sous son PIN

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-28, avec ses retours)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-48 à ED-55, ED-65 |
| **ADR lié** | [ADR-0065](../adr/0065-matricule-de-l-eleve.md) (matricule) · [ADR-0066](../adr/0066-espace-direction-droits-et-gestes.md) (second facteur de la direction) · [UDR-0005](0005-design-system-fondateur.md) |
| **Amende** | [UDR-0009](0009-rejoindre-une-classe.md) (inscription élève) · [UDR-0041](0041-page-profil.md) (profil) · [UDR-0020](0020-debloquer-un-compte.md) (débloquer un compte : second facteur de la direction) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève doit désormais donner son **matricule** en s'inscrivant (ADR-0065) : c'est par lui que la direction de son établissement le retrouvera. Il le saisit sur un téléphone, souvent sans l'avoir sous les yeux, au milieu d'une classe qui s'inscrit en même temps : il se trompera de caractère, tapera des espaces, une minuscule. S'il se trompe, ou si quelqu'un a déjà pris son matricule, il doit savoir **quoi faire** sans apprendre à qui le matricule appartient.

À la relecture de la phase Décider (2026-09-28), le porteur a décidé que **seul l'élève corrige son matricule** : depuis son profil, sous son PIN actuel, comme il change déjà son PIN (UDR-0041, ADR-0055). L'équipe ne cherche plus un compte par matricule et ne le corrige plus. Elle réinitialise, en revanche, le second facteur d'un membre de la direction qui a perdu son téléphone (ADR-0066).

## 2. Décision

1. **Un champ « Matricule »** dans la rubrique « Ton identité » de l'inscription, après le nom et les prénoms : saisie libre (espaces, tirets, minuscules acceptés), normalisée par le serveur.
2. **Trois messages seulement** : vide, format, déjà utilisé. « Déjà utilisé » ne dit jamais à qui et dit quoi faire (contacter l'équipe).
3. **Au profil, l'élève lit son matricule et le corrige lui-même** : une ligne avec « Corriger », une modale au gabarit de « Changer mon PIN » (PIN actuel, nouveau matricule), les mêmes trois messages qu'à l'inscription.
4. **« Débloquer un compte » ne change pas pour les élèves** : la recherche reste par numéro, la carte d'un élève n'affiche pas son matricule. Seule la carte d'un membre de la direction change : l'état de son second facteur et « Réinitialiser le second facteur », comme pour l'équipe.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Inscription — `classroom/joins/_signup_form` (amende l'UDR-0009)

**Structure**
- Dans la `<fieldset>` « Ton identité », après « Prénom(s) » et avant « Genre » : `ui_field :student_number`, libellé « Matricule », `required: true`, `maxlength` 16, `autocomplete="off"`, `autocapitalize="characters"`, `spellcheck=false`, `inputmode="text"`, `placeholder` « 12345678A », classes `font-mono tracking-wider uppercase`, aide « Ton matricule scolaire : 8 chiffres et une lettre. Tu le trouves sur ta carte scolaire ou ton bulletin. ».
- La valeur re-rendue après une erreur est la **saisie brute**.

**Tokens** : `ui_field` et tokens `@theme` seulement.

**Comportement**
- `POST /c/<code>` : le DTO normalise (`Entities::Identity::StudentNumber.normalize`) puis valide. Limite de débit inchangée (10 par minute et par adresse, UDR-0009).
- Échec : 422 re-rendu par Turbo, saisies gardées sauf les PIN (UDR-0009).

**États obligatoires**
- Vide : le champ, son aide.
- Chargement : sans objet (Turbo pose `aria-busy` sur le formulaire).
- Erreur, sous le champ : vide « Saisis ton matricule. » ; format « Le matricule compte 8 chiffres et une lettre, par exemple 12345678A. » ; pris « Ce matricule est déjà utilisé. Vérifie-le ; s'il est bien le tien, demande à ton professeur de contacter l'équipe Lnclass. » (le même au profil, §3.2).
- Succès : inchangé (toast « Bienvenue dans ta classe ! » sur l'accueil).

**Accessibilité** : libellé visible, aide et erreur reliées par `aria-describedby`, `aria-invalid` (via `ui_field`) ; cible ≥ 48 px ; parcours prouvé à 390 px.

### 3.2 Profil de l'élève — `identity/profiles/_information` et modale « Corriger mon matricule » (amende l'UDR-0041)

**Structure**
- Pour un élève, une ligne de la `dl`, après « Numéro » : `dt` « Matricule », `dd#profile_student_number` en `font-mono tracking-wider`, et le bouton « Corriger » (`secondary`, `sm`, icône `pencil-square`, `href: edit_profile_student_number_path`, `data-turbo-frame="modal"`, `aria-label` « Corriger mon matricule »), au gabarit des boutons « Modifier » de la carte (UDR-0041). Ligne et bouton : Lot 0b ; la route répond dès le Lot 0b, son contrôleur arrive au Lot F.
- Modale `identity/profile_student_numbers/edit` (`ui_modal` dans `turbo_frame_tag "modal"`, taille `sm`, titre « Corriger mon matricule ») : `form#profile-student-number-form` (`PATCH profile_student_number_path`, scope `student_number_change`) : « PIN actuel » (mêmes attributs que la modale « Changer mon PIN » : `inputmode="numeric"`, `autocomplete="current-password"`, 4 chiffres, `reveal: true`), puis `ui_field :student_number` aux attributs du §3.1, valeur actuelle pré-remplie, aide « Ton matricule complet : 8 chiffres et une lettre. ». Pied : « Annuler », « Enregistrer ».
- Élève sans matricule (compte anonymisé : il ne se connecte plus) : sans objet.

**Routes** (Lot 0b, `config/routes/identity.rb`, dans `resource :profile`) : `resource :student_number, only: %i[edit update], controller: :profile_student_numbers` → `GET /profile/student_number/edit` (`edit_profile_student_number_path`) et `PATCH /profile/student_number` (`profile_student_number_path`). Aucun identifiant : toujours le compte de la session (ADR-0055).

**Comportement**
- `PATCH` → `Identity::ChangeOwnStudentNumber` (ADR-0065), dans cet ordre, comme `ChangeOwnPin` : le formulaire (vide, format) est vérifié d'abord, sans coûter d'essai de PIN ; puis le PIN actuel (un PIN faux compte comme un échec de connexion) ; puis « inchangé » et l'unicité : « déjà utilisé » n'est dit qu'une fois le PIN reconnu.
- Succès : `update.turbo_stream.erb` remplace `#profile_information`, ferme la modale, toast `success` « Ton matricule est enregistré. » ; repli HTML : 303 vers `profile_path` avec `notice`. La session n'est pas renouvelée (le matricule n'est pas un secret).
- Échec : 422, modale re-rendue, PIN vidé, matricule gardé : « PIN incorrect. » en alerte `role="alert"` (UDR-0041) ; sous le champ : vide, format ou pris (messages du §3.1) ; inchangé « C'est déjà ton matricule. ». Compte verrouillé : message de verrouillage de la connexion (ADR-0050).
- **Débit** : 10 tentatives par heure et par compte ; au-delà, 429 et, dans la modale, « Trop de tentatives. Réessaie dans une heure. » sans formulaire.
- Un compte qui n'est pas élève : la ligne et le bouton n'existent pas ; la route forcée → 403.

**États obligatoires**
- Vide : sans objet (un élève a toujours un matricule).
- Chargement : bouton de soumission en `loading` (`aria-busy`).
- Erreur : alerte (PIN), sous le champ (matricule), message 429 dans la modale.
- Succès : toast, carte « Mes informations » remplacée avec le nouveau matricule.

**Accessibilité** : libellés visibles ; erreurs reliées par `aria-describedby`, `aria-invalid` ; modale `<dialog>` native (focus piégé, Échap) ; cibles ≥ 48 px ; 390 px.

### 3.3 Débloquer un compte — `teams/account_lookups/_result` (amende l'UDR-0020)

- La recherche **ne change pas** : un numéro complet, paramètre `contact` (UDR-0020). Aucune recherche par matricule, aucun matricule sur la carte d'un élève, aucune action sur le matricule.
- `_result` pour un **membre de la direction** (`school_admin`) : la `dl` affiche « Fonction · Établissement » (ou « Aucun établissement ») et l'état du second facteur (`ui_badge` « Activé » `success`, « Non activé » `warning`), comme pour l'équipe ; l'action « Réinitialiser le second facteur » et sa confirmation `reset-second-factor-modal` sont celles de l'UDR-0020.
- Comportement, états, accessibilité : ceux de l'UDR-0020, inchangés.

## 4. Conséquences

- L'inscription d'un élève demande un champ de plus ; la page reste en trois rubriques (UDR-0009).
- **Personne d'autre que l'élève ne corrige un matricule** : ni l'équipe, ni la direction, ni l'enseignant. Un matricule usurpé se libère par l'anonymisation du compte usurpateur (`annuaire-equipe`), dont la recherche de comptes retrouve un élève par son matricule entier (PRD §8).
- « Débloquer un compte » garde son paramètre `contact` et sa recherche par numéro.
- Interdit : afficher à l'élève à qui appartient un matricule pris ; une recherche partielle par matricule ; un écran de modification du matricule hors du profil de l'élève.
