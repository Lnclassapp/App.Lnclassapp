# Journal — Blog de Lnclass

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-02 | Ouvrir le chantier `blog`, hors plan de `refonte-application` : un blog public de Lnclass, écrit par l'équipe, lisible sans compte. Quatre objectifs : se faire connaître, rassurer et convaincre, aider à réussir, annoncer les nouveautés. Hors périmètre : commentaires, abonnement, publication programmée | Demande du porteur (« créer le blog de Lnclass ») ; la rentrée et le démarchage en cours | Non — le rattachement à une vague est tranché au grill |
| 2026-10-02 | Fin des questions : le porteur délègue les choix restants (« arrête de me poser des questions… crée un système de blog et puis c'est tout »). Grill 12 retenu par défaut ; hôte canonique `lnclass.com` par défaut ; le passage de la phase 3 à la phase 4 se fait sans nouvelle validation | Consigne explicite du porteur | Non |
| 2026-10-03 | PRD §7 amendé : la cible « 0 Ko de JavaScript ajouté aux pages de lecture » est ramenée au budget de l'ADR-0051. Mesure : point d'entrée commun 43,0 → 45,6 Ko gzip (+2,6 ; base `f3494b80` recompilée, `bin/check-asset-budget`), budget 60 Ko tenu. Les contrôleurs `communication--cover-picker`, `--image-alts`, `--character-count` et la partie images de `rich-text-editor` restent dans le bundle commun | Les sortir derrière un `import()` exige un enregistrement paresseux des contrôleurs Stimulus pour toutes les pages (observer le DOM, cadres et flux Turbo compris) : mécanisme nouveau, jugé ni simple ni sûr dans la passe de corrections (challenge C4) | Non — PRD §7 modifié (mention datée) ; suivi `optimize` proposé : `controleurs-de-gestion-a-la-demande` |
| 2026-10-03 | Décisions renumérotées : ADR-0073 → **ADR-0074**, UDR-0064 → **UDR-0066**, UDR-0065 → **UDR-0067** | Pendant le chantier, `Develop` a accepté ses propres ADR-0073 (validation des enseignants en pause), UDR-0064 (page d'accueil) et UDR-0065 (mode sombre) ; un numéro ne se réutilise jamais. Seules les lignes écrites par ce chantier ont été renumérotées, pour ne pas toucher aux références de `Develop` | Non |
| 2026-10-03 | Les robots d'IA (GPTBot, ClaudeBot, PerplexityBot…) gardent l'accès au blog : `robots.txt` reste ouvert à tous | Porteur : « laisse les IA lire le blog » ; « se faire connaître » est un objectif. Le filtre du compteur ne bloque personne, il ne compte pas les robots | Non |
| 2026-10-03 | `debugbar` est retiré du dépôt dans un chantier séparé, `retrait-debugbar` (PR #154), et non dans ce chantier | Porteur : « retire debugbar du repo » ; le défaut (500 en développement après un envoi d'image) est préexistant et hors du blog | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche partie d'un `Develop` périmé.** Dans le conteneur, la référence `origin/Develop` avait 181 commits de retard (`c6d7977` au lieu de `8354045`, PR #142) : `git status` disait « à jour ». Repéré par l'exploration de la documentation (UDR-0056 à 0063 et ADR-0069 à 0072 absents de l'arbre), rattrapé par un merge avant toute écriture de fond. Parade : `git fetch origin Develop` avant de brancher.
- **Lot 0 interrompu par un redémarrage du conteneur** après la sous-étape 0.1 : le travail de 0.2 a été sauvé dans un commit de point de sauvegarde (`1e479240`), puis relu et vérifié par mutation (30 mutants tués) à la reprise. Parade : committer et pousser après chaque élément vert.
- **Migration renommée** `20261003120000_create_articles.rb` (le plan disait `20261004090000`) : Rails refuse une migration datée de plus d'un jour dans le futur.
- **Assainisseur de l'ADR-0074 §6 inopérant tel qu'écrit** : le `:prune` de Loofah supprime `<action-text-attachment>` avant le filtre. Corrigé par `ArticlePrune`, qui n'épargne que la pièce jointe d'image d'article ; en mode article, `<img>` sort de la liste blanche (BL-16). Le mode des cours, fiches et imports est inchangé.
- **Tests système non joués en local** au Lot 0 (pas de Chrome dans le conteneur au départ) : la CI les joue.
- **Phase 5, revues : des échecs silencieux livrés verts** (corrections F1 à F11, 2026-10-03). `Rails.error` n'avait aucun abonné (le compteur « signalait » ses pannes à personne) ; `transition` rendait toujours `true` (deux archivages simultanés écrivaient deux fois) ; une collision de slug sur un article déjà enregistré était réessayée ; un `sgid` illisible faisait détruire les images citées ; `attach` rattachait une image prise entre-temps par un autre article ; `params.dig` sur une chaîne répondait 500. Chaque correction a son test vu rouge. Parade : pour chaque `rescue` et chaque écriture conditionnelle, écrire le test du cas qui échoue, pas seulement du cas nominal.
- **Transaction de l'adaptateur jointe à celle du use case.** En corrigeant F8, l'échec rattrapé dans `ArticleRepository#save` laissait l'article écrit : en production la transaction de l'adaptateur rejoint celle du use case (`Repositories::Shared::Transaction#call`), et une exception rattrapée à l'intérieur ne l'annule pas. Les tests de l'adaptateur ne le voyaient pas : la transaction de test n'est pas joignable, celle de l'adaptateur y devient un point de sauvegarde. Corrigé par `requires_new: true` (`703b8475`), testé dans `Transaction#call`. Parade : tester un rattrapage d'échec d'écriture à l'intérieur de la transaction du use case.
- **Lecture du bucket avant la règle de lecture** : `/blog/images/:public_id` téléchargeait le fichier avant de savoir si le lecteur avait le droit de le voir (image de brouillon demandée par un visiteur), et `Rack::ConditionalGet` ne répondait 304 qu'après le téléchargement. Corrigé (S1, `1ea47d78`) : `find` sans fichier, règle de lecture, puis 304 par `ETag` ou téléchargement.
- **Test système instable sous charge** (R1) : l'état « en attente » d'un envoi s'observait sous un réseau ralenti ; sous charge l'envoi finissait avant l'assertion. Remplacé par un envoi retenu par le test (`hold_uploads`), dont l'alias pouvait lui-même manquer à une requête libérée juste avant la fin du bloc : l'action d'origine est gardée dans une variable. Cinq passages verts de suite sous charge (suite complète dans un autre worktree, charge 7 à 22 sur 4 cœurs).
- **Challenge produit** : un titre au mot long (« Anticonstitutionnellement ») faisait défiler la page à 390 et 360 px (C1) ; le bouton de fichier de Trix restait titré « Attach Files » (C3) ; `X-Purpose: preview` était compté (C2). Aucun test ne mesurait un titre réel au téléphone.
- **Reprise après une erreur d'API** au milieu de F7 : le test rouge non committé a été retrouvé dans l'arbre de travail et repris tel quel.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Docs périmées, à ne pas suivre** (relevées par l'exploration du 2026-10-02) : `docs/guide/conventions.md` §7 (cliquet de couverture à 45 % : il désigne l'ancien dépôt, la CI impose ici 100 %, ADR-0024) et §8 (`OpenStruct` : abandonné, le contrat réel est `call` + `Shared::Result`, ADR-0026) ; `docs/blueprints/use_case.md` (même écart) ; `docs/workflows/feature.md` (« les ports `communication` existent déjà » : faux ici) ; `docs/guide/architecture.md` (cite un contrôleur de messages qui n'existe pas) ; `docs/guide/glossaire.md`, entrée SchoolStaff (fonction et second facteur, retirés par l'ADR-0065).
- **Une transaction ActiveRecord ouverte dans un adaptateur rejoint celle du use case** : un échec rattrapé à l'intérieur n'annule rien. Pour qu'un adaptateur annule ses propres écritures, `requires_new: true` (point de sauvegarde). Les tests transactionnels masquent l'écart (transaction de test non joignable).
- **`Rack::ConditionalGet` répond 304 après l'action** : il ne fait rien économiser à une action qui lit un fichier. Pour éviter la lecture, `stale?`/`fresh_when` dans l'action, avant le téléchargement.
- - Le contexte `communication` porte déjà des pages publiques statiques sans table (`/aide`, UDR-0061 ; `/mission` et les trois pages juridiques, UDR-0063). Aucune table `communication` n'existe : les annonces (ADR-0045) ne sont pas codées.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| En développement, après l'envoi d'une image (blog **ou** photo de profil existante), toutes les requêtes répondent 500 (`JSON::GeneratorError "\xD0" from ASCII-8BIT to UTF-8`, gem debugbar) jusqu'au redémarrage du serveur | Préexistant, développement seulement (la production ne charge pas debugbar) ; hors du blog (challenge C5) | `bugfix` proposé : `debugbar-televersement-binaire` |
| L'image d'un article archivé reste dans les caches (navigateur, relais) jusqu'à un an : `public, immutable` | Conséquence de l'adresse versionnée sans CDN ; coût consenti (ADR-0074 §5, amendement du 2026-10-03) | Aucun en V1 |
| Le compteur de lectures peut être gonflé : ni plafond, ni dédoublonnage, ni limite de débit | Chiffre indicatif pour l'équipe, sans cookie ni IP par choix (ADR-0074 §4.7, §5) | Aucun en V1 ; à rouvrir si le chiffre sert à décider |
| La purge des orphelines supprime aussi l'image d'une modale restée ouverte plus de 48 h : l'enregistrement la perd en silence | Délai aligné sur les fichiers jamais rattachés (ADR-0047) ; coût consenti (ADR-0074 §5) | Aucun en V1 |
| JavaScript des pages de lecture : +2,6 Ko gzip (contrôleurs de gestion du blog dans le point d'entrée commun), budget ADR-0051 tenu | Enregistrement paresseux des contrôleurs : mécanisme nouveau pour toutes les pages (PRD §7 modifié, challenge C4) | `optimize` proposé : `controleurs-de-gestion-a-la-demande` |
| `og:image` en WebP : les aperçus WhatsApp et Facebook n'ont pas été vérifiés sur un vrai partage | Pas de compte de test ni de partage réel depuis le conteneur (challenge C6) | Vérification manuelle au premier article publié ; si l'aperçu manque, variante JPEG de la couverture |
| Une requête SQL par image du texte au rendu (Action Text résout chaque `sgid`) : N+1 borné à 10 | Déjà consenti par l'ADR-0074 §5, dans le budget de 100 ms (challenge C6) | Aucun en V1 |
| Le cookie de session est posé pour un visiteur sur les pages HTML du blog | Préexistant : nonce CSP de toute page (ADR-0049) ; les images publiques n'en posent pas (challenge C6) | Aucun ; à traiter avec la CSP si besoin |
| Une image prise par un autre article pendant un enregistrement rend « L'enregistrement n'a pas abouti. Réessayez. » ; au nouvel essai, l'image prise disparaît du texte sans message dédié | Course rare (deux modales sur la même image orpheline) ; F8 garantit seulement qu'aucune écriture partielle ne passe | Aucun en V1 |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
