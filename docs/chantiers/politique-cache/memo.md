# Memo — Politique de cache : ce qui rend les pages lentes, et ce qu'un cache peut y changer

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | cadrage — mesure « avant » prise, leviers proposés, en attente du porteur |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `perf/politique-cache` |

---

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
| **A** | **Activité récente rendue avec la page** (accueil élève et accueil équipe) au lieu d'un frame différé (`loading: :lazy`). | −1 requête en série sur ces deux accueils, la page la plus ouverte de l'élève et de l'équipe, soit ≈ −250 ms pour la carte. Côté serveur, au plus le coût actuel de la requête du frame : 7 à 19 ms (élève), 10 ms (équipe), mesurés en local | Faible côté code, mais l'[UDR-0010](../../decisions/udr/0010-accueil-eleve.md) et l'[UDR-0018](../../decisions/udr/0018-accueil-equipe.md) prescrivent le frame différé : **amendement des deux UDR**, donc accord du porteur. Au téléphone, la carte est sous la ligne de flottaison : le gain ne se voit qu'au défilement |
| **B** | **Connexion, inscription et déconnexion sans rechargement forcé.** Le formulaire est soumis par le navigateur (`data-turbo="false"`) au lieu de Turbo. Le document qui arrive porte donc déjà la CSP de la nouvelle session, et le `turbo-visit-control: reload` devient inutile sur ces parcours. | −1 requête en série par connexion, inscription et déconnexion, soit ≈ −250 ms et un rendu de moins. Parcours rare : la session est permanente (`cookies.signed.permanent`), on se connecte peu | Moyen. Le mécanisme vient de l'[ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (amendement du 2026-09-26) : **amendement de l'ADR-0049**. Un PIN refusé (422) se ré-affiche alors en page complète au lieu d'un rendu Turbo. Les tests CSP existants servent de non-régression. La déconnexion est aujourd'hui un lien `data-turbo-method="delete"`, qui ne marche qu'avec Turbo : elle devient un petit formulaire (`button_to`) |
| **D** | **Cloudflare** : activer *Early Hints* (le navigateur charge CSS, JS et police depuis Cloudflare pendant qu'il attend le HTML) et *Tiered Cache* (un PoP froid demande d'abord à un PoP de Cloudflare, pas à Singapour). | Première visite : le chargement des assets (390 à 500 ms entre le premier octet et `DOMContentLoaded`) se fait pendant l'attente du HTML | Faible : ce sont deux réglages du tableau de bord Cloudflare, sans code. **Action du porteur** (aucun accès à la zone Cloudflare depuis le dépôt). Le `Link: preload` qu'Early Hints réutilise est déjà envoyé par Rails |
| **R** | **Rapprocher l'application et sa base des utilisateurs** : région Railway `europe-west4` (Amsterdam), qui est la plus proche de la Côte d'Ivoire à vol d'oiseau, au lieu de `asia-southeast1` (Singapour). | Sur **toutes** les requêtes. L'ampleur dépend de la mesure depuis Abidjan (question 1) | **Élevé, hors code** : migration du volume PostgreSQL avec interruption, à planifier. **Décision du porteur**, et l'ADR-0069 la consigne. On ne déplace jamais l'application sans sa base : chaque page fait 4 à 25 requêtes SQL, et une seule traversée Europe–Asie par requête coûterait plus que tout le reste |
| C | `immutable` sur les assets digérés : `public, max-age=31536000, immutable`. | Safari et Firefox ne revalident plus les assets quand la page est rechargée, notamment au rechargement forcé de la connexion | Très faible, une ligne. Le gain n'est **pas mesurable ici** (seul Chromium est installé, et il ne revalide pas les sous-ressources) et il disparaît presque si le lot B supprime le rechargement. **À fermer** si la mesure n'est pas faisable |

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

1. **Mesure depuis Abidjan** : pouvez-vous lancer `ruby script/perf/measure_network.rb` (Ruby seul, sans compte) trois fois depuis un poste en Côte d'Ivoire, idéalement sur le réseau mobile des élèves ? Sans ce chiffre, le lot R n'a pas de « avant » et ne s'ouvre pas.
2. **Région** : d'accord pour étudier le passage de la production (application **et** PostgreSQL) en `europe-west4`, avec une fenêtre de maintenance ? Staging et Develop d'abord, pour mesurer le gain sans risque ?
3. **Lot A** : d'accord pour amender l'UDR-0010 et l'UDR-0018 (activité récente rendue avec la page) ?
4. **Lot B** : d'accord pour amender l'ADR-0049 ? Le formulaire de connexion serait soumis hors Turbo, et un PIN refusé recharge alors la page avec son message d'erreur.
5. **Lot D** : pouvez-vous activer *Early Hints* et *Tiered Cache* dans la zone Cloudflare `lnclass.com` ? Le dépôt n'y a pas accès.
