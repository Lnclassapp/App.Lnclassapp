# UDR-0031 : Création de classe — l'équipe ajoute une classe à un établissement, en modale ouverte depuis sa fiche

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot D8 ; CL-01, CL-04) |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (qui crée une classe, génération) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (année scolaire, code d'adhésion) · UDR-0005, UDR-0006, UDR-0007, UDR-0036 |
| **Remplacé par** | — |

---

## 1. Contexte

Les classes d'un établissement naissent à son import (ADR-0030). Il en manque parfois une : une Tle D ouverte en cours d'année, une 6ème dédoublée. Dans l'ancienne application, le formulaire de l'équipe ne marchait pas (CL-01 : « École introuvable », puis un code de 6 caractères trop long pour sa colonne), la série n'était pas contrôlée contre le niveau, et le code d'adhésion s'affichait tantôt en minuscules, tantôt en majuscules (CL-04). L'équipe ne pouvait donc pas dépanner un établissement, et un code mal lu ne permettait pas à un élève de rejoindre sa classe.

## 2. Décision

- **Une modale ouverte depuis la fiche de l'établissement** (bouton « Ajouter une classe » de l'UDR-0036), jamais une page autonome : l'équipe reste sur la fiche, qui se met à jour par morphing (UDR-0006).
- **Le code n'est jamais saisi** : il est tiré à la création, stocké en minuscules, et **affiché en majuscules** dans le toast (« Classe créée. Code : KFM37 ») et sur la fiche.
- **Les séries sont rangées sous leur niveau** (`optgroup`), calculées côté serveur à partir des couples ouverts, sans Stimulus : l'équipe voit d'un coup d'œil qu'une 6ème n'a pas de série. Le serveur refuse quand même un couple fermé (422), puisque le formulaire peut être contourné.
- **Un collège (cycle « premier ») ne propose que les niveaux du premier cycle**, comme la génération des classes.
- **Un établissement désactivé ne reçoit plus de classe** : la fiche masque déjà le bouton (UDR-0036) ; un envoi direct reçoit 422 avec la raison dans la modale.
- **Un établissement en brouillon non plus** (décision du porteur, 2026-09-27) : il est activé avant de recevoir une classe. La fiche masque le bouton « Ajouter une classe » ; un envoi direct reçoit 422 avec « Cet établissement est en brouillon : activez-le avant d'y ajouter une classe. »

## 3. Règles d'implémentation

**Structure**
- `teams/school_classrooms/new` : `turbo_frame_tag "modal"` → `ui_modal(title: "Ajouter une classe", id: "classroom-modal", open: true)` → rappel « <établissement> · année scolaire <AAAA-AAAA> » → `_form`.
- `_form` : `form_with id: "classroom-form"`, portée `classroom`, `POST school_classrooms_path(school_public_id)`.
  1. Alerte `role="alert"` des erreurs de base (établissement désactivé ou en brouillon), au-dessus des champs.
  2. Ligne 1 : Niveau (`select`, obligatoire, invite « Choisir un niveau ») · Série (`select` : « Aucune série » puis un `optgroup` par niveau à séries).
  3. Ligne 2 : Nom (15 caractères au plus, `maxlength`, placeholder « Ex. : Tle D 7 ») · Nombre maximal d'élèves (`number`, 1 à 150, 80 par défaut).
  4. Encart d'information : le code d'adhésion est créé automatiquement.
- Pied de modale : « Annuler » (`modal#close`) · « Créer la classe » (`form="classroom-form"`).

**Tokens**
- Composants `ui_modal`, `ui_field`, `ui_button`, `ui_icon` uniquement ; alerte en `bg-error-soft text-error`, encart en `bg-info-soft text-info`. Aucune valeur arbitraire.

**Comportement**
- Ouverture : lien `data-turbo-frame="modal"` de la fiche (S2). Hors frame, la même modale s'ouvre sur le shell (repli HTML).
- Erreur (nom pris dans l'établissement et l'année, série fermée au niveau, niveau hors cycle, plafond hors 1-150, établissement désactivé ou en brouillon) : `render :new`, 422, erreurs sous les champs, saisie conservée.
- Succès : `create.turbo_stream.erb` → toast de succès avec le code en majuscules, `update "modal"` (modale refermée), `refresh(request_id: nil)` (la fiche de l'établissement est re-demandée et fusionnée : la nouvelle classe apparaît avec son code). Jamais de redirection depuis la modale.
- Sans Turbo : redirection vers la page de la classe (`classroom_path`), avec le même message en flash.
- Un rôle hors équipe reçoit 403 (toast en Turbo Stream) ; un établissement inconnu, 404.

**États obligatoires**
- Vide : sans objet (formulaire). Chargement : état occupé de Turbo sur le formulaire. Erreur : 422 dans la modale. Succès : toast, modale fermée, fiche à jour.

**Accessibilité**
- Chaque champ a son `label` ; l'aide et l'erreur sont reliées par `aria-describedby`, `aria-invalid` sur le champ fautif.
- Le code est affiché en police à chasse fixe et en majuscules, pour qu'un « l » ne se lise pas « 1 » (l'alphabet exclut déjà i, o, 0 et 1).
- Boutons de la modale ≥ 48 px de haut (`min-h-tap`).

## 4. Conséquences

- Le code d'adhésion ne se saisit nulle part ; seul le repository le tire, et le retire une fois en cas de collision.
- Toute page qui affiche un code l'affiche par `Entities::Classroom::JoinCode.display` (majuscules).
- La création de classe par un enseignant ou par la direction reste hors V1 (ADR-0030) : la policy `ManageClassroomPolicy` ne laisse passer que l'équipe.
