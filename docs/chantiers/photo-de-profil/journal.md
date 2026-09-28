# Journal — Photo de profil

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Numéros ADR-0060 et UDR-0047 (plus haut existant + 4) | Consigne du porteur : éviter les collisions avec les chantiers parallèles (0057, 0058, UDR 0044, 0045 déjà pris dans d'autres worktrees) | non |
| 2026-09-28 | Lecture par un contrôleur authentifié plutôt que par une URL `rails_storage_proxy` signée | Le proxy d'Active Storage répond `Cache-Control: public` pour toujours, et une URL signée est un laissez-passer sans session | oui, ADR-0060 |
| 2026-09-28 | Le serveur **retire** les métadonnées (JPEG, PNG, WebP) au lieu de refuser l'image — révision de la réponse du grill, PRD amendé | Sans navigateur Safari pour le vérifier, rien ne garantit que son canvas JPEG (chemin iPhone : pas d'encodage WebP) n'écrit pas un segment Exif ; refuser aurait bloqué tous les iPhone. Retirer quelques segments est sûr et court en Ruby pur | oui, ADR-0060 |
| 2026-09-28 | Lecture stricte (fail closed) de tout le flux d'image, et non de l'en-tête | Contre-épreuve de la PR #50 : contournement du retrait de l'Exif | oui, ADR-0060 amendé |
| 2026-09-28 | Routes Active Storage non dessinées | Aucune fonctionnalité ne les utilise ; elles servaient un `signed_id` fuité et acceptaient un envoi direct anonyme | oui, ADR-0060 amendé |
| 2026-09-28 | Pas d'exigence de carré côté serveur ; `purge_later` gardé au remplacement | Voir les coûts consentis de l'ADR-0060 | oui |
| 2026-09-28 | Pas de photo dans la liste des enseignants d'un établissement | `SchoolDetailQuery::TeacherRow` n'a pas d'identifiant public et le fichier est modifié par `feature/code-etablissement` en parallèle | non (dette) |

## Ce qui a dérapé

- **Contre-épreuve de la PR #50 : KO, puis corrigée.** (1) *Majeur, confidentialité* : la lecture JPEG s'arrêtait au premier octet inattendu et `strip` recopiait le reste tel quel. Un octet de remplissage `0xFF` (légal) ou un `0x00` égaré avant l'APP1, dans un envoi direct, suffisait à stocker l'Exif et le GPS. Cause : un lecteur « d'en-tête » tolérant, alors qu'un filtre de confidentialité doit échouer fermé. Correction : lecture stricte de tout le flux pour les trois formats, remplissage géré, refus de tout le reste, relecture des octets gardés, fuzz à chaque frontière de segment. (2) *Moyen* : un WebP de 40 octets (en-tête seul) ou corrompu était stocké avec un toast de succès ; il est maintenant refusé par le serveur, et le navigateur refuse une image qui se décode en rien. (3) Les routes Active Storage répondaient à un `signed_id` fuité et acceptaient un envoi direct anonyme (avant cette PR) : elles ne sont plus dessinées. Tous les tests de ces cas ont été lancés rouges avant la correction.
- Couper les routes Active Storage a cassé les deux formulaires de l'éditeur riche (12 erreurs) : `rich_textarea` d'Action Text construit par défaut l'adresse d'envoi direct. Les formulaires passent maintenant des adresses vides ; les tests des formulaires vérifient qu'aucune adresse n'est émise.
- La lecture stricte a aussi révélé qu'un VP8X trop court faisait lire la taille dans le chunk suivant : la taille est maintenant lue dans le chunk lui-même, et un VP8X n'est accepté qu'en premier.

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
| Test de mutation (`mutant-minitest`) sur le domaine | L'outil n'est pas installé dans ce dépôt (écart connu, conventions §7) | chantier outillage |

## Clôture

| | |
|---|---|
| **Livré le** | — (branche `feature/photo-de-profil` poussée, PR à ouvrir) |
| **PR** | — |
| **ADR produits** | ADR-0060 |
| **UDR produits** | UDR-0047 |
