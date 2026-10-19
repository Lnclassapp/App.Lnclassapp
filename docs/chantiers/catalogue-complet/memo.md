# Memo — Catalogue complet : pages publiques Niveau, Matière et Série

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — questions au porteur ouvertes |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `docs/cadrage-catalogue-complet` (cadrage, docs seules) ; le code passera par `feature/catalogue-complet` et une PR |
| **Programme** | [`refonte-application`](../refonte-application/feuille-de-route.md), vague **V4**, premier chantier de la vague |

---

## Le problème

La feuille de route range six features dans `catalogue-complet` : CA-02, CA-03, CA-17, CA-21, CA-23, AS-01, plus la partie V4 de CA-01 ([§5, V4](../refonte-application/feuille-de-route.md#v4--contenu-à-léchelle-et-back-office-équipe)). Depuis le recadrage du 2026-09-28, plusieurs chantiers livrés hors ordre ont touché le catalogue : `politique-cache` (pagination), `interface-enseignant-organisation` (filtres de l'enseignant), `catalogue-niveau-eleve`, `epuration-contenus` et `cours-eleve`, fusionné le 2026-10-15 (#246). Une partie du périmètre est donc déjà livrée sans que la feuille de route le dise.

Ce qui manque vraiment : **aucune page ne présente le programme de Lnclass par niveau, par matière ou par série**. Un visiteur sans compte ne voit rien du contenu (la homepage affiche sept noms de matières écrits en dur, sans lien). Une personne connectée ne trouve les cours d'un niveau qu'en filtrant le catalogue. Google n'indexe que la homepage, `/aide`, les pages juridiques et le blog.

## Pour qui

- **Le visiteur sans compte** (futur élève, parent, enseignant) qui arrive depuis Google, un lien WhatsApp ou la homepage, et veut savoir si Lnclass couvre « Terminale D » ou « les maths de 3e » avant de créer un compte.
- **La personne connectée** (élève, enseignant, direction, équipe) qui suit le même lien : elle voit la même page.
- **L'équipe** (Contenu) indirectement : chaque cours publié devient une vitrine.

## Pourquoi maintenant

Le porteur a demandé le 2026-10-16 de lancer les vagues V2 à V6. `catalogue-complet` est le premier chantier de la V4 et peut chevaucher la V2 (contexte `catalog` disjoint, [tableau de collision](../refonte-application/feuille-de-route.md#chevauchement-v2--v4--tableau-de-collision)). La page Cours de l'élève vient d'être livrée : le catalogue est stable, ses requêtes et ses cartes sont fraîches.

## Inventaire au 2026-10-16

Relevé dans le code de `origin/Develop` (`d1226437`).

| Feature | Ce que demandait l'inventaire | État aujourd'hui | Preuve | Reste à faire |
|---|---|---|---|---|
| **CA-01** (partie V4) | Le niveau et la matière ne filtraient pas les brouillons | ✅ **Livrée.** Hors équipe, seul le publié est lu, sur la liste comme sur les portes d'un cours, d'une fiche, d'un exercice | `Queries::Catalog::CourseCatalogQuery#filtered` (`status = 'published'` hors équipe) ; `Policies::Catalog::ReadPublishedPolicy` | Rien |
| **CA-02** Filtrer par niveau ou matière | Filtres absents de la page | ✅ **Livrée.** Équipe et direction : Niveau, Série, Matière et recherche. Enseignant : ses niveaux et séries, sa seule matière (UDR-0077 §3.2). Élève : pas de filtre (décision de `catalogue-niveau-eleve` et de `cours-eleve`), vue d'une matière par `?material=` (UDR-0085). Filtres dans l'adresse (`turbo_action: advance`), visibles au téléphone | `app/views/catalog/courses/index.html.erb` ; `test/system/catalog/course_catalog_test.rb` | Rien |
| **CA-03** Pagination infinie | Lien de page jamais rendu (💀) | ✅ **Livrée.** 24 cartes, puis la page suivante dans un frame différé chargé au défilement, lien « Afficher plus de cours » sans JavaScript | `CourseCatalogQuery::PER_PAGE` ; `catalog/courses/_page.html.erb` ; UDR-0013, amendement du 2026-10-05 (`politique-cache`, lot E4) | Rien ; le mécanisme est repris par la page matière |
| **CA-17** Espace Niveau | Page `/levels/:slug` « tout connecté » : séries du niveau, carrousel des cours, brouillons visibles | ⚠️ **Partielle.** Connecté, `/courses?level=tle` donne les cours d'un niveau (pas à l'élève ni, hors de ses niveaux, à l'enseignant). Aucune page de niveau, rien sans compte | `config/routes/catalog.rb` (trois routes, toutes connectées) | **La page** |
| **CA-21** Page matière | Page `/materials/:slug` « tout connecté », brouillons visibles | ⚠️ **Partielle.** L'élève a la vue de sa matière à son niveau (`/courses?material=`) ; l'équipe filtre par matière. Rien sans compte | `Catalog::CoursesController#student_material` | **La page** |
| **CA-23** Pages des séries | Liste et page réservées à l'équipe, sans gabarit (❌) | ⚠️ **Partielle.** L'équipe a la liste et la matrice niveau × série (`/teams/series`, UDR-0033) ; le catalogue filtre par série. Aucune page d'une série | `Teams::SeriesController#index` | **La page** (forme : question 5) |
| **AS-01** Parcourir tous les exercices | `Orm::Exercise.all`, brouillons compris ; l'inventaire concluait : « à refaire, scopé au chapitre parent et aux exercices publiés » | ✅ **Couverte sous sa forme corrigée.** La page d'une fiche liste ses exercices, publiés hors équipe, avec l'avancement de l'élève (CA-11, AS-37). Aucune liste transverse de tous les exercices | `catalog/essentials/show.html.erb` (bloc `essential_exercises`) | Rien, si le porteur ferme AS-01 (question 9) |

**Bilan** : quatre features sur sept sont livrées ou couvertes. Restent trois pages, et ce qu'elles entraînent : lecture sans compte, référencement, points d'entrée.

### Q9 de la feuille de route

> « Matrice des sous-rôles (ADR-0038) pour les pages livrées après elle : Pilotage, Croissance, validation des comptes en attente, barème et génération des classes. Qui voit quoi ? »

**Non tranchée.** La feuille de route ne porte pas de réponse, l'[index des chantiers](../README.md) note « Q9 ouverte » pour la V4, et l'ADR-0038 n'a été amendé que pour le blog (ADR-0074). Elle concerne `sous-roles-equipe`, pas ce chantier : `catalogue-complet` n'ajoute aucune page ni action de l'équipe, et la matrice de l'ADR-0038 donne déjà le contenu à `admin` et `content`. **Elle ne bloque pas ce chantier** (question 11).

## Hors périmètre

- **Le contenu des cours** : aucune fiche, aucun exercice, aucune question n'est lisible sans compte. Les pages publiques ne montrent que des noms, des descriptions courtes et des nombres.
- **Une page publique d'un cours** (sommaire des fiches) : chantier suivant si le porteur le veut (question 3).
- **Le catalogue connecté `/courses`** : inchangé pour tous les rôles (filtres, groupes de l'élève, pagination, actions de l'équipe).
- **La règle de l'élève** (ADR-0035, second amendement) : les cinq portes du contenu restent en 404 hors de son niveau.
- **Une liste transverse « Tous les exercices »**, pour l'équipe ou l'enseignant (question 9).
- **Les sous-rôles de l'équipe** (Q9, `sous-roles-equipe`).
- **Un cache HTML partagé** (Cloudflare ou Solid Cache) : l'ADR-0076 le refuse, ce chantier ne le rouvre pas (question 7).
- **La gestion de la taxonomie** (`/teams/levels`, `/teams/series`, `/teams/materials`) : inchangée.
- **Le rang des niveaux et des séries** : `levels.position` existe ; les séries se trient par nom.
- **L'app Android** : les pages s'ouvrent dans la coque comme toute page web ; aucune règle native nouvelle.

## Ce que le grill a révélé

Grill tenu par l'agent sur l'inventaire et les décisions en vigueur ; les réponses sont **à donner par le porteur**. Chaque ligne porte la recommandation de l'agent, que le PRD, l'ADR-0099 et les UDR-0113 à 0115 appliquent en attendant.

| # | Question au porteur | Recommandation | Conséquence sur le chantier |
|---|---|---|---|
| 1 | **Public visé.** Dans l'ancienne application, les pages Niveau et Matière étaient « tout connecté » et les séries réservées à l'équipe ; la feuille de route les appelle « pages publiques ». Pour qui sont-elles : visiteurs sans compte, personnes connectées, ou les deux ? | **Les deux, une seule page.** Lisible sans compte (vitrine et recherche Google) ; une personne connectée voit la même page, sans shell ni redirection, comme le blog (BL-20). Des pages réservées aux connectés doubleraient `/courses`, qui filtre déjà par niveau et matière | Première lecture anonyme du catalogue : ADR-0099. Contrôleurs hors `AuthenticatedController`, layout `application` |
| 2 | **Référencement.** Google doit-il indexer ces pages ? | **Oui, en production seulement**, comme le blog (ADR-0074 et son amendement du 2026-10-07) : plan du site, lien `canonical`, balises de partage. Les pages vides ne s'indexent pas | Le plan du site gagne les niveaux, matières et séries qui ont au moins un cours publié ; `noindex` sur une page vide |
| 3 | **Que voit-on d'un cours ?** Le nom et la description ; ou aussi le sommaire de ses fiches (une quatrième page) ; ou une fiche en libre accès ? | **Le nom et la description seulement.** La carte n'est pas un lien ; un seul appel à l'action par page (« Créer mon compte élève », ou « Voir mes cours » pour une personne connectée). Le sommaire peut venir dans un chantier suivant | Aucune page de cours publique ; le contenu reste derrière le compte |
| 4 | **Les autres niveaux.** Une page publique montre à tous, y compris à un élève de Tle D connecté, les titres des cours de 6e. Est-ce compatible avec « un élève de la TleD ne peut voir que les cours de la TleD » (2026-10-01) ? | **Oui.** La règle du 2026-10-01 protège l'accès au contenu et le catalogue de l'élève : les deux restent intacts (404 sur les cinq portes). Les titres sont une vitrine, sans lien vers le contenu | Amendement de l'ADR-0035 par l'ADR-0099 : les titres des cours publiés sont lisibles par tous ; le reste de la règle ne change pas |
| 5 | **Forme de la page série.** Une page par série tous niveaux confondus (`/series/d` : 1re D et Tle D), ou une page par niveau et série (`/niveaux/tle/d` : « Terminale D ») ? | **Niveau et série**, la façon dont élèves et parents nomment une classe. La liste des séries de l'équipe existe déjà (`/teams/series`), ce qui couvre la partie équipe de CA-23 | UDR-0115 ; adresse `/niveaux/:niveau/:serie` ; la page Niveau mène à ses séries |
| 6 | **Points d'entrée.** La bande « Matières » de la homepage (sept noms écrits en dur) devient-elle une rangée de liens vers les pages matière ? Ajoute-t-on « Les cours par niveau » au pied de page ? | **Oui aux deux.** La bande lit les matières qui ont au moins un cours publié, dans l'ordre du programme (`materials.position`) ; le pied de page gagne un lien vers `/niveaux`. Aucune entrée dans la navigation connectée | Lot D touche la homepage (amende UDR-0064 et UDR-0063 §3.4, règles à l'UDR-0113 §3.9) ; rien dans `NavigationHelper` |
| 7 | **Cache.** Accepte-t-on que ces pages ne soient mises en cache ni chez Cloudflare ni sur le serveur ? Chaque visite fait un aller-retour jusqu'au serveur (250 à 360 ms mesurés depuis Abidjan, ADR-0076) | **Oui.** La page porte le cookie de session et le jeton CSRF du layout ; un cache partagé les donnerait à un autre visiteur (option B refusée par l'ADR-0076). Un nombre fixe de requêtes et le budget de l'ADR-0067 suffisent. À rouvrir si le trafic de Google le justifie, avec un gabarit sans session | ADR-0099 §4.5 confirme l'ADR-0076 ; pas de `expires_in public` sur ces pages |
| 8 | **Adresses.** En français, comme `/mission` et `/blog` : `/niveaux`, `/niveaux/tle`, `/niveaux/tle/d`, `/matieres/mathematiques` ? | **Oui**, avec les slugs figés du référentiel (ADR-0029, ADR-0034 : `tle`, `d`, …). `/courses` garde son nom | Routes du Lot 0 |
| 9 | **AS-01.** La page d'une fiche liste déjà ses exercices publiés, comme l'inventaire le demandait. Ferme-t-on AS-01, ou veut-on une page « Tous les exercices » (pour l'équipe : retrouver les brouillons et les exercices incomplets) ? | **Fermer AS-01.** Une liste transverse pour l'équipe serait un nouveau besoin, à ouvrir en chantier séparé s'il se confirme | Aucun lot pour AS-01 ; la feuille de route la marque couverte à la clôture |
| 10 | **CA-01, CA-02, CA-03.** Les marque-t-on livrées sans travail dans ce chantier ? | **Oui**, livrées hors ordre (voir l'inventaire) | Mise à jour de la feuille de route §6 et de `features-refonte.md` au commit de clôture |
| 11 | **Q9.** On la laisse à `sous-roles-equipe` ? | **Oui** : ce chantier n'ajoute rien à l'équipe | Aucune policy de l'équipe touchée ; pas de collision avec `sous-roles-equipe` |
| 12 | **Maquettes.** Valides-tu les trois pages en maquette (téléphone à 390 px, puis ordinateur) avant le code, comme pour `cours-eleve` ? | **Oui**, une toile par page avant le Lot A | Le plan ne démarre qu'après validation des maquettes et des questions 1 à 7 |

## Cas limites identifiés

- **Niveau, matière ou série sans cours publié** : la page s'affiche avec un état vide, `noindex`, absente du plan du site et des points d'entrée. Slug inconnu : 404.
- **Série non rattachée au niveau** (`/niveaux/6eme/d`) : 404, même si la série existe.
- **Cours sans série** : commun à toutes les séries de son niveau (règle d'`AudienceFilter`) ; il apparaît donc sur `/niveaux/tle/d` et sur `/niveaux/tle/c`.
- **Cours dépublié ou archivé** : disparaît de toutes les pages à la requête suivante (aucun cache).
- **Renommage d'un niveau ou d'une matière** : le slug est figé (ADR-0029), l'adresse indexée ne casse pas ; le titre suit le nouveau nom.
- **Matière sans rang** (`materials.position` vide) : après les autres, par nom (règle de l'ADR-0090).
- **Beaucoup de cours** dans une matière : 24 par page, la suite au défilement (mécanisme de CA-03).
- **Élève connecté sur la page d'un autre niveau** : il voit les titres ; « Voir mes cours » le ramène à son catalogue ; aucun lien vers un contenu hors de son niveau.
- **Enseignant en attente** (sans établissement) : la page publique s'affiche ; seul l'espace connecté le retient (`hold_pending_teacher`).
- **Visite d'un robot sur Staging ou Develop** : `X-Robots-Tag: noindex` et `robots.txt` existants (ADR-0074, amendement du 2026-10-07).

## Questions encore ouvertes

Les questions 1 à 12 ci-dessus, à trancher par le porteur. Les décisions des questions 1 à 7 conditionnent l'ADR-0099 et les trois UDR ; si une réponse diffère de la recommandation, ces documents sont réécrits avant le Lot 0.

## Réponses du porteur (2026-10-16)

- Recommandations acceptées. Les maquettes (Q12) sont les captures à 390 px et sur ordinateur jointes à la PR.
