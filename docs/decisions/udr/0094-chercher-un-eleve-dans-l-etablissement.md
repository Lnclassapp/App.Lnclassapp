# UDR-0094 : Chercher un élève dans tout l'établissement, depuis l'accueil de la direction
<!-- index
titre: Recherche d'un élève dans l'établissement, depuis la carte « Établissement » de l'accueil de la direction
statut: Accepté
adr-lie: [0092](../adr/0092-fonctions-de-direction-droits-par-rang-et-changement-de-classe.md)
problematique: La direction ne retrouve un élève qu'en ouvrant sa classe ; un champ sur l'accueil et une page de résultats qui mène à la classe filtrée. Amende UDR-0074 §3.3.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16, Q6) |
| **Date** | 2026-10-16 |
| **Chantier** | `docs/chantiers/espace-direction` |
| **ADR lié** | ADR-0092 (aucune donnée nouvelle ; lecture seule) |
| **Remplacé par** | — |

---

## 1. Contexte

La direction lit ses élèves classe par classe : accueil → niveau → classe → recherche dans la classe (UDR-0074, UDR-0081 §3.7). Un parent appelle pour « Kouassi Aya » : la direction ne sait pas sa classe, et ouvre les classes une à une. Pour retirer un élève de sa classe, il faut d'abord le trouver.

## 2. Décision

- **Un champ « Chercher un élève » dans la carte « Établissement » de l'accueil**, plutôt qu'une entrée de navigation de plus : la direction y arrive à chaque connexion, et la navigation a déjà ses entrées (UDR-0006).
- **Une page de résultats à part** (`GET`, adresse partageable, bouton retour du navigateur), plutôt qu'une liste qui s'ouvre sous le champ : elle marche sans JavaScript et au téléphone.
- **Chaque résultat mène à la page de sa classe, filtrée sur son nom** (paramètre `q` existant de `school_admin/classrooms#show`) : aucune fiche d'élève nouvelle ; le geste (retirer) est sur sa ligne. Toutes les fonctions de direction y ont accès (ADR-0092 §4.3).
- **Le nom seul** : jamais le numéro de téléphone, ni en critère ni en résultat.

## 3. Règles d'implémentation

### 3.1 Champ — `school_admin/classrooms/_school_card`

- En bas de la carte « Établissement » (UDR-0074 §3.3), après les alertes, séparé par `border-t border-line pt-4` :
  `form_with url: school_admin_student_search_path, method: :get, html: { role: "search", "aria-label": "Chercher un élève" }, data: { turbo_frame: "_top" }`.
- `ui_field form, :q, as: :search, label: "Chercher un élève", name: "q", autocomplete: "off", hint: "Nom ou prénom, 3 lettres au moins."`, `minlength: 3`, `maxlength: 80` ; à droite (`sm`) ou dessous (téléphone), `ui_button` « Chercher » (`variant: :secondary`, `type: :submit`).
- Rendu même pour un établissement inactif (lecture).

### 3.2 Page de résultats — `school_admin/student_searches/show`

- `page_title` « Chercher un élève » ; `ui_page_header title: "Chercher un élève"`, lien retour vers l'accueil (brique de retour de `finitions-ux`).
- Le même formulaire qu'au §3.1, valeur gardée, `autofocus` si vide.
- `q` normalisé comme la recherche serveur (`Queries::Shared::TextSearch.normalize`). Moins de 3 caractères après normalisation : aucun appel à la requête, `text-sm text-mute` « 3 lettres au moins. »
- Lecture : `Queries::School::StudentSearchQuery#call(school_id: current_actor.school_id, term:, limit: 21)` → `[Row(student_public_id, display_name, classroom_public_id, classroom_name, level_name)]`, élèves dont l'adhésion principale est active (`left_at` nul) dans une classe active de l'année de l'établissement, compte non anonymisé ; correspondance sur `index_users_on_searchable_full_name` ou `…_reversed_name` (prénom ou nom d'abord) ; tri par nom puis classe.
- `aria-live="polite"` : « %{count} élève(s) trouvé(s). »
- Liste `<ul class="divide-y divide-line">` ; chaque `<li>` est un lien entier `min-h-tap` vers `school_admin_classroom_path(classroom_public_id, q: display_name)`, avec le nom (`font-medium`), puis `text-sm text-mute` « %{classe} · %{niveau} », et un chevron `aria-hidden`.
- 21 lignes lues : 20 affichées, puis `text-sm text-mute` « Affinez votre recherche : 20 premiers résultats. »
- Aucun résultat : `ui_empty_state title: "Aucun élève ne porte ce nom dans vos classes.", icon: "magnifying-glass"` et un bouton « Effacer » vers la page sans `q`.
- Aucune donnée de contact, aucune photo, aucune note dans les résultats.

### 3.3 États

- **Vide** (aucun `q`) : le formulaire seul.
- **Chargement** : `data-turbo-submits-with` « Recherche… ».
- **Erreur** : aucun cas serveur hors 403 (rôle) ; la limite de débit générale s'applique.
- **Succès** : la liste.

### 3.4 Accessibilité

- `role="search"` et `aria-label` sur le formulaire ; `label` visible.
- Le nombre de résultats est annoncé (`aria-live`).
- Chaque lien a un nom accessible complet : « Kouassi Aya, 6ème 3 ».
- Cibles ≥ 48 px.

## 4. Conséquences

- L'UDR-0074 §3.3 : la carte « Établissement » gagne un formulaire en bas.
- Le budget HTML de l'accueil (ADR-0067, < 150 Ko) inclut le champ ; la page de résultats tient sous 100 ms en p95 pour 2 000 élèves.
- Interdit : chercher par numéro de téléphone ; afficher des élèves d'un autre établissement ou retirés.

## 5. Écarts de l'implémentation (2026-10-16)

- Le nom s'affiche « Prénom Nom », comme sur la page de classe (le filtre `q` de `school_admin/classrooms#show` le retrouve tel quel) ; le libellé accessible reste « %{nom}, %{classe} ».
- Le formulaire est un partiel (`school_admin/student_searches/_form`), le même sur la carte et sur la page de résultats ; le bouton « Chercher » passe sous le champ au téléphone, à droite dès `sm`.
- Les lignes ne portent aucun identifiant d'élève : `student_result_<rang>`.
- Pas d'`autofocus` sur la page de résultats : l'UDR-0054 §3.3 l'interdit hors d'`ui_field` (garde `page_titles_test`).
