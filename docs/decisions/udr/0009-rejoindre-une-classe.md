# UDR-0009 : Rejoindre une classe — un code, un aperçu limité à trois noms, une inscription en trois rubriques, arrivée connecté sur l'accueil

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `interface-epuree`* |
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

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **`/join`** : le formulaire porte le contrôleur `autosubmit` (motif du code d'adhésion, 3 lettres puis 2 chiffres, espaces et tiret retirés) ; il part au 5ᵉ caractère valide, une seule fois ; l'aide dit « La classe s'ouvre dès le code complet. » ; « Rejoindre » reste. Le champ du code garde le focus d'arrivée (`data-autofocus-target="field"`).
- **`/c/<code>`** : pas de focus d'arrivée ; après un 422, focus sur le premier champ en erreur.
- **Pages publiques** : le logo est un lien vers l'accueil public (« Lnclass, accueil »).
- Titres : « Rejoindre une classe · Lnclass », « Rejoindre ma classe · Lnclass » par `page_title`.

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Accepté (2026-10-02, porteur)

> **Décision du porteur (2026-10-02)** : amendement accepté.

*Chantier [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/plan.md), Lot E, [UDR-0057](0057-ecrans-eleve-epures.md). Statut : `Accepté` (porteur, 2026-10-02). Le Lot E ne code rien avant l'acceptation du porteur (plan, « Porte des lots C à F »). Une fois acceptée, cette section fait foi en cas d'écart avec le texte ci-dessus et avec les amendements du 2026-09-28 et du 2026-09-29.*

Cet amendement applique la règle de sobriété de l'UDR-0057 aux deux écrans du parcours, `/join` et `/c/<code>`, où six textes d'aide restent affichés en permanence.

**Ce qui change**

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| `/join` — sous-titre de la carte | « Saisis le code de ta classe, donné par ton professeur. » (`join_codes.new.subtitle`) | Retiré. La clé est supprimée. | R4 | Dans l'infobulle du champ du code (`code_info_tip`). |
| `/join` — aide du champ du code | « 3 lettres puis 2 chiffres. La classe s'ouvre dès le code complet. » | L'aide garde seulement « La classe s'ouvre dès le code complet. » (`shared.autosubmit.hint_join`). La clé `join_codes.new.code_hint` est supprimée. | R4, avec une exception d'accessibilité pour l'envoi automatique | Le format va dans l'infobulle `code_info_tip`. L'annonce de l'envoi automatique reste visible : elle prévient d'un changement de page avant la frappe (UDR-0054 §3.6, critère WCAG 3.2.2). |
| `/join` — infobulle du code | Aucune | `ui_info_tip t(".code_info_tip"), label: t(".code_label")`, juste après le champ. Texte : « Ton professeur te donne ce code : 3 lettres puis 2 chiffres. » | R4 | Elle reçoit le sous-titre et le format. Le placeholder « KFM37 » reste dans le champ. |
| `/c/<code>`, visiteur — sous-titre de la carte | « Tu rejoins cette classe dès la création de ton compte. » (`joins.new.subtitle`) | Retiré. La clé est supprimée. | R6 | Nulle part : le bandeau `_classroom_preview`, juste dessous, le dit déjà (« Ta classe », puis la classe). |
| `/c/<code>`, élève connecté — sous-titre de la carte | « Tu gardes ton compte, tes sessions et tes badges. » (`joins.new.student_subtitle`) | Retiré du texte. Une infobulle le porte, à droite du `h1`. La clé devient `joins.new.student_info_tip`, même texte. | R4 | Dans l'infobulle, à un tap. |
| `/c/<code>` — aide du numéro | « 10 chiffres. Il te servira à te connecter. » sous le champ (`signup_form.contact_hint`) | Retirée du champ. Une infobulle la porte, juste après le champ. La clé devient `signup_form.contact_info_tip`, même texte. | R4 | Dans l'infobulle. Le placeholder « 07 00 00 00 00 » montre toujours le format. |
| `/c/<code>` — aide du PIN | « 4 chiffres, que toi seul connais. » sous le champ (`signup_form.pin_hint`) | Retirée du champ. Une infobulle la porte, juste après le champ. La clé devient `signup_form.pin_info_tip`, même texte. | R4 | Dans l'infobulle. Le message d'erreur dit toujours « Le PIN compte 4 chiffres. ». |

**Règles d'implémentation (remplacent les points correspondants du §3)**

- `classroom/join_codes/new` :
  - La carte s'ouvre sur le seul `h1` « Rejoindre une classe ». Le `p` de sous-titre disparaît.
  - Le champ du code et son infobulle sont dans un `div`, l'infobulle juste après le champ, comme le PIN de la connexion (`identity/sessions/new`).
  - `ui_field` garde `label: t(".code_label")`, `hint: t("shared.autosubmit.hint_join")`, le motif `autosubmit`, `autofocus: true` et tous ses attributs actuels.
  - « Continuer » (`brand`, `lg`, pleine largeur) et « Déjà un compte ? Se connecter » restent.
- `classroom/joins/new` :
  - Le titre est un `div.flex.items-center.justify-center.gap-1` qui contient le `h1`. Le `p` de sous-titre disparaît dans les deux variantes.
  - Variante élève connecté : `ui_info_tip t(".student_info_tip"), label: t(".student_title")` suit le `h1`, dans ce `div`.
  - Variante visiteur : pas d'infobulle de titre.
  - Le reste est inchangé : colonne de gauche (à partir de `md`), logo et accroche au-dessus de la carte (sous `md`), `_classroom_preview`, carte du code invalide, `ui_error_state` du débit dépassé.
- `classroom/joins/_signup_form` :
  - Le numéro : `ui_field form, :contact, …` sans `hint:`, puis `ui_info_tip t(".contact_info_tip"), label: Dtos::Classroom::JoinWithCodeInput.human_attribute_name(:contact)`, dans un `div`.
  - Le PIN : `ui_field form, :pin, …` sans `hint:`, puis `ui_info_tip t(".pin_info_tip"), label: Dtos::Classroom::JoinWithCodeInput.human_attribute_name(:pin)`, dans un `div`.
  - Les trois rubriques, leurs `legend`, les placeholders, le genre et « Créer mon compte » (`brand`, `lg`, pleine largeur) sont inchangés.
- `config/locales/classroom/joins.fr.yml` :
  - supprimées : `classroom.join_codes.new.subtitle`, `classroom.join_codes.new.code_hint`, `classroom.joins.new.subtitle` ;
  - créée : `classroom.join_codes.new.code_info_tip` (« Ton professeur te donne ce code : 3 lettres puis 2 chiffres. ») ;
  - renommées, même texte : `joins.new.student_subtitle` → `joins.new.student_info_tip`, `joins.signup_form.contact_hint` → `contact_info_tip`, `joins.signup_form.pin_hint` → `pin_info_tip` ;
  - inchangées : toutes les autres, dont les messages d'erreur.
- Accessibilité :
  - Sans `hint:`, le numéro et le PIN ne sont plus décrits par une aide (`aria-describedby`). Leur erreur reste reliée par `aria-describedby`.
  - Chaque infobulle s'appelle « Aide : <libellé> » (UDR-0054 §3.4). Elle s'ouvre au toucher, au clavier et au survol.
  - Les attributs du PIN, de la confirmation et du code restent ceux du §3.
- Mise en page : ces écrans n'ont pas de maquette téléphone. Ils gardent une seule mise en page et appliquent la règle à toutes les tailles (UDR-0057 §3, « Deux familles d'écrans »).

