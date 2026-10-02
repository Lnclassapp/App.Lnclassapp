# PRD — Blog de Lnclass

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass n'a aucun contenu public en dehors de sa page d'accueil et de ses pages institutionnelles : elle n'est pas trouvable par ce qu'elle sait, l'équipe démarche les mains vides, les conseils et les nouveautés n'ont pas d'endroit où vivre ([memo](memo.md)). Le blog est un ensemble d'**articles publics**, écrits dans Lnclass par l'équipe (Administration et Contenu), lisibles sans compte à `lnclass.com/blog`, illustrés (couverture et images dans le texte), partageables sur WhatsApp et Facebook avec un aperçu, et indexables par Google. V1 minimale, pour la rentrée et le démarchage : une liste simple, ni rubrique, ni recherche, ni commentaire, ni abonnement, ni publication programmée.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Visiteur** (anonyme, `actor: nil` ; un parent est toujours un visiteur) | Lire la liste des articles publiés et chaque article publié ; voir la page « n'est plus disponible » d'un article archivé | Voir un brouillon (introuvable) ; écrire quoi que ce soit |
| **Élève, enseignant, direction** (connectés) | Lire exactement ce que lit un visiteur ; l'élève a un lien « Blog » au pied de sa carte d'aide | Voir un brouillon ; ouvrir la gestion du blog (refus) |
| **Équipe — Administration (`admin`) et Contenu (`content`)** | Créer, modifier, prévisualiser un brouillon ; publier, archiver, remettre en ligne ; téléverser les images d'un article ; choisir la signature ; lire le compteur de lectures de chaque article | Supprimer un article (on archive) ; publier un article incomplet |
| **Équipe — Terrain (`field`)** | Lire et partager les articles publiés, comme un visiteur | Ouvrir la gestion du blog, créer, modifier, publier, archiver (refus) ; il ne voit pas le raccourci « Blog » de l'accueil équipe |

Règles d'autorisation (domaine) :

- `Policies::Communication::ManageArticlesPolicy` — succès si `actor&.team?` **et** `actor.team_role` ∈ `admin`, `content` ; sinon `:forbidden`. Première policy qui distingue les sous-rôles pour un contenu : amendement de la matrice de l'ADR-0038 (ligne « Blog »), voir ADR-0073.
- `Policies::Communication::ReadArticlePolicy` — article publié : succès pour tous, `actor: nil` compris ; archivé : `:expired` pour qui ne gère pas le blog ; brouillon : `:not_found` pour qui ne gère pas le blog ; succès pour qui le gère, quel que soit l'état.

## 3. Parcours utilisateur

### Chemin nominal A — l'équipe publie un article

