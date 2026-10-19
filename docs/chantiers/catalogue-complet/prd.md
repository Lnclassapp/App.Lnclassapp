# PRD — Catalogue complet : pages publiques Niveau, Matière et Série

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Statut : accepté le 2026-10-16.** Le porteur a accepté les recommandations du [memo](memo.md#ce-que-le-grill-a-révélé). Écart d'exécution : le nom du niveau est celui du référentiel (« Tle », pas « Terminale » des exemples) ; le fil d'Ariane devient un lien de retour (UDR-0054).

## 1. Contexte

Le filtre du catalogue (CA-02), sa pagination (CA-03) et le filtrage des brouillons (CA-01) sont livrés ; la page d'une fiche liste ses exercices publiés (AS-01 corrigée). Il manque les pages qui présentent le programme par niveau (CA-17), par matière (CA-21) et par niveau et série (CA-23). Elles se lisent sans compte, ne montrent que les titres des cours publiés, s'indexent en production et mènent à l'inscription (ADR-0099).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur sans compte | Lire `/niveaux`, un Espace Niveau, une page niveau × série, une page matière ; suivre « Créer mon compte élève » | Lire un brouillon ou un archivé, même son titre ; ouvrir un cours, une fiche ou un exercice depuis ces pages |
| Student | La même page que le visiteur, appel à l'action « Voir mes cours » | Ouvrir un contenu hors de son niveau (404 inchangé, ADR-0035) ; voir sa progression sur ces pages |
| Teacher, direction, Team | La même page, appel à l'action « Ouvrir le catalogue » | Voir un brouillon sur ces pages (l'équipe les voit dans `/courses`) |
| Robot d'indexation | Lire les pages et `/sitemap.xml` sur un hôte de production | Indexer Staging ou Develop (`X-Robots-Tag`, inchangé) |

Règle d'autorisation : aucune policy. La portée tient dans `Queries::Catalog::PublicCourses.scope` (`courses.status = 'published'`), seule portée lue par les requêtes publiques (ADR-0099 §4.2).

## 3. Parcours utilisateur

### Chemin nominal

1. Un parent cherche « cours Terminale D Lnclass » et arrive sur `/niveaux/tle/d`.
2. Il voit « Cours de Terminale D », les autres séries (C, A1, A2), puis les cours groupés par matière, six au plus par matière.
3. Il touche « Voir les 14 cours » sous Mathématiques : `/matieres/mathematiques?niveau=tle&serie=d` s'ouvre, 24 cours puis la suite au défilement.
4. Il touche « Créer mon compte élève » : l'inscription élève s'ouvre.
5. Un visiteur de la homepage touche « Physique-Chimie » dans la bande « Matières » : `/matieres/physique-chimie` s'ouvre, cours groupés par niveau, pastilles de niveau.
6. Il touche la pastille « 3e » : seuls les cours de 3e restent ; l'adresse devient `?niveau=3eme`.
7. Au pied de la homepage, « Les cours par niveau » ouvre `/niveaux` : premier et second cycle, un niveau par case.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Slug de niveau, de série ou de matière inconnu | 404 « Page introuvable. » |
| Série existante non rattachée au niveau (`/niveaux/6eme/d`) | 404 |
| `?niveau=` inconnu ou sans cours de la matière | 404 |
| `?serie=` sans `?niveau=` | 404 |
| Niveau, série ou matière sans cours publié | Page avec état vide, `noindex`, absente du plan du site, de `/niveaux` et des pastilles |
| Cours dépublié, archivé ou retiré | Absent à la requête suivante |
| Plus de 6 cours d'une matière sur l'Espace Niveau ou la page série | Lien « Voir les N cours » vers la page matière filtrée |
| Plus de 24 cours sur la page matière | Page suivante au défilement ; sans JavaScript, « Afficher plus de cours » |
| Personne connectée | Même page, sans shell, sans redirection ; appel à l'action selon le rôle |
| Élève de Tle D sur `/niveaux/6eme` | Il voit les titres ; aucun lien vers ces cours ; `/courses` et les portes du contenu inchangés |
| Enseignant en attente (sans établissement) | Page publique lisible ; l'espace connecté le retient toujours |
| App Android | Page web dans la coque, sans règle nouvelle |
| Hôte Staging ou Develop | `X-Robots-Tag: noindex, nofollow` (inchangé) |

## 4. Critères d'acceptation