**Ce qui ne change pas, et pourquoi**

- **L'aperçu** garde ses trois noms : la classe, l'établissement et le niveau (§2.2). Le nom d'une classe est libre : il ne contient pas toujours le niveau. « Niveau : <niveau> » n'est donc pas une redite.
- **L'accroche** « Ton espace d'apprentissage… » reste, dans la colonne de gauche à partir de `md` et au-dessus de la carte sous `md`. Ce n'est pas une aide : elle présente Lnclass au visiteur qui arrive par un lien partagé.
- **Les placeholders** (« Ex. : Kouassi », « 07 00 00 00 00 », « KFM37 ») restent. Ils disparaissent dès la frappe : ce ne sont pas des textes permanents.
- **Les messages d'erreur** et la carte « Code de classe invalide. » restent. Ce sont des états, pas des aides.
- **Le titre et le bouton de l'élève connecté** disent tous deux « Rejoindre cette classe ». Le titre nomme l'écran, le bouton nomme l'action : ce n'est pas une information redite.

**Contrôle des six points (UDR-0057), après l'amendement**

| # | `/join` | `/c/<code>` |
|---|---|---|
| R1 | Une seule action principale : « Continuer » (`brand`). « Se connecter » est un lien texte. Respecté. | Une seule action principale par état : « Créer mon compte » (visiteur), « Rejoindre cette classe » (élève connecté) ou « Saisir un autre code » (code invalide), toutes `brand`. « Se connecter » est un lien texte. Respecté. |
| R2 | À 390 × 844 : le logo, la carte. Respecté (2 ≤ 5). | À 390 × 844 : le bloc logo et accroche, la carte. La colonne de gauche est `hidden` sous `md`. Respecté (2 ≤ 5). |
| R3 | Aucune liste. Sans objet. | Aucune liste. Sans objet. |
| R4 | Le sous-titre et le format passent dans l'infobulle. Reste l'annonce de l'envoi automatique, exception d'accessibilité. Respecté après l'amendement. | Les deux sous-titres, l'aide du numéro et celle du PIN sont retirés ou passent en infobulle. Respecté après l'amendement. |
| R5 | Accent `brand` seul. Les erreurs sont en `error`. Respecté. | Accent `brand` seul : colonne de gauche, bandeau, genre coché, bouton. Les erreurs sont en `error`. Respecté. |
| R6 | Rien n'est dit deux fois. Respecté. | La classe, l'établissement et le niveau ne sont dits qu'une fois, dans le bandeau. Le sous-titre du visiteur, qui redisait le bandeau, est retiré. Respecté après l'amendement. |

