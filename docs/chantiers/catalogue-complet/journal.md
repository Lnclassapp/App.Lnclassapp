# Journal — Catalogue complet : pages publiques Niveau, Matière et Série

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sur les recommandations de l'agent, en attente des réponses du porteur aux questions 1 à 12 | Le porteur a demandé de lancer V2 à V6 ; le cadrage doit être validé avant le code | ADR-0099, UDR-0113 à 0115, toutes « Proposé » |
| 2026-10-16 | Pas de lot pour CA-01, CA-02, CA-03, AS-01 | L'inventaire du code les montre livrées (`politique-cache`, `interface-enseignant-organisation`, `catalogue-niveau-eleve`, `cours-eleve`) ou couverte sous sa forme corrigée (page d'une fiche) | Non : constat d'inventaire, écrit dans le memo |
| 2026-10-16 | Une requête par page publique, sur un socle commun `PublicCourses` | Quatre lots parallèles ne peuvent pas partager un fichier de requête | Oui, ADR-0099 §4.2 |
| 2026-10-16 | Le porteur accepte les recommandations (questions 1 à 12) ; les maquettes sont les captures de la PR | Réponses du porteur du 2026-10-16 (memo) | ADR-0099, UDR-0113 à 0115 passées « Accepté » au Lot 0 |
| 2026-10-16 | Lot 0 : un lien de retour (`ui_back_link`) remplace le fil d'Ariane prévu par les UDR-0113 à 0115 | L'UDR-0054 §3.2 n'admet qu'un retour à chevron, et le garde-fou FU-11 (`test/views/page_titles_test.rb`) refuse « breadcrumb » et « Fil d'Ariane » dans les vues | Amendement écrit dans les UDR-0113 §3.1, 0114 §3.2, 0115 §3.2 |
| 2026-10-16 | Lot 0 : la ligne de groupe (6 cartes et nombre de cours par matière) sort d'**une** requête, par `ROW_NUMBER()` et `COUNT(*) OVER (PARTITION BY material_id)` ; `series_pairs` donne les séries visibles de tous les niveaux en une requête | Tenir trois requêtes par page (ADR-0099 §4.5) : le niveau, ses séries, ses groupes | Non : détail de `PublicCourses` |
| 2026-10-16 | Lot B : la page matière fait trois requêtes (la matière, les comptes par niveau, la page de cartes), une de plus avec `?serie=` (la série rattachée et son compte, dans une sous-requête) ; une série inconnue ou non rattachée au niveau répond 404, comme un niveau sans cours de la matière | Le compte d'une série ne se déduit pas des comptes par niveau ; le PRD ne disait rien de `?serie=` non rattachée | Non : UDR-0114 §3.1 l'écrit déjà |
| 2026-10-16 | Lot B : le test système du défilement tourne à 390 px | Sur l'écran large des tests, 24 cartes sans description tiennent dans la fenêtre et le frame différé se charge à l'arrivée ; au téléphone il est hors de l'écran, comme le veut l'ADR-0076 §4.2 | Non |
| 2026-10-16 | Lot C : la page série se lit en trois requêtes (le couple rattaché, les séries visibles du niveau, les groupes) ; « dont les cours communs » n'est écrit que si la page en compte un | `BOOL_OR(series_id IS NULL) OVER ()` dans la requête des groupes, sans requête de plus | Non |
| 2026-10-16 | Lot D : `script/perf/audit_pages.rb` n'est pas modifié | Il part déjà de toutes les routes GET sans paramètre (dont `/niveaux`) et suit les liens de chaque page, profil visiteur compris : les quatre pages y entrent seules | Non |
| 2026-10-16 | Lot D : le plan du site reste en cache public d'une heure, sans session (ADR-0074 §4.6) ; seules les pages HTML du catalogue sont sans cache partagé | Le plan du site ne porte ni cookie ni jeton ; un cours dépublié en sort au plus une heure après | Non : ADR-0099 §4.4 et §4.5 inchangés |
| 2026-10-16 | Les titres disent le nom du niveau tel qu'il est en base (« Cours de Tle »), pas « Terminale » comme les exemples du PRD | Le slug est figé (ADR-0029) mais le nom suit le référentiel (memo, cas limites) : renommer « Tle » en « Terminale » dans `/teams/levels` change les titres sans casser une adresse | Non : à décider par l'équipe Contenu |

## Ce qui a dérapé

