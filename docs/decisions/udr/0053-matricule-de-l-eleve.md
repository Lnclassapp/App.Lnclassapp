# UDR-0053 : Le matricule de l'élève — un champ de plus à l'inscription, une ligne en lecture seule au profil, une recherche et une correction par l'équipe

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction`](../../chantiers/espace-direction/prd.md) — critères ED-48 à ED-55 |
| **ADR lié** | [ADR-0065](../adr/0065-matricule-de-l-eleve.md) (matricule) · [ADR-0066](../adr/0066-espace-direction-droits-et-gestes.md) (second facteur de la direction) · [UDR-0005](0005-design-system-fondateur.md) |
| **Amende** | [UDR-0009](0009-rejoindre-une-classe.md) (inscription élève) · [UDR-0041](0041-page-profil.md) (profil) · [UDR-0020](0020-debloquer-un-compte.md) (débloquer un compte) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève doit désormais donner son **matricule** en s'inscrivant (ADR-0065) : c'est par lui que la direction de son établissement le retrouvera. Il le saisit sur un téléphone, souvent sans l'avoir sous les yeux, au milieu d'une classe qui s'inscrit en même temps : il se trompera de caractère, tapera des espaces, une minuscule. S'il se trompe, ou si quelqu'un a déjà pris son matricule, il doit savoir **quoi faire** sans apprendre à qui le matricule appartient.

L'équipe, elle, doit retrouver un compte par son matricule quand un élève appelle (« mon matricule est déjà pris ») et le corriger. Elle réinitialise aussi, désormais, le second facteur d'un membre de la direction qui a perdu son téléphone (ADR-0066).

## 2. Décision

1. **Un champ « Matricule »** dans la rubrique « Ton identité » de l'inscription, après le nom et les prénoms : saisie libre (espaces, tirets, minuscules acceptés), normalisée par le serveur.
2. **Trois messages seulement** : vide, format, déjà utilisé. « Déjà utilisé » ne dit jamais à qui et dit quoi faire (contacter l'équipe).
3. **Au profil, le matricule se lit, il ne se modifie pas** : une ligne sans bouton, avec l'indication de qui peut le corriger.
4. **« Débloquer un compte » cherche par numéro ou par matricule**, dans le même champ ; la carte d'un élève affiche son matricule et offre « Corriger le matricule » en modale ; la carte d'un membre de la direction affiche l'état de son second facteur et offre « Réinitialiser le second facteur », comme pour l'équipe.

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
- Erreur, sous le champ : vide « Saisis ton matricule. » ; format « Le matricule compte 8 chiffres et une lettre, par exemple 12345678A. » ; pris « Ce matricule est déjà utilisé. Vérifie-le ; s'il est bien le tien, demande à ton professeur de contacter l'équipe Lnclass. ».
- Succès : inchangé (toast « Bienvenue dans ta classe ! » sur l'accueil).

**Accessibilité** : libellé visible, aide et erreur reliées par `aria-describedby`, `aria-invalid` (via `ui_field`) ; cible ≥ 48 px ; parcours prouvé à 390 px.

### 3.2 Profil de l'élève — `identity/profiles/_information` (amende l'UDR-0041)

- Pour un élève, une ligne de la `dl`, après « Numéro » : `dt` « Matricule », `dd#profile_student_number` en `font-mono tracking-wider`, et sous la valeur `p.text-sm.text-mute` « Pour le corriger, demande à ton professeur de contacter l'équipe Lnclass. ». **Aucun bouton**, aucun lien d'édition.
- Élève sans matricule (compte anonymisé : il ne se connecte plus) : sans objet.

### 3.3 Débloquer un compte — `teams/account_lookups` (amende l'UDR-0020)

