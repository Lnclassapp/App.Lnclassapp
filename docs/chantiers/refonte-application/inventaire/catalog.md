# Inventaire du contexte borné **catalog** — Lnclass

> Inventaire fonctionnel réalisé en vue de la refonte complète de l'application.
> Objet : **ce que fait l'application**, pas comment elle le fait.
> Périmètre : taxonomie (niveaux, séries, matières), contenu pédagogique (cours → fiches/essentiels),
> système d'import, et organisation scolaire (DRENA → écoles) qui vit dans les mêmes contrôleurs `Catalog::`
> bien qu'elle relève d'ADR-0023.

**Légende des états** : ✅ fonctionne · ⚠️ partiellement cassé · ❌ cassé · 💀 code mort

---

## A. Contenu pédagogique

### Consulter le catalogue des cours
- **Acteur** : tout utilisateur connecté (élève, prof, team, staff). Non connecté → redirigé vers `/` avec « Veuillez vous connecter pour continuer. »
- **Parcours** : `GET /courses` → grille de cartes (icône + couleur par matière, chip niveau + série, matière, titre, sous-titre ou début du contenu, « Ouvrir le cours »). Le bloc d'import JSON n'apparaît que si `team?`.
- **Règles métier** :
  - Seuls les cours dont `status` vaut **`"publié"` ou `"published"`** sont listés (scope `published`). Un `draft` ou un `archived` est invisible pour tout le monde, **y compris son auteur**, sur cette page.
  - Filtres acceptés en query string : `level_id`, `material_id`. **Ils sont silencieusement ignorés** (le contrôleur produit un hash à clés String, le repository lit des clés Symbol).
  - Un filtre `series_id` existe côté repository (sémantique : `series_id IN (NULL, valeur)` — un cours sans série est considéré valable pour toutes les séries) mais n'est jamais alimenté.
  - Pagination stubée (`@pagy.next = nil`) : la liste complète est chargée d'un coup, le bouton « Charger la suite » n'apparaît jamais.