```gherkin
# CC-01 Liste des niveaux
Étant donné des cours publiés en 6e, 3e et Terminale, et aucun en 5e
Quand un visiteur ouvre /niveaux
Alors il voit « Premier cycle » avec 6e et 3e, et « Second cycle » avec Terminale
Et la 5e n'est pas listée
Et chaque niveau donne son nombre de cours publiés

# CC-02 Liste vide
Étant donné qu'aucun cours n'est publié
Quand un visiteur ouvre /niveaux
Alors il voit « Les cours arrivent bientôt. »
Et la page porte la balise robots « noindex »

# CC-03 Espace Niveau groupé dans l'ordre du programme
Étant donné des cours publiés de Terminale en SVT, Mathématiques et Philosophie
Quand un visiteur ouvre /niveaux/tle
Alors le titre est « Cours de Terminale »
Et les groupes viennent dans l'ordre Mathématiques, SVT, Philosophie (rang des matières)
Et chaque titre de groupe donne le nombre de cours de la matière à ce niveau

# CC-04 Six cartes par matière
Étant donné 9 cours publiés de Mathématiques en Terminale
Quand un visiteur ouvre /niveaux/tle
Alors le groupe Mathématiques montre 6 cartes
Et un lien « Voir les 9 cours » mène à /matieres/mathematiques?niveau=tle

# CC-05 Séries du niveau
Étant donné la Terminale rattachée aux séries C et D, avec des cours publiés en D seulement et aucun cours sans série
Quand un visiteur ouvre /niveaux/tle
Alors il voit la pastille « Terminale D » vers /niveaux/tle/d
Et pas de pastille « Terminale C »

# CC-06 Jamais un brouillon ni un archivé
Étant donné, en Terminale et en Mathématiques, un cours publié « Suites », un brouillon « Intégrales » et un archivé « Limites »
Quand un visiteur ouvre /niveaux/tle, /niveaux/tle/d et /matieres/mathematiques
Alors il voit « Suites »
Et le HTML ne contient ni « Intégrales » ni « Limites »
Et les nombres de cours ne les comptent pas

# CC-07 Une carte ne mène à aucun contenu
Étant donné un visiteur sur /niveaux/tle
Alors une carte montre le nom et la description du cours
Et la page ne contient aucun lien vers /courses/, /exercises/ ni vers une fiche

# CC-08 Appel à l'action selon la session
Étant donné une page publique du catalogue
Quand un visiteur l'ouvre
Alors il voit « Créer mon compte élève » vers l'inscription élève et « J'ai déjà un compte » vers la connexion
Quand un élève connecté l'ouvre
Alors il voit « Voir mes cours » vers /courses
Quand un enseignant connecté l'ouvre
Alors il voit « Ouvrir le catalogue » vers /courses
Et aucune de ces personnes n'est redirigée

# CC-09 Page matière groupée par niveau
Étant donné des cours publiés de Physique-Chimie en 4e, 3e et Terminale
Quand un visiteur ouvre /matieres/physique-chimie
Alors il voit les groupes 4e, 3e, Terminale dans cet ordre
Et les pastilles « Tous les niveaux », « 4e », « 3e », « Terminale », la première active

# CC-10 Filtre de niveau
Étant donné un visiteur sur /matieres/physique-chimie
Quand il touche la pastille « 3e »
Alors l'adresse devient /matieres/physique-chimie?niveau=3eme
Et le titre devient « Physique-Chimie en 3e »
Et seuls les cours de 3e restent

# CC-11 Pagination de la page matière
Étant donné 30 cours publiés de Mathématiques
Quand un visiteur ouvre /matieres/mathematiques
Alors il voit 24 cartes
Et les 6 suivantes se chargent quand il descend en bas de la page
Et sans JavaScript, « Afficher plus de cours » ouvre la page 2
Et le titre d'un niveau déjà ouvert n'est pas répété

# CC-12 Adresses inconnues
Quand un visiteur ouvre /matieres/inconnue, /matieres/mathematiques?niveau=inconnu, /matieres/mathematiques?serie=d ou /niveaux/inconnu
Alors la réponse est 404

# CC-13 Matière sans cours publié
Étant donné une matière « Espagnol » sans cours publié
Quand un visiteur ouvre /matieres/espagnol
Alors il voit « Les cours de cette matière arrivent bientôt. »
Et la page porte la balise robots « noindex »

# CC-14 Page série : la série et les cours communs
Étant donné en Terminale un cours publié « Suites » de série D, « Mécanique » de série C et « Philosophie morale » sans série
Quand un visiteur ouvre /niveaux/tle/d
Alors le titre est « Cours de Terminale D »
Et il voit « Suites » et « Philosophie morale »
Et il ne voit pas « Mécanique »

# CC-15 Série non rattachée
Étant donné la série D non rattachée à la 6e
Quand un visiteur ouvre /niveaux/6eme/d
Alors la réponse est 404

# CC-16 Autres séries
Étant donné la Terminale avec des cours en C et en D
Quand un visiteur ouvre /niveaux/tle/d
Alors la pastille « Terminale D » est active, sans lien
Et la pastille « Terminale C » mène à /niveaux/tle/c

# CC-17 Suite d'une matière dans la série
Étant donné 8 cours de Mathématiques visibles en Terminale D
Quand un visiteur touche « Voir les 8 cours »
Alors il arrive sur /matieres/mathematiques?niveau=tle&serie=d
Et le titre est « Mathématiques en Terminale D »

# CC-18 Couple niveau × série vide
Étant donné la série A1 rattachée à la Terminale, sans cours de A1 ni cours sans série
Quand un visiteur ouvre /niveaux/tle/a1
Alors il voit « Les cours de Terminale A1 arrivent bientôt. » et « Voir la Terminale »
Et la page porte la balise robots « noindex »

# CC-19 La règle de l'élève ne change pas
Étant donné un élève de Tle D connecté
Quand il ouvre /niveaux/6eme
Alors il voit les titres des cours de 6e
Quand il ouvre /courses
Alors il ne voit que les cours de son niveau
Quand il ouvre l'adresse d'un cours de 6e
Alors la réponse est 404

# CC-20 Aucun cache partagé
Quand un visiteur ouvre une page publique du catalogue
Alors l'en-tête Cache-Control ne contient pas « public »
Et un cours publié puis dépublié disparaît à la visite suivante

# CC-21 Plan du site
Étant donné des cours publiés en Terminale D et en Mathématiques, et aucun en 5e
Quand un robot lit /sitemap.xml
Alors il y trouve /niveaux, /niveaux/tle, /niveaux/tle/d et /matieres/mathematiques en adresses canoniques
Et il n'y trouve ni /niveaux/5eme, ni une adresse avec « page », « niveau » ou « serie »

# CC-22 Points d'entrée de la homepage
Étant donné des cours publiés en Mathématiques et en SVT, et aucun en Philosophie
Quand un visiteur ouvre la homepage
Alors la bande « Matières » montre Mathématiques et SVT, dans l'ordre du programme, chacune vers sa page
Et ne montre pas Philosophie
Et le pied de page a un lien « Les cours par niveau » vers /niveaux

# CC-23 Budget
Quand on mesure les quatre pages avec script/perf/audit_pages.rb sur le jeu de l'ADR-0067
Alors chacune répond en moins de 100 ms serveur, pèse moins de 150 Ko de HTML et fait au plus trois requêtes SQL de lecture du catalogue
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | **Aucun** : ni entité, ni port, ni use case, ni policy (lecture CQRS, ADR-0099 §4.2) |
| Infrastructure | `Queries::Catalog::PublicCourses` (portée, `Card`, ordre) ; `PublicLevelsQuery` (liste et Espace Niveau) ; `PublicSeriesQuery` ; `PublicMaterialQuery` ; `PublicSitemapQuery` ; `Queries::Catalog::HomepageMaterialsQuery` (bande de la homepage). Aucune migration |
| Delivery | 4 routes dans `config/routes/catalog.rb` ; `Catalog::PublicController` ; `Catalog::LevelPagesController` (`index`, `show`) ; `Catalog::SeriesPagesController#show` ; `Catalog::MaterialPagesController#show` ; `Communication::SitemapsController#show` étendu ; `HomepageController` lit les matières |
| UI | `catalog/public/_header`, `_footer`, `_head`, `_call_to_action`, `_course_card`, `_material_group` ; `catalog/level_pages/index`, `show` ; `catalog/series_pages/show` ; `catalog/material_pages/show`, `_page`, `_page_frame` ; `communication/sitemaps/show.xml.builder` ; `homepage/index` (bande et pied) ; `config/locales/catalog/public.fr.yml`, `config/locales/homepage/index.fr.yml` |