- L'agent exécutant a été arrêté avant la clôture ; un agent de reprise a fusionné `origin/Develop` (docs seules, sans conflit), refait le parcours visiteur sur un serveur local (`curl` de chaque page, `/sitemap.xml`, brouillon absent du HTML) et clos le chantier.
- `bin/ci-quiet` sur une machine saturée (charge 55 puis 94 sur 4 cœurs, une dizaine de CI en parallèle) : tests système en échec en masse sur des écrans que le chantier ne touche pas, puis passage tué ; relancé une fois dans la file commune (`flock`). Le garde-fou `test_no_ignored_yarn_advisory_is_past_its_review_date` échoue depuis le 2026-10-18 sur toutes les branches : l'avis Yarn `1240992` (`braces`) devait être réexaminé le 2026-10-17 (chantier `audit-yarn-braces`), hors de ce chantier.

- La feuille de route appelle CA-17, CA-21 et CA-23 « pages publiques » alors que l'inventaire de l'ancienne application les décrit « tout connecté » (CA-17, CA-21) et « `team` » (CA-23). L'écart n'avait jamais été posé au porteur : c'est la question 1.
- Le jeu de mesure `script/perf/seed_dataset.rb` ne tourne plus : `teacher_profiles.joined_via` (ADR-0083) est obligatoire et le jeu ne le remplit pas. La mesure de CC-23 a été faite sur 200 cours publiés semés à part (hors dépôt), avec `audit_pages.rb` en profil visiteur.
- `script/ci/record_timings` associe une durée au fichier par le nom court de la classe : un test système et un test d'intégration de même nom (`PublicLevelPagesTest`) se confondent. Les tests système s'appellent `…JourneyTest`.
- La première tentative de commit du Lot D a échoué au pre-commit sur une machine chargée (semis du jeu de mesure en parallèle) ; la seconde, identique, est passée.
- Lot A : `assert_queries_count` ne compte pas les requêtes servies par le cache de requêtes d'Active Record ; un test qui lit deux fois la même page dans un même test doit mesurer la première lecture.

## Ce qu'on a appris sur la codebase

- Le catalogue connecté n'a plus de dette de V4 : filtres dans l'adresse pour tous les rôles sauf l'élève, pagination par frame différé, brouillons filtrés en SQL hors équipe.
- `ReadPublishedPolicy` refuse un acteur `nil` : toute lecture anonyme du catalogue doit passer par une requête qui filtre le publié elle-même.
- Le blog a posé tout l'outillage du référencement (`canonical_url`, `_head`, plan du site, `X-Robots-Tag` hors production) ; le catalogue le reprend sans le modifier.
- La bande « Matières » de la homepage est une liste écrite en dur dans la vue, sans lien.
- Une sous-requête passée en jointure écrite (`joins("… (#{relation.to_sql}) …")`) qui joint `levels` fait renommer par Active Record la jointure d'association `:level` de la requête englobante : écrire alors toutes les jointures.
- Le frame différé n'est « hors de l'écran à l'arrivée » qu'à condition que la page soit assez haute : 24 cartes sans description tiennent dans un écran d'ordinateur de test.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Sommaire public d'un cours | Question 3 : vitrine limitée aux titres | À ouvrir si le porteur le demande |
| Cache HTML des pages publiques (gabarit sans session) | ADR-0076 ; trafic non mesuré | À rouvrir sur mesure du trafic |
| Liste « Tous les exercices » pour l'équipe | Question 9 : AS-01 fermée sous sa forme corrigée | À ouvrir si le besoin se confirme |
| Q9, matrice des sous-rôles | Hors de ce chantier | `sous-roles-equipe` |
| Noms des niveaux du référentiel (« Tle », « 6ème ») dans les titres publics | Le nom est celui de la base ; « Terminale » demande un renommage par l'équipe, pas du code | Équipe Contenu, dans `/teams/levels` |
| Jeu de mesure `script/perf/dataset.rb` cassé (`joined_via`) | Hors du périmètre ; contourné pour CC-23 | À réparer au prochain chantier qui mesure |
| Revue par les sous-agents (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) | Ni l'agent exécutant ni l'agent de reprise n'avaient d'outil pour lancer d'autres agents | Avant la fusion de la PR |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 |
| **PR** | `feature/catalogue-complet` → `Develop`, prête, non fusionnée |
| **ADR produits** | ADR-0099 (Accepté) |
| **UDR produits** | UDR-0113, UDR-0114, UDR-0115 (Accepté ; retour à chevron au lieu du fil d'Ariane) |