**Garde-fous**

- **L'inscription par code reste la seule porte de l'élève** (§2.1). L'épuration n'ajoute ni cascade école → niveau → classe, ni recherche de classe, ni liste de classes. Aucune route n'est ajoutée.
- **L'aperçu ne montre que trois noms** (§2.2) : jamais l'effectif, un enseignant, un élève ni un identifiant.
- **Jamais de liste nominative des camarades** (UDR-0011) : aucun écran du parcours ne lit les élèves de la classe.
- Le débit (10 requêtes par minute et par adresse, compteur commun), les codes HTTP (404, 422, 403, 429) et le toast de succès sont inchangés.
- Tokens du `@theme` seulement : aucun `#hex`, aucun `style=`, aucune valeur entre crochets, aucun `dark:` (UDR-0005).

**Vérification (Lot E, phase code)**

- `test/controllers/classroom/join_codes_controller_test.rb` : `/join` n'a plus de sous-titre ; l'aide du champ est la seule annonce de l'envoi automatique ; l'infobulle du code est présente ; `assert_single_primary_action` passe.
- `test/controllers/classroom/joins_controller_test.rb` : les deux variantes de `/c/<code>` n'ont plus de sous-titre ; le numéro et le PIN ont leur infobulle et plus d'aide sous le champ ; `assert_single_primary_action` passe pour le visiteur, l'élève connecté et le code invalide.
- `test/system/classroom/join_test.rb` : le parcours complet à 390 px, de `/join` à l'accueil, passe `assert_blocks_above_fold(max: 5)` sur les deux écrans. L'infobulle du PIN s'ouvre au toucher.
