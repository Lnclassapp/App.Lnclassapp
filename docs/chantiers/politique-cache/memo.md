# Memo — Politique de cache : ce qui rend les pages lentes, et ce qu'un cache peut y changer

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours — lot R appliqué le 2026-10-03/04 (production et Staging en Europe ; base de Develop déplacée le 2026-10-05) ; lot E (audit de toutes les pages, 2026-10-05) livré en PR ; lot D et mesure depuis Abidjan attendus du porteur |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `perf/politique-cache` |

---

## Décisions du porteur (2026-10-03)

Réponse du porteur aux six questions du cadrage : « 1, 2, 5 et 6 oui ; 2 et 4 non, garder ». Le « 2 » apparaît deux fois. On le lit comme **3 et 4 non** : ce sont les deux questions qui proposaient de modifier une décision existante, et « garder » ne s'applique qu'à elles.

| Question | Réponse | Conséquence |
|---|---|---|
| 1. Mesure depuis Abidjan | oui, le porteur la lance | le lot R a bientôt son « avant » |
| 2. Étudier la région `europe-west4`, Develop et Staging d'abord | oui | étude dans le [plan](plan.md) (lot R), aucune migration avant la mesure d'Abidjan |
| 3. Amender l'UDR-0010 et l'UDR-0018 (activité récente rendue avec la page) | **non, garder** | **lot A fermé** : les accueils élève et équipe gardent leur frame différé |
| 4. Amender l'ADR-0049 (connexion hors Turbo) | **non, garder** | **lot B fermé** : le rechargement forcé à la connexion et à la déconnexion reste |
| 5. Early Hints et Tiered Cache chez Cloudflare | oui, le porteur les active | lot D mesuré une fois les réglages actifs |
| 6. Pousser la branche, PR brouillon vers `Develop` | oui | fait |

Sans les lots A et B, **aucun levier de code ne reste** : le compte de requêtes en série devient un plafond à ne pas dépasser (ADR-0076 §4.2), et le gain viendra de la périphérie (D) et de la région (R). Le lot C, qui dépendait de B, est fermé (voir le [plan](plan.md)).

## Mesure après — région (lot R, 2026-10-04)