**Structure**
- `form#account-lookup-form` : le champ devient `input[type=text][name=q]`, libellé « Numéro ou matricule », aide « Un numéro complet (10 chiffres) ou un matricule complet (8 chiffres et une lettre). », `autocomplete="off"`. Le paramètre `contact` reste lu s'il est seul (liens déjà partagés).
- États vides : « Saisissez un numéro ou un matricule » ; « Aucun compte pour « <saisie> » ».
- `_result` pour un **élève** : la `dl` gagne « Matricule » (`font-mono`) ; les actions gagnent `ui_button` « Corriger le matricule » (`secondary`, icône `pencil-square`, `href: edit_teams_account_student_number_path(public_id)`, `data: { turbo_frame: "modal" }`).
- `_result` pour un **membre de la direction** (`school_admin`) : la `dl` affiche « Fonction · Établissement » et l'état du second facteur (`ui_badge` « Activé » `success`, « Non activé » `warning`), comme pour l'équipe ; l'action « Réinitialiser le second facteur » et sa confirmation `reset-second-factor-modal` sont celles de l'UDR-0020.
- Modale `teams/student_numbers/edit` : `turbo_frame_tag "modal" { ui_modal(title: "Corriger le matricule de <nom>", open: true) }` : `form#student-number-form` (`PATCH teams_account_student_number_path(public_id)`, scope `student_number`) : `ui_field :student_number` (valeur actuelle, mêmes attributs que 3.1, aide « Le matricule complet. L'ancien cessera de désigner ce compte. »). Pied : « Annuler », « Enregistrer ».

**Routes** (Lot 0b) : dans `namespace :teams`, `resources :accounts, only: [], param: :user_public_id do resource :student_number, only: %i[edit update], path: "student-number", controller: "student_numbers" end`, soit `GET /teams/accounts/:account_user_public_id/student-number/edit` → `edit_teams_account_student_number_path(public_id)` et `PATCH …/student-number` → `teams_account_student_number_path(public_id)` (noms vérifiés par le test de routage du Lot 0b).

**Comportement**
- Recherche : GET dans le frame `account_lookup`, URL avancée (`?q=`, paramètre filtré des journaux par `/\Aq\z/`, ADR-0065) ; une saisie au format d'un numéro cherche le numéro, au format d'un matricule cherche le matricule ; sinon, « Aucun compte ».
- Correction : succès → Turbo Stream : toast `success` « Matricule de <nom> corrigé. » et `replace "account-lookup-result"` ; repli HTML : 303 vers `/teams/accounts` (sans paramètre : jamais le matricule dans une URL de redirection) avec `notice`. Échec → 422, modale re-rendue : format (message de 3.1), pris « Ce matricule est déjà celui d'un autre compte. » ; refus → 403 en toast ; compte inconnu ou non élève → 404.
- Réinitialisation du second facteur d'un `school_admin` : comportement de l'UDR-0020, inchangé.

**États obligatoires**
- Vide : « Saisissez un numéro ou un matricule ».
- Chargement : `aria-busy` du frame et du formulaire de la modale.
- Erreur : sous le champ (422), toast (403, 404).
- Succès : toast, carte remplacée avec le nouveau matricule.

**Accessibilité** : le formulaire reste `role="search"` étiqueté ; le matricule de la carte est lu par son `dt` ; la modale est une `<dialog>` native (focus piégé, Échap) ; cibles ≥ 48 px ; 390 px.

## 4. Conséquences

- L'inscription d'un élève demande un champ de plus ; la page reste en trois rubriques (UDR-0009).
- Personne ne corrige un matricule ailleurs que dans « Débloquer un compte » ; quand l'annuaire des comptes (`annuaire-equipe`) livrera la fiche d'un compte, il y **déplacera** « Corriger le matricule » en réutilisant `Identity::ChangeStudentNumber` et `teams/student_numbers`, sans nouveau geste.
- Le paramètre `contact` de `/teams/accounts` est remplacé par `q` ; l'ancien reste lu.
- Interdit : afficher à l'élève à qui appartient un matricule pris ; une recherche partielle par matricule.
