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
| 2026-09-28 | Parties gardées vérifiées à leur forme exacte (JPEG, PNG, WebP), VP8X réécrit, taille VP8X croisée avec le bitstream | Retour du challenger de la PR #65 (M1 à M3) : des octets libres survivaient dans les parties de la liste blanche | oui, ADR-0060 amendé |
| 2026-09-28 | JPEG accepté et coupé à son premier EOI au lieu d'être refusé | Décision du coordinateur (M4) : les Motion Photo, MPF et cartes de gain des téléphones bloquaient des photos ordinaires | oui, ADR-0060 amendé |
| 2026-09-28 | Octets après le flux zlib (PNG), après le bitstream VP8/VP8L et dans l'ALPH compressé (WebP), en fin de scan (JPEG) : limite documentée, pas de décodage | Invérifiables sans décoder ; décompresser le PNG ouvrirait la porte aux bombes de décompression et contredirait « le serveur ne décode pas l'image » | oui, ADR-0060 (coûts consentis) |
| 2026-09-28 | Tables JPEG : chaque définition doit servir avant d'être redéfinie (plutôt que « une seule définition ») | Seule option sûre qui accepte les JPEG progressifs, où libjpeg redéfinit les tables DHT entre deux scans | oui, ADR-0060 amendé |
| 2026-09-28 | PNG : palette suggérée, cHRM et gAMA invraisemblable retirés ; ordre de la norme imposé ; plafonds de parties | Second retour du challenger #65 | oui, ADR-0060 amendé |
| 2026-09-28 | DNL refusé partout plutôt qu'« accepté si la hauteur du SOF vaut 0 » | Une hauteur nulle est déjà refusée (la taille est lue dans le SOF) : aucun DNL utile ne peut exister ; le refus est plus simple et sûr | oui, ADR-0060 amendé |
| 2026-09-28 | EOBn (symboles AC de taille 0) admis dans une table DHT seulement en progressif | La règle « 0x00, 0xF0 ou taille 1 à 10 » refusait le JPEG progressif de libjpeg, dont les tables AC portent des EOBn | oui, ADR-0060 amendé |
| 2026-09-28 | Pas de photo dans la liste des enseignants d'un établissement | `SchoolDetailQuery::TeacherRow` n'a pas d'identifiant public et le fichier est modifié par `feature/code-etablissement` en parallèle | non (dette) |

## Ce qui a dérapé