## 6. Décisions rattachées

- [ADR-0099](../../decisions/adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md) — lecture sans compte, titres seulement, référencement, aucun cache HTML (Proposé)
- [UDR-0113](../../decisions/udr/0113-pages-publiques-du-catalogue-gabarit-liste-des-niveaux-et-espace-niveau.md) — gabarit commun, `/niveaux`, Espace Niveau (Proposé)
- [UDR-0114](../../decisions/udr/0114-page-publique-d-une-matiere.md) — page matière (Proposé)
- [UDR-0115](../../decisions/udr/0115-page-publique-d-un-niveau-et-de-sa-serie.md) — page niveau × série (Proposé)
- Inchangés et lus : ADR-0029 (slugs figés), ADR-0035 et son second amendement, ADR-0067, ADR-0074, ADR-0076, ADR-0090 ; UDR-0013, UDR-0059, UDR-0063, UDR-0066, UDR-0085

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Pages du catalogue lisibles sans compte | 0 | `/niveaux` + 1 par niveau, couple niveau × série et matière ayant un cours publié | Atteint (tests d'intégration CC-01 à CC-18) |
| Adresses du catalogue dans `/sitemap.xml` | 0 | idem | Atteint (CC-21) |
| Temps serveur de chaque page (ADR-0067) | — | < 100 ms | p50 de 16 à 23 ms (`audit_pages.rb`, visiteur, 200 cours publiés), 23 à 60 ms sur une seconde mesure, machine partagée |
| Requêtes SQL du catalogue par page | — | ≤ 3 | 2 (`/niveaux`) ou 3 ; 4 pour la page matière avec `?serie=` ; plus 1 pour le lien « Blog » du pied |
| Poids du HTML | — | < 150 Ko | 10 à 26 Ko |
