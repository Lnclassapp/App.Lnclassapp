# UDR-0009 : Rejoindre une classe — un code, un aperçu limité à trois noms, une inscription en trois rubriques, arrivée connecté sur l'accueil

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot A1, critères ID-01, ID-02, ID-07, CL-06, CL-07, CL-08, TR-cadre-1, sécurité n° 5 |
| **ADR lié** | [ADR-0037](../adr/0037-nom-et-prenoms-en-deux-champs.md) (nom et prénoms) · [ADR-0040](../adr/0040-classe-principale-unique-de-l-eleve.md) (classe principale) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (code, plafond, débit) · [ADR-0050](../adr/0050-authentification-et-session.md) (PIN, session) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0024](0024-inscription-enseignant.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Dans l'ancienne application, un élève rejoignait sa classe par deux chemins aux règles différentes :

- `/student-signup` : une case « J'ai le code de ma classe », sinon une cascade niveau → école → classe qui permettait de rejoindre **n'importe quelle classe sans son code** (ID-08) ;
- `/c/<code>` : une page qui montrait le premier enseignant de la classe, un formulaire sans DTO, et un **PIN laissé vide remplacé par le numéro** (sécurité n° 5) ;
- le code se vérifiait par une API publique, sans limite de débit, qui renvoyait les identifiants de la classe, de l'école et du niveau (CL-08) ;
- aucune transaction : un compte pouvait rester sans classe ; une erreur rechargeait toute la page (`turbo: false`).

## 2. Décision

1. **Le code est la seule porte.** Aucune cascade école + niveau → classe n'existe. « Rejoindre une classe » (`/join`) n'a qu'un champ, « Code de classe » ; le code saisi n'importe comment (`Kfm 37`) est normalisé et ouvre `/c/kfm37`. Cet écran ne cherche pas la classe : seule `/c/<code>` le fait, sous limite de débit.
2. **L'aperçu ne dit que trois noms** : la classe, l'établissement et le niveau, dans un bandeau « Classe — Établissement ». Jamais l'effectif, un enseignant, un élève ni un identifiant.
3. **Code inconnu, ou remplacé depuis : 404** avec « Code de classe invalide. » et le bouton « Saisir un autre code ».
4. **Le visiteur s'inscrit sur la même page**, sous le bandeau, dans une carte : trois rubriques reprises de l'ancienne application — Ton identité (Nom, Prénom(s), Genre), Ton contact (numéro), Sécurité (PIN et confirmation). Ni rôle, ni classe, ni école dans le formulaire : le code suffit.
5. **L'élève connecté ne voit pas le formulaire** : un seul bouton « Rejoindre cette classe ». Il ne change de classe que si sa classe principale est archivée ; sinon « Tu es déjà inscrit dans une classe. ».
6. **Erreur sans rechargement** : 422 re-rendu par Turbo, saisies gardées (sauf les PIN), chaque message sous son champ. Un refus de `JoinPolicy` (classe archivée, classe complète) s'affiche en 403, avec sa raison, dans l'alerte en tête du formulaire.
7. **Succès : la page change**, c'est voulu : la session vient de naître. L'élève arrive sur son accueil (`/students`) avec le toast « Bienvenue dans ta classe ! ». Aucun `*.turbo_stream.erb`.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `classroom/join_codes/new` : logo, puis `ui_card(padding: :lg)` → titre « Rejoindre une classe », `form#join-code-form` (scope `join`, champ `code`), bouton « Continuer », « Déjà un compte ? Se connecter ».
- `classroom/joins/new` : `main.grid.md:grid-cols-2` comme la connexion ; colonne gauche `bg-brand-soft`, logo, « Bienvenue sur Lnclass » ; colonne droite : `ui_card(padding: :lg)` → titre, `_classroom_preview`, puis `_signup_form` (visiteur) ou `form#join-form` au seul bouton (élève).
- `_classroom_preview` : `#classroom-preview`, icône `academic-cap`, « Ta classe » en petites capitales, « <classe> — <établissement> », « Niveau : <niveau> ».
- `_signup_form` : `form#join-form` (scope `join`, `POST /c/<code>`), une `<fieldset>` par rubrique, `<legend>` en petites capitales `text-mute` ; genre en deux radios `min-h-tap` côte à côte, sans présélection.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement : `ui_card`, `ui_field`, `ui_button` (`brand`, `lg`, pleine largeur), `ui_error_state` pour le débit dépassé ; bandeau `bg-brand-soft border-brand/30` ; alerte `bg-error-soft text-error`. Aucune classe de l'ancienne application.

**Comportement**
- `/c/<code>` (aperçu et inscription) : 10 requêtes par minute et par adresse, compteur commun ; au-delà, 429 **sans aperçu**.
- `JoinWithCode` : dans une transaction, verrou de la classe, `JoinPolicy`, compte élève (rôle imposé), adhésion principale, session. Aucun compte sans adhésion.
- Enseignant, direction, équipe, ou session d'équipe sans second facteur : 403 sur la page et sur le formulaire.
- Élève dont la classe principale est archivée : l'ancienne adhésion est close (`left_at`), la nouvelle devient principale, sans nouveau compte.

**États obligatoires**
- Vide : sans objet (la page existe par son code).
- Erreur : message sous chaque champ (`aria-invalid`, `aria-describedby`) ; numéro pris : « Ce numéro est déjà utilisé. » ; raison du refus (archivée, complète, déjà inscrit) dans le bloc `role="alert"`.
- Code invalide : 404, « Code de classe invalide. », « Saisir un autre code ».
- Débit dépassé : `ui_error_state` « Trop de tentatives ».
- Succès : toast « Bienvenue dans ta classe ! » sur l'accueil.

**Accessibilité**
- PIN et confirmation en `type="password"`, `inputmode="numeric"`, `maxlength="4"`, `autocomplete="new-password"` ; jamais renvoyés au re-rendu.
- Le champ du code : `autocomplete="off"`, `autocapitalize="characters"`, sans correcteur.
- Le genre est un `<fieldset>` avec `<legend>`, son erreur reliée par `aria-describedby`.
- Cibles tactiles ≥ 48 px ; parcours prouvé à 390 px.

## 4. Conséquences

- ID-08 (cascade) n'est pas reprise : un élève sans code demande le code à son professeur.
- L'API publique de vérification d'un code (CL-08) disparaît : la page `/c/<code>` limitée en débit la remplace.
- Un élève connecté qui ouvre le code d'une autre classe voit l'aperçu et le bouton ; le refus « Tu es déjà inscrit dans une classe. » s'affiche quand il le presse (le Lot A1 ne lit pas l'adhésion à l'ouverture de la page).

## Amendement du 2026-09-28 — `/join` vérifie le code

Chantier [`recette-v1-defauts`](../../chantiers/recette-v1-defauts/memo.md) (D1). Remplace la dernière phrase du point 1 (« Cet écran ne cherche pas la classe »).

- `/join` vérifie le code avant de rediriger : il ne mène à `/c/<code>` que si cette page a un aperçu. Sinon (code inconnu, remplacé, fermé, classe archivée), l'écran se ré-affiche en **422**, la saisie gardée, avec sous le champ « Code de classe invalide. Vérifie le code auprès de ton professeur, puis saisis-le de nouveau. » : les mots de la page 404 de `/c/<code>`, rien de plus.
- Pourquoi : une soumission de formulaire Turbo suivie d'une page 4xx après redirection n'est pas rendue de façon fiable (recette `Staging` : écran resté sur `/join`, sans message).
- La vérification lit la même requête que `/c/<code>` (`Queries::Classroom::JoinPreviewQuery`) et **partage son compteur** : 10 requêtes par minute et par adresse, `/join` (envoi) et `/c/<code>` confondus ; au-delà, 429 et « Trop de tentatives. Patiente une minute, puis réessaie. » sous le champ, sans rien chercher.