- **Contre-épreuve de la PR #50 : KO, puis corrigée.** (1) *Majeur, confidentialité* : la lecture JPEG s'arrêtait au premier octet inattendu et `strip` recopiait le reste tel quel. Un octet de remplissage `0xFF` (légal) ou un `0x00` égaré avant l'APP1, dans un envoi direct, suffisait à stocker l'Exif et le GPS. Cause : un lecteur « d'en-tête » tolérant, alors qu'un filtre de confidentialité doit échouer fermé. Correction : lecture stricte de tout le flux pour les trois formats, remplissage géré, refus de tout le reste, relecture des octets gardés, fuzz à chaque frontière de segment. (2) *Moyen* : un WebP de 40 octets (en-tête seul) ou corrompu était stocké avec un toast de succès ; il est maintenant refusé par le serveur, et le navigateur refuse une image qui se décode en rien. (3) Les routes Active Storage répondaient à un `signed_id` fuité et acceptaient un envoi direct anonyme (avant cette PR) : elles ne sont plus dessinées. Tous les tests de ces cas ont été lancés rouges avant la correction.
- La PR #50 a été fusionnée dans `Develop` (ba28faf8) avant la correction de la seconde contre-épreuve : ces corrections partent dans la branche de suivi `fix/photo-de-profil-suivi`, depuis `Develop`.
- **Retour du challenger de la PR #65 : quatre défauts mineurs** dans `ImageHeader`, corrigés sur `fix/photo-image-header`. (M1) Des octets libres survivaient dans des parties gardées : gAMA, sRGB, cHRM allongés, PLTE et tRNS hors bornes, IEND non vide, chunk après le premier IEND (seul le dernier chunk devait être IEND), octets réservés de VP8X (seul l'octet des drapeaux était masqué), bourrage RIFF non nul. (M2) DQT allongé, VP8X de plus de 10 octets, ALPH à l'en-tête invalide acceptés ; en passant, DHT, SOF, SOS, DRI et DAC allongés, second SOF, second IHDR, second VP8X, IHDR hors norme et VP8L de version non nulle l'étaient aussi. (M3) La taille du VP8X n'était pas croisée avec celle du bitstream. (M4) Un JPEG de téléphone avec des images après EOI était refusé ; il est désormais coupé au premier EOI. 13 tests lancés rouges sur l'ancien code (domaine, DTO, contrôleur), verts après ; cinq fixtures normales ajoutées (JPEG progressif, PNG indexé, gris avec tRNS, avec gAMA/cHRM/sRGB, WebP sans perte étendu) et une hostile (`hostile/motion_photo_trailer.jpg`). `strip` rend désormais tel quel tout fichier que `read` refuse : réécrire un VP8X tronqué aurait levé une exception.
- **Second retour du challenger sur 56fe4e2f : KO.** (1) *Bloquant* : un DAC n'était vérifié que sur sa longueur paire ; ~65 Ko libres passaient, dans un fichier qui ne se décodait plus. (2) DQT et DHT sur des numéros inutilisés, ou redéfinis à volonté : 64 octets libres par DQT. (3) Plusieurs segments Adobe : un octet libre (la transformée) par segment. (4) PNG : palette suggérée d'une image en couleurs, cHRM et gAMA restaient des champs libres ; aucun ordre n'était imposé. (5) Performance : un fichier de 1 Mo pathologique prenait 1,2 à 1,9 s. Corrigé : tables suivies de leur définition à leur usage, DAC seulement en codage arithmétique et borné, un seul Adobe, retrait des chunks PNG inutiles au rendu, ordre de la norme, plafonds, recherche du remplissage par expression régulière, une seule lecture dans `strip`. En passant, le harnais a montré qu'un scan de plus dans un JPEG séquentiel portait des octets libres : chaque composante doit y être codée dans exactement un scan. Tests rouges d'abord (7 tests, puis 1 pour le scan de trop).
- **Troisième retour du challenger sur a2185ea8 : KO.** (1) *Bloquant* : seule la forme d'une table DHT (16 effectifs) était vérifiée ; une table AC de 510 symboles ou trois codes de longueur 1 passaient. (2) DNL accepté partout (2 octets libres chacun). (3) SOF sans perte accepté sans DHT. Corrigé : table de Huffman réalisable (≤ 256 codes, règle de libjpeg sans code tout à 1, symboles distincts et valides pour la classe), DNL et SOF sans perte refusés. La première version de la règle des symboles AC refusait la fixture progressive (EOBn) : les EOBn sont admis en progressif seulement, la table étant revérifiée une fois le SOF connu. Tests rouges d'abord ; `atk.rb`, `atk2.rb`, `adobe.rb`, `fuzz.rb` rejoués ; corpus `reg/` : 205/205 acceptés et idempotents, sortie identique à `reg_h.txt`.
- **Seconde contre-épreuve** : trois réserves non bloquantes. (1) Le retrait fonctionnait par liste noire : un APP2 signé `ICC_PROFILE`, un APP14 `Adobe` allongé, une vignette JFXX et un chunk PNG privé (`gpSx`) ou `tIME` transportaient encore un secret. Passage à une liste blanche avec réécriture des segments à champs libres (JFIF, Adobe) ; les profils ICC partent aussi, au-delà de la demande, parce que leur contenu est libre. (2) Un flux compressé corrompu dans une structure valide reste accepté (coût consenti). La double bulle du navigateur est corrigée : le champ reprend notre message. (3) `active_storage/blobs/_blob` appelait `blob.representation` sans route : 500 latent sur un contenu riche qui aurait une pièce jointe ; réécrit sans adresse, test d'intégration à l'appui. Tests rouges d'abord.
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