1. Un membre Administration ou Contenu ouvre l'accueil équipe et touche le raccourci « Blog » : la liste de gestion montre tous les articles (brouillons, publiés, archivés), leur état, leur date et leur nombre de lectures.
2. « Nouvel article » ouvre la modale d'édition : titre, résumé (une à deux phrases, sert à la liste et à l'aperçu partagé), image de couverture et son texte de remplacement (facultatives), texte (éditeur avec mise en forme et images), signature (« L'équipe Lnclass » par défaut, ou son nom). Un rappel sous l'éditeur dit la règle : aucun élève nommé ni montré ; un enseignant ou un établissement seulement avec son accord.
3. Les images sont réduites par le navigateur avant l'envoi, puis vérifiées par le serveur. Enregistrer crée un **brouillon**.
4. « Aperçu » ouvre l'article tel que le verra un visiteur, avec un bandeau « Brouillon ».
5. « Publier » (menu ⋮) met l'article en ligne immédiatement : il apparaît en tête de la liste publique, dans le plan du site, et le lien « Blog » apparaît au pied de la page d'accueil et de la carte d'aide s'il était le premier.

### Chemin nominal B — un parent lit un article partagé sur WhatsApp

1. Dans un groupe WhatsApp, le lien `lnclass.com/blog/<adresse>` s'affiche avec le titre, le résumé et l'image de couverture (ou l'image par défaut de Lnclass).
2. Le parent ouvre le lien sans compte : la page montre le logo, le retour « Blog », le titre, la signature et la date de publication, la couverture, puis le texte et ses images, chargées à mesure du défilement.
3. En bas, un appel « Découvrir Lnclass » mène à la page d'accueil, et « Tous les articles » à la liste.
4. La lecture est comptée.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun article publié | `/blog` affiche l'état vide « Aucun article pour le moment » ; aucun lien « Blog » n'apparaît sur la page d'accueil ni sur la carte d'aide |
| Brouillon ouvert par son adresse par quiconque ne gère pas le blog | 404 « page introuvable », comme une adresse qui n'a jamais existé |
| Article archivé ouvert par son adresse | 410 : « Cet article n'est plus disponible », lien vers la liste ; absent de la liste et du plan du site |
| Article archivé remis en ligne | Même adresse qu'avant ; date de publication d'origine conservée |
| Titre corrigé après publication | L'adresse ne change pas |
| Deux titres identiques | Deux adresses distinctes (suffixe `-2`, `-3`) |
| Publication d'un article sans titre, sans résumé ou sans texte | Refus (422), le brouillon est conservé, le message nomme le champ |
| Image de format inconnu, trop lourde, trop grande, ou fichier qui n'est pas une image | Refus de l'image à l'envoi, le message dit pourquoi ; rien n'est stocké |
| Image (couverture ou dans le texte) sans texte de remplacement au moment de publier | Refus de publier (422), le message nomme l'image |
| Trop d'images dans un article | Refus de l'image en trop |
| Membre du Terrain, enseignant, direction, élève sur une adresse de gestion | 403, sans effet |
| Visiteur sur une adresse de gestion | Renvoyé à la connexion, comme pour tout écran de l'équipe |
| Auteur désactivé ou anonymisé | Ses articles restent en ligne ; ceux signés de son nom s'affichent signés « L'équipe Lnclass » |
| Personne connectée qui ouvre `/blog` ou un article | Même page qu'un visiteur, sans l'espace connecté ; aucune redirection |
| Lecture par l'équipe, en aperçu, d'un brouillon ou d'un archivé, ou par un robot qui se déclare | Non comptée |
| Une même personne relit l'article | Comptée deux fois (pas de cookie) : limite affichée dans la gestion (« lectures, sans dédoublonnage ») |

## 4. Critères d'acceptation

Chaque critère devient au moins un test, nommé par son identifiant.

```gherkin
# BL-01 — lecture publique
Étant donné un article publié « Réviser le BEPC en 4 semaines »
Quand un visiteur sans compte ouvre /blog
Alors il voit l'article dans la liste, avec son titre, son résumé, sa couverture et sa date
Et la liste est triée du plus récent au plus ancien, paginée

# BL-02 — page d'un article
Étant donné un article publié
Quand un visiteur ouvre /blog/<adresse>
Alors la page répond 200, sans l'espace connecté
Et elle porte un seul h1 (le titre), la signature, la date de publication et le texte assaini

# BL-03 — aperçu partagé et référencement
Étant donné un article publié avec une couverture
Quand on lit l'en-tête HTML de sa page
Alors il contient une meta description (le résumé), og:title, og:description, og:type « article »,
  og:image en adresse absolue vers la couverture, et un lien canonical vers l'adresse de l'article
Et sans couverture, og:image vise l'image par défaut de Lnclass

# BL-04 — brouillon introuvable
Étant donné un brouillon
Quand un visiteur, un élève, un enseignant, une direction ou un membre du Terrain ouvre son adresse
Alors la réponse est 404
Et la page ne contient ni son titre ni son texte

# BL-05 — article archivé
Étant donné un article archivé
Quand un visiteur ouvre son adresse
Alors la réponse est 410 avec « Cet article n'est plus disponible » et un lien vers /blog
Et l'article n'apparaît ni dans la liste ni dans le plan du site

# BL-06 — état vide et liens conditionnels
Étant donné qu'aucun article n'est publié
Quand un visiteur ouvre /blog
Alors il voit « Aucun article pour le moment »
Et ni la page d'accueil ni la carte d'aide de l'élève ne contiennent de lien vers /blog
Mais dès qu'un article est publié, les deux contiennent le lien « Blog »

# BL-07 — qui gère
Étant donné un membre de l'équipe de sous-rôle Administration, puis Contenu
Quand il crée un brouillon, le modifie, le publie, l'archive puis le remet en ligne
Alors chaque geste réussit et est inscrit au journal d'audit

# BL-08 — qui ne gère pas
Étant donné un membre du Terrain, un enseignant, une direction, un élève
Quand il ouvre la gestion du blog ou envoie une création, une modification, une publication ou un archivage
Alors la réponse est 403 et rien ne change en base
Et le membre du Terrain ne voit pas le raccourci « Blog » de l'accueil équipe

# BL-09 — publier exige un article complet
Étant donné un brouillon sans résumé
Quand un administrateur le publie
Alors la publication est refusée (422) avec le champ nommé
Et l'article reste un brouillon

# BL-10 — adresse figée et unique
Étant donné un article publié à l'adresse /blog/reviser-le-bepc
Quand on corrige son titre
Alors son adresse reste /blog/reviser-le-bepc
Et un nouvel article au même titre reçoit /blog/reviser-le-bepc-2

# BL-11 — remise en ligne
Étant donné un article archivé, publié pour la première fois le 2026-10-05
Quand un administrateur le remet en ligne
Alors il répond de nouveau 200 à la même adresse, daté du 2026-10-05

# BL-12 — image vérifiée
Étant donné un fichier renommé en .jpg qui n'est pas une image, puis une image trop lourde, puis un GIF
Quand un administrateur les envoie comme image d'article
Alors chacun est refusé avec sa raison et aucun fichier n'est stocké

# BL-13 — texte de remplacement obligatoire
Étant donné un brouillon dont une image du texte n'a pas de texte de remplacement
Quand un administrateur le publie
Alors la publication est refusée (422) et l'image est nommée

# BL-14 — images servies par Lnclass
Étant donné un article publié avec une couverture et deux images dans le texte
Quand un visiteur ouvre la page
Alors chaque image est servie par une adresse de lnclass.com, lisible sans session, avec un cache public de longue durée
Et l'image d'un brouillon n'est pas lisible par un visiteur

# BL-15 — les cours restent sans image
Étant donné l'éditeur d'un cours ou d'une fiche
Quand on y colle ou dépose une image
Alors elle est toujours refusée (comportement inchangé)

# BL-16 — contenu assaini
Étant donné un texte d'article contenant <script>, un attribut onerror ou un lien javascript:
Quand l'article est enregistré puis affiché
Alors aucun de ces éléments n'atteint la page

# BL-17 — compteur de lectures
Étant donné un article publié lu 0 fois
Quand un visiteur l'ouvre, puis un élève, puis un membre de l'équipe, puis un robot qui se déclare
Alors le compteur vaut 2
Et un aperçu de brouillon ne change aucun compteur
Et l'équipe lit ce nombre dans la gestion du blog

# BL-18 — signature
Étant donné un article signé du nom de son auteur
Quand le compte de l'auteur est désactivé ou anonymisé
Alors l'article s'affiche signé « L'équipe Lnclass »
Et un article signé « L'équipe Lnclass » ne montre jamais le nom de son auteur

# BL-19 — plan du site
Quand un robot lit /sitemap.xml
Alors il contient la page d'accueil, les pages publiques en ligne, /blog et chaque article publié avec sa date
Et aucun brouillon ni article archivé

# BL-20 — connecté sans détour
Étant donné un élève connecté
Quand il ouvre /blog depuis sa carte d'aide
Alors il lit la liste sans être renvoyé vers son accueil

# BL-21 — budgets
Étant donné un article de 1 500 mots avec une couverture et cinq images
Quand un visiteur l'ouvre
Alors le HTML pèse moins de 150 Ko, les images sous la ligne de flottaison se chargent à la demande
Et la page n'ajoute aucun JavaScript au-delà du budget (ADR-0051), sans aucune ressource tierce
```

## 5. Modélisation préliminaire

Contexte borné : **`communication`** (défaut du grill 12, à confirmer). Contrat des use cases : `call` → `Shared::Result` (ADR-0026).

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Communication::Article` (titre ≤ 120, résumé ≤ 200, signature `team`/`author`, statut) ; cycle de vie `draft → published → archived → published` (même table de transitions que l'ADR-0035, sans parent) ; `Entities::Communication::ArticleImage` (format, poids, dimensions, texte de remplacement) ; DTO `Dtos::Communication::ArticleInput` ; ports `Ports::Communication::ArticleRepositoryPort`, `Ports::Communication::ArticleImageStorePort` ; use cases `CreateArticle`, `UpdateArticle`, `PublishArticle`, `ArchiveArticle`, `UploadArticleImage`, `RecordArticleRead` ; policies `ManageArticlesPolicy`, `ReadArticlePolicy` ; actions d'audit `article.published`, `article.archived` |
| Infrastructure | Migration `articles` (`public_id`, `slug` figé et unique, `title`, `excerpt`, `signature`, `status` + CHECK, `published_at`, `archived_at`, `author_id` FK `restrict`, `reads_count`, horodatages) ; `Orm::Article` (`has_rich_text :body`, `has_one_attached :cover`, `has_frozen_slug`) ; repositories `Repositories::Communication::ArticleRepository`, `ArticleImageStore` ; queries `Queries::Communication::PublishedArticlesQuery`, `ArticleDetailQuery`, `TeamArticlesQuery`, `SitemapQuery` ; assainissement partagé avec le catalogue, images d'article seules admises |
| Delivery | Routes publiques `/blog`, `/blog/:slug`, `/sitemap.xml`, adresse publique des images ; routes équipe `/teams/blog` (+ `new`, `edit`, `publish`, `archive`, envoi d'image) ; `Communication::ArticlesController` (`allow_unauthenticated_access`), `Communication::SitemapsController`, `Teams::ArticlesController`, `Teams::ArticleImagesController` |
| UI | Liste publique, page d'article, page « n'est plus disponible », état vide ; liste de gestion, modale d'édition (Trix avec images, pour le blog seul), aperçu ; lien « Blog » au pied de la page d'accueil et de la carte d'aide ; raccourci « Blog » de l'accueil équipe ; balises de partage et de référencement via `content_for :head` |

## 6. Décisions rattachées

- **ADR-0073** — Blog public : articles dans `communication`, adresse lisible figée, images publiques servies par Lnclass, éditeur ouvert aux images pour le blog seul, compteur de lectures côté serveur, plan du site. Amende les ADR-0027 (tables du contexte), 0029 (adresses lisibles), 0038 (matrice de l'équipe, ligne « Blog »), 0047 (fichiers publics), 0051 (Action Text hors cours et fiches).
- **UDR-0064** — Blog public : liste, article, article retiré, état vide, balises de partage ; liens « Blog » de la page d'accueil et de la carte d'aide (amende UDR-0061 et UDR-0063 §3.4).
- **UDR-0065** — Gestion du blog par l'équipe : raccourci de l'accueil équipe, liste de gestion, modale d'édition avec images, aperçu, menu ⋮.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Pages publiques de contenu indexables | 0 | ≥ 5 articles à la sortie (porteur) | |
| p95 serveur `/blog` et `/blog/:slug` (ADR-0067) | — | < 100 ms | |
| Poids HTML d'un article de 1 500 mots (ADR-0067) | — | < 150 Ko | |
| JavaScript ajouté aux pages de lecture | — | 0 Ko (Trix seulement en gestion, chargé à la demande) | |
| Poids d'une image d'article servie | — | ≤ plafond de l'ADR-0073 | |
| Lectures par article, 30 jours après publication | — | suivi, sans cible en V1 | |