- **Données** : `courses` (+ `levels`, `materials`, `series` pour l'affichage).
- **État** : ⚠️ partiellement cassé (filtres et pagination inopérants).
- **À refaire différemment** : décider une bonne fois du vocabulaire de statut (voir règle implicite n°2) et brancher une vraie pagination.

### Consulter un cours
- **Acteur** : tout utilisateur connecté.
- **Parcours** : `GET /courses/:slug` (le slug ou l'id fonctionnent) → fil d'Ariane (retour vers la matière pour un élève, vers le niveau sinon), titre, badges niveau + matière, image de couverture (placeholder — l'`image_tag` réel est commenté), description riche (ActionText, rendu maths via `data-controller="math"`), puis la section **« Habiletés »** listant les fiches. Menu « Modifier / Supprimer » réservé à `team?`. Introuvable → redirection vers `/courses` avec « Cours introuvable ».
- **Règles métier** : aucun filtre de statut ici — **un brouillon est consultable par n'importe qui via son URL directe**.
- **Données** : `courses`, `essentials`, `exercises`.
- **État** : ✅

### Créer un cours
- **Acteur** : `team` uniquement (`authenticate_team!`).
- **Parcours** : `GET /courses/new` → formulaire → `POST /courses` → redirection vers la fiche du cours, « Cours créé avec succès. » (ou Turbo Stream).
- **Règles métier** :
  - Champs soumis : `name`, `subtitle`, `slug`, `status`, `level_id`, `series_id`, `material_id`, `content`. Le champ `import_data` du formulaire n'est pas dans les paramètres autorisés → **toujours jeté**.
  - Obligatoires (DTO) : `name`, `status`. Obligatoires (base) : `name`, `status`, `level_id`, `material_id`. Série facultative.
  - `name` : max 200 caractères, **unique sur toute la base** (index unique global, pas scopé au niveau ni à la matière).
  - Le nom est **normalisé en `strip.titleize`** avant validation : « les atouts de la côte d'ivoire » devient « Les Atouts De La Côte D'Ivoire ».
  - Le **slug est dérivé du nom par FriendlyId** et régénéré à chaque changement de nom ; unique sur toute la base. Le champ `slug` du formulaire n'existe pas dans l'UI.
  - Statuts proposés par l'UI : `draft` (« Brouillon — Visible uniquement par vous »), `published` (« Publié — Visible par tous »), `archived` (« Archivé — Masqué, mais conservé »). Aucune contrainte en base : `status` est une chaîne libre non nulle.
  - `published_at` (date) existe mais **n'est jamais renseigné** par aucun chemin de code.
  - `image_cover` : champ présent dans le formulaire (direct upload), **non autorisé dans les params** → jamais enregistré.
  - Le sous-titre est marqué `required` en HTML mais n'est validé nulle part côté serveur (max 150 en base).
- **Données** : `courses`.
- **État** : ✅ (aux champs fantômes près : `import_data`, `image_cover`).

### Modifier un cours
- **Acteur** : `team`.
- **Parcours** : `GET /courses/:slug/edit` → `PATCH /courses/:slug`.
- **Règles métier** : identiques à la création.
- **État** : ❌ cassé — bug connu (incohérence `Entities::Catalog::Course` / `Entities::Course`). Concrètement : le niveau, la matière, la série et le statut ne sont pas réassignables, et la sauvegarde lève une erreur avant d'écrire quoi que ce soit. **Aucune donnée n'est perdue, mais aucune modification n'est possible.**

### Supprimer un cours
- **Acteur** : `team`. Confirmation « Supprimer ce cours ? ».
- **Parcours** : `DELETE /courses/:slug` → retour au catalogue, « Cours supprimé. » (si on venait de la page du cours, redirection ; sinon flash Turbo).
- **Règles métier** : la suppression **détruit en cascade toutes les fiches du cours, donc tous leurs exercices, questions, réponses, lacunes (`knowledge_gaps`) et assignations aux classes**. Aucun garde-fou, aucun avertissement sur le volume détruit.
- **État** : ✅ (fonctionne ; c'est la cascade qui est dangereuse).

### Importer des cours en masse depuis un JSON
- **Acteur** : `team` uniquement. Point d'entrée : encart « 📥 Importer des cours depuis JSON » en haut de `/courses`.
- **Parcours** : sélection **multi-fichiers** (`accept: application/json`, au moins un requis) → `POST /courses/import_json` → chaque fichier est écrit dans `tmp/imports/<uuid>_<nom>` et confié à un job asynchrone → redirection immédiate vers `/courses` avec « L'import de vos cours est en cours. ». **Aucun retour sur le résultat de l'import : ni compteur, ni rapport d'erreurs, ni notification.** Le fichier temporaire est supprimé en fin de job dans tous les cas.
- **Format attendu** — tableau d'objets (un objet seul est accepté et enveloppé) ; l'arbre complet cours → fiches → exercices → questions → réponses est importable en une passe :

```json
[{
  "name": "Physique Quantique",
  "level_name": "Tle",
  "material_name": "Physique Chimie",
  "series_name": "D",
  "status": "publié",
  "content": "…",
  "subtitle": "…",
  "essentials": [{
    "name": "Dualité Onde Corpuscule",
    "subtitle": "Les bases",
    "content": "…",
    "exercises": [{
      "title": "…", "description": "…", "exercise_type": "fixation",
      "questions": [{
        "content": "…", "question_type": "single_choice",
        "answers": [{ "content": "…", "is_correct": true }]
      }]
    }]
  }]
}]
```

- **Règles métier** :
  - Clés lues indifféremment en String ou Symbol.
  - `level_name`, `material_name`, `series_name` sont **normalisés en `strip.titleize`** puis résolus par nom. **Si le niveau ou la matière n'existe pas, il est créé à la volée** (`Orm::Level.create!` / `Orm::Material.create!`). Idem pour la série ; la série créée est en plus **rattachée automatiquement au niveau** si le lien n'existe pas.
  - Conséquence : une matière créée par import n'a **ni `shortname` ni `category` explicite** (catégorie par défaut `other`) — alors que le formulaire manuel exige le `shortname`.
  - **Déduplication** : clé `[name.strip.titleize, level_id, material_id]`. Un doublon est compté en `skipped`, pas en erreur. Le set de contrôle est mis à jour au fil de l'eau (pas de doublon intra-fichier).
  - `status` par défaut : **`"draft"`** (l'exemple affiché à l'utilisateur contient pourtant `"publié"`).
  - Exercices : `title` accepte l'alias `name` ; `exercise_type` par défaut **`"fixation"`** ; `published` forcé à **`true`** quel que soit le JSON.
  - Questions : `question_type` par défaut **`"single_choice"`** ; réponses : `is_correct` par défaut `false`.
  - **Tout le fichier est dans une transaction unique** (ADR-0020, bulk). Mais l'échec d'enregistrement d'un cours est seulement collecté dans `errors` sans `raise` → la transaction n'est pas annulée. Le message de l'UI (« En cas d'erreur sur un cours, aucun n'est importé ») **est faux**.
  - En revanche, si une création à la volée de niveau/matière/série échoue (`create!`), l'exception remonte et **tout le fichier est annulé**.
  - Le `team_id` est passé au job puis **ignoré** : un cours importé n'est rattaché à aucune équipe.
- **Données** : `courses`, `essentials`, `exercises`, `questions`, `answers`, `levels`, `materials`, `series`, `level_series`.
- **État** : ⚠️ fonctionne, mais silencieux (aucun feedback) et la promesse d'atomicité est mensongère.
- **À refaire différemment** : persister un rapport d'import (fichier, lignes importées / ignorées / en erreur) consultable dans l'UI, et décider explicitement si la création implicite de taxonomie est souhaitée — aujourd'hui un `"Terminale"` mal orthographié crée un niveau parasite.

### « Import JSON Express » dans les formulaires cours et fiche
- **Acteur** : `team`.
- **Parcours** : zone de collage de JSON en haut des formulaires, censée pré-remplir titre / contenu / niveau / matière.
- **État** : 💀 **code mort** — les contrôleurs Stimulus `course-json-import` et `essential-json-import` n'existent pas. Les deux encarts sont inertes ; les boutons « Appliquer » / « Réinitialiser » ne font rien.

### Lister les fiches d'un cours
- **Acteur** : tout utilisateur connecté ; bouton « Nouvelle Habilité » visible seulement pour un **enseignant** (`current_teacher`) — incohérent avec la création réelle, qui n'est pas protégée par rôle.
- **Parcours** : `GET /courses/:course_id/essentials` → grille des fiches + modale Turbo pour la création.
- **Règles métier** : sans `course_id` → redirection vers `/courses`. Cours introuvable → « Cours introuvable ».
- **État** : ✅

### Consulter une fiche (essentiel / habileté)
- **Acteur** : tout utilisateur connecté. Vocabulaire de l'UI : « Habilité » (sic, sans « e »).
- **Parcours** : `GET /essentials/:slug` → retour vers le cours, titre, placeholder d'image, contenu riche avec « lire plus », encart de validation collaborative, puis la section « 🎯 Exercices » avec le compteur. Pour un **élève connecté**, la progression (sessions et badges) est chargée et injectée dans les cartes d'exercices. Introuvable → « Habilité introuvable ».
- **Règles métier** : aucun filtre de publication sur les fiches — une fiche est visible dès qu'elle existe.
- **Données** : `essentials`, `courses`, `exercises`, `exercise_sessions`, `exercise_badges`.
- **État** : ✅

### Créer une fiche
- **Acteur** : **tout utilisateur connecté** — `EssentialsController` n'a que `authenticate_user!`, **aucun `authenticate_team!`**. N'importe quel élève connecté peut créer, modifier et supprimer des fiches en postant directement. Trou d'autorisation réel.
- **Parcours** : `GET /courses/:course_id/essentials/new` (modale Turbo) → `POST /courses/:course_id/essentials`.
- **Règles métier** :
  - Champs : `name`, `subtitle`, `slug`, `content`. `image_cover` est dans le formulaire mais **non autorisé** → jeté.
  - `name` obligatoire, max 150 caractères, **unique par cours** (index unique `(course_id, name)`).
  - Nom normalisé en `titleize`, slug FriendlyId unique globalement.
  - `subtitle` max 150.
- **État** : ❌ cassé — bug connu (`result.course` au lieu de `result.resource`). **La fiche est bien enregistrée**, puis la réponse plante. En Turbo Stream, l'utilisateur voit une erreur ; en rechargeant, la fiche est là. Risque de double création par clic répété.

### Modifier une fiche
- **Acteur** : tout utilisateur connecté (même trou d'autorisation).
- **Parcours** : `GET /essentials/:slug/edit` → `PATCH /essentials/:slug` → redirection vers la fiche.
- **État** : ❌ cassé — même famille de bug que l'édition de cours : l'entité relue ne porte ni `subtitle`, ni `content`, ni `course_id`, et la sauvegarde lève avant d'écrire. **Aucune modification possible.**

### Supprimer une fiche
- **Acteur** : tout utilisateur connecté (même trou). Confirmation « Supprimer cette habilité ? ».
- **Parcours** : `DELETE /essentials/:slug` → retour au cours, « Habilité supprimée. »
- **Règles métier** : cascade sur **exercices → questions → réponses**, plus les `knowledge_gaps` et les assignations aux classes.
- **État** : ✅

### Importer des fiches dans un cours depuis un JSON
- **Acteur** : tout utilisateur connecté (route `POST /courses/:course_id/essentials/import_json`).
- **Parcours** : upload d'**un seul fichier**, traité **en synchrone** (pas de job) → redirection vers le cours, « Habilités importées avec succès. »
- **Règles métier** : tableau d'objets `{ "name":…, "subtitle":…, "slug":…, "content":…, "image_cover":… }`. Une entrée sans `name` est **silencieusement ignorée**. Le `course_id` vient de l'URL. JSON malformé → « Fichier JSON invalide. ». Aucun fichier → « Veuillez sélectionner un fichier JSON. ». **Aucune déduplication** : ré-importer le même fichier fait échouer l'unicité `(course_id, name)` en base sans message.
- **État** : 💀 inaccessible — le partiel `components/_import_form.html.erb` qui pointe vers cette route **n'est rendu nulle part**. La fonctionnalité n'existe que pour un appel direct.

---

## B. Taxonomie

### Gérer les niveaux
- **Acteur** : lecture pour tout utilisateur connecté ; création / modification / suppression réservées à `team`.
- **Parcours** :
  - `GET /levels` → liste. `GET /levels/:slug` → page « Espace Niveau » : nom, chips des séries associées, carrousel des cours du niveau.
  - `GET /new-level` (route dédiée, chargée dans un turbo-frame depuis le tableau de bord team) → `POST /levels` → retour à `/levels`, « Niveau créé avec succès. »
  - `GET /levels/:slug/edit` → `PATCH /levels/:slug`. `DELETE /levels/:slug`.
- **Règles métier** :
  - `name` obligatoire, **unique**, **max 20 caractères en base** (le formulaire annonce « Maximum 10 caractères » — faux).
  - Nom normalisé en `titleize`, slug FriendlyId.
  - Un niveau porte une liste de **séries associées** (cases à cocher, N-N via `level_series`, couple `(level_id, series_id)` unique). C'est cette association qui pilote la génération automatique des classes.
  - Sur `/levels/:slug`, les cours affichés sont filtrés par la matière de l'enseignant connecté. Pour un élève, le contrôleur tente un filtre par série **que la requête n'implémente pas** → l'élève voit tous les cours du niveau, toutes séries confondues. Aucun filtre de statut : **les brouillons sont visibles ici**.
  - Les blocs `@teacher_material` / `@student_level` des vues ne sont jamais alimentés → le nom de la matière et le lien « Voir tout » ne s'affichent jamais.
  - `levels.name`, `levels.slug` et les listes de niveaux sont **mis en cache 12 h** (`Rails.cache`). L'invalidation après enregistrement porte sur le **nouveau** nom/slug : renommer un niveau laisse l'ancienne clé empoisonnée jusqu'à 12 h.
  - **Suppression : cascade destructrice** — supprimer un niveau détruit **tous ses cours** (donc fiches, exercices, questions, réponses) **et toutes les classes** rattachées. Aucun avertissement au-delà du « Supprimer ce niveau ? ».
  - `/levels/:slug/edit` n'a pas de garde sur l'introuvable → erreur 500 au lieu d'une redirection.
- **Données** : `levels`, `level_series`, `series`, `courses`.
- **État** : ✅ pour le CRUD ; ⚠️ pour la page de détail (filtres inopérants) et le cache.

### Gérer les matières
- **Acteur** : lecture connecté, écriture `team`.
- **Parcours** : `GET /materials`, `GET /materials/:slug` (carrousel « 📚 Mes Cours »), `GET /new-material` → `POST /materials`, `edit` / `update` / `destroy`. Tous les retours pointent vers `/materials`.
- **Règles métier** :
  - `name` obligatoire, **unique**, **max 25 caractères en base** (le formulaire annonce « Maximum 50 caractères » — faux). Normalisé en `titleize`.
  - `shortname` obligatoire (DTO + entité), **max 10 caractères** — sert à l'affichage mobile. En base la colonne est nullable, donc les matières créées par import n'en ont pas.
  - `category` : énumération **`literature` (0) / `science` (1) / `other` (2)**, défaut `other`. Le paramètre est autorisé mais **aucun champ de formulaire ne l'expose** → jamais renseignable manuellement. Elle sert pourtant à la palette de couleurs des cartes de cours.
  - Sur `/materials/:slug`, le contrôleur filtre par niveau et série de l'élève connecté ; **seul le filtre niveau est appliqué** par la requête, la série est ignorée. Pas de filtre de statut → brouillons visibles.
  - Cache 12 h avec la même faiblesse d'invalidation que les niveaux.
  - **Suppression : cascade** — détruit **tous les cours de la matière** et leur descendance ; les enseignants rattachés voient leur `material_id` remis à `NULL`.
  - `edit` sans garde sur l'introuvable → 500.
- **Données** : `materials`, `courses`, `teachers`.
- **État** : ✅ CRUD ; ⚠️ détail.

### Gérer les séries
- **Acteur** : **`team` pour absolument toutes les actions**, y compris `index` et `show` (le `before_action :authenticate_team!` n'a pas de `only:`). Un élève ou un prof ne peut pas consulter la liste des séries.
- **Parcours** : `GET /series`, `GET /series/:slug`, `GET /new-series` → `POST /series`, `edit` / `update` / `destroy`.
- **Règles métier** :
  - `name` obligatoire (message : « Le nom de la série est requis »), **unique**, pas de limite de longueur en base. Normalisé en `titleize`, slug FriendlyId unique.
  - Exemples réels : `C`, `D`, `A1`, `A2`.
  - Une série se rattache aux niveaux depuis le formulaire **du niveau**, pas depuis celui de la série.
  - Suppression : les cours et les classes rattachés voient leur `series_id` remis à `NULL` (pas de cascade destructrice ici).
- **État** : ❌ partiellement cassé :
  - `index` et `show` **n'ont aucun template** (`app/views/catalog/series/` ne contient ni `index.html.erb` ni `show.html.erb`) → erreur de template manquant. Seuls `new`, `edit` et les turbo-streams existent.
  - `update` **ne valide pas le DTO** : un nom vide passe le contrôleur, échoue sur l'entité, et la branche d'erreur lit un champ inexistant → 500.
  - La branche d'erreur de `create` a le même défaut.
  - Autrement dit : créer une série marche tant qu'il n'y a pas d'erreur, la modifier marche tant que le nom est valide, et il n'y a aucune page pour les voir.

---

## C. Organisation scolaire (vit dans `Catalog::`, relève d'ADR-0023)

### Gérer les DRENA (directions régionales)
- **Acteur** : lecture connecté, écriture `team`.
- **Parcours** : `GET /drenas` → liste avec compteur d'écoles. `GET /drenas/:slug` → fil d'Ariane, en-tête, **3 cartes de statistiques** (établissements, enseignants, élèves — les mentions de tendance « +2 ce mois », « +12% » sont **codées en dur**), formulaire d'import d'écoles, liste des écoles avec **recherche par `?query=`** (Turbo Stream, bascule grille/liste via `?view=`). CRUD classique par ailleurs.
- **Règles métier** : `name` obligatoire, **unique**, max 50 caractères, `titleize`, slug FriendlyId. `team_id` rattaché à l'équipe créatrice. **Suppression : cascade sur toutes les écoles → toutes leurs classes → tout leur contenu.**
- **Données** : `drenas`, `schools`.
- **État** : ✅

### Importer des DRENA depuis un JSON
- **Acteur** : `team`. Route `POST /drenas/import_json`. Aucun formulaire ne pointe vers elle dans les vues → **fonctionnalité sans point d'entrée UI**.
- **Format** : tableau de `{ "name": "…" }` — l'alias `"nom"` est accepté.
- **Règles métier** : nom obligatoire ; **doublon détecté par slug** (`name.parameterize`) → l'entrée est ignorée sans erreur ; le `team_id` de l'importateur est appliqué. Traitement asynchrone, fichier temporaire supprimé, **aucun retour utilisateur**. Une exception sur un élément est capturée, compte comme « ignoré », et n'interrompt pas le fichier.
- **Attention** : la détection de doublon compare `name.parameterize` (minuscules, tirets) au slug stocké, lequel est produit par FriendlyId **après `titleize`**. Sur des noms composés cela coïncide le plus souvent, mais ce n'est pas garanti.
- **État** : ⚠️ le code marche, l'UI n'existe pas.

### Gérer les écoles
- **Acteur** : lecture connecté, création via une DRENA.
- **Parcours** : `GET /schools` → « Organisation Scolaire », grille de cartes — **la barre de recherche et le sélecteur de DRENA de cette page sont un mockup non branché** (aucun formulaire, aucune action). `GET /schools/:slug` → liste des classes avec recherche (filtrage en Ruby, insensible à la casse). Création : `GET /drenas/:drena_id/schools/new` → `POST` → retour à la DRENA.
- **Règles métier** :
  - `name` obligatoire, **unique sur toute la base**, max 150 en base (l'entité du domaine dit 200 — incohérent), `titleize`, slug FriendlyId.
  - `schoolsigle` facultatif, max 10 caractères.
  - `schoolstatus` obligatoire : **`draft` / `active` / `inactive`** (chaînes).
  - `schooltype` obligatoire : **`privée` (0) / `public` (1) / `mixte` (2)**.
  - Rattachement obligatoire à une DRENA ; `team_id` = équipe créatrice.
  - **Après création, les classes par défaut sont générées automatiquement** (voir ci-dessous).
  - Suppression : cascade sur classes, inscriptions d'élèves, affectations d'enseignants, rôles et personnel de l'école.
- **État** : ✅ (filtres de `/schools` non fonctionnels).

### Générer automatiquement les classes d'une école
- **Acteur** : déclenché sans intervention, à la création manuelle d'une école **et** à chaque école créée par import.
- **Règles métier** — barème exact, par type d'établissement :

  | Niveau | Public | Privée / mixte |
  |---|---|---|
  | 6ème | 4 classes | 2 |
  | 5ème | 4 | 2 |
  | 4ème | 10 | 4 |
  | 3ème | 10 | 4 |
  | 2nd | 6 **par série** du niveau | 3 par série |
  | 1ère | 6 **par série** du niveau | 3 par série |
  | Tle | C : 2 · D : 6 · A1 : 3 · A2 : 2 | C : 1 · D : 3 · A1 : 2 · A2 : 2 |

  - La clé de configuration est `"public"` si `schooltype == "public"`, **`"privée"` dans tous les autres cas** (donc « mixte » est traité comme privé).
  - **Si le nom de l'école contient « collège » ou « college »** (insensible à la casse), le second cycle (`2nd`, `1ère`, `Tle`) est **entièrement exclu**.
  - Un niveau absent de la base est sauté silencieusement. Les noms de niveaux attendus sont exactement `6ème`, `5ème`, `4ème`, `3ème`, `2nd`, `1ère`, `Tle`, et les séries `C`, `D`, `A1`, `A2`.
  - Pour la Terminale, une série n'est retenue que si elle est **effectivement associée au niveau** via `level_series`.
  - **Nommage** : sans série → `"<Niveau> <n>"` (ex. « 6ème 3 »). Avec série → `"<Niveau> <Série><sep><n>"`, où le séparateur est **une espace si le nom de la série se termine par un chiffre**, rien sinon : « Tle D2 » mais « Tle A1 2 ».
  - Un garde-fou anti-doublon `(nom, école)` existe dans la branche de repli ; la branche principale passe par une insertion en masse.
- **État** : ✅

### Importer des écoles dans une DRENA depuis un JSON
- **Acteur** : `team`. Formulaire visible sur la page d'une DRENA (« Importer », **un seul fichier**).
- **Parcours** : `POST /drenas/:drena_id/schools/import_json` → job asynchrone → « L'import de vos établissements est en cours. » Aucun compte rendu.
- **Format** : tableau d'objets ; alias acceptés :
  - `name` **ou** `nom` — **obligatoire**
  - `schoolsigle` **ou** `sigle`
  - `schoolstatus` **ou** `status` **ou** `statut` — défaut **`"active"`**
  - `schooltype` **ou** `type` — défaut **`"public"`**
- **Règles métier** : doublon détecté par slug (`name.parameterize`) → ignoré ; la DRENA vient de l'URL ; le `team_id` de l'importateur est appliqué ; **chaque école importée déclenche la génération des classes par défaut**. Une valeur de `schoolstatus`/`schooltype` hors énumération fait échouer l'enregistrement en base — l'exception est capturée, l'élément compté « ignoré », l'import continue.
- **État** : ⚠️ fonctionne, aucun feedback.

### Rôles et personnel d'école
- **Acteur** : tout utilisateur connecté (aucune restriction de rôle).
- **Parcours** : `GET|POST /schools/:school_id/school_roles` (création d'un rôle nommé, suppression) ; `GET|POST /schools/:school_id/school_staffs` — **on ajoute un membre en saisissant son contact téléphonique** ; si aucun utilisateur ne correspond → « Utilisateur non trouvé avec ce contact. »
- **État** : ✅ pour le chemin nominal. Pas de vue `edit`. À traiter avec le contexte `school`.

---

## D. Validation collaborative (ADR-0011)

- **État** : 💀 **entièrement morte**. Il ne reste que deux partiels décoratifs (`community_validations/_card` affiche un badge statique « Validation collaborative / Conforme au programme », `_success` un message de remerciement jamais déclenché). Il n'y a **ni table `community_validations`, ni entité, ni use case, ni contrôleur, ni route**. Le helper `show_community_validation?` fait `return false unless teacher?` puis `false` inconditionnel. Les colonnes `essentials.validated_at` et `essentials.validated_by` existent en base et ne sont **jamais lues ni écrites**.
- **À refaire différemment** : la fonctionnalité est à concevoir de zéro. L'ADR-0011 décrit une intention (double évaluation « Exactitude » / « Conformité », relation polymorphe `validatable_type` / `validatable_id`, un vote par enseignant écrasant le précédent, champ `error_description` obligatoire si `is_correct == false`, retour en Turbo Stream) qui n'a jamais été implémentée.

---

## 1. Tables du contexte (colonnes et index)

### `courses`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | varchar(200) | NOT NULL |
| `slug` | varchar | NOT NULL |
| `subtitle` | varchar(150) | — |
| `status` | varchar | NOT NULL (chaîne libre, pas d'énumération) |
| `level_id` | bigint | NOT NULL |
| `material_id` | bigint | NOT NULL |
| `series_id` | bigint | nullable |
| `essentials_count` | integer | défaut 0, NOT NULL |
| `published_at` | date | nullable |
| `import_data` | jsonb | défaut `{}` |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `level_id` · `material_id` · `series_id` · `import_data` (GIN).
Le contenu riche `content` vit dans `action_text_rich_texts` (ActionText), l'image de couverture dans Active Storage.

### `essentials`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `course_id` | bigint | NOT NULL |
| `name` | varchar(150) | NOT NULL |
| `slug` | varchar | NOT NULL |
| `subtitle` | varchar(150) | — |
| `exercises_count` | integer | défaut 0, NOT NULL (compteur de cache **actif**) |
| `validated_at` | date | jamais écrite |
| `validated_by` | integer | jamais écrite |
| `import_data` | jsonb | défaut `{}`, jamais écrite |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `(course_id, name)` **unique** · `course_id` · `import_data` (GIN).
**Pas d'index unique sur `slug`**, contrairement à toutes les autres tables du contexte.

### `levels`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | varchar(20) | — |
| `slug` | varchar | — |
| `public_id` | varchar | — |
| `team_id` | bigint | nullable, jamais renseigné |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `public_id` **unique** · `team_id`.

### `series`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | varchar | NOT NULL |
| `slug` | varchar | NOT NULL |
| `public_id` | varchar | NOT NULL |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `public_id` **unique**.
**Pas de `team_id`** (contrairement à `levels` et `materials`).

### `materials`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | varchar(25) | NOT NULL |
| `shortname` | varchar(10) | nullable en base, obligatoire côté domaine |
| `slug` | varchar | — |
| `category` | integer | défaut 2 (`other`) — `literature`=0, `science`=1, `other`=2 |
| `public_id` | varchar | — |
| `team_id` | bigint | nullable, jamais renseigné |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `public_id` **unique** · `team_id`.

### `level_series` (jointure N-N niveaux ↔ séries)
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `level_id` | bigint | NOT NULL |
| `series_id` | bigint | NOT NULL |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `(level_id, series_id)` **unique** · `level_id` · `series_id`.

### `drenas`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `name` | varchar(50) | — |
| `slug` | varchar | — |
| `public_id` | varchar | — |
| `team_id` | bigint | nullable |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `public_id` **unique** · `team_id`.

### `schools`
| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `drena_id` | bigint | NOT NULL |
| `name` | varchar(150) | NOT NULL |
| `schoolsigle` | varchar(10) | — |
| `schoolstatus` | varchar | NOT NULL — `draft` / `active` / `inactive` |
| `schooltype` | integer | `privée`=0, `public`=1, `mixte`=2 |
| `slug` | varchar | NOT NULL |
| `public_id` | varchar | — |
| `team_id` | bigint | nullable |
| `created_at` / `updated_at` | datetime | NOT NULL |

Index : `name` **unique** · `slug` **unique** · `public_id` **unique** · `drena_id` · `team_id`.

### `friendly_id_slugs`
Historique des slugs, alimenté par FriendlyId pour toutes les tables ci-dessus. Permet la résolution des anciennes URL après renommage.

---

## 2. Règles métier implicites à rendre explicites

1. **Tout nom est `titleize`é avant enregistrement.** Niveaux, séries, matières, cours, fiches, écoles, DRENA : l'utilisateur ne saisit jamais le nom qu'il verra. « SVT » devient « Svt », « côte d'ivoire » devient « Côte D'Ivoire ». C'est une décision produit majeure, cachée dans un concern d'infrastructure.

2. **Le vocabulaire des statuts de cours est incohérent sur trois plans.** La base accepte n'importe quelle chaîne ; l'UI propose `draft` / `published` / `archived` ; le filtre de visibilité accepte `"publié"` **ou** `"published"` ; l'import par défaut écrit `"draft"` mais l'exemple montré à l'utilisateur écrit `"publié"`. Il faut trancher : une énumération unique, et `archived` doit avoir un comportement défini (aujourd'hui il est simplement « non publié », strictement équivalent à `draft`).

3. **Le nom d'un cours est unique sur toute la plateforme**, pas par niveau ni par matière. Deux niveaux ne peuvent pas avoir un cours « Les Fractions ». La déduplication de l'import raisonne pourtant sur `(nom, niveau, matière)` : l'import est plus permissif que la base, et échoue donc là où il croit réussir.

4. **Il n'y a aucune notion de propriété du contenu.** `courses`, `essentials` et `exercises` n'ont pas de `team_id` ni d'auteur. Le `team_id` transmis à l'import de cours est ignoré. La seule autorisation est « être de rôle `team` » — donc toute équipe peut éditer le contenu de toute autre. Le statut `draft` promet « Visible uniquement par vous » alors que rien ne permet de savoir qui est « vous ».

5. **La suppression d'un élément de taxonomie détruit du contenu pédagogique.** Supprimer un niveau ou une matière détruit en cascade tous les cours associés, leurs fiches, exercices, questions, réponses et l'historique de lacunes des élèves. C'est irréversible et présenté à l'utilisateur comme un simple « Supprimer ce niveau ? ».

6. **Les brouillons ne sont cachés que sur `/courses`.** Les pages niveau, matière et l'URL directe d'un cours les affichent à tout le monde, élèves compris. Le statut n'est donc pas un contrôle de visibilité mais un filtre d'index.

7. **La taxonomie se crée toute seule à l'import.** Un niveau, une matière ou une série inconnue est créée à la volée, et une série importée est automatiquement rattachée au niveau du cours. Il n'y a aucun référentiel figé des niveaux et séries du système ivoirien — pourtant tout le générateur de classes en dépend nommément.

8. **Le générateur de classes encode le système scolaire ivoirien en dur** : noms de niveaux, noms de séries, barèmes par type d'établissement, règle « si le nom contient *collège*, pas de second cycle ». C'est de la connaissance métier dans une constante Ruby.

9. **`courses.essentials_count` n'est jamais mis à jour** (pas de compteur de cache sur la relation fiche → cours), contrairement à `essentials.exercises_count` qui l'est. Toute UI qui affiche le nombre de fiches d'un cours affiche 0.

10. **Le catalogue est mis en cache 12 heures** (niveaux, matières, séries — sous deux jeux de clés concurrents : `catalog/levels/all` et `catalog_levels`, invalidés séparément et incomplètement). Une modification peut mettre jusqu'à 12 h à se propager, et un renommage laisse l'ancienne clé servir de la donnée périmée.

11. **Le contrôleur des fiches n'exige aucun rôle.** Seul `authenticate_user!` le protège : n'importe quel compte peut créer, modifier, supprimer une fiche et importer un JSON de fiches. Tous les autres contrôleurs du catalogue exigent `team`.

12. **Un cours sans série vaut pour toutes les séries** (`series_id IN (NULL, valeur)`), règle implicite du filtre, jamais énoncée dans l'interface où la série est libellée « Optionnel ».

13. **Les imports sont asynchrones et muets.** Aucun rapport, aucune notification, aucune trace persistée. L'utilisateur ne sait jamais combien de lignes ont été importées, ignorées ou rejetées, ni pourquoi.

14. **Les colonnes `import_data` (jsonb, indexées GIN) sur `courses`, `essentials` et `exercises` ne sont jamais écrites par le catalogue** — seul le contrôleur d'exercices en accepte le paramètre. Elles étaient prévues pour tracer l'origine des données importées.

15. **Les limites de longueur annoncées dans les formulaires sont fausses.** Niveau : « Maximum 10 caractères » pour une colonne de 20. Matière : « Maximum 50 caractères » pour une colonne de 25. L'entité `School` valide 200 caractères pour une colonne de 150.

---

## 3. Ce que je n'ai pas pu déterminer

- **La finalité de `courses.published_at`** : la colonne existe, le DTO la transporte, aucune UI ni aucun code ne la renseigne. Publication différée abandonnée, ou date de publication historique jamais branchée ?
- **La sémantique attendue du statut `archived`** : aucun code ne le distingue de `draft`.
- **Ce que devaient contenir `import_data`, `essentials.validated_at` et `essentials.validated_by`** : format et règles jamais implémentés.
- **Le rôle de `levels.team_id` et `materials.team_id`** : renseignés nulle part dans le catalogue, alors que `series` n'en a pas. Cloisonnement de la taxonomie par équipe abandonné en cours de route ?
- **Si l'import de cours doit rester silencieux ou si un rapport était prévu** : rien dans le code, rien dans les vues, rien dans les ADR.
- **Le partage du contexte avec `school`** : DRENA, écoles, rôles et personnel sont servis par des contrôleurs `Catalog::` mais relèvent d'ADR-0023 et de `UseCases::School` / `Repositories::Identity::`. Je les ai inventoriés, mais la frontière exacte entre « catalogue » et « organisation scolaire » dans la refonte est une décision produit. J'ignore si un autre agent couvre `school`.
- **La cohérence des noms de séries entre `level_series` et le générateur de classes en production** : le générateur exige des séries nommées exactement `C`, `D`, `A1`, `A2` et associées aux bons niveaux. `db/seeds.rb` ne contient aucune donnée métier, je n'ai donc pas pu vérifier l'état réel du référentiel.

---

## 4. Code mort à ne pas reconduire

| Élément | Chemin |
|---|---|
| `UseCases::Catalog::CreateCourse` (jamais appelé, appelle un `save` inexistant sur le repository) | `app/domain/use_cases/catalog/create_course.rb` |
| `Strategies::CourseImportStrategy` (remplacé par `bulk_import_courses`) | `app/domain/strategies/course_import_strategy.rb` |
| `Repositories::CatalogRepository` + `Ports::CatalogRepositoryPort` (façade jamais instanciée, délègue à deux méthodes inexistantes : `find_courses`, `create_course_with_essentials_and_exercises`) | `app/infrastructure/repositories/catalog_repository.rb`, `app/domain/ports/catalog_repository_port.rb` |
| `Queries::CatalogQuery#get_catalog` | `app/infrastructure/queries/catalog_query.rb:9` |
| `CourseRepository#find_exercises_for_essential` (`map_exercise` a un corps vide → renvoie `[nil]`) | `app/infrastructure/repositories/catalog/course_repository.rb:234` |
| `CourseRepository#find_course_by_name_and_level_and_material` | `app/infrastructure/repositories/catalog/course_repository.rb:100` |
| `Catalog::GenerateSchoolDemoDataJob` (jamais mis en file) | `app/jobs/catalog/generate_school_demo_data_job.rb` |
| Encarts « Import JSON Express » (contrôleurs Stimulus `course-json-import` et `essential-json-import` absents) | `app/views/catalog/courses/_form.html.erb:29`, `app/views/catalog/essentials/_form.html.erb:12` |
| Partiel d'import de fiches (jamais rendu, la route existe pourtant) | `app/views/components/_import_form.html.erb` |
| Validation collaborative (coquille purement décorative) | `app/views/community_validations/` |
| Double jeu d'entités concurrentes `Entities::X` (racine) vs `Entities::Catalog::X` — **cause racine des trois bugs d'édition** | `app/domain/entities/` |
