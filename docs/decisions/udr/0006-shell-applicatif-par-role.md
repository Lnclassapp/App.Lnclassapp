# UDR-0006 : Shell applicatif par rôle (en-tête, navigation, accueil, toasts, états)

| | |
|---|---|
| **Statut** | Accepté (2026-09-25) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/refonte-application`](../../chantiers/refonte-application/) (Lot 0c, décision F-31) |
| **ADR lié** | [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids) · UDR-0005 (tokens et composants) |
| **Remplacé par** | — |

---

## 1. Contexte

Dans l'ancienne application, chaque rôle a sa propre navigation : 4 rôles × 4 partials (en-tête, barre latérale, tiroir, barre basse), qui ont divergé. Sur mobile, un élève ne voit que 2 de ses 4 destinations dans la barre basse et un membre de l'équipe 1 sur 6 : le reste est caché dans un tiroir que peu de gens ouvrent. Aucune UDR ne décrit les accueils, les tableaux de bord, la navigation ni les toasts. Un toast d'erreur envoyé par Turbo Stream perd son message (CO-09), et l'accueil élève levait une exception sans qu'aucun test ne le signale (TR-04).

## 2. Décision

1. **Un seul shell, paramétré par le rôle** : `app/views/layouts/shell.html.erb`, pour les quatre rôles `student`, `teacher`, `team` et `school_admin`. Ce qui change d'un rôle à l'autre est une **donnée** (`NavigationHelper::DESTINATIONS`), pas un partial.
2. **Une seule liste de destinations par rôle**, servie à la fois à la barre latérale (bureau) et à la barre basse (mobile). Le mobile voit tout ce que voit le bureau. Il n'y a **pas de tiroir** : c'est moins de JavaScript, et plus aucune destination n'est cachée. Chaque rôle a donc au plus 5 destinations.
3. **Le compte passe par le menu de l'avatar** (en-tête, bureau et mobile) : profil et déconnexion.
4. **Accueil de chaque rôle** : un en-tête de bienvenue (prénom, comme l'ancienne application) suivi des sections du rôle, en cartes. Le squelette est livré au Lot 0c. Chaque vague remplace l'état d'une section par ses données, **dans la vague qui livre ce rôle**.
5. **Toasts** : le message est rendu côté serveur dans le HTML du toast. Il survit ainsi au Turbo Stream comme à la redirection. Une seule région, `#toasts`, dans le layout commun.
6. **États** vide, chargement et erreur par les composants de l'UDR-0005, jamais par du balisage local.
7. **Tous les CRUD passent par Hotwire** (règle du porteur). Le formulaire s'ouvre en modale dans un frame du layout, un échec le re-rend en 422 dans ce frame et un succès répond en Turbo Stream. On ne recharge jamais la page, et il n'existe pas de page « new » ou « edit » autonome.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Layout : `app/views/layouts/shell.html.erb`, imbriqué dans `layouts/application` (`content_for :body`). Il se compose, dans l'ordre, d'un lien d'évitement (« Aller au contenu »), de `shared/navigation/_header`, de `shared/navigation/_sidebar`, de `main#main` (conteneur `max-w-page px-gutter`) et de `shared/navigation/_bottom_bar`.
- Le contrôleur qui rend `layout "shell"` expose `shell_user` par `helper_method` : un `NavigationHelper::ShellUser.new(name:, role:, detail:, avatar_url:)`, où `detail` et `avatar_url` sont facultatifs. Le shell ne lit jamais `current_user` directement.
- En-tête (`h-bar`, collant) : filet de la couleur du rôle, logo et « Lnclass » (lien vers l'accueil du rôle), badge de rôle (à partir de `sm`), menu `account-menu` avec l'avatar (et le nom à partir de `md`).
- Barre latérale (`w-rail`, à partir de `lg`) : carte de profil puis liste des destinations.
- Barre basse (sous `lg`) : une colonne par destination (`nav_grid_class`), au-dessus de l'indicateur système (`pb-safe`).
- Accueil : `shared/home/_skeleton` (`ui_page_header`, puis une `ui_card` par entrée de `HOME_SECTIONS[role]`).

**Destinations** — les noms de route sont le **contrat du Lot 0 de la V1** et ne changent pas :

| Rôle | Destinations (route) |
|---|---|
| `student` | Accueil `student_home_path` · Cours `courses_path` · Ma classe `student_classroom_path` |
| `teacher` | Accueil `teacher_home_path` · Classes `teacher_classrooms_path` · Cours `courses_path` |
| `team` | Accueil `team_home_path` · Cours `courses_path` · Établissements `schools_path` · Pilotage `team_dashboard_path` |
| `school_admin` | Accueil `school_admin_home_path` · Classes `school_admin_classrooms_path` · Enseignants `school_admin_teachers_path` · Élèves `school_admin_students_path` |
| compte | Mon profil `profile_path` · Se déconnecter `session_path` (`DELETE`) |

- Une route pas encore dessinée rend l'entrée **inactive** : `<a>` sans `href`, avec `aria-disabled="true"` et `opacity-50`. Elle n'est pas focusable et ne mène nulle part. Dans le menu du compte, l'entrée devient un `span` `aria-disabled`. En V1, `schools_path`, `team_dashboard_path` et `profile_path` restent inactives.
- Entrée active : l'URL courante (`current_page?`) ou la clé déclarée par la vue (`content_for :nav_key, "courses"`, utile sur une page imbriquée). L'entrée active porte `aria-current="page"` et une icône pleine ; les autres ont une icône au trait.

**Sections d'accueil** (`HOME_SECTIONS`) : élève « À faire », « Ma classe », « Cours » ; enseignant « Mes classes », « Activités », « Cours » ; équipe « Régions éducatives », « Structure scolaire », « Activités » ; direction « Tableau de bord », « Classes », « Activités ».

**Tokens** : ceux de l'UDR-0005 uniquement. Couleur de rôle : `role_accent(role)` (`bg-brand`, `bg-teacher`, `bg-team`, `bg-school`). Entrée active : `bg-brand-soft` (barre latérale) ou pastille `bg-brand-soft` sous l'icône (barre basse). Libellés de la barre basse en `text-2xs`.

**Toasts**
- Région `div#toasts` dans `layouts/application`, `aria-live="polite"`, **jamais** `data-turbo-permanent` (sinon les toasts d'une page survivraient à la suivante).
- Flash : `layouts/application` rend chaque entrée de `flash` par `ui_toast(message, type: toast_type_for(clé))`. `notice` devient `success` et `alert` devient `error` ; `success`, `info`, `warning` et `error` sont repris tels quels ; toute autre clé devient `info`.
- Turbo Stream : `render turbo_stream: helpers.turbo_stream_toast(message, type:)` fait un `append` dans `toasts`. Le message est dans le HTML, jamais reconstruit par le JavaScript.
- Délais : 5 s pour un succès ou une information, 8 s pour un avertissement. Une **erreur reste** jusqu'à sa fermeture et porte `role="alert"`. Le survol et le focus suspendent le délai.

**CRUD Hotwire**
- Le layout commun porte `<turbo-frame id="modal">` (vide) et `#toasts`. Le shell en hérite.
- Ouvrir : un lien `data-turbo-frame="modal"` vers `new` ou `edit`. La vue répond `turbo_frame_tag "modal" { ui_modal(title:, open: true) { form_with … id: "…-form" } }`. La modale s'ouvre dès son arrivée. Le bouton d'envoi, placé dans `modal.footer`, vise le formulaire par `form: "…-form"`.
- Échec : `render :new, status: :unprocessable_entity`. Le frame est remplacé, la modale se rouvre et `ui_field` affiche la première erreur de chaque champ (`aria-invalid`, `aria-describedby`). Les valeurs saisies sont conservées.
- Succès : `render turbo_stream: [turbo_stream_toast(…), turbo_stream.append/replace/remove(…)]`. Le contrôleur `modal` ferme la modale sur `turbo:submit-end` réussi. **Jamais de redirection** depuis un formulaire servi dans le frame « modal » : le frame chercherait sa cible dans la page d'arrivée.
- Fermer (bouton, Échap, fond, succès) vide le frame et retire son `src`, pour que le même lien puisse le recharger.
- Chargement différé : `turbo_frame_tag id, src:, loading: :lazy, class: "block transition-opacity aria-busy:pointer-events-none aria-busy:opacity-50" { ui_loading_state variant: :skeleton }`. La réponse rend le même frame avec ses données ou `ui_empty_state`. Pendant un rechargement, Turbo pose `aria-busy` sur le frame, qui s'estompe.
- Démonstration et test : section « CRUD Hotwire » de `/design` (`GET/POST /design/modal`, `GET /design/frame`).

**États obligatoires** : chaque section d'accueil affiche `ui_loading_state variant: :skeleton` pendant son chargement, `ui_empty_state` sans données et `ui_error_state` en échec (avec `retry_href:` si la section peut être rechargée).

**Accessibilité**
- Lien d'évitement visible au focus, cible `#main`.
- Deux `nav` nommées (« Navigation principale »), dont une seule est visible à une largeur donnée.
- Toutes les entrées ≥ 48 px de haut (`min-h-tap`) ; menu du compte au clavier (motif « menu button », UDR-0005).

**Vérification** : `/design/shell/:role` rend le shell de chaque rôle avec un utilisateur fictif. `test/system/design_system_test.rb` vérifie la barre latérale en bureau, la barre basse et le menu du compte en mobile, l'entrée active et le toast (Turbo Stream et redirection).

## 4. Conséquences

- Ajouter une destination revient à modifier `DESTINATIONS` et la locale `shared.navigation`, **jamais** un partial. Au-delà de 5 destinations pour un rôle, il faut une nouvelle UDR : la barre basse n'en tient pas plus.
- L'accueil d'un rôle n'est « livré » que lorsque ses sections affichent des données réelles et que son test système passe.
- Interdit désormais : un partial de navigation par rôle, un tiroir de navigation mobile, un toast dont le texte est produit côté client, `data-turbo-permanent` sur `#toasts`, un CRUD qui recharge la page ou redirige depuis la modale.

## Amendement du 2026-09-25

*Chantier `docs/chantiers/boucle-pedagogique`. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **`schools_path` devient actif en V1.** Les établissements entrent dans le périmètre de la V1 (ADR-0030, ADR-0034) : le lot S2 de la boucle pédagogique livre leur liste. L'entrée « Établissements » de la navigation `team` est donc active.
- En V1, seules `team_dashboard_path` et `profile_path` restent inactives.
- **Entrée « Imports » (`teams_imports_path`, icône `arrow-up-tray`) ajoutée à la navigation `team`**, entre « Établissements » et « Pilotage », par l'étape e4 du Lot 0e (ADR-0039). La navigation `team` compte maintenant **5 destinations**, le maximum de la règle du §4 : toute destination de plus pour ce rôle exige une nouvelle UDR.
- **Position de la région `#toasts`** : sur ordinateur (`sm` et plus), elle est **en bas à droite**. En haut, un toast recouvrait les actions de l'en-tête de page, comme « Ajouter » (constaté au lot S1). Sur téléphone, elle reste **en haut**, parce que la barre basse porte la navigation. Preuve : `test/system/design_system_test.rb`, « a toast never covers the page header on a desktop ».
