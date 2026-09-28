# Journal — Photo de profil

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros ADR-0060 et UDR-0047 (plus haut existant + 4) | Consigne du porteur : éviter les collisions avec les chantiers parallèles (0057, 0058, UDR 0044, 0045 déjà pris dans d'autres worktrees) | non |
| 2026-09-28 | Lecture par un contrôleur authentifié plutôt que par une URL `rails_storage_proxy` signée | Le proxy d'Active Storage répond `Cache-Control: public` pour toujours, et une URL signée est un laissez-passer sans session | oui, ADR-0060 |
| 2026-09-28 | Le serveur **retire** les métadonnées (JPEG, PNG, WebP) au lieu de refuser l'image — révision de la réponse du grill, PRD amendé | Sans navigateur Safari pour le vérifier, rien ne garantit que son canvas JPEG (chemin iPhone : pas d'encodage WebP) n'écrit pas un segment Exif ; refuser aurait bloqué tous les iPhone. Retirer quelques segments est sûr et court en Ruby pur | oui, ADR-0060 |
| 2026-09-28 | Pas de photo dans la liste des enseignants d'un établissement | `SchoolDetailQuery::TeacherRow` n'a pas d'identifiant public et le fichier est modifié par `feature/code-etablissement` en parallèle | non (dette) |

## Ce qui a dérapé

- **Réponse du grill révisée en phase 4** : « refuser une image avec Exif » aurait probablement bloqué tous les iPhone (Safari n'encode pas le WebP dans un canvas, son JPEG passe par ImageIO, et aucun Safari n'était disponible pour vérifier qu'il n'écrit pas d'Exif). Le serveur retire désormais les métadonnées ; PRD, ADR et UDR amendés explicitement.
- Le test « chaque préfixe de chaque image se lit sans erreur » (fuzz par troncature) a trouvé un plantage réel : `strip` sur un WebP tronqué dans son en-tête VP8X (`nil & flags`). Corrigé avant le premier commit.
- Un `sed` sur la page du design system a aussi modifié la boucle des tailles de **bouton** (même motif `%i[sm md lg]`) ; `DesignControllerTest` l'a attrapé.
- `#fff` dans le contrôleur Stimulus (fond du canvas) : refusé par `DesignTokensTest` ; remplacé par la variable du token `--color-white`.
- Premier passage du test système : la vérification « l'image a chargé » lisait `img.complete` avant la fin du chargement ; elle est maintenant réessayée (`synchronize`).
- **Rouge d'abord, prouvé après coup pour le test système** : le contrôleur Stimulus a été écrit avant le premier lancement du test système. Pour le prouver, le contrôleur a été retiré du bundle : 3 tests système sur 4 échouent (pas d'aperçu, pas d'allègement), seul le refus du PDF (chemin serveur) passe. Les tests du domaine, de l'adaptateur, des requêtes, des contrôleurs et de l'affichage ont été lancés rouges avant leur code.
- Le dossier de captures du scratchpad est partagé avec les autres agents : les captures de ce chantier vivent dans `shots/photo-de-profil/`.

## Ce qu'on a appris sur la codebase

- `ui_avatar` acceptait déjà `src:` et le shell passait déjà `user.avatar_url` : l'en-tête et la barre latérale n'avaient besoin que d'une donnée.
- `config.active_storage.resolve_model_to_route = :rails_storage_proxy` est posé mais rien ne sert de fichier Active Storage au navigateur.
- Le contrôleur proxy d'Active Storage répond `Cache-Control: public` sans fin : inadapté à une donnée personnelle, d'où le contrôleur authentifié.
- Un blob créé avec `metadata: { analyzed: true }` n'enfile pas d'`AnalyzeJob` : sans cela, chaque envoi réveillerait l'avertissement libvips en production.
- Le pre-commit exécute les tests avec le Ruby et la locale du shell : lancé sans l'environnement du projet (Ruby 3.4, `LANG=C.UTF-8`), il échoue sur `it` (Ruby 3.3) et sur l'encodage US-ASCII d'un fichier du domaine. Ce n'est pas le code : il faut commiter depuis un shell préparé.
- `turbo_stream.refresh(request_id: nil)` (morphing) met à jour l'en-tête et la barre latérale sans cible dédiée : aucune modification des partiels de navigation n'a été nécessaire, `ShellUser#avatar_url` existait déjà.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Photo dans la liste des enseignants d'un établissement (équipe) | Collision avec `feature/code-etablissement` ; la requête n'expose pas l'identifiant public | à ouvrir après le merge |
| Vérifier le parcours sur un iPhone (Safari : chemin JPEG du canvas) et sur un Android d'entrée de gamme réel | Aucun Safari ni appareil dans l'environnement ; seul Chrome headless a exécuté le recadrage | recette |
| Aucune limite de taille de requête avant Rails : un envoi de plusieurs centaines de Mo est écrit sur disque par Rack avant que le DTO le refuse | Même situation que les imports ; relève de la configuration du serveur | à ouvrir (infra) |
| Routes Active Storage toujours dessinées (`/rails/active_storage/...`) | Aucun `signed_id` de photo n'est émis ; les couper demande de vérifier les autres usages | à ouvrir |
| Test de mutation (`mutant-minitest`) sur le domaine | L'outil n'est pas installé dans ce dépôt (écart connu, conventions §7) | chantier outillage |

## Clôture

| | |
|---|---|
| **Livré le** | — (branche `feature/photo-de-profil` poussée, PR à ouvrir) |
| **PR** | — |
| **ADR produits** | ADR-0060 |
| **UDR produits** | UDR-0047 |
