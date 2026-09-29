# UDR-0052 : Espace direction simple — « Travail des élèves » et « Enseignants », en lecture seule

| | |
|---|---|
| **Statut** | Accepté *(par le porteur le 2026-09-29)* |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/espace-direction-simple`](../../chantiers/espace-direction-simple/prd.md) |
| **ADR lié** | [ADR-0065](../adr/0065-espace-direction-simple-en-lecture-seule.md) · [ADR-0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (navigation `school_admin`) · [UDR-0019](0019-invitation-equipe.md) (acceptation) · [UDR-0036](0036-gestion-des-etablissements.md) (fiche) · [UDR-0041](0041-page-profil.md) (profil) |
| **Remplacé par** | — |

---

## 1. Contexte

Une direction connectée arrive aujourd'hui sur l'écran d'attente : elle ne voit rien de son établissement. Ce qu'elle veut savoir tient en deux questions : « qui enseigne chez nous sur Lnclass ? » et « nos élèves font-ils leurs devoirs ? ». Elle consulte surtout au téléphone.

## 2. Décision

1. **Deux destinations, pas d'accueil** : « Travail des élèves » (l'accueil de la direction) et « Enseignants ». Un accueil de plus n'aurait rien à dire que ces deux pages ne disent.
2. **Des tableaux, pas des cartes** : une ligne par classe, une ligne par élève, une ligne par enseignant. Les nombres se comparent d'une ligne à l'autre. Sur téléphone, le tableau défile dans sa carte, la page jamais.
3. **La classe s'ouvre par son nom**, lien de la première colonne, vers une page qui reprend ses chiffres puis liste ses élèves.
4. **« — » plutôt que 0** quand un chiffre n'a pas de sens (aucun devoir, moins de 5 élèves ayant rendu). Une phrase sous le tableau dit pourquoi.
5. **L'équipe invite depuis la fiche de l'établissement**, par la modale de l'UDR-0019 réduite au numéro.
6. **Aucun bouton d'action** pour la direction : ni modale, ni formulaire, ni Turbo Stream.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Navigation** (`NavigationHelper::DESTINATIONS[:school_admin]`, accueil `HomeDestination` → `school_admin_classrooms_path`, locale `shared.navigation`) : `[:classrooms, :school_admin_classrooms_path, "chart-bar"]` « Travail des élèves », puis `[:teachers, :school_admin_teachers_path, "user-group"]` « Enseignants ». L'entrée `school_admin` de `HOME_SECTIONS` ne sert plus qu'à la page de démonstration du shell. Détail du shell sous le nom : le nom de l'établissement.

**Page « Travail des élèves »** — `GET /school-admin/classrooms`, `school_admin/classrooms/index`, `content_for :nav_key, "classrooms"` :

1. `ui_page_header` « Travail des élèves », sous-titre « <établissement> · Année <2026-2027> ».
2. `ui_card#student_work` → `div.relative.overflow-x-auto` → `table.w-full.min-w-xl.text-left.text-sm`, `caption.sr-only` « Travail des élèves par classe ». En-têtes `th scope="col"` : Classe, Élèves, Devoirs donnés, Taux de rendu, Moyenne. Ligne `tr#classroom_<public_id>` : `th scope="row"` avec le lien `school_admin_classroom_path` (`font-medium text-ink`, `min-h-tap inline-flex items-center`) et le niveau dessous (`block text-xs text-mute`) ; nombres `text-right tabular-nums` ; taux et moyenne en « 64 % ».
3. Sous le tableau, `p.mt-3.text-xs.text-mute` : « La moyenne s'affiche à partir de 5 élèves ayant rendu un devoir. »

**Page d'une classe** — `GET /school-admin/classrooms/:public_id`, `school_admin/classrooms/show`, `content_for :nav_key, "classrooms"` :