Décision du porteur, le 2026-10-03 : « déplace tous les environnements en Europe, production, Staging et Develop, avec les bases et les buckets ». Le déroulé est dans le [journal](journal.md#lot-r--le-déplacement-en-europe-2026-10-03-et-04).

**État au 2026-10-04, 00:10 UTC :**

| Environnement | Application | PostgreSQL | Fichiers (Active Storage) |
|---|---|---|---|
| production | `europe-west4` | `europe-west4` (volume migré) | `lnclass-fichiers-eu-production` (`ams`) : 1 fichier, copié et vérifié deux fois |
| Staging | `europe-west4` | `europe-west4` (volume migré) | `lnclass-fichiers-eu-staging` (`ams`) : l'ancien bucket était vide |
| Develop | `europe-west4` | **`asia-southeast1`** (pas déplacée) | `lnclass-fichiers-eu-develop` (`ams`) : 28 fichiers (3,16 Mio), copiés et vérifiés deux fois |

L'ancien bucket `organized-trunk` (`sin`) existe toujours, ainsi que les trois services de copie (arrêtés) : leur suppression a été refusée au moment de la demander.

**Production, même machine, même méthode, médiane de 3 exécutions :**

| Métrique | Avant | Cible | **Après** | Tenu ? |
|---|--:|--:|--:|:-:|
| Surcoût d'une requête qui va jusqu'au serveur (comparé à un `HIT` Cloudflare) | 227 ms | < 100 ms | **107 ms** | non, à 7 ms |
| Trajet jusqu'au serveur, hors serveur | 251 ms | — | **133 ms** | — |
| Chargement d'une page déjà visitée (`load`), `/` et `/login` | 403 / 393 ms | < 200 ms | **238 / 231 ms** | non |
| Premier octet, page déjà visitée | 360 / 358 ms | — | 204 / 200 ms | — |
| Chargement d'une première visite (`load`) | 943 / 875 ms | — | 734 / 732 ms | — |
| Connexion neuve à `/login` | 348 ms | — | 208 ms | — |
| Temps serveur (`x-runtime`) de `/`, `/login`, `/up` | 8,7 / 6,4 / 1,7 ms | inchangé | 3,4–5,4 / 2,8–6,6 / 0,9–2,2 ms | oui |
| Requêtes en série par parcours | 4 / 3 / 3 / 2 / 1 / 2 / 1 / 3 | plafond | inchangé | oui |
| **Surcoût vu d'Abidjan** | non mesuré | < 150 ms | **non mesuré** | à mesurer |

Staging donne les mêmes chiffres (trajet 129 ms, surcoût 101 à 108 ms).

Ce que la mesure dit :

1. **Chaque aller-retour jusqu'au serveur coûte 47 % de moins** au point de mesure (Chicago) : 227 → 107 ms. Une page déjà visitée se charge en 238 ms au lieu de 403, soit −41 %.
2. Les deux cibles fixées pour Chicago sont manquées de peu (107 ms contre 100, 238 ms contre 200). Elles servaient de témoin : la cible qui compte est celle d'Abidjan, où l'écart entre Singapour et Amsterdam doit être plus grand qu'aux États-Unis. Elle reste à mesurer (question 1).
3. **Develop reste lent tant que sa base est à Singapour** : chaque requête SQL y coûte ~170 ms, et une page connectée 1 à 10 s.

## Lot E — audit de toutes les pages (2026-10-05)

Le porteur, le 2026-10-05 : « après la migration vers UE, je trouve l'app Lnclass super lente », puis « analyse toutes les pages, puis assure-toi que la politique de cache est respectée, et que toutes les pages sont optimisées ».

### D'où vient la lenteur ressentie : Develop, pas la production

Railway (`http-response-time`, 72 h ; journaux HTTP du 2026-10-05) :

| Environnement | p50 serveur depuis la migration | Pages > 300 ms le 2026-10-05 |
|---|--:|---|
| production | **4 à 6 ms** (p99 ≤ 110 ms) | **aucune** depuis 06:00 UTC |
| Staging | 10 à 35 ms | — |
| **Develop** | **1 731 à 3 249 ms** (p99 jusqu'à 9 968 ms) | toutes les pages connectées : `/teams` 3 574 à 9 911 ms, `/teams/referential` 3 223 à 8 163 ms, `/courses` 1 374 à 5 148 ms, `/exercises/:id` 3 630 à 6 508 ms |

Les pages lentes sont celles du porteur, sur `app-develop.lnclass.com`. Son application est à Amsterdam, mais sa base est restée à Singapour : chaque requête SQL fait l'aller-retour Europe–Asie (~170 ms), et une page en fait 5 à 23. C'est le cas que le lot R interdisait (ADR-0076 §4.3 : « on ne déplace jamais l'application sans sa base »). Sur demande du porteur (« déplace sa DB Amsterdam aussi »), le déplacement de PostgreSQL vers `europe-west4` est préparé en changement en attente dans Develop (Postgres seul). Sa validation par l'API expire deux fois, mais le changement est appliqué à 14:15 UTC, volume migré. Develop répond depuis en **18 à 380 ms** par page connectée au lieu de 1,7 à 10 s (question 2).

### L'audit

`script/perf/audit_pages.rb` explore, pour cinq profils (visiteur, élève, enseignant, direction, équipe), toutes les routes GET sans paramètre. Il suit ensuite les liens, les frames et les formulaires GET de chaque page, comme des clics Turbo. Il mesure chaque page sur 15 visites après chauffe, en mode production, sur le jeu de l'ADR-0067 (500 établissements, 40 000 élèves, 311 957 sessions).

- **Couverture** : 405 adresses visitées, dont **218 pages en 200** (équipe 89, enseignant 42, direction 39, élève 31, visiteur 17), soit **91 routes**. 7 routes restent hors d'atteinte : un jeton d'invitation, trois fichiers lus depuis le bucket (photo, image et audio d'annonce), et trois pages sans ligne dans le jeu (session d'exercice en cours, annonce à modifier, demande de suppression).
- **Cache du HTML, conforme partout** : les 218 pages sont en `max-age=0, private, must-revalidate`, et **aucune réponse HTML n'est `public`**. L'action `secret_response` atteinte (`/identity/second-factor/enrollment/new`) répond `no-store`. En production, Staging et Develop, le HTML est `cf-cache-status: DYNAMIC` et les assets digérés `public, max-age=31556952`, servis en `HIT` par Cloudflare dès le second appel. Le seul cache serveur est celui que l'ADR-0067 admet : le pilotage « année » (ADR-0062) et l'accueil de la direction (ADR-0065, amendement du 2026-10-04), 5 minutes chacun.
- **Temps serveur** : p95 médian **15 ms** sur les 218 pages. Au-dessus de 100 ms, seulement les listes déjà connues de l'ADR-0067 (établissements, catalogue de l'équipe) et des pointes isolées au bord du seuil.

### Écarts trouvés, et ce qui en est fait

| Écart | Où | Règle | Suite |
|---|---|---|---|
| **Carte « Parrainage » redemandée à chaque clic de l'enseignant** (frame de la barre latérale, UDR-0069 §3.6, posé le 2026-10-04) | 20 pages de l'espace enseignant, sur grand écran | ADR-0076 §4.2 : 1 requête par clic, 3 à la connexion | **corrigé, lot E1** |
| **HTML au-dessus de 150 Ko** : icônes redessinées sur chaque ligne | catalogue (enseignant, direction, équipe), établissements, DRENA, fiche d'un établissement | ADR-0067 | **réduit, lot E2** ; reste au-dessus du budget (ci-dessous) |
| Frame différé de l'« Activité récente » de la direction (UDR-0074 §3.11, posé le 2026-10-04) | accueil de la direction : 2 requêtes en série | ADR-0076 §4.2 ne l'admet que sur les accueils élève et équipe, ou hors de l'écran à l'arrivée | **question au porteur** (5) |
| Une requête par image du texte d'un article (Action Text résout chaque pièce jointe) | `/blog/:slug` ×5, `/teams/blog/:id/edit` ×6 | ADR-0067 : budget tenu (p95 25 à 37 ms) | gardé : 5 à 6 requêtes dans la même région coûtent ~2 ms |
| Lien `/` vers l'accueil depuis une page publique ou d'erreur, vu par une personne connectée : une redirection | `/aide`, `/blog`, pages légales, pages 403 | plafond « ouverture de lnclass.com » : 3 | dans le plafond ; gardé (journal, leviers abandonnés) |

### Mesures du lot E

**E1 — carte « Parrainage » permanente, rendue avec l'accueil** (`count_round_trips.rb`, base du jeu de mesure, 3 exécutions identiques) :

| Parcours (enseignant, grand écran) | Plafond | Avant | **Après** |
|---|--:|--:|--:|
| Connexion (formulaire → accueil) | 3 | **4** | **3** |
| Clic vers l'accueil | 1 | **2** | **1** |
| Clic d'une page de l'espace à une autre | 1 | **2** | **1** |

Décomposition : avec le seul `data-turbo-permanent`, le clic de page à page passe à 1, mais la connexion reste à 4 et l'accueil à 2. Le rendu de la carte avec l'accueil, qui lit déjà l'invitation, ramène ces deux parcours au plafond. Tous les autres parcours sont inchangés.

**E2 — icônes dessinées une fois** (`ui_icon_sprite`, déjà admis par l'ADR-0067 pour « Enseignants » de la direction) ; `measure_screens.rb`, même jeu, 30 requêtes après 3 de chauffe, médiane de 3 exécutions :

| Écran | HTML avant | **HTML après** | p50 avant → après | p95 avant → après |
|---|--:|--:|--:|--:|
| Catalogue, enseignant (`/courses`) | 487,8 Ko | **338,8 Ko** (−31 %) | 73,8 → 71,6 ms | 103,8 → 87,6 ms |
| Catalogue, équipe | 566,7 Ko | **410,4 Ko** (−28 %) | 84,2 → 82,2 ms | 122,6 → 110,3 ms |
| DRENA (`/teams/drenas`) | 317,0 Ko | **240,4 Ko** (−24 %) | 77,3 → 77,0 ms | 114,2 → 101,2 ms |
| Établissements (`/teams/schools`) | 603,4 Ko | **517,1 Ko** (−14 %) | 104,6 → 101,7 ms | 139,3 → 139,5 ms |
| Fiche d'un établissement | 305,0 Ko | **268,8 Ko** (−12 %) | 70,1 → 64,2 ms | 153,8 → 155,6 ms |

Les temps bougent dans le bruit de la machine. Compressé, le HTML ne baisse que de 2 à 9 % (catalogue de l'équipe 16,9 → 15,4 Ko, établissements 23,0 → 22,5 Ko) : le gain porte sur le poids brut, donc sur l'analyse du DOM par un téléphone d'entrée de gamme, presque pas sur les données mobiles. Le challenger a rejoué les deux bancs (avant et après, 3 fois chacun) et retrouvé les mêmes chiffres, à 0,1 Ko près. Il a aussi tranché deux p95 « après » plus hauts en alternant avant et après sur 100 requêtes : c'était du bruit. **Aucun de ces écrans ne passe sous 150 Ko.** Ce qui reste :
- les deux modales par ligne (formulaire et jeton CSRF compris) des établissements et des DRENA : 290 Ko sur 517 pour les établissements ;
- les classes Tailwind des 210 cartes du catalogue : 183 Ko.

Les retirer change la structure de l'écran : modale lue à la demande, comme pour « Retirer » de la direction (UDR-0056, amendement du 2026-10-04), ou liste paginée. C'est le lot 5 du chantier `cache-ecrans-lourds`, que le porteur a reporté après les lots UX (question 6). La page d'une classe (enseignant, 216,5 Ko, dont 69 Ko de 56 formulaires) n'est pas touchée : le sprite n'y retirerait qu'environ 45 Ko.

## Le problème

Le porteur trouve l'application lente : « le chargement des pages dépasse 500 ms ». Il demande une révision en profondeur de la politique de cache pour accélérer toutes les pages.

La mesure dit que **le serveur n'est pas le goulot**. Les pages se calculent en 2 à 9 ms (`x-runtime`), et Railway mesure 19 à 25 ms de médiane en production. Le temps part dans le **trajet jusqu'au serveur** : l'application et sa base tournent à **Singapour** (`asia-southeast1`), loin des utilisateurs ivoiriens. Chaque requête qui va jusqu'au serveur paie ce trajet, et certains parcours en enchaînent jusqu'à quatre, l'une après l'autre.

Un cache côté serveur (Solid Cache, fragments, ETag) ne peut donc gagner que quelques millisecondes sur des centaines. Pour qu'une politique de cache accélère les pages, il faut qu'elle évite des allers-retours jusqu'à Singapour. Trois moyens existent : servir depuis le navigateur ou depuis Cloudflare ce qui peut l'être, supprimer les requêtes en série inutiles, et rapprocher le serveur des utilisateurs.

## Pour qui

- **Tous les acteurs**, sur toutes les pages : chaque navigation paie au moins un aller-retour.
- **Élèves et enseignants en 3G sur Android d'entrée de gamme** ([ADR-0009](../../decisions/adr/0009-stack-frontend-vanilla-css-tailwind-hotwire.md)) : leur réseau ajoute sa propre latence à chaque aller-retour.
- **Quiconque se connecte** : c'est le parcours qui enchaîne le plus de requêtes (4 pour un élève).

## Pourquoi maintenant

- La V1 est en production depuis le 2026-09-28 et le porteur constate déjà la lenteur.
- Les tableaux de bord Railway ne la montrent pas. Ils mesurent 10 à 28 ms pour des requêtes que le client a attendues ~260 ms (journal, « Où part le temps »). Sans mesure côté client, on optimiserait ce qui est déjà rapide.

## Mesure avant

**Machine de mesure** : conteneur cloud de Claude Code, sortie par un proxy local, Cloudflare vu au PoP de Chicago (`ORD`) ou de Washington (`IAD`). **Ce n'est pas Abidjan** : les chiffres réseau valent pour ce point de mesure, et la même mesure reste à prendre depuis la Côte d'Ivoire (dernière ligne du tableau, question 1).

**Code** : `Develop` en `c6d7977c`, déployé en production (`lnclass.com`). **Hébergement** : un réplica de l'application et un de PostgreSQL 18, tous deux en `asia-southeast1-eqsg3a`. Cloudflare devant (DNS proxifié), puis le proxy de Railway, puis Thruster, puis Puma. Develop et Staging sont aussi à Singapour.

**Méthode** : trois scripts versionnés, protocole complet dans le [journal](journal.md#protocole). Chaque script est lancé **3 fois**, et le tableau retient la **médiane des 3**.

| Métrique | Contexte / volume | Valeur avant (médiane de 3) | Cible | Comment mesurée |
|---|---|---|---|---|
| Temps serveur, GET 200, production | trafic réel des 96 dernières heures, pages et assets | p50 19 à 25 ms, p95 100 ms | inchangé : ce n'est pas le goulot | métrique `http-response-time` de Railway |
| Temps serveur de `/up`, `/login`, `/` | production, 30 requêtes par page | 1,7 / 6,4 / 8,7 ms (`x-runtime`) | inchangé | `script/perf/measure_network.rb` |
| **Surcoût d'une requête qui va jusqu'au serveur**, hors temps serveur | production, connexion gardée ouverte, point de mesure ci-dessus | **227 ms** : 251 ms jusqu'au serveur contre 24 ms jusqu'au cache de Cloudflare | **< 100 ms** au même point de mesure (lot R) | `measure_network.rb`, 30 requêtes × 3 |
| **Chargement d'une page déjà visitée** (`load`) | `/` et `/login`, Chromium, assets en cache | **403 / 393 ms**, dont **360 / 358 ms** d'attente du premier octet | < 200 ms au même point de mesure (lot R) | `script/perf/measure_browser.cjs`, 10 visites × 3 |
| Chargement d'une première visite (`load`) | idem, cache du navigateur vide | 943 / 875 ms ; 10 et 6 ressources téléchargées | −30 % (lot D) | idem |
| **Requêtes en série — connexion d'un élève** | comptes de `db/seeds`, du clic « Se connecter » à l'accueil complet | **4** : `POST /session` → 303, `GET /students` (Turbo), `GET /students` (rechargement forcé), `GET /students` (activité récente) | **2** (lots A et B) | `script/perf/count_round_trips.rb` |
| Requêtes en série — connexion d'un enseignant | idem | 3 | 2 (lot B) | idem |
| Requêtes en série — ouvrir `lnclass.com` déjà connecté (élève) | idem | 3 : `GET /` → 302, `GET /students`, activité récente | 2 (lot A) | idem |
| Requêtes en série — clic vers l'accueil élève / équipe | idem | 2 / 2 | 1 / 1 (lot A) | idem |
| Requêtes en série — clic vers l'accueil enseignant, le catalogue | idem | 1 / 1 | 1 / 1 | idem |
| Requêtes en série — déconnexion | idem | 3 : `DELETE /session` → 303, `GET /` (Turbo), `GET /` (rechargement forcé) | 2 (lot B) | idem |
| **Surcoût d'une requête vu d'Abidjan** | production, même script, depuis la Côte d'Ivoire | **non mesuré** : aucun point de mesure en Côte d'Ivoire n'est accessible depuis ce conteneur | < 150 ms (lot R) | `measure_network.rb` et `measure_browser.cjs`, lancés par le porteur |

Ce que le tableau dit :

1. **Le serveur répond en moins de 10 ms et le client attend 250 à 360 ms.** Au point de mesure, plus de 95 % de l'attente d'une page déjà visitée est du trajet. Un cache côté serveur en retirerait au mieux les 2 à 9 ms du calcul.
2. **Le cache qui marche déjà est celui des assets.** Cloudflare sert la feuille de style, le script et la police en 24 ms (`HIT`), et le navigateur les garde un an. Seul le HTML va jusqu'à Singapour, et il le doit : il est personnel, il porte le jeton CSRF et le nonce CSP de la session.
3. **Le coût d'un parcours se compte en requêtes en série.** Calcul au point de mesure (requêtes × 251 ms, plus le serveur) : une connexion d'élève attend environ 4 × 251 ms de trajet, plus 290 ms de bcrypt, soit ≈ 1,3 s. Un clic vers l'accueil élève attend environ 2 × 251 ms.
4. **Les chiffres de Railway trompent.** Pour les mêmes requêtes, Railway journalise 10 à 28 ms, et le client attend 250 à 260 ms. Le trajet entre l'edge de Railway et Singapour n'apparaît dans aucune métrique de Railway.

Le détail (journaux HTTP, en-têtes, profondeur de chaque parcours) est dans le [journal, « Où part le temps »](journal.md#où-part-le-temps).

## Leviers classés

Classés par ratio gain/risque, **un lot = un levier = un chiffre** ([plan](plan.md)). Le lot R est le seul qui accélère **toutes** les pages ; il vient après les lots de code parce que son risque est élevé, qu'il ne relève pas du dépôt et qu'il attend la mesure depuis Abidjan. Les gains en millisecondes sont **calculés** à partir de la mesure au point de mesure ; ils seront remesurés après chaque lot.

| Lot | Levier | Gain attendu | Risque, décision requise |
|---|---|---|---|
| ~~**A**~~ *fermé (porteur)* | **Activité récente rendue avec la page** (accueil élève et accueil équipe) au lieu d'un frame différé (`loading: :lazy`). | −1 requête en série sur ces deux accueils, la page la plus ouverte de l'élève et de l'équipe, soit ≈ −250 ms pour la carte. Côté serveur, au plus le coût actuel de la requête du frame : 7 à 19 ms (élève), 10 ms (équipe), mesurés en local | Faible côté code, mais l'[UDR-0010](../../decisions/udr/0010-accueil-eleve.md) et l'[UDR-0018](../../decisions/udr/0018-accueil-equipe.md) prescrivent le frame différé : **amendement des deux UDR**, donc accord du porteur. Au téléphone, la carte est sous la ligne de flottaison : le gain ne se voit qu'au défilement |
| ~~**B**~~ *fermé (porteur)* | **Connexion, inscription et déconnexion sans rechargement forcé.** Le formulaire est soumis par le navigateur (`data-turbo="false"`) au lieu de Turbo. Le document qui arrive porte donc déjà la CSP de la nouvelle session, et le `turbo-visit-control: reload` devient inutile sur ces parcours. | −1 requête en série par connexion, inscription et déconnexion, soit ≈ −250 ms et un rendu de moins. Parcours rare : la session est permanente (`cookies.signed.permanent`), on se connecte peu | Moyen. Le mécanisme vient de l'[ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (amendement du 2026-09-26) : **amendement de l'ADR-0049**. Un PIN refusé (422) se ré-affiche alors en page complète au lieu d'un rendu Turbo. Les tests CSP existants servent de non-régression. La déconnexion est aujourd'hui un lien `data-turbo-method="delete"`, qui ne marche qu'avec Turbo : elle devient un petit formulaire (`button_to`) |
| **D** | **Cloudflare** : activer *Early Hints* (le navigateur charge CSS, JS et police depuis Cloudflare pendant qu'il attend le HTML) et *Tiered Cache* (un PoP froid demande d'abord à un PoP de Cloudflare, pas à Singapour). | Première visite : le chargement des assets (390 à 500 ms entre le premier octet et `DOMContentLoaded`) se fait pendant l'attente du HTML | Faible : ce sont deux réglages du tableau de bord Cloudflare, sans code. **Action du porteur** (aucun accès à la zone Cloudflare depuis le dépôt). Le `Link: preload` qu'Early Hints réutilise est déjà envoyé par Rails |
| **R** | **Rapprocher l'application et sa base des utilisateurs** : région Railway `europe-west4` (Amsterdam), qui est la plus proche de la Côte d'Ivoire à vol d'oiseau, au lieu de `asia-southeast1` (Singapour). | Sur **toutes** les requêtes. L'ampleur dépend de la mesure depuis Abidjan (question 1) | **Élevé, hors code** : migration du volume PostgreSQL avec interruption, à planifier. **Décision du porteur**, et l'ADR-0076 la consigne. On ne déplace jamais l'application sans sa base : chaque page fait 4 à 25 requêtes SQL, et une seule traversée Europe–Asie par requête coûterait plus que tout le reste |
| ~~C~~ *fermé* | `immutable` sur les assets digérés : `public, max-age=31536000, immutable`. | Safari et Firefox ne revalident plus les assets quand la page est rechargée, notamment au rechargement forcé de la connexion | Très faible, une ligne. Le gain n'est **pas mesurable ici** (seul Chromium est installé, et il ne revalide pas les sous-ressources) et il disparaît presque si le lot B supprime le rechargement. **À fermer** si la mesure n'est pas faisable |

Leviers **écartés par la mesure** :

- **Cache serveur pour la latence** (Solid Cache, fragments, `fresh_when` / ETag). Le calcul coûte 2 à 9 ms sur ces pages, un 304 paie quand même l'aller-retour complet, et le nonce CSP et le jeton CSRF changent le HTML d'une session à l'autre. Les écrans qui dépassent leur budget serveur relèvent de l'[ADR-0067](../../decisions/adr/0067-budgets-de-temps-serveur-des-ecrans.md) et du chantier [`cache-ecrans-lourds`](../cache-ecrans-lourds/memo.md), pas de celui-ci.
- **Cache du HTML chez Cloudflare**, même pour les pages publiques (`/`, `/login`) : elles posent le cookie de session et portent un jeton CSRF et le nonce CSP de la session. Les servir depuis un cache partagé donnerait le jeton d'une personne à une autre. **Refusé** ([ADR-0031](../../decisions/adr/0031-second-facteur-totp-pour-l-equipe.md), [ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md)).
- **Préchargement au toucher.** Turbo 8.0.23 précharge au survol de la souris (`mouseenter`, après 100 ms), et c'est déjà actif sur ordinateur. Au toucher, le gain est borné par la durée d'un appui moins ces 100 ms, soit 0 à 50 ms. Et chaque défilement qui commence sur un lien enverrait une requête, payée en données mobiles.
- **Supprimer la redirection de `/` pour une personne connectée** (−1 requête à chaque ouverture de l'application) : cela change l'adresse de l'accueil, donc c'est une `feature`, pas une optimisation. Noté en dette.

## Hors périmètre

- Le temps serveur des écrans et leurs budgets (ADR-0067), et le lot 5 de `cache-ecrans-lourds` (HTML des listes).
- Le coût du bcrypt à la connexion (≈ 290 ms côté serveur) : c'est la protection d'un PIN de 4 chiffres ([ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md)).
- Le poids du JavaScript et du CSS (ADR-0051), le mode hors ligne et le service worker (`installation-pwa`, V4).
- Toute modification visible d'un écran, et l'adresse de l'accueil.
- La mise en veille de Develop et de Staging (`sleepApplication: true`) : Railway y endort le service inactif, et le premier appel le réveille. Ce délai n'a pas été mesuré. C'est un réglage de recette, à traiter à part s'il gêne les tests.

## Ce que le grill a révélé

| Question posée | Réponse (mesurée) | Conséquence sur le chantier |
|---|---|---|
| Le serveur est-il lent ? | Non : 1,7 à 8,7 ms sur les pages mesurées en production, et p50 de 19 à 25 ms sur tout le trafic. | Aucun cache serveur dans ce chantier. |
| Où part le temps ? | Dans le trajet jusqu'à Singapour : 227 ms de plus qu'une réponse de Cloudflare, invisibles dans Railway. | La métrique du chantier est mesurée côté client, pas sur Railway. |
| Le cache de Cloudflare et du navigateur fonctionne-t-il ? | Oui pour les assets digérés (`HIT`, un an dans le navigateur). Le HTML est `DYNAMIC`, à juste titre. Un PoP peu sollicité oublie les assets, et la première visite paie alors Singapour. | Lot D pour les premières visites ; rien à changer pour le HTML. |
| Combien de requêtes en série par parcours ? | De 1 (enseignant, catalogue) à 4 (connexion d'un élève). | Lots A et B : chaque requête en série retirée vaut un aller-retour. |
| Turbo cache-t-il déjà ? | Oui : aperçu des pages déjà vues (10 en cache) et préchargement au survol, tous deux actifs par défaut. Rien au toucher. | Rien à ajouter côté Turbo. |
| Mesurer depuis où ? | Les utilisateurs sont en Côte d'Ivoire, la mesure est faite aux États-Unis. Le compte de requêtes ne dépend pas du lieu ; le trajet, si. | Les scripts réseau et navigateur se rejouent sans compte, depuis n'importe où. Le lot R attend la mesure depuis Abidjan. |

## Cas limites identifiés

- Le frame de l'activité récente est différé jusqu'à ce qu'il soit visible. Au téléphone, il est sous la ligne de flottaison : le script le compte comme visible, c'est donc un pire cas.
- Une première visite dépend du cache du PoP Cloudflare de la personne. Un PoP froid (peu de trafic à Abidjan) va chercher les assets à Singapour.
- La « connexion neuve » (DNS, TCP, TLS) est faussée par le proxy du conteneur de mesure : 348 ms, contre 251 ms sur une connexion gardée ouverte. Elle ne sert de référence que depuis un poste sans proxy.
- Le proxy de Railway journalise la durée vue depuis la région de l'application : une régression du trajet ne s'y verra jamais.

## Questions encore ouvertes

*Questions du cadrage, posées le 2026-10-03 ; réponses en tête de ce memo. Mise à jour le 2026-10-05 après le lot E.*

1. **Mesure depuis Abidjan** : `ruby script/perf/measure_network.rb` (production) trois fois, depuis un poste en Côte d'Ivoire (sans compte, Ruby 3.4). Il n'y a plus de « avant » à Singapour, la production est en Europe. Cette mesure dit si la cible de moins de 150 ms est tenue là où sont les élèves.
2. ~~**Base de Develop**~~ : déplacée en `europe-west4` le 2026-10-05 (changement préparé par l'API, appliqué à 14:15 UTC ; volume migré). Le `x-runtime` de `/`, une requête SQL, passe de 175 ms à **5–11 ms**. Les pages connectées du porteur sur Develop passent de 3,5–10 s à **18–380 ms** dans les journaux de Railway, première visite après la migration comprise.
3. ~~**Nettoyage**~~ : fait le 2026-10-05. `organized-trunk` et les trois services de copie sont supprimés ; il ne reste que les buckets `lnclass-fichiers-eu-<environnement>`.
4. **Cloudflare** : prévenir quand *Early Hints* et *Tiered Cache* sont actifs, pour la mesure « après » du lot D. Le conteneur passe par un relais qui termine le TLS : il ne voit pas les réponses `103`, et l'activation ne peut pas être vérifiée d'ici.
5. **Accueil de la direction** (nouveau, lot E) : son « Activité récente » est un frame différé (UDR-0074 §3.11, du 2026-10-04). Cela fait 2 requêtes en série par visite, alors que l'ADR-0076 §4.2 ne l'admet que sur les accueils élève et équipe. Deux réponses possibles : **(a)** l'admettre comme eux, en ajoutant l'accueil de la direction à la ligne « 2 » du plafond ; **(b)** rendre l'activité avec la page, ce qui fait gagner une requête et amende l'UDR-0074.
6. **Listes encore au-dessus de 150 Ko** (lot E2) : établissements (517 Ko), catalogue de l'équipe (410 Ko) et de l'enseignant (339 Ko), DRENA (240 Ko), fiche d'un établissement (269 Ko), page d'une classe (217 Ko). Il faudrait sortir les modales des lignes (chargées à la demande, une requête au clic) ou paginer le catalogue, ce qui change l'écran. Faut-il ouvrir maintenant le lot 5 de `cache-ecrans-lourds`, que le porteur avait reporté après les lots UX ?
