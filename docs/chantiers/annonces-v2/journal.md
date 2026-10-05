# Journal — Annonces, deuxième version — saisie guidée, illustrations de l'équipe, trois annonces visibles, thèmes de couleur

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-05 | Le bugfix `annonce-audio-mp3` s'arrête ; ses cinq demandes deviennent ce chantier | Le fichier refusé est perdu : rien à reproduire ; quatre demandes sur cinq sont des évolutions (porteur) | — (memo) |
| 2026-10-05 | Fin = parution + 30 jours, heure gardée ; « Visible jusqu'au » disparaît | Choix du porteur au grill ; le PRD disait « 00:00 » (AV-02), l'ADR a primé et le PRD a été corrigé | ADR-0081 §4.1 |
| 2026-10-05 | « En ligne » pour le plafond = publiée et `now < ends_at`, sans comparer `published_at` | Risque signalé par le Lot 0 : deux parutions qui lisent l'horloge dans un ordre et prennent le verrou dans l'autre laissaient 4 en ligne | ADR-0081 §4.1 |
| 2026-10-05 | `DrawingReaderPort` créé au Lot C, pas au Lot 0 | `port_contracts_test` exige un adaptateur par port : un port gelé seul casse la suite | — (plan) |
| 2026-10-05 | Le port de lecture SVG rend `failure(:invalid, errors: { file: [raison] })` | `Shared::Result` n'accepte que ses codes ; l'ADR écrivait `failure(:unsafe)` | ADR-0081 (amendement de clôture) |
| 2026-10-05 | Bibliothèque plafonnée à 50 dessins actifs | Revue de sécurité du Lot C (B1) : sans plafond, un compte de l'équipe compromis alourdit le formulaire de tous les auteurs | ADR-0081 (amendement de clôture) |
| 2026-10-05 | Une annonce modifiée garde son dessin de l'équipe retiré ; seul un nouveau choix d'un dessin retiré est refusé (422) | AV-10 à la lettre obligeait à changer de dessin pour corriger une faute ; le dessin reste servi jusqu'à la fin de l'annonce | UDR-0075 (amendement de clôture) |
| 2026-10-05 | « jusqu'au » montre la date de `ends_at` | Le challenger a vu « jusqu'au 4 nov. » pour une fin le 4 nov. à 19:21 : c'est le vrai dernier jour ; la règle « fin − 1 jour » de l'UDR et du PRD était fausse | UDR-0075 §3.4 (corrigée) |
| 2026-10-05 | L'encadré nomme toutes les annonces qu'une parution archiverait | Un auteur à plus de 3 en ligne (données antérieures) en perd plusieurs ; l'encadré n'en nommait qu'une | UDR-0075 (amendement, Lot F) |
| 2026-10-05 | Un Lot F, hors plan, corrige les constats de la phase 5 | Revue de sécurité (F1, F2, F3, verrou) et analyse des tests : défauts de concurrence trouvés après les lots | — (plan) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **La parution relisait l'annonce hors de sa transaction** (Lot A). Deux « Publier » simultanés sur le même brouillon archivaient une annonce de trop ; le job de programmation réécrivait une copie périmée de l'annonce, toutes colonnes comprises (F1, F2). Les tests à deux threads du Lot A prouvaient le plafond entre deux annonces **différentes**, pas la double soumission d'une même annonce. Trouvé par la revue de sécurité de la phase 5, corrigé au Lot F. À ne pas refaire : toute écriture qui dépend d'un verrou relit ce qu'elle écrit **après** l'avoir pris.
- **Trois chiffres de la référence étaient faux**, et chacun a coûté un aller-retour : l'heure de fin (PRD « 00:00 » contre ADR « heure gardée »), la règle « jusqu'au » (« fin − 1 jour »), le contraste minimal de l'UDR (8,9:1 annoncé, 8,06:1 calculé). Le nombre de requêtes de l'accueil élève (16 au PRD §7) venait du journal de la V1 (15 et 16), alors que `Develop` en était déjà à 16 et 17. À ne pas refaire : mesurer la base sur `Develop` avant d'écrire un chiffre dans le PRD.
- **Un `pkill -f "rails test"` du Lot A** a pu couper les tests des lots B, C et D qui tournaient en parallèle. Dans des worktrees parallèles, on n'arrête que ses propres processus.
- **Le Lot E a lu un repository depuis la vue** du formulaire, faute de pouvoir toucher le contrôleur du Lot A, et gardé le dessin porté dans une variable d'instance du use case. Repris au Lot F.
- **`script/ci/record_timings` ne lit pas un fichier système lancé seul** : « Capybara starting Puma… » s'imprime sur la ligne du test. La durée du parcours (9,3 s) a été écrite à la main, médiane de 5 passages.
- **Le dump local de PostgreSQL 16 reformate `db/schema.rb`** en entier : la migration du Lot 0 a été reportée à la main, aller-retour vérifié.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `FOR UPDATE` sur une ligne `users` bloque toute insertion qui la référence par clé étrangère (le contrôle de la clé prend `FOR KEY SHARE`) : journal d'audit, sessions… `FOR NO KEY UPDATE` sérialise autant les parutions d'un même auteur sans bloquer ces insertions.
- `Shared::Result.failure` n'accepte qu'une liste fermée de codes : une raison métier va dans `errors:`.
- `test/architecture/port_contracts_test.rb` exige un adaptateur par port : un port ne peut pas être gelé au Lot 0 sans son adaptateur.
- `test/design/dark_mode_test.rb` énumère chaque règle qui redéfinit des tokens : une règle de thème (`[data-announcement-theme]`) doit y être déclarée, avec exactement ses 4 tokens.
- Le morphing de Turbo garde le fichier choisi dans un `<input type="file">` après un ajout réussi : le formulaire d'ajout porte `data-turbo-action="advance"`.
- libxml2 nomme `x:script` un élément au préfixe non déclaré : une liste de refus compare le nom local, après `:`.
- Le Chromium de Playwright n'a pas de codec AAC : un M4A ne se lit pas dans les tests système ; la preuve passe par le 206, l'identité des octets et le décodage `ffmpeg` du fichier servi.
- L'accueil élève fait 16 requêtes sans annonce et 17 avec, sur `Develop` comme sur la branche ; les thèmes n'en ajoutent aucune, les dessins de l'équipe une seule, quel que soit leur nombre (18).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| À 360 px, le nom d'un dessin de la bibliothèque est tronqué à 1 caractère ; sous 640 px, seul l'aperçu « Ciel » s'affiche | Choix entre trois aperçus et un nom lisible, à trancher dans l'UDR | `finitions-ux` |
| Aucun aperçu du dessin avant son envoi | Le PRD §3 et l'UDR §3.5 montrent les 3 thèmes après l'ajout seulement | `finitions-ux` |
| Aucune limite de taille du corps de requête (Thruster `MAX_REQUEST_BODY` à 0) : le poids d'un fichier est vérifié après sa réception complète | Propriété de la plateforme, pas du chantier (revue de sécurité du Lot C, B2) | à ouvrir, transverse |
| Le téléversement des fichiers se fait dans la transaction de la parution, sous le verrou de l'auteur | `FOR NO KEY UPDATE` (Lot F) ne bloque plus que les parutions du même auteur ; téléverser avant la transaction demande de séparer l'écriture des pièces jointes | à ouvrir si la mesure le demande |
| Le rôle `field` de l'équipe peut téléverser des dessins | Conforme à l'ADR-0081 (« équipe ») ; la reconstruction borne l'impact à des formes d'une couleur | à revoir avec les rôles de l'équipe |
| `index` et `edit` de la bibliothèque lisent sans use case ni policy (seul `allow_roles :team` les garde) | Lecture permise à toute l'équipe, sans fuite ; hors ADR-0028 à la lettre | — |
| En sombre, le fond de « Nuit » est plus foncé que la page ; les parties blanches des 8 dessins de base deviennent sombres | Conforme à l'UDR-0075 et à la V1 ; élément décoratif | `finitions-ux` |
| `script/ci/record_timings` ne lit pas un fichier lancé seul | Contourné à la main (médiane de 5 passages) | outillage CI |
| `DirectionHomeQueryTest` (AD-23) a échoué une fois, sans lien avec ce chantier | Vert en relance ; à reproduire dans son chantier | `tests-instables` |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