1. Lien retour `ui_button` « Travail des élèves » `variant: :ghost`, `icon: "arrow-left"`, vers la liste.
2. `ui_page_header` titre = nom de la classe, sous-titre « <niveau> · <n> élèves ».
3. `ul#classroom_figures.grid.grid-cols-3.gap-3` de trois tuiles `li.rounded-ln.bg-mist.px-3.py-4` (comme l'UDR-0049) : Devoirs donnés, Taux de rendu, Moyenne ; nombre en `font-display text-2xl font-extrabold tabular-nums`, libellé en `text-sm text-mute`.
4. `ui_card#classroom_students` → même tableau que la liste, `caption.sr-only` « Élèves de <classe> ». En-têtes : Élève, Devoirs rendus, Score moyen. Ligne `tr#student_<index>` (aucun identifiant d'élève dans le HTML) : `th scope="row"` avec le nom, « 3 / 5 », « 72 % ».

**Page « Enseignants »** — `GET /school-admin/teachers`, `school_admin/teachers/index`, `content_for :nav_key, "teachers"` :

1. `ui_page_header` « Enseignants », sous-titre « <établissement> · <n> enseignants ».
2. `ui_card#school_teachers` → tableau, `caption.sr-only` « Enseignants de <établissement> ». En-têtes : Enseignant, Matière, Classes. Ligne `tr#teacher_<index>` : `th scope="row"` avec le nom ; `ui_subject_badge(matière, category:)` ou « — » ; les noms des classes séparés par « , », ou « Aucune classe » en `text-mute`.

**Inviter la direction (équipe)** — fiche `teams/schools/show` :

- Le menu ⋮ `#school-header-actions` gagne, en premier, `ui_dropdown_item` « Inviter la direction » (`icon: "user-plus"`, `frame: "modal"`) vers `new_school_staff_invitation_path(school)`. Absent pour un établissement non actif.
- `teams/staff_invitations/new` : `turbo_frame_tag "modal"` → `ui_modal(id: "staff-invitation-modal", open: true)`, titre « Inviter la direction », phrase « La personne invitée verra les enseignants et le travail des élèves de <établissement>. », `form#staff-invitation-form` (scope `invitation`) avec `ui_field :contact, as: :tel` ; pied « Annuler », « Créer l'invitation ».
- Succès et erreurs : ceux de l'UDR-0019 (toast « Invitation créée », modale remplacée par le lien à usage unique, `Cache-Control: no-store`, 422 re-rendu), plus « Cet établissement n'est pas actif. » en tête de la modale.

**Accepter l'invitation** — `identity/invitations/show`, type `school_staff` : l'encadré `bg-info-soft` dit « Vous rejoignez <établissement> comme direction. » au lieu d'annoncer le second facteur. Après l'envoi, le toast sur « Se connecter » dit « Votre compte est créé. Connectez-vous avec votre numéro et votre PIN. »

**Profil** (`identity/profiles/_information`) : pour `school_admin`, plus de badge « En attente » ; une ligne « Établissement » avec son nom, comme pour l'enseignant.

**Tokens** : ceux de l'UDR-0005, rien d'autre. Aucune valeur arbitraire, aucun attribut `style`.

**Comportement** : aucun JavaScript ajouté. Les liens sont des navigations Turbo de la page entière. Les pages de la direction n'ont ni Turbo Frame, ni Turbo Stream, ni toast.

**États obligatoires**
- Vide : liste sans classe → `ui_empty_state` « Aucune classe cette année », icône `squares-2x2` ; classe sans élève → « Aucun élève dans cette classe », icône `users` (les tuiles restent) ; établissement sans enseignant → « Aucun enseignant pour l'instant », icône `user-group`, description « Un enseignant apparaît ici dès qu'il a rejoint l'établissement. ».
- Donnée absente : `span[aria-hidden="true"]` « — » suivi de `span.sr-only` « non calculé ».
- Chargement : aucun ; la page arrive entière (barre de progression de Turbo).
- Erreur : page d'erreur commune. Classe inconnue ou d'un autre établissement : 404. Autre rôle : 403.
- Succès : la page elle-même.

**Accessibilité**
- Un seul `h1` par page ; `caption` et `scope` sur chaque tableau.
- Liens et entrées de navigation ≥ 48 px de haut (`min-h-tap`).
- Chaque nombre se lit avec son en-tête de colonne ; aucune information portée par la seule couleur.

## 4. Conséquences

- La navigation `school_admin` passe de 4 entrées (dont 3 sans route) à 2 : l'UDR-0006 est amendée.
- Interdit sur ces pages : un bouton, un formulaire, un identifiant d'élève ou d'enseignant, un numéro de téléphone.
- Une vraie demande d'une direction (filtre, export, geste) passe par une nouvelle UDR, pas par un ajout discret à celle-ci.

## Amendement du 2026-09-29 — clé de navigation de « Travail des élèves »

Le libellé d'une destination se lit sous sa clé (`shared.navigation.<clé>`, partiel `shared/navigation/_link`), et `classrooms` vaut déjà « Classes » pour l'enseignant. La destination « Travail des élèves » a donc la clé **`student_work`** : `[:student_work, :school_admin_classrooms_path, "chart-bar"]`. Les pages `school_admin/classrooms/index` et `show` déclarent `content_for :nav_key, "student_work"` (au lieu de `"classrooms"` au §3). La page de démonstration du shell (`design/shell`) marque active la première destination du rôle. Constaté au Lot 0 du chantier.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Proposé`. Le texte ci-dessus reste tel qu'accepté ; une fois l'UDR-0054 acceptée, cette section fait foi en cas d'écart.*

- **Retour** : le bouton `ghost` `arrow-left` « Travail des élèves » devient le lien de retour commun (`ui_page_header(back:)`, UDR-0054 §3.2).
- **Chercher un élève** : la page d'une classe gagne `form#student-work-search` (GET, champ `q`, contrôleur `search`) et le frame `student_work_students` ; la recherche ne lit que les élèves de cette classe ; état vide « Aucun élève ne correspond ». Aucun identifiant d'élève n'entre dans le HTML (inchangé).
- **Infobulles** : « Taux de rendu », « Moyenne », « Score moyen » et la légende de « — », sur la liste et sur la page d'une classe (UDR-0054 §3.4).
- Titres : « Travail des élèves · Direction · Lnclass », « <nom de la classe> · Direction · Lnclass » (au lieu du nom brut).
- Ces règles s'appliquent aux pages de cette UDR, en production depuis la V2 simple.
