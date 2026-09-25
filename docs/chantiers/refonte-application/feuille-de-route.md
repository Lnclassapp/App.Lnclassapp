# Feuille de route — Recodage complet de Lnclass

| | |
|---|---|
| **Programme** | `refonte-application` — cycle [programme](../../workflows/programme.md) |
| **Écrite le** | 2026-09-22 |
| **Sources** | ADR/UDR ([`decisions/`](../../decisions/)) · [`conventions.md`](../../guide/conventions.md) · [PRD cadre](prd.md) · [inventaire](inventaire/) et ses compléments · [`securite.md`](securite.md) · [`feature_listing.md`](../../feature_listing.md) |
| **Prompt d'origine** | [`prompt-exploration.md`](prompt-exploration.md) |

> **Ce document est le plan de recodage complet.** Il couvre toutes les features de l'ancienne application, les répartit en vagues livrables, et dit pour chacune ce qui doit être décidé avant d'écrire la première ligne. Les lots détaillés n'existent que pour la vague 1 ([`plan.md`](plan.md)) : les suivantes seront découpées à leur ouverture, par `/feature` puis `/plan-lots` (planning roulant, [`programme.md` §3](../../workflows/programme.md#3-planifier--feuille-de-routemd)).

---

## 1. Vue d'ensemble

```
V0  Amorçage du dépôt                 garde-fous avant tout code métier
 │
V1  Boucle pédagogique                équipe publie → enseignant assigne → élève fait l'exercice
 │                                    (= plan.md, périmètre « 72 h »)
 ├──────────────┬───────────────────┐
V2  Organisation scolaire    V4  Contenu à l'échelle
    et espace direction          imports, catalogue complet, back-office équipe
 │                                  │
V3  Suivi pédagogique enseignant    │
    rapports, multi-établissements  │
 │                                  │
 └──────────────┬───────────────────┘
V5  Remédiation et lacunes            à concevoir — n'a jamais tourné
 │
V6  Communication                     annonces

V8  Hors vague — à décider            validation collaborative, sous-rôles équipe

Retiré du plan le 2026-09-22          examens et Prepa BAC (ex-V7), élèves de démonstration,
                                      messagerie de classe (ex-V6b), rôle Parent, LnclassAI
```

L'ordre V2 → V6 suit la priorité déjà décidée au §5 de [`plan.md`](plan.md) (« direction d'abord, puis rapports et multi-établissements, imports, remédiation, annonces »). Les examens, dernier élément de cette liste, sont retirés du plan le 2026-09-22 ; le numéro V7 reste libre pour ne pas renuméroter les références. V4 ne dépend que de V1 : elle peut chevaucher V2-V3 si ses fichiers et contrats sont disjoints ([`programme.md` §4](../../workflows/programme.md#4-exécuter--une-vague-à-la-fois)).

> ⚠️ **Date de la vague 1 à reconfirmer.** Le plan à 72 h a été écrit le 2026-09-18, avec une mise en ligne « date ferme ». Au 2026-09-22 la fenêtre est échue et aucun dépôt cible n'est référencé dans `docs/`. Le périmètre de V1 reste valable ; sa date doit être refixée par l'équipe, et consignée dans le [journal](journal.md).

---

## 2. Phase 0 — Amorçage du dépôt

**Chantier à ouvrir** : `amorcage-depot` (cycle feature, sans UI métier). **Dépend de** : rien. **Bloque** : tout.

| # | Garde-fou | Preuve exigée |
|---|---|---|
| 1 | `docs/`, `CLAUDE.md`, `.claude/skills/` copiés au premier commit | `git log --diff-filter=A --format=%h -- docs/README.md` = premier commit |
| 2 | `bin/setup` pose `core.hooksPath .githooks`, idempotent | un second `bin/setup` ne change rien |
| 3 | Pre-commit : pureté du domaine, HITL, `:nocov:`, rubocop | quatre commits fautifs, quatre refus |
| 4 | CI : purity → lint + brakeman + bundler-audit → tests → tests système Chrome headless ; SimpleCov 100 % lignes et branches, `track_files "{app,lib}/**/*.rb"` | une PR à 99 % refusée |
| 5 | Branches `Develop`, `Staging`, `main` protégées ; Railway déploie `main` | un push direct refusé |
| 6 | Production : `force_ssl`, `assume_ssl`, route `/up`, `:contact` filtré des logs, CSP active, `config.hosts`, stockage de fichiers persistant (F-25), `raise_on_missing_translations` en dev/test | test d'intégration par point |
| 7 | Un test système « page d'accueil » vert en CI | la chaîne complète est prouvée à vide |

Pièges connus, à ne pas rejouer : les trois défauts de CI trouvés sur la PR #14 ([`guide/configuration.md`](../../guide/configuration.md)), `bin/ci` et `.github/workflows/ci.yml` qui divergent, `db/*_schema.rb` de la Solid Suite jamais chargés, `kamal`/`jbuilder` inutiles au Gemfile ([`inventaire/transverse.md` §5-6](inventaire/transverse.md)).

---

## 3. Registre des décisions de fondation

> Chaque ligne se tranche par un ADR ou une UDR au statut `Accepté` **avant** le Lot 0 de la vague qu'elle bloque. Les recommandations sont celles de l'architecte du programme : elles ne valent pas décision.

| ID | Question | Options | Recommandation | Bloque | Tranché par | Statut |
|---|---|---|---|---|---|---|
| **F-01** | Contrat de retour des use cases **et** des queries | `OpenStruct` · `Struct` local · objet `Result` partagé · exceptions | Un `Result` immuable partagé (`Data.define(:value, :errors)`, `success?`, code d'erreur symbolique dont `:forbidden`, `:not_found`, `:invalid`), une seule méthode publique `call`. Les queries retournent des objets de lecture typés (`Data`), jamais une relation | V1 | [ADR-0026](../../decisions/adr/0026-contrat-result-entites-et-dto.md) | **Accepté** 2026-09-25 |
| **F-02** | Découpage des contextes bornés et arborescence | ADR-0023 (école et classe dans `identity`) · conventions (`school`, `classroom`) · architecture (DRENA dans `catalog`) | `identity` = comptes, profils, sessions ; `school` = DRENA, écoles, rôles et personnel ; `classroom` = classes, adhésions, enseignement, assignations ; `catalog` = taxonomie et contenu ; `assessment` = exercices, sessions, badges, lacunes ; `communication` = annonces. Pas de `app/presentation/` ni `adapters/` avant besoin (ADR-0014 §2.2 à remplacer) | V1 | [ADR-0027](../../decisions/adr/0027-contextes-bornes-et-arborescence.md), remplace ADR-0023 et ADR-0014 §2.2 | **Accepté** 2026-09-25 |
| **F-03** | Nature des entités et DTO | Ruby pur (`Data`) · `ActiveModel::Model` toléré | Garder la tolérance `ActiveModel::Model/Validations/Attributes` (ADR-0014) et l'**étendre explicitement aux entités** ; jamais `ActiveRecord` ; le garde-fou de pureté l'encode | V1 | [ADR-0026](../../decisions/adr/0026-contrat-result-entites-et-dto.md) (même ADR que F-01) | **Accepté** 2026-09-25 |
| **F-04** | Forme des policies | `before_action` · Pundit · policies de domaine | Une policy de domaine par use case, Ruby pur, injectée, appelée **en premier** par le use case, qui renvoie `Result` `:forbidden` ; le contrôleur traduit en 403 ou redirection. Un test par policy, avec cas de refus | V1 | [ADR-0028](../../decisions/adr/0028-policies-de-domaine-par-use-case.md), étend ADR-0004 §3.3 et ADR-0015 | **Accepté** 2026-09-25 |
| **F-05** | Identifiants exposés | `id` séquentiel · slug · `public_id` préfixé par rôle | `public_id` opaque `SecureRandom.base58` dans toutes les URL de comptes, classes, sessions ; **sans préfixe de rôle** (il divulgue le rôle) ; slugs réservés au contenu public du catalogue ; clés primaires `bigint` partout, y compris lacunes | V1 | [ADR-0029](../../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md), complète ADR-0017 | **Accepté** 2026-09-25 |
| **F-06** | Établissements d'un enseignant en V1 | une école (décidé) — modélisée par colonne ou par table n-n | **Décision déjà prise : une école visible par enseignant en V1.** Modélisation recommandée : garder la table `teacher_schools` avec un drapeau « principale » — la V3 ajoutera le sélecteur sans migration | V1 (Lot D) | [ADR-0030](../../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md), remplace ADR-0004 §3.1 | **Accepté** 2026-09-25 |
| **F-07** | Second facteur des comptes `team` | TOTP · code SMS · WebAuthn | TOTP (application d'authentification), codes de secours à usage unique ; aucun coût par message | V1 (0b) | [ADR-0031](../../decisions/adr/0031-second-facteur-totp-pour-l-equipe.md), complète ADR-0025 comp. 5 | **Accepté** 2026-09-25 |
| **F-08** | Récupération du PIN | SMS (ADR-0002) · réinitialisation assistée · question secrète | V1 : **réinitialisation assistée** — l'enseignant de la classe ou l'équipe génère un code à usage unique (15 min, journalisé). SMS en vague ultérieure quand un fournisseur est choisi | V1 (0b) | [ADR-0032](../../decisions/adr/0032-recuperation-assistee-du-pin.md), complète ADR-0025 comp. 6, amende ADR-0002 §4 | **Accepté** 2026-09-25 |
| **F-09** | Design system fondateur | palette `@theme` · palette `slate/blue` de `.interface-design/system.md` · mode sombre ou non · iconographie | Palette `@theme` seule (tokens courts, `rounded-ln` et non `rounded-[var(--radius-ln)]`) ; échelles d'espacement, d'ombre, de rayon ; peu de composants, tous substantiels ; **pas de mode sombre en V1** (on retire les bascules) ; heroicons seul ; test qui refuse `[…]` et `#hex` dans les vues ; KaTeX servi par le bundle | V1 (0c) | UDR-0005, remplace les sections « Tokens » des UDR-0001, 0002, 0003 ; UDR-0004 déclarée non applicable au projet cible | ouvert |
| **F-10** | Barème et vocabulaire des badges | ADR-0008 (or ≥ 80 %, bronze/argent/or, remplacement si `>=`) · code (or = 100 %, `>`) · UDR-0003 (Argent/Or/Diamant) | Trancher **un** barème, **un** jeu de noms, la règle de remplacement, et si l'historique des badges est conservé ; « Diamant » supprimé ou défini | V1 (Lot C) | [ADR-0033](../../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md), remplace ADR-0008 §3 | **Accepté** 2026-09-25 |
| **F-11** | Seuils pédagogiques et sens du score | réussite 50 %, maîtrise 70 %, note sur 20 implicites ; `percentage` = avancement **puis** score | Constantes métier nommées dans le domaine ; deux champs distincts, avancement et score | V1 (Lot C), V3 | [ADR-0033](../../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (même ADR que F-10) | **Accepté** 2026-09-25 |
| **F-12** | Reprise des données | base vide · référentiel seedé · migration de l'ancienne base | Confirmer qu'**aucune donnée utilisateur réelle** n'existe (l'ancienne app n'est pas en ligne) ; seeder le **référentiel ivoirien** (niveaux `6ème…Tle`, séries `A1 A2 C D`, `level_series`, matières) dès V1 ; DRENA et écoles importées en V2 ; contenu importé en V4 | V1 (seed), V2, V4 | [ADR-0034](../../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md) | **Accepté** 2026-09-25 |
| **F-13** | Cycle de vie du contenu | statut libre (« publié »/« published »…) · énumération | Énumération `draft` / `published` / `archived` sur cours, fiches **et** exercices ; un brouillon n'est lisible que par l'équipe (policy, pas filtre d'index) ; `published_at` renseigné à la publication ; auteur tracé | V1 (Lot B) | [ADR-0035](../../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md) | **Accepté** 2026-09-25 |
| **F-14** | Suppression et archivage | cascades de l'ancien · restriction · archivage | Contenu consommé par des élèves : archivage, jamais suppression ; taxonomie : suppression refusée tant qu'elle est référencée ; comptes : anonymisation ; classes : archivage de fin d'année (voir F-19) | V1 (Lot B), V2 | [ADR-0036](../../decisions/adr/0036-suppression-archivage-et-anonymisation.md), étend ADR-0005 et ADR-0016 | **Accepté** 2026-09-25 |
| **F-15** | Saisie et normalisation des noms | nom complet découpé au dernier mot · deux champs | Deux champs **Nom** et **Prénom(s)** ; plus de `titleize` automatique sur les noms propres ni les titres de contenu (« Svt », « D'almeida ») ; normalisation limitée aux espaces | V1 (Lot A) | [ADR-0037](../../decisions/adr/0037-nom-et-prenoms-en-deux-champs.md) | **Accepté** 2026-09-25 |
| **F-16** | Comptes internes de l'équipe | un rôle `team` · sous-rôles (admin, contenu, terrain, gestionnaire DRENA…) | V1 : un seul rôle `team`, créé par seed puis invitation. Sous-rôles et matrice fine avant V4 (back-office) | V1 (minimal), V4 | [ADR-0038](../../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md) | **Accepté** 2026-09-25 |
| **F-17** | Format d'import du contenu | format de l'ancien import de cours (arbre complet) · format par ressource | Reprendre le format arbre de l'ancien (seul format réellement utilisé), versionné, validé par un schéma ; rapport d'import persisté et consultable ; **aucune création implicite de taxonomie** | V4 | [ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md), remplace ADR-0012 §3.3 et ADR-0020 §2.1 pour l'import | **Accepté** 2026-09-25 |
| **F-18** | Multi-classes de l'élève | une classe visible (état de l'ancien) · sélecteur de classe (promesse de l'ADR-0003) | V1 : une classe principale, garantie unique par index partiel ; sélecteur en V3 si la demande est confirmée | V3 | [ADR-0040](../../decisions/adr/0040-classe-principale-unique-de-l-eleve.md), amende ADR-0003 | **Accepté** 2026-09-25 |
| **F-19** | Vie d'une classe | éternelle · année scolaire · archivage | Année scolaire sur la classe, archivage en fin d'année ; code d'adhésion révocable et régénérable, plafond d'effectif | V3 | [ADR-0041](../../decisions/adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) | **Accepté** 2026-09-25 |
| **F-20** | Élèves de démonstration | reprendre l'ADR-0019 · refonte · abandon | Les comptes démo de l'ancien étaient de **vrais comptes** (`users` avec mot de passe `123456`) qui occupaient des numéros de téléphone et gonflaient les listes nominatives, sans jamais être filtrés ni produire d'activité (simulation et purge jamais appelées). Ils n'étaient pas connectables **par accident** — `/login` ne garde que les chiffres du contact ([`complements-school-classroom.md`](inventaire/complements-school-classroom.md) CL-24) —, et leur slug aléatoire sur 2 octets fait échouer la création d'écoles à mesure que le volume croît. Si la feature est gardée : données simulées **hors de `users`**, non authentifiables par construction, visibles comme telles, purgeables | — | ADR-0042, remplace ADR-0019, **seulement si** la feature revient au plan | **retiré du plan** (2026-09-22) |
| **F-21** | Remédiation | reprendre l'ADR-0018 · la reconcevoir | La reconcevoir : déclenchée par **le** use case de clôture unique, caractère « remédiation » persisté sur la session, une seule lacune en attente garantie en base | V5 | [ADR-0043](../../decisions/adr/0043-remediation-declenchee-par-la-cloture.md), remplace ADR-0018 §3 | **Accepté** 2026-09-25 |
| **F-22** | Rattachement de la direction | auto-déclaration (ancien) · invitation · validation par l'équipe · code d'établissement | Invitation par l'équipe ou par un membre déjà rattaché ; rôles d'établissement de référence (Proviseur, Censeur, Éducateur, Secrétaire) plutôt que texte libre | V2 | [ADR-0044](../../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md) | **Accepté** 2026-09-25 |
| **F-23** | Communication | annonces seules · messagerie de classe | V6a : annonces refondues (`published_at` horodaté + job de publication, rejets en base, audience `school_admin`, pièces jointes validées). La messagerie de classe et le temps réel sont **retirés du plan** le 2026-09-22 | V6 | [ADR-0045](../../decisions/adr/0045-annonces-publication-programmee-et-audience.md) | **Accepté** 2026-09-25 |
| **F-24** | Examens et Prepa BAC | reporter · spécifier | Décision produit d'abord : modèle économique (paywall, `prepa_status`, acquisitions enseignant) ; puis modèle de données des sujets d'examen de zéro | — | décision produit + ADR-0046, **seulement si** la feature revient au plan | **retiré du plan** (2026-09-22) |
| **F-25** | Stockage des fichiers en production | disque du conteneur (ancien, perdu à chaque déploiement) · stockage objet | Stockage objet compatible S3 dès qu'un téléversement existe | V0 si V1 téléverse, sinon V4 | [ADR-0047](../../decisions/adr/0047-stockage-objet-s3-sur-railway.md) | **Accepté** 2026-09-25 |
| **F-26** | Statuts d'une assignation | `added` / `active` / `validated` / `archived` (défaut SQL `active`, code `added`, `validated` jamais écrit) | Deux statuts, `active` et `archived` ; `assigned_by_id` référence un **utilisateur** | V1 (Lot D) | [ADR-0048](../../decisions/adr/0048-statuts-d-assignation-active-et-archived.md), remplace ADR-0016 §2 (statuts) et ADR-0007 §5 | **Accepté** 2026-09-25 |
| **F-27** | Analytique, consentement, CSP | GTM + Clarity en dur (ancien) · rien · outil configurable | Identifiants en variables d'environnement, CSP stricte, consentement si l'outil pose des cookies | V0 | [ADR-0049](../../decisions/adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) — option C, mesure côté serveur | **Accepté** 2026-09-24 |

**Décisions ajoutées après l'exploration du 2026-09-22** ([`inventaire/complements-*.md`](inventaire/)) :

| ID | Question | Options | Recommandation | Bloque | Tranché par | Statut |
|---|---|---|---|---|---|---|
| **F-28** | Authentification et session | notes d'implémentation de l'ADR-0002 (contact 10 à 15 chiffres, quatre réseaux dont Wave, rotation de session annoncée) · code (10 chiffres exactement, préfixes `01/05/07`, aucune rotation) | Contact : exactement 10 chiffres, préfixes `01/05/07`, normalisation des indicatifs `225`/`00225` ; `reset_session` à la connexion et à la déconnexion ; authentification par **un** use case appelé par le contrôleur (l'ancien lisait l'ORM directement) ; aucun écran n'affiche un PIN en clair, connexion comprise | V1 (0b) | [ADR-0050](../../decisions/adr/0050-authentification-et-session.md), remplace les §3.2, §3.3 et §5 de l'ADR-0002 | **Accepté** 2026-09-25 |
| **F-29** | Navigateurs supportés et budget de performance | `allow_browser :modern` (ancien : 406 sur un Chrome 99 Android) · liste explicite · aucune restriction | Aligner sur le public de l'ADR-0009 : Android d'entrée de gamme en 3G. Liste de navigateurs **minimale** fixée par l'ADR, budget JS et CSS chiffré, vérifié en CI ; aucune bibliothèque chargée depuis un CDN tiers (KaTeX dans le bundle) | V0 | [ADR-0051](../../decisions/adr/0051-navigateurs-supportes-et-budget-de-poids.md) — option C, plancher non bloquant, complète ADR-0009 | **Accepté** 2026-09-24 |
| **F-30** | Chaîne de livraison et exécution des jobs | ancien : configuration Railway non versionnée, `main` 58 commits en retard, worker conditionné par une variable jamais posée, `/up` absent, Thruster contre l'ADR-0010 | Configuration de déploiement **versionnée** ; branche déployée écrite ; worker Solid Queue lancé de la même façon en dev, en test et en production ; échecs de job visibles (tableau de supervision ou alerte) ; `/up` testé | V0 | [ADR-0052](../../decisions/adr/0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) — worker dans Puma, Mission Control, Thruster gardé, recette Railway ; amende ADR-0010 §3.1 et §5 | **Accepté** 2026-09-24 |
| **F-31** | Shell applicatif par rôle | ancien : 4 × 4 partials de navigation divergents, aucune UDR sur les accueils, les tableaux de bord, la navigation ni les toasts | Une UDR de fondation : en-tête, navigation bureau et mobile, page d'accueil de chaque rôle, toasts (message conservé en Turbo Stream), états vide, chargement, erreur ; l'écran d'accueil d'un rôle est livré **dans la vague** qui livre ce rôle | V1 (0c) | UDR-0006 | ouvert |
| **F-32** | Nom de l'`Essential` à l'écran | glossaire « Fiche essentielle » · UI « Habilité » (sic) et « Habiletés » · ADR-0022 « Notions clés » · UDR-0001 « essentiels (habiletés) » | **Un** terme d'interface, écrit dans le glossaire et la locale `fr`, repris par toutes les UDR | V1 (Lot B) | glossaire + [UDR-0007](../../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) | **Accepté** 2026-09-25 |
| **F-33** | Validation collaborative | ADR-0011 (Accepté, rédigé au passé, jamais implémenté) · abandon · report | Requalifier l'ADR-0011 en `Proposé` : le bandeau « Conforme au programme » affiché à tous est **retiré** ; la feature n'entre en vague qu'après décision produit (qui est « certifié », quelle table) | V8 | [ADR-0053](../../decisions/adr/0053-validation-collaborative-requalifiee.md), remplace ADR-0011 | **Accepté** 2026-09-25 |
| **F-34** | Moteur d'évaluation | ADR-0008 : `CompleteExerciseSession` central, comparaison des **contenus**, statuts `in_progress/completed` · code : `SubmitQuestionAttempt`, comparaison des **ids**, statuts `started/completed/abandoned`, réponse stockée en texte `inspect` | **Un** use case de soumission et **un** de clôture ; comparaison par identifiants de réponse ; une tentative par question et par session, garantie en base, **immuable** une fois corrigée ; réponse stockée en données structurées ; statuts de session fixés ; `exercises.essential_id` obligatoire | V1 (Lot C) | [ADR-0054](../../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md), remplace ADR-0008 §3 et §6 | **Accepté** 2026-09-25 |

Recoupements consignés sans nouvelle ligne, parce qu'une décision existante les couvre :

- **F-01** tranche aussi le chemin de lecture : les ADR-0006 §3.2, 0012 §3.1 et 0022 §2.C se contredisent (C-17). L'ADR-0026 doit dire lequel il remplace.
- **F-04** couvre les trous d'autorisation que l'exploration a découverts. Aucun de ces trous n'est cité dans l'ancien `securite.md`, qui est mis à jour en conséquence :
  - n'importe quel utilisateur connecté peut créer, modifier, supprimer ou importer des fiches (CA-12 à CA-15) ;
  - n'importe quel utilisateur connecté peut modifier, supprimer ou importer des établissements (SC-06 à SC-08) ;
  - on peut gérer les rôles et le personnel d'une autre école que la sienne (SC-11 à SC-14) ;
  - `GET /classrooms` renvoie la liste nationale des classes (CL-28) ;
  - `GET /users/:id` expose le contact de n'importe quel compte, même avec l'identifiant numérique (TR-21).
- **F-06** tranche aussi **qui crée une classe**. L'ADR-0004 §2 autorise l'enseignant à en créer, alors que le code ne l'autorise qu'à l'équipe et à la direction.
- **F-13** tranche aussi **la propriété du contenu**. `team_id` n'est jamais renseigné, et le libellé « Visible uniquement par vous » d'un brouillon est donc faux.
- **F-24**, retirée du plan, couvre le parcours « Prépa BAC » (ID-06, TR-17 à TR-19) : paywall, gains des enseignants, inscription publique sans PIN. Tant qu'elle est retirée, **aucune** de ces routes n'existe dans le nouveau dépôt.

> Numérotation des ADR indicative : vérifier `ls docs/decisions/adr/ | tail -3` au moment d'écrire ([conventions §2](../../guide/conventions.md#2-nommage-des-fichiers)).

---

## 4. Registre des contradictions entre sources

> Chaque ligne est une contradiction entre documents faisant autorité. Elle ne se résout **pas** en choisissant l'un des deux : elle se ferme quand l'ADR ou l'UDR de la colonne « Fermée par » est accepté et marque l'autre comme remplacé ([`docs/README.md`](../../README.md#hiérarchie-des-sources-de-vérité)).

| ID | Sujet | Source A | Source B | Fermée par |
|---|---|---|---|---|
| C-01 | Établissements d'un enseignant | ADR-0004 : plusieurs, table `teacher_schools` | [`plan.md`](plan.md) : une seule école en V1, « tranché par ADR » — ADR inexistant | ✅ **Fermée** 2026-09-25 — F-06 |
| C-02 | Barème des badges | ADR-0008 : or ≥ 80 %, bronze/argent/or, remplacement si `>=` | Code : or = 100 %, remplacement si `>` · UDR-0003 : Argent/Or/**Diamant** · glossaire : bronze ≥ 50, argent ≥ 80, or 100 | ✅ **Fermée** 2026-09-25 — F-10 (voir aussi C-46) |
| C-03 | Contexte de DRENA, école, classe | ADR-0023 : contexte `Identity` | conventions et architecture §5 : contextes `school` et `classroom` ; architecture §5 : DRENA dans `catalog` | ✅ **Fermée** 2026-09-25 — F-02 |
| C-04 | Types assignables à une classe | ADR-0007 : `Course`, `Essential`, `ExamSubject` | glossaire et code : + `Exercise` | ✅ **Fermée** 2026-09-25 — F-02 / F-26 |
| C-05 | Tokens des UDR | UDR-0001/0002/0003 : classes Tailwind brutes (`slate`, `shadow-[…]`, `bg-green-100`) | [`plan.md`](plan.md) Lot 0c : aucune valeur arbitraire, tokens `@theme` seuls · `.interface-design/system.md` : palette `slate/blue` | F-09 |
| C-06 | Couche de lecture | ADR-0012 : `ViewObjects` typés, use case CRUD générique, `Strategies` | architecture §7 : aucun `ViewObject` n'existe, queries renvoient des Hash | ✅ **Fermée** 2026-09-25 — F-01 |
| C-07 | Arborescence de présentation | ADR-0014 : `app/presentation/`, `adapters/`, ports d'entrée et de sortie | conventions et architecture : `app/controllers/`, pas de presenters | ✅ **Fermée** 2026-09-25 — F-02 |
| C-08 | Récupération du mot de passe | ADR-0002 : par SMS | ADR-0025 : obligatoire, moyen non fixé · ADR-0010 : aucune infrastructure SMS | ✅ **Fermée** 2026-09-25 — F-08 |
| C-09 | Élèves de démonstration *(sans objet : retirés du plan le 2026-09-22)* | ADR-0019 : génération « à la création d'une classe », `is_demo` pour filtrer l'analytique, aucun marquage visuel | ADR-0019 §2.4 et code : à la création d'un **établissement** ; jamais filtrés · [`plan.md`](plan.md) : écartés · [`securite.md`](securite.md) : comptes connectables — **démenti** : `/login` ne les retrouve pas (CL-24) | F-20 |
| C-10 | Statuts d'assignation | ADR-0016 : `archived`, réactivation en `added` | colonne : défaut `active` · entité : `validated` jamais écrit | ✅ **Fermée** 2026-09-25 — F-26 |
| C-11 | `public_id` | glossaire : préfixe de rôle (`stdt_`, `tch_`…) | [`securite.md`](securite.md) : le rôle se lit dans l'URL ; ADR-0017 : 14 caractères base58 sans préfixe | ✅ **Fermée** 2026-09-25 — F-05 |
| C-12 | Multi-classes élève | ADR-0003 : illimité, classe principale | interface : une seule classe visible, aucun sélecteur | ✅ **Fermée** 2026-09-25 — F-18 |
| C-13 | Rôles de l'interface | UDR-0004 : 5 rôles dont `parent`, drawer et sidebar « non altérés » | memo : `Parent` hors périmètre ; UDR-0004 décrit une migration de l'ancienne app | F-09 (UDR-0004 non applicable au projet cible) |
| C-14 | Seuil de l'or dans l'architecture | [`guide/architecture.md` §2.7](../../guide/architecture.md) : or 100 % présenté comme règle | ADR-0008 : or ≥ 80 % | ✅ **Fermée** 2026-09-25 — F-10 |
| C-15 | Clé primaire des lacunes | ADR-0018 : `has_nanoid(:id)`, clé `string` | toutes les autres tables : `bigint` | ✅ **Fermée** 2026-09-25 — F-05 |

**Contradictions ajoutées par l'exploration du 2026-09-22.** Chaque ligne cite le complément qui la prouve, où se trouvent les références `chemin:ligne` : [identity-communication](inventaire/complements-identity-communication.md) (IC), [school-classroom](inventaire/complements-school-classroom.md) (SC), [catalog](inventaire/complements-catalog.md) (CA), [transverse](inventaire/complements-transverse.md) (TR).

| ID | Sujet | Source A | Source B | Fermée par |
|---|---|---|---|---|
| C-16 | Statut des ADR « appliqués » | ADR-0011, 0012, 0020, 0021 se déclarent `Accepté` et **mis en place** | Le code ne les applique pas : aucune validation collaborative (0011), aucun `ViewObject` (0012), aucun `insert_all` pour les cours (0020), une délégation ORM → entités qui n'existe que sur une branche non fusionnée et cassée (0021). Voir CA §4, IC §4 | ✅ **Fermée** 2026-09-25 — Ces ADR ne décrivent pas le projet cible. Chaque ADR de fondation qui les couvre les marque `Remplacé` ; l'ADR-0011 est remplacé par F-33 |
| C-17 | Chemin de lecture | ADR-0006 §3.2 et ADR-0012 §3.1 : les lectures n'appellent **jamais** de use case, les contrôleurs appellent les queries | ADR-0022 §2.C : les contrôleurs appellent `BrowseCatalog` et `ViewCourse`. Le code fait les deux, et les quatre fils d'accueil passent par `UseCases::Identity::Get*Feed` (CA §4, TR §4) | ✅ **Fermée** 2026-09-25 — F-01 |
| C-18 | Import de contenu | ADR-0012 §3.3 : `ImportCatalogData` + `Strategies` | ADR-0020 §2.1 : méthode de repository dédiée avec `insert_all!`. Le code fait un troisième choix : `save` cours par cours, sans atomicité (CA §4) | ✅ **Fermée** 2026-09-25 — F-17 |
| C-19 | Forme des entités et des ports du catalogue | ADR-0022 §2.A-B : `Course` porte `status`, `published_at` et ses références ; les ports exposent `find_by_slug`, `find_published` | Les entités `Entities::Catalog::*` n'ont ni statut ni clé étrangère. Des entités racine complètes coexistent, et les méthodes des ports divergent de leur implémentation. C'est la cause des éditions cassées (CA-06, CA-13) | ✅ **Fermée** 2026-09-25 — F-01 / F-03 |
| C-20 | Rôles privilégiés et second facteur | ADR-0025 comp. 5 : second facteur pour `team` seulement | `school_admin` lit des listes nominatives de mineurs et rattache des comptes ; `feature_listing.md` prévoit des sous-rôles d'équipe (IC §4) | ✅ **Fermée** 2026-09-25 — F-16 et F-22 : chacune dit si le rôle qu'elle crée exige un second facteur |
| C-21 | Secret dérivé de l'identifiant | ADR-0025 comp. 4 et [`securite.md`](securite.md) n° 5 : un seul chemin, `/c/<code>` | `/teachers/prepa_acquisitions` crée **systématiquement** un compte dont le PIN est le contact ; la page de connexion affiche le PIN en clair (IC §4, TR §5.2) | ✅ **Fermée** 2026-09-25 — F-28. D'ici là, [`securite.md`](securite.md) est mis à jour |
| C-22 | Contact téléphonique | ADR-0002 §5 : 10 à 15 chiffres ; §1 : réseaux Orange, MTN, Moov, **Wave** | ADR-0002 §3.2 et code : exactement 10 chiffres, trois préfixes, Wave n'a pas de préfixe propre (IC §4) | ✅ **Fermée** 2026-09-25 — F-28 |
| C-23 | Rotation de session | ADR-0002 §3.3 : cookies chiffrés, rotation de session | Aucun `reset_session` dans le code (IC §4) · [PRD cadre §4](prd.md#4-exigences-transverses--valables-dès-la-vague-1) : `reset_session` exigé | ✅ **Fermée** 2026-09-25 — F-28 |
| C-24 | Suppression d'un compte élève | ADR-0005 : aucune suppression de compte n'anéantit des résultats. L'ADR ne vise pourtant que les créateurs `team` | `DELETE /users/:id` détruit en cascade les sessions, les badges et les lacunes (IC §4) | ✅ **Fermée** 2026-09-25 — F-14 |
| C-25 | Traçabilité de l'activité par enseignant | ADR-0016 §2 : `ExerciseSession` porte le `teacher_id` | `exercise_sessions` n'a ni `teacher_id` ni `classroom_id` (SC §4) | ✅ **Fermée** 2026-09-25 — F-26 |
| C-26 | Suppression d'une classe ou d'un niveau | ADR-0016 : l'historique des assignations ne se détruit pas | `dependent: :destroy` de la classe vers ses assignations, et du niveau vers ses classes (SC §4) | ✅ **Fermée** 2026-09-25 — F-14 / F-19 |
| C-27 | Création d'une classe par l'enseignant | ADR-0004 §2 : l'enseignant crée des classes dans ses établissements | Code : seuls `team` et `school_admin` en créent (SC §4) | ✅ **Fermée** 2026-09-25 — F-06 |
| C-28 | Rejoindre une classe supplémentaire | ADR-0003 §4 : un élève rejoint « n'importe quel cours du soir » avec un code | Code : `/c/:code` et `/student-signup` **créent un compte**, aucun chemin n'existe pour un élève déjà connecté (SC §4) | ✅ **Fermée** 2026-09-25 — F-18 |
| C-29 | Unicité « sans collision » | ADR-0020 §2.3 : « 0 % de probabilité de conflit » | Le slug aléatoire des comptes démo, sur 2 octets, fait échouer environ une création d'école sur quatre vers 50 écoles (calcul non exécuté, SC §2) | ✅ **Fermée** 2026-09-25 — F-05 |
| C-30 | Personnel d'établissement : combien d'écoles | Glossaire §1 : unicité « par école », ce qui laisse entendre plusieurs écoles | `has_one :school_staff` : une seule école ; aucun index unique (SC §4, TR §4) | ✅ **Fermée** 2026-09-25 — F-22 |
| C-31 | Interface de l'organisation scolaire | UDR-0002 : recherche et filtre DRENA, carte d'école unique, onglets école → classes, badges `bg-green-100` | Maquette non branchée, deux cartes d'école, aucun onglet, badges `bg-green-50` (SC §4) | F-09 (tokens) + UDR de la V2 |
| C-32 | Interface du catalogue | UDR-0001 : la carte de cours sert partout, « titre + badge de matière », Physique en bleu | Trois balisages de carte, une carte plus riche, Physique en violet et Mathématiques en bleu (CA §4) | F-09 + UDR de la V1 (Lot B) |
| C-33 | Vocabulaire de la fiche | Glossaire : « Fiche essentielle » | UI « Habilité » (sic) et « Habiletés », ADR-0022 « Notions clés », UDR-0001 « essentiels (habiletés) », `feature_listing.md` « habilletés » (CA §4) | ✅ **Fermée** 2026-09-25 — F-32 |
| C-34 | Validation collaborative | ADR-0011 : réservée aux enseignants **certifiés**, entités à la racine | Glossaire : aucune certification ; conventions : tout est namespacé ; code : rien, sauf un bandeau « Conforme au programme » affiché à tous (CA-29) | ✅ **Fermée** 2026-09-25 — F-33 |
| C-35 | Tables de liaison classe ↔ contenu | [`feature_listing.md`](../../feature_listing.md) : `classroom_courses`, `classroom_essentials`, `classroom_exercises` | ADR-0007, glossaire et schéma : une table unique `classroom_assignments`. Les trois anciennes tables n'existent plus, mais le code des fils d'accueil les appelle encore (TR §5.1) | Correction de `feature_listing.md` : aucun ADR, la décision existe |
| C-36 | Public cible et navigateurs | ADR-0009 : Android d'entrée de gamme en 3G/4G, JavaScript minimal | `allow_browser :modern` renvoie 406 à Chrome 99 Android ; bundle JS de 622 Ko ; KaTeX, GTM et Clarity viennent d'un CDN tiers (TR §4) | F-29 |
| C-37 | Worker, SMS, temps réel, Thruster | ADR-0010 : worker intégré à Puma, SMS par jobs, notifications Solid Cable, Thruster non requis | Worker conditionné par une variable jamais posée ; aucun SMS ni broadcast ; `Dockerfile` lancé via Thruster (TR §4) | ✅ **Fermée** 2026-09-25 — F-30 (et F-23 pour le temps réel) |
| C-38 | Mode sombre | ADR-0013 §2.1 : le thème sombre est un état géré par Stimulus | Bascule présente, mais aucune variante `dark:` ni palette sombre (TR §4) | F-09 (aucun mode sombre en V1) |
| C-39 | Dépendances du domaine | ADR-0001 §3 : communication **exclusivement** par injection | 20 fichiers de `app/domain/` instancient `Repositories::…` par défaut ; le test de pureté ne le détecte pas (TR §4) | ✅ **Fermée** 2026-09-25 — F-03. Le garde-fou de pureté (phase 0, n° 3) refuse aussi `Repositories::` et `Queries::` dans le domaine |
| C-40 | `/admin` | ADR-0006 §1 : tableau de bord administrateur `/admin` | Aucune route `/admin` ; l'équivalent `/teams/dashboard` lève une exception (TR §4) | ✅ **Fermée** 2026-09-25 — F-01 : l'ADR qui remplace l'ADR-0006 corrige la référence |
| C-41 | Écarts connus des conventions | Conventions §8 : trois écarts connus | L'exploration en ajoute plus de trente, rassemblés ici | Conventions §8 renvoie à ce registre (fait le 2026-09-22) |
| C-42 | Moteur de correction | ADR-0008 §3 et §6 : `CompleteExerciseSession` central, comparaison des contenus, logique dans `evaluate_and_award_badges!` | Code : `SubmitQuestionAttempt`, comparaison des ids, méthode inexistante ; [`architecture.md`](../../guide/architecture.md) §2.7 présente `SubmitQuestionAttempt` comme « le meilleur exemple du dépôt » ([AS](inventaire/complements-assessment.md) E-05) | ✅ **Fermée** 2026-09-25 — F-34 ; `architecture.md` §2.7 corrigé ensuite (rang 5) |
| C-43 | Statuts d'une session | ADR-0008 §3 : `in_progress` / `completed` | Glossaire et code : `started` / `completed` / `abandoned` (AS E-04) | ✅ **Fermée** 2026-09-25 — F-34 |
| C-44 | Stockage de la réponse de l'élève | Glossaire §4 : `answer_data` (jsonb) | Code : `answer_data` et `attempted_answer_ids` jamais écrits ; un tableau stocké sous sa forme `inspect` Ruby dans `provided_answer` (AS E-17) | ✅ **Fermée** 2026-09-25 — F-34 |
| C-45 | Rattachement d'un exercice | Glossaire §3 : un exercice est « rattaché à un `Essential` » | Schéma : `exercises.essential_id` nullable (AS E-20) | ✅ **Fermée** 2026-09-25 — F-34 |
| C-46 | Barème et échelles | ADR-0008 : Or à 80 % ; §4 : l'élève voit son score sur 100, sa note sur 20 et son badge · ADR-0018 : 50 % | Code : cinq seuils non nommés (50, 70, **75**, 80, 100) ; l'élève ne voit que le pourcentage ; /10 sur un sujet ; la landing promet « Diamant » (AS E-01, E-02, E-07, E-15) | ✅ **Fermée** 2026-09-25 — F-10 / F-11 (complète C-02) |
| C-47 | Remédiation | ADR-0018 §3.1 : détection « lors de l'échec d'une session », une **ou plusieurs** lacunes ; une session de remédiation reconnaissable | Code : une lacune au plus, déclenchée par une simulation morte ; aucune colonne ne marque la session de remédiation (AS E-08, E-11) | ✅ **Fermée** 2026-09-25 — F-21 |
| C-48 | Vocabulaire de l'évaluation | Glossaire : « tentative » = `QuestionAttempt` ; ne jamais écrire « Quiz » | UDR-0003 §2 : « Quiz interactif » ; UI enseignant : « Tentatives » compte des sessions (AS E-18, E-19) | ✅ **Fermée** 2026-09-25 — F-32 (étendue au vocabulaire de l'évaluation) |
| C-49 | Nommage des lacunes | ADR-0018 §3.2 : `Entities::KnowledgeGap`, `Ports::KnowledgeGapRepository` à la racine | Conventions §2 : tout est namespacé par contexte borné (AS E-09) | ✅ **Fermée** 2026-09-25 — F-02 |

Les écarts d'**état** — le code ne fait pas ce que tout le monde attend, par exemple la réactivation d'une assignation (ADR-0016) ou le fil de la direction toujours vide — ne sont pas des contradictions entre sources. Ce sont des bugs de l'ancien, listés dans la colonne « Ne pas reproduire » du §6.

---

## 5. Les vagues

### V0 — Amorçage du dépôt

Voir §2. **Décisions préalables** : F-27, F-29, F-30 ; F-25 si la V1 téléverse. **Porte** : les 7 garde-fous prouvés.

### V1 — Boucle pédagogique

| Champ | Contenu |
|---|---|
| **Objectif** | L'équipe crée la taxonomie (niveaux, séries, leurs associations, matières) puis publie un cours, une fiche, un exercice ; un enseignant déclare ses classes et leur assigne le contenu ; un élève rejoint sa classe par code, voit ce qui lui est assigné, fait l'exercice, obtient son résultat et son badge |
| **Chantiers** | Plan détaillé existant : [`plan.md`](plan.md) (Lots 0a, 0b, 0c, A, B, C, D, E). À son ouverture, il est déplacé dans le chantier `boucle-pedagogique` |
| **Tables** | `users`, `students`, `teachers`, `teams`, `schools`, `drenas` *(lecture, seedée)*, `classrooms`, `classroom_students`, `teacher_classrooms` ou `teacher_schools` (F-06), `levels`, `series`, `level_series`, `materials` *(créées par l'équipe, ADR-0034)*, `courses`, `essentials`, `exercises`, `questions`, `answers`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `classroom_assignments` + journal d'audit et journal d'échecs de connexion |
| **Décisions préalables** | F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-08, F-09, F-10, F-11, F-12 (taxonomie par l'équipe), F-13, F-14 (contenu), F-15, F-16, F-26, F-28, F-31, F-32, F-34 ; F-25 si téléversement |
| **Dépend de** | V0 |
| **Porte** | Critères du [PRD cadre §5](prd.md#5-critères-dacceptation-transverses) verts ; parcours bout en bout en navigateur réel ; recette sur `Staging` par un rôle distinct |

Écarts avec [`plan.md`](plan.md), à corriger à l'ouverture du chantier :

- La table `drenas` y est écartée, alors que `schools.drena_id` est obligatoire (ADR-0023). Elle entre en V1, en lecture seule et seedée.
- `teacher_schools` y est écartée, alors que F-06 recommande de la garder avec un drapeau « principale ». Elle entre en V1 (ADR-0030).
- Le Lot 0b reprend la règle « le dernier mot du nom complet est le prénom ». L'ADR-0037 tranche : deux champs, sans changement de casse.
- Le Lot A laisse ouverte l'inscription par listes en cascade. Le [PRD cadre](prd.md#2-acteurs) exige un code de classe valide : la cascade école + niveau → classe est écartée (ID-08, CL-08).
- Le plan suppose une taxonomie seedée. L'ADR-0034 (arbitrage du porteur, 2026-09-25) la fait créer par l'équipe dans l'interface dès la V1 : CA-18, CA-19, CA-20, CA-22, CA-24 et CA-25 entrent en V1, et les seeds de taxonomie ne servent qu'en développement et en test.
- Liste des features livrées par la V1 : §6, colonne « Vague » = V1. C'est elle qui remplace le décompte approximatif « environ 25 features » du plan.

### V2 — Organisation scolaire et espace direction

| Champ | Contenu |
|---|---|
| **Objectif** | L'équipe administre les DRENA, les écoles et les classes (la taxonomie est gérée dès la V1, ADR-0034) ; une direction d'établissement, invitée, gère ses classes, ses enseignants et ses élèves ; chacun gère son compte |
| **Chantiers** | `referentiels-equipe` (DRENA, écoles, import JSON d'écoles, génération des classes par défaut) · `espace-direction` · `mon-compte` (profil, PIN avec PIN actuel, avatar) · `annuaire-equipe` (liste, fiche, anonymisation) |
| **Tables** | `school_roles`, `school_staffs` ; `drenas` et `schools` en écriture |
| **Décisions préalables** | F-14, F-16, F-22 ; F-25 (avatar) |
| **Dépend de** | V1 |
| **Porte** | Une direction invitée administre son seul établissement ; aucune fuite inter-établissements (test de refus) |

### V3 — Suivi pédagogique enseignant

| Champ | Contenu |
|---|---|
| **Objectif** | L'enseignant suit sa classe : rapport par exercice (synthèse et détaillé), fiche élève, compteurs de badges, tableau de bord de classe, liste paginée d'élèves ; il gère ses établissements ; les classes vivent au rythme de l'année scolaire |
| **Chantiers** | `rapports-de-classe` · `multi-etablissements-enseignant` · `vie-de-la-classe` (année scolaire, archivage, code révocable, retrait d'élève) · `multi-classes-eleve` si F-18 le confirme |
| **Tables** | colonnes d'année scolaire et d'archivage ; aucune table nouvelle hors décision |
| **Décisions préalables** | F-11, F-18, F-19 |
| **Dépend de** | V1, V2 (établissements administrés) |
| **Porte** | Rapports sans cache périmé (invalidation à la clôture de session) ; seuils issus des constantes de F-11 |

### V4 — Contenu à l'échelle et back-office équipe

| Champ | Contenu |
|---|---|
| **Objectif** | L'équipe alimente la plateforme en masse et la pilote : imports JSON avec rapport, catalogue complet (filtres, pagination, pages niveau et matière), tableau de bord équipe, installation PWA |
| **Chantiers** | `import-contenu` · `catalogue-complet` · `pilotage-equipe` · `installation-pwa` |
| **Tables** | table de rapports d'import |
| **Décisions préalables** | F-16 (sous-rôles), F-17, F-25 |
| **Dépend de** | V1 — peut chevaucher V2-V3 si fichiers et contrats disjoints |
| **Porte** | Un import de 50 cours produit un rapport exact (importés, ignorés, en erreur) et aucun élément de taxonomie parasite |

### V5 — Remédiation et lacunes

| Champ | Contenu |
|---|---|
| **Objectif** | Un élève en échec sur une notion voit une remédiation ciblée ; l'enseignant voit qui est en difficulté, qui s'est corrigé seul, qui a réussi sa remédiation |
| **Chantiers** | `remediation` |
| **Tables** | `knowledge_gaps` (et sessions marquées « remédiation ») |
| **Décisions préalables** | F-21 |
| **Dépend de** | V3 (rapports), V1 (clôture de session unique) |
| **Porte** | Le parcours **réel** de l'élève crée et résout les lacunes — c'est exactement ce que l'ancienne app ne faisait pas |

### V6 — Communication

| Champ | Contenu |
|---|---|
| **Objectif** | L'équipe publie des annonces riches ciblées, planifiables, que chacun peut écarter durablement |
| **Chantiers** | `annonces` |
| **Tables** | `messages`, `message_dismissals` |
| **Décisions préalables** | F-23, F-25 |
| **Dépend de** | V1 |
| **Porte** | Aucune annonce lisible hors de son audience ni avant sa publication, même par URL directe |

### V8 — Hors vague, à décider

Validation collaborative (ADR-0011, jamais implémentée ; F-33), sous-rôles de l'équipe s'ils ne sont pas tranchés en V4. Chacun ne devient une vague qu'après une décision produit consignée ici.

### Retiré du plan (2026-09-22)

Décision du porteur produit, le 2026-09-22 : ces éléments sortent du plan **pour le moment**. Ils ne sont ni planifiés ni décidés, et le nouveau dépôt n'en porte **aucune trace** : ni route, ni table, ni rôle, ni colonne préparée « pour plus tard ». Leurs lignes restent dans la traçabilité (§6), marquées « retirée », pour que rien ne se perde.

| Élément retiré | Ex-vague | Features | Décision mise en sommeil | Ce qui en reste dans le plan |
|---|---|---|---|---|
| Examens et Prepa BAC : sujets d'examen, paywall, gains des enseignants, inscription « Prépa BAC », offre établissement | V7 | ID-06, ID-34, TR-03, TR-06, TR-17 à TR-19, AS-27 à AS-35 | F-24 | Rien. `ExamSubject` n'est pas un type assignable (C-04 se ferme sans lui) |
| Élèves de démonstration : génération, simulation, purge | V5 | ID-30, CL-24 à CL-27, TR-30, AS-26 | F-20 | Rien. Aucune colonne `is_demo`, et la génération des classes par défaut (SC-09) ne crée aucun élève |
| Messagerie de classe et temps réel | V6b | CO-08, TR-33 | F-23 (partie messagerie) | Les annonces (V6) ; `solid_cable_messages` n'est pas installée |
| Rôle Parent | V8 | ID-25 | — | Le rôle n'est **pas déclaré** dans l'énumération : l'ancien le déclarait sans espace (chantier `acteurs-fantomes-parent-examsubject`) |
| LnclassAI | — | TR-14 | — | Rien : aucune iframe tierce dans l'espace équipe |

**Pour réintégrer un élément**, il faut une décision produit datée, consignée dans le [journal](journal.md). L'élément reçoit alors une vague dans ce document, puis son chantier s'ouvre par `/feature`. Ses anciennes lignes du §6 et ses défauts « à ne pas reproduire » redeviennent des exigences.

---

## 6. Traçabilité — chaque feature de l'existant a une vague

Rempli à partir des catalogues d'ID produits par l'exploration du 2026-09-22 ([`inventaire/complements-*.md`](inventaire/)). La fiche complète de chaque ID, avec ses preuves `chemin:ligne`, est dans son complément.

**Lire la table.**
- **État** : état de l'ancienne application. ✅ marche · ⚠️ fragile · ❌ cassé · 💀 jamais exécuté.
- **Vague** : la vague qui livre la feature dans le nouveau dépôt, ou **écartée**, avec sa raison.
- **Ne pas reproduire** : le défaut de l'ancien que le chantier de la vague transforme en **test de non-régression**.

Une feature ❌ ou 💀 ne se porte pas : elle se construit, grill compris (§8).

### 6.1 Identity — `ID`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| ID-01 | S'inscrire comme élève | ⚠️ | V1 (Lot A) | La classe choisie par listes en cascade, **sans code** : le [PRD cadre](prd.md#2-acteurs) exige un code de classe valide. Le PIN laissé vide qui devenait le contact. Une création non transactionnelle |
| ID-02 | S'inscrire par le lien `/c/<code>` | ⚠️ | V1 (Lot A) | Un PIN dérivé du contact |
| ID-03 | S'inscrire comme enseignant | ⚠️ | V1 (Lot D) | — |
| ID-04 | S'inscrire comme membre de l'équipe | ❌ | **écartée** : aucune route publique ne crée un compte `team`. Remplacée par le seed et l'invitation (V1, F-16) | La route `/team-signup` |
| ID-05 | S'inscrire comme administrateur d'établissement | ❌ | **écartée** : remplacée par l'invitation de la direction (V2, F-22) | La route `/staff-signup` |
| ID-06 | S'inscrire depuis la page « Prépa BAC » | ❌ | **écartée** — retirée du plan le 2026-09-22 | Une route publique qui crée un compte dont le PIN est le contact |
| ID-07 | Vérifier en direct un code de classe | ⚠️ | V1 (Lot A) | Un endpoint énumérable, sans limite de débit, qui renvoie plus que le strict nécessaire |
| ID-08 | Listes en cascade DRENA → écoles, école + niveau → classes | ✅ | V1 pour DRENA → écoles (inscription enseignant) · **écartée** pour école + niveau → classes | Rejoindre une classe sans son code |
| ID-09 | Rattacher un enseignant existant à l'établissement | ⚠️ | V2 (`espace-direction`) | Un formulaire sans vue (`MissingTemplate`) |
| ID-10 | Rattacher un élève existant à une classe | ⚠️ | V2 (`espace-direction`) | Idem ; adhésion non principale sans règle |
| ID-11 | Lister les enseignants et les élèves de l'établissement | ⚠️ | V2 (`espace-direction`) | Comptes démo mêlés aux vrais élèves |
| ID-12 | Se connecter | ⚠️ | V1 (0b) | PIN affiché en clair ; aucune limite de débit ; aucune rotation de session |
| ID-13 | Être dirigé vers son espace | ⚠️ | V1 (0b) | Deux boucles de redirection infinies ; l'onboarding déduit de `classrooms.empty?` |
| ID-14 | Se déconnecter | ⚠️ | V1 (0b) | Aucun `reset_session` |
| ID-15 | Récupérer un PIN oublié | ❌ absent | V1 (0b, F-08) | La perte définitive du compte |
| ID-16 | Restreindre chaque espace à son rôle | ⚠️ | V1 (Lot 0a, F-04) | Une autorisation par `before_action` au lieu d'une policy testée |
| ID-17 | Modifier son profil | ⚠️ | V2 (`mon-compte`) | Changer son PIN sans saisir le PIN actuel |
| ID-18 | Modifier une fiche depuis `/users/:id/edit` | ❌ | V2 (`annuaire-equipe`, fusionnée avec ID-17) | Des clés de formulaire que le contrôleur ne lit pas |
| ID-19 | Profil de direction, avatar compris | ❌ | V2 (`mon-compte`) | Un avatar qu'aucun chemin n'enregistre |
| ID-20 | Changer son PIN côté direction | ❌ | V2 (`mon-compte`, fusionnée avec ID-17) | Idem ID-17 ; route `settings/edit` sans action |
| ID-21 | Lister tous les utilisateurs | ⚠️ | V2 (`annuaire-equipe`) | — |
| ID-22 | Consulter la fiche d'un utilisateur | ⚠️ | V2 (`annuaire-equipe`) | Une fiche ouverte à tout connecté, qui expose le contact et accepte l'identifiant numérique |
| ID-23 | Supprimer un utilisateur | ⚠️ | V2 (`annuaire-equipe`, F-14) | Une cascade qui détruit sessions, badges et lacunes |
| ID-24 | Changer de rôle | ❌ absent | **écartée** : aucun besoin exprimé | — |
| ID-25 | Espace parent | ❌ absent | **écartée** — retirée du plan le 2026-09-22 (hors périmètre depuis le 2026-09-18) | Un rôle déclaré sans espace, qui retombe sur `/` |
| ID-26 | Bannière d'installation PWA | ⚠️ | V4 (`installation-pwa`) | « Installée » enregistré sur iOS sans installation ; n'importe quelle valeur d'enum acceptée |
| ID-27 | Enseigner dans plusieurs établissements | ⚠️ | V3 (`multi-etablissements-enseignant`, F-06) | `schools.first` sans ordre |
| ID-28 | Normaliser et valider le contact | ⚠️ | V1 (0b, F-28) | — (règle juste, à reprendre) |
| ID-29 | Générer l'identifiant public et le slug | ⚠️ | V1 (Lot 0a, F-05) | Un préfixe qui révèle le rôle ; le repli sur l'identifiant entier |
| ID-30 | Comptes démo qui occupent des numéros | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | Des démos stockées dans `users` |
| ID-31 | Refonte visuelle des pages d'authentification (branche) | ⚠️ non fusionné | **écartée** comme code ; matière d'inspiration pour l'UDR du Lot 0c | — |
| ID-32 | Délégation ORM → entités (branche) | ❌ non fusionné, cassé | **écartée** : l'architecture cible (F-01, F-03) la rend sans objet | Fusionner cette branche : elle casserait les cinq inscriptions |
| ID-33 | Plan « Ticket 4 » (branche) | ❌ jamais livré | **écartée** : document obsolète (il suppose Devise et un ADR-0016 d'identité) | — |
| ID-34 | Tableau des examens sur le fil équipe (branche) | ⚠️ non fusionné | **écartée** — retirée du plan le 2026-09-22 | — |

### 6.2 Communication — `CO`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| CO-01 | Publier une annonce | ⚠️ | V6a (`annonces`) | Des pièces jointes non validées ; un flux Turbo qui ne cible rien |
| CO-02 | Modifier une annonce | ⚠️ | V6a | Aucun bouton Éditer pour l'équipe sur `/messages` |
| CO-03 | Supprimer une annonce | ⚠️ | V6a | Idem |
| CO-04 | Parcourir les annonces qui me sont destinées | ⚠️ | V6a | — |
| CO-05 | Lire le détail d'une annonce | ⚠️ | V6a | Une annonce lisible hors de son audience ou avant sa publication, par URL directe |
| CO-06 | Voir les annonces récentes dans son fil | ⚠️ | V6a | — |
| CO-07 | Écarter une annonce | ⚠️ | V6a (`message_dismissals`) | Un rejet stocké dans un cookie de session, perdu au changement d'appareil |
| CO-08 | Recevoir une annonce sans recharger la page | ❌ absent | **écartée** — retirée du plan le 2026-09-22 | — |
| CO-09 | Toasts de confirmation et d'erreur | ⚠️ | V1 (Lot 0c, F-31) | Un toast d'erreur Turbo qui perd son message |
| CO-10 | Programmer ou archiver une annonce | ❌ | V6a (job de publication, F-23) | Des statuts sans effet |
| CO-11 | Annonces dans l'espace direction | ❌ | V6a | Un bloc vide codé en dur ; une audience sans valeur `school_admin` |
| CO-12 | Widget « annonces » du tableau de bord équipe | 💀 | V6a | — |
| CO-13 | Annonces factices en développement | ⚠️ | **écartée** : remplacée par des seeds de développement | Des données factices dans le code des contrôleurs |

### 6.3 School — `SC`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| SC-01 | Gérer les DRENA | ⚠️ | V1 en lecture (seed) · V2 en écriture (`referentiels-equipe`) | Une suppression qui échoue dès qu'une école a du personnel |
| SC-02 | Importer des DRENA | ⚠️ | V2 (`referentiels-equipe`) | Une action d'import sans route (TR-29) |
| SC-03 | Créer un établissement | ⚠️ | V1 (seed) · V2 (écran) | Une erreur 500 pour les rôles non autorisés au lieu d'un refus |
| SC-04 | Liste nationale des établissements | ⚠️ | V2 | Des filtres factices ; un bouton « Nouvelle École » mort |
| SC-05 | Consulter un établissement | ✅ | V2 | Une fiche ouverte à tout connecté |
| SC-06 | Modifier un établissement | ⚠️ | V2 | Une modification ouverte à tout connecté |
| SC-07 | Supprimer un établissement | ❌ | V2 (F-14) | `RecordNotDestroyed` dès qu'un membre du personnel existe ; une suppression ouverte à tout connecté |
| SC-08 | Importer des établissements | ⚠️ | V2 (F-17 pour le format) | Aucun rapport d'import ; des comptes démo créés en effet de bord |
| SC-09 | Générer les classes par défaut | ⚠️ | V2 | Des collisions de slug qui laissent l'école sans classes |
| SC-10 | S'inscrire comme administrateur d'établissement | ⚠️ | **écartée** (= ID-05) | — |
| SC-11 | Lister et créer les rôles d'un établissement | ⚠️ | V2 (F-22 : rôles de référence) | Un échec de création silencieux |
| SC-12 | Supprimer un rôle | ⚠️ | V2 | Une suppression non scopée à l'école de l'URL |
| SC-13 | Rattacher un membre du personnel | ⚠️ | V2 (invitation, F-22) | Un doublon affiché comme un succès ; le rôle d'une autre école accepté |
| SC-14 | Retirer un membre du personnel | ⚠️ | V2 | Un retrait non scopé à l'école |
| SC-15 | Tableau de bord de l'établissement | ⚠️ | V2 (`espace-direction`) | Un fil d'actualité vide codé en dur |
| SC-16 | Page « en attente d'affectation » | ✅ | V2 | — |
| SC-17 | Classes de son établissement | ✅ | V2 | — |
| SC-18 | Tableau de bord d'une classe (direction) | ❌ | V2 | Une fuite inter-établissements ; des statistiques vides |
| SC-19 | Créer une classe (direction) | ❌ | V2 (qui crée une classe : F-06) | Une action sans vue |
| SC-20 | Lister les élèves de l'établissement | ✅ | V2 (= ID-11) | — |
| SC-21 | Ajouter un élève existant à une classe | ❌ | V2 (= ID-10) | — |
| SC-22 | Lister les enseignants de l'établissement | ✅ | V2 (= ID-11) | — |
| SC-23 | Rattacher un enseignant existant | ❌ | V2 (= ID-09) | — |
| SC-24 | Profil de direction | ✅ | V2 (= ID-19) | — |
| SC-25 | Changer son PIN côté direction | ⚠️ | V2 (= ID-20) | — |
| SC-26 | API des établissements d'une DRENA | ✅ | V1 (inscription enseignant) | Un endpoint public sans limite de débit |
| SC-27 | Rattachement à l'école à l'inscription enseignant | ✅ | V1 (Lot D) | — |

### 6.4 Classroom — `CL`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| CL-01 | Créer une classe (équipe) | ❌ | V1 (Lot D : « les classes sont créées par l'équipe », [`plan.md`](plan.md) §1) | Un slug passé à `find_by_id` ; un code de 6 caractères pour une colonne de 5 |
| CL-02 | Modifier une classe | ❌ | V2 (`referentiels-equipe`) | Un échec muet |
| CL-03 | Supprimer une classe | ⚠️ | V3 (`vie-de-la-classe` : archivage, F-19) | Une suppression définitive qui détruit l'historique des assignations |
| CL-04 | Générer et afficher le code d'adhésion | ⚠️ | V1 (Lot D) | Un affichage tantôt en minuscules, tantôt en majuscules |
| CL-05 | Partager le lien de classe sur WhatsApp | 💀 | V3 (`vie-de-la-classe`) | — |
| CL-06 | Rejoindre une classe par `/c/<code>` | ⚠️ | V1 (Lot A) (= ID-02) | — |
| CL-07 | S'inscrire avec un code | ✅ | V1 (Lot A) (= ID-01) | — |
| CL-08 | API de vérification de code et de liste de classes | ⚠️ | V1 pour la vérification (= ID-07) · **écartée** pour la liste de classes | Une API énumérable |
| CL-09 | Déclarer les classes que l'on enseigne | ⚠️ | V1 (Lot D) | Un remplacement qui efface les classes de toutes les écoles |
| CL-10 | Fiche d'une de ses classes | ❌ | V1 (Lot D) | La fiche qui casse dès le premier exercice assigné |
| CL-11 | Consulter un cours dans sa classe | ❌ | V1 (Lot D) | — |
| CL-12 | Consulter une fiche dans sa classe | ❌ | V1 (Lot D) | — |
| CL-13 | Fiche d'un élève de sa classe | ❌ | V3 (`rapports-de-classe`) | — |
| CL-14 | Tableau de bord générique d'une classe | ❌ | V3, fusionné avec CL-10 | Une classe ouverte à tout connecté ; 3 compteurs sur 4 toujours vides |
| CL-15 | Liste paginée des élèves d'une classe | ⚠️ | V3 | Un cache de ligne jamais invalidé ; une liste ouverte à tout connecté |
| CL-16 | Assigner ou retirer un cours | 💀 | V1 (Lot D) | Réassigner une ressource retirée lève `RecordNotUnique` au lieu de la réactiver |
| CL-17 | Assigner ou retirer une fiche | 💀 | V1 (Lot D) | Idem |
| CL-18 | Cours dans le contexte d'une classe (chemin générique) | ❌ | **écartée** : doublon de CL-11 | — |
| CL-19 | Fiche dans le contexte d'une classe (chemin générique) | ❌ | **écartée** : doublon de CL-12 | — |
| CL-20 | Assigner ou retirer un exercice | ⚠️ | V1 (Lot D) | Idem CL-16 |
| CL-21 | Assignations depuis l'espace enseignant | 💀 | **écartée** : doublon de CL-16, CL-17 et CL-20 ; les use cases n'ont jamais existé | — |
| CL-22 | Sa classe et ses cours (élève) | ⚠️ | V1 (Lot A / D) | Des cours retirés (archivés) encore affichés |
| CL-23 | Fil d'accueil élève | ❌ | V1 (= TR-04) | — |
| CL-24 | Peupler les classes d'élèves démo | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | Des démos dans `users` |
| CL-25 | Second générateur de démos | 💀 | **écartée** (doublon mort de CL-24) | — |
| CL-26 | Simuler l'activité des démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| CL-27 | Purger les démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| CL-28 | Liste nationale des classes | ⚠️ | **écartée** : l'équipe liste les classes par école (V2) | Une liste nationale ouverte à tout connecté |

### 6.5 Catalog — `CA`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| CA-01 | Parcourir le catalogue publié | ⚠️ | V1 (Lot B, liste simple) · V4 (`catalogue-complet`) | Un niveau et une matière qui ne filtrent pas les brouillons |
| CA-02 | Filtrer par niveau ou matière | ⚠️ | V4 | — |
| CA-03 | Pagination infinie | 💀 | V4 | Un lien de page jamais rendu |
| CA-04 | Consulter un cours | ✅ | V1 (Lot B) | Un brouillon lisible par URL directe |
| CA-05 | Créer un cours | ⚠️ | V1 (Lot B) | Aucun point d'entrée dans l'interface |
| CA-06 | Modifier un cours | ❌ | V1 (Lot B) | Deux familles d'entités incompatibles (C-19) |
| CA-07 | Supprimer un cours | ✅ | V1 (Lot B, archivage : F-14) | Une cascade qui détruit lacunes et assignations |
| CA-08 | Importer des cours en masse | ⚠️ | V4 (`import-contenu`, F-17) | Un import non atomique, sans rapport, qui crée de la taxonomie implicite |
| CA-09 | « Import JSON Express » dans le formulaire | 💀 | **écartée** : aucun contrôleur JavaScript n'existe ; l'import de V4 le remplace | — |
| CA-10 | Lister les fiches d'un cours | ⚠️ | V1 (Lot B) | — |
| CA-11 | Consulter une fiche et sa progression | ✅ | V1 (Lot B / C) | — |
| CA-12 | Créer une fiche | ❌ | V1 (Lot B, `team` seulement) | Une création ouverte à tout connecté |
| CA-13 | Modifier une fiche | ❌ | V1 (Lot B) | Idem ; C-19 |
| CA-14 | Supprimer une fiche | ✅ | V1 (Lot B, archivage) | Idem ; cascade |
| CA-15 | Importer des fiches dans un cours | 💀 | V4 (F-17) | Un import synchrone ouvert à tout connecté |
| CA-16 | Lister les niveaux | ✅ | V1 (écran de l'équipe, ADR-0034) | — |
| CA-17 | Espace Niveau | ⚠️ | V4 (`catalogue-complet`) | — |
| CA-18 | Gérer les niveaux | ⚠️ | V1 (écran de l'équipe, ADR-0034) | Supprimer un niveau détruit ses classes |
| CA-19 | Associer des séries à un niveau | ✅ | V1 (ADR-0034) | — |
| CA-20 | Lister les matières | ⚠️ | V1 (écran de l'équipe, ADR-0034) | — |
| CA-21 | Page matière | ⚠️ | V4 | — |
| CA-22 | Gérer les matières | ⚠️ | V1 (ADR-0034, `category` obligatoire) | `category` laissée à `NULL` ; une clé de cache jamais invalidée |
| CA-23 | Pages des séries | ❌ | V2 | — |
| CA-24 | Gérer les séries | ⚠️ | V1 (ADR-0034) | — |
| CA-25 | Taxonomie depuis l'onglet « Setup » | ⚠️ | V1 (= TR-13, ADR-0034) | — |
| CA-26 | Icône et couleur de la matière | ✅ | V1 (Lot B, UDR) | Une couleur déduite du nom au lieu de `category` |
| CA-27 | Affecter un cours depuis sa page | 💀 | V1 (Lot D) : le point d'entrée de l'assignation est fixé par l'UDR du lot | Un bouton inatteignable (`@teacher_classrooms` jamais affecté) |
| CA-28 | Validation collaborative | 💀 | V8 (F-33) | — |
| CA-29 | Bandeau « Conforme au programme » | ⚠️ | **écartée** : affirmation fausse affichée à tous (F-33) | Une validation affichée qui n'a jamais eu lieu |

### 6.6 Assessment — `AS`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| AS-01 | Parcourir tous les exercices de la plateforme | ⚠️ | V4 (`catalogue-complet`) | Une page liée nulle part ; une carte mise en cache sans l'utilisateur ni le rôle dans la clé |
| AS-02 | Consulter le détail d'un exercice | ⚠️ | V1 (Lot C) | — |
| AS-03 | Créer un exercice par le formulaire | ❌ | V1 (Lot B) — **à construire** | « + Ajouter une question » inerte (contrôleur Stimulus absent) ; des questions jamais persistées ; un titre passé en `titleize` |
| AS-04 | Modifier un exercice | ❌ | V1 (Lot B) | Idem |
| AS-05 | Supprimer un exercice | ✅ | V1 (Lot B, archivage : F-14) | Une cascade qui détruit sessions, tentatives et badges des élèves |
| AS-06 | Importer des exercices par le « content engine » | ❌ 💀 | **écartée** : le service n'a jamais existé dans aucun commit ; l'import de V4 (F-17) le remplace | — |
| AS-07 | Démarrer une session | ✅ | V1 (Lot C) | — |
| AS-08 | Reprendre une session en cours | ✅ | V1 (Lot C) | — |
| AS-09 | Répondre aux questions une à une | ❌ ⚠️ | V1 (Lot C, F-34) | Une question déjà répondue qu'on peut re-soumettre après avoir vu le corrigé, doublon compté dans le score ; une réponse vide qui produit une erreur 500 en Turbo |
| AS-10 | Voir la correction immédiate | ⚠️ | V1 (Lot C) | — |
| AS-11 | Obtenir un badge à la clôture | ⚠️ | V1 (Lot C, F-10) | Un badge écrit mais jamais affiché |
| AS-12 | Voir le résultat d'une session | ⚠️ | V1 (Lot C, F-11) | Le pourcentage seul, sans la note ni le badge promis par l'ADR-0008 |
| AS-13 | Recommencer un exercice | ✅ | V1 (Lot C) | — |
| AS-14 | Détecter une lacune après un échec | 💀 | V5 (F-21) | Une détection branchée sur un use case que le parcours réel n'appelle pas |
| AS-15 | Résoudre une lacune après une réussite | 💀 | V5 (F-21) | Idem |
| AS-16 | Lancer une session de remédiation | ❌ | V5 | Un bouton qui appelle un helper de route inexistant |
| AS-17 | Suivre les remédiations de sa classe | ❌ | V5 | `NoMethodError` sur panneau fermé |
| AS-18 | Assigner un exercice à une classe | ❌ | V1 (Lot D) (= CL-20) | Une réponse `204` qui laisse le bouton inchangé ; `assigned_by_id` qui reçoit un id de profil pour une clé vers `users` |
| AS-19 | Retirer un exercice d'une classe | ⚠️ | V1 (Lot D) (= CL-20) | — |
| AS-20 | Exercices d'un chapitre dans une classe | ❌ | V1 (Lot D) (= CL-12) | — |
| AS-21 | Rapport de synthèse d'un exercice | ❌ | V3 (`rapports-de-classe`) | « Tentatives » qui compte des sessions ; des niveaux de badge affichés en anglais |
| AS-22 | Rapport détaillé par question et par élève | ❌ | V3 | Un taux de réussite qui dépasse 100 % dès qu'un élève recommence ; des questions numérotées par `id` |
| AS-23 | Message d'encouragement à l'enseignant | ❌ | V3 | 36 phrases en dur dans la vue |
| AS-24 | Détail d'un élève | ⚠️ | V3 (= CL-13) | Un mur de badges qui mélange toutes les classes |
| AS-25 | Compteurs de badges de la classe sur la carte | ⚠️ | V3 | Une requête par carte (N+1) |
| AS-26 | Simuler les sessions des démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-27 | Catalogue de sujets d'examen (élève) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-28 | Consulter un sujet (paywall) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-29 | Refaire un sujet | ❌ 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-30 | Banque de sujets (enseignant) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-31 | Sujet et classes éligibles | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-32 | Assigner ou retirer un sujet | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-33 | Valider une assignation de sujet | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-34 | Gérer la banque de sujets (équipe) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| AS-35 | Importer des sujets en JSON | ❌ | **écartée** — retirée du plan le 2026-09-22 | Un message d'erreur d'import passé en `html_safe` (injection HTML par fichier) |
| AS-36 | Exercices de ma classe sur l'accueil élève | ❌ | V1 (Lot A / D) (= TR-04) | — |
| AS-37 | Ma progression sur la fiche d'un chapitre | ⚠️ | V1 (Lot C) (= CA-11) | Des exercices non publiés listés à l'élève |
| AS-38 | Créer exercices, questions et réponses par l'import de cours | ⚠️ | V4 (`import-contenu`, = CA-08) | `questions.position` jamais écrite |
| AS-39 | Aperçu des questions sur la carte d'exercice | ❌ | V1 (Lot C) | **Fuite des bonnes réponses** : un fragment mis en cache par question, sans le rôle dans la clé, servi à un élève après un enseignant ([`securite.md`](securite.md) n° 29) |
| AS-40 | Durée estimée d'un exercice | 💀 | **écartée** : jamais affichée, aucune règle décidée | — |

### 6.7 Transverse — `TR`

| ID | Feature | État | Vague | Ne pas reproduire |
|---|---|---|---|---|
| TR-01 | Landing et modales élève / enseignant | ✅ | V0 (squelette, garde-fou n° 7) · V1 (contenu) | — |
| TR-02 | Redirection selon le rôle | ⚠️ | V1 (0b) (= ID-13) | La boucle infinie de l'enseignant sans école |
| TR-03 | « Espace Etabl. » à 2 000 FCFA | ❌ | **écartée** — retirée du plan le 2026-09-22 | Un lien vers une route inexistante |
| TR-04 | Fil d'accueil élève | ❌ | V1 (Lot A / D, F-31) · annonces en V6 | Un écran d'accueil sans test système (il levait une exception sans alerte) |
| TR-05 | Fil d'accueil enseignant | ❌ | V1 (Lot D) · activité des élèves en V3 | Idem |
| TR-06 | Gains « Prepa » en FCFA | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| TR-07 | `/teachers/dashboard` | 💀 | **écartée** : page d'échafaudage vide ; le tableau de bord de classe est livré en V3 | — |
| TR-08 | `/teachers/setup` | 💀 | **écartée** : remplacée par un onboarding à état persisté (V1, Lot D) | — |
| TR-09 | Fil d'accueil équipe | ✅ | V1 (Lot B, minimal) · V4 (`pilotage-equipe`) | — |
| TR-10 | « Control Center » équipe | ❌ | V4 (`pilotage-equipe`) | Un tableau de bord sans test (méthode renommée sans mise à jour de l'appelant) |
| TR-11 | Rechercher un élève ou un enseignant | ❌ | V4 | — |
| TR-12 | Répartition des élèves par niveau | 💀 | V4 | — |
| TR-13 | « Configuration Plateforme » | ✅ | V1 (taxonomie, ADR-0034) · V2 (DRENA, écoles, `referentiels-equipe`) | — |
| TR-14 | « LnclassAI » | ⚠️ | **écartée** — retirée du plan le 2026-09-22 : iframe vers un artefact externe non inspecté, aucun besoin documenté | Charger un contenu tiers dans l'espace équipe sans CSP |
| TR-15 | Tableau de bord de l'établissement | ⚠️ | V2 (= SC-15) | — |
| TR-16 | « En attente d'affectation » | ✅ | V2 (= SC-16) | — |
| TR-17 | Formulaire « Prepa BAC » enseignant | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | — |
| TR-18 | PDF « Analyse de récurrence » | 💀 | **écartée** — retirée du plan le 2026-09-22 | Un téléchargement sans contrôle de rôle ; un bouton `href="#"` |
| TR-19 | Paywall « Prepa BAC » | 💀 | **écartée** — retirée du plan le 2026-09-22 | Un faux numéro WhatsApp ; un statut de paiement jamais persisté |
| TR-20 | Annuaire des comptes | ⚠️ | V2 (= ID-21) | — |
| TR-21 | Fiche d'un compte | ⚠️ | V2 (= ID-22) | — |
| TR-22 | Modifier ou supprimer un compte | ⚠️ | V2 (= ID-18, ID-23) | — |
| TR-23 | Thème clair / sombre | 💀 | **écartée** en V1 (F-09) | Une bascule sans palette sombre |
| TR-24 | Manifeste PWA et service worker | ⚠️ | V4 (`installation-pwa`) | Un service worker entièrement commenté |
| TR-25 | Bandeau d'installation | ⚠️ | V4 (= ID-26) | — |
| TR-26 | Mesure d'audience | ⚠️ | V0 (F-27) | Des identifiants en dur, sans consentement ni CSP |
| TR-27 | Navigation par rôle | ⚠️ | V1 (Lot 0c, F-31) | 4 × 4 partials divergents |
| TR-28 | Imports JSON en arrière-plan | ⚠️ | V2 (écoles) · V4 (contenu) | Un échec de job silencieux ; un fichier posé sur le disque éphémère du conteneur ; un nom de fichier client dans un chemin disque |
| TR-29 | Import des DRENA en arrière-plan | 💀 | V2 (= SC-02) | — |
| TR-30 | Démos : générer et simuler | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| TR-31 | Purge horaire des jobs terminés | ⚠️ | V0 (F-30) | Un job récurrent qui dépend d'un worker jamais lancé |
| TR-32 | Cache des agrégats et référentiels | ✅ | V0 (installation) · V3 (rapports) | Un cache actif en production seulement |
| TR-33 | Temps réel (Solid Cable) | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| TR-34 | Sonde de santé `/up` | ❌ | V0 (garde-fou n° 6) | — |
| TR-35 | Refus des navigateurs anciens | ✅ | V0 (F-29) | Un 406 sur les Android d'entrée de gamme du public cible |
| TR-36 | Déploiement en production | ⚠️ | V0 (F-30) | Une configuration de déploiement non versionnée |
| TR-37 | Conservation des fichiers téléversés | ⚠️ | V0 ou V2 (F-25) | Un stockage local perdu à chaque déploiement |
| TR-38 | E-mails (Action Mailbox) | 💀 | **écartée** : aucune feature ne l'utilise ; les 14 routes sont retirées | — |
| TR-39 | Journaux sans donnée sensible | ⚠️ | V0 (garde-fou n° 6) | `:contact` en clair dans les logs |
| TR-40 | Interface en français par clés | ⚠️ | V0 (`raise_on_missing_translations`) · toutes les vagues | 1 vue sur 315 qui passe par `t()` |
| TR-41 | Formules mathématiques (KaTeX) | ✅ | V1 (Lot B / C, F-29) | KaTeX chargé depuis un CDN tiers |
| TR-42 | `Current.user` dans les couches basses | 💀 | **écartée** comme feature : l'acteur est passé en paramètre au use case et à sa policy (F-04) | — |

### 6.8 Chantiers de bug de l'ancien dépôt

Les huit chantiers ouverts par l'audit du 2026-09-18 ([`chantiers/README.md`](../README.md#chantiers-ouverts)) ne sont pas portés. Chacun devient le **cas de test** qui prouve que la vague ne le reproduit pas.

| Chantier | Vague | Test qui le couvre |
|---|---|---|
| `queries-constantes-orm-disparues` | V1 (Lot E) | Un test système par rôle, qui ouvre l'écran d'accueil après une connexion réelle |
| `catalog-lecture-ecriture-incompatibles` | V1 (Lot B) | Créer, lire, modifier et archiver un cours par le même agrégat (F-01, F-03) |
| `classroom-assignment-belongs-to-casses` | V1 (Lot D) | Repository d'assignation couvert à 100 %, branches comprises |
| `message-repository-fuite-activerecord` | V0 (garde-fou n° 3) · V6 | Le test de pureté refuse tout objet ActiveRecord dans une entité |
| `classroom-code-adhesion-trop-long` | V1 (Lot 0a) | Un test de schéma : longueur de colonne égale à la longueur du code généré |
| `dette-contrats-ports-et-injection` | V0 (garde-fou n° 3) · V1 (Lot 0a) | Un test de contrat par port ; le domaine n'instancie aucun `Repositories::` (C-39) |
| `acteurs-fantomes-parent-examsubject` | **écartée** : `Parent` et `ExamSubject` sont retirés du plan | Aucun rôle ni type assignable n'est déclaré sans table ni espace |
| `hitl-refs-adr-obsoletes` | **écartée** | Sans objet : le nouveau dépôt commence avec la numérotation d'ADR actuelle |

### 6.9 Bilan

Compté par script sur les tables ci-dessus, après les retraits du 2026-09-22 ; mis à jour le 2026-09-25 (taxonomie en V1, ADR-0034 : six features passent de V2 à V1).

| Préfixe | Features | V0-V1 | V2-V4 | V5-V6 | Écartées ou retirées |
|---|---|---|---|---|---|
| `ID` | 34 | 12 | 12 | 0 | 10 |
| `CO` | 13 | 1 | 0 | 10 | 2 |
| `SC` | 27 | 4 | 22 | 0 | 1 |
| `CL` | 28 | 14 | 6 | 0 | 8 |
| `CA` | 29 | 19 | 7 | 1 | 2 |
| `TR` | 42 | 17 | 12 | 0 | 13 |
| `AS` | 40 | 17 | 7 | 4 | 12 |
| **Total** | **213** | **84** | **66** | **15** | **48** |

Certaines features sont réparties sur deux vagues, par exemple une lecture seedée en V1 et un écran en V2. Elles sont comptées dans la **première** vague qui les livre. Les 48 écartées comprennent 26 features retirées du plan le 2026-09-22 ; les autres sont des doublons, du code mort ou des routes qu'aucune règle ne justifie.

---|---|---|---|---|---|
| `ID` | 34 | 12 | 12 | 3 | 7 |
| `CO` | 13 | 1 | 0 | 11 | 1 |
| `SC` | 27 | 4 | 22 | 0 | 1 |
| `CL` | 28 | 14 | 6 | 3 | 5 |
| `CA` | 29 | 14 | 12 | 1 | 2 |
| `TR` | 42 | 16 | 13 | 7 | 6 |
| `AS` | 40 | 21 | 9 | 4 | 12 |

Certaines features sont réparties sur deux vagues, par exemple une lecture seedée en V1 et un écran en V2. Elles sont comptées dans la **première** vague qui les livre.

---

## 7. Couverture des tables de [`feature_listing.md`](../../feature_listing.md)

Source : [`complements-transverse.md` §5.1](inventaire/complements-transverse.md), recoupé avec la couverture de chaque complément. **Chaque ligne du listing a une vague ou une raison d'écart.** La vague indiquée est celle où la table est **créée** ; les vagues suivantes ne font que l'étendre, par une migration décidée dans leur chantier.

### 7.1 Lignes du listing

| Ligne du listing | Table cible | Créée en | Features (§6) | Remarque pour le projet cible |
|---|---|---|---|---|
| `Users` | `users` | V1 | ID-01…29, TR-02 | `public_id` opaque (F-05), nom et prénom séparés (F-15), `contact` sur 10 chiffres (F-28). Colonnes du bandeau PWA : voir plus bas |
| `team` | `teams` | V1 | ID-04 (remplacée), TR-09 | Créée par seed puis invitation (F-16), index unique sur `user_id` |
| `teacher` | `teachers` | V1 | ID-03, SC-27 | `material_id` avec clé étrangère : l'ancien n'en avait pas |
| `student` | `students` | V1 | ID-01, ID-02 | Index unique sur `user_id` ; `matricule` n'était écrit que par les comptes démo : non créée |
| `Drena` | `drenas` | V1 (lecture, seed) · V2 (écriture) | SC-01, SC-02 | `schools.drena_id` est obligatoire (§5 V1) |
| `Schools` | `schools` | V1 (seed) · V2 (écriture) | SC-03…09 | — |
| `series` | `series` | V1 (équipe) | CA-23, CA-24 | Créées par l'équipe ; `A1 A2 C D` en seed de développement (ADR-0034) |
| `Level` | `levels` | V1 (équipe) | CA-16…19 | Créés par l'équipe ; `6ème…Tle` en seed de développement (ADR-0034) ; supprimer un niveau ne détruit plus de classes (C-26) |
| `level_series` | `level_series` | V1 (équipe) | CA-19 | Table vivante, contrairement à ce que disait l'inventaire |
| `classrooms` | `classrooms` | V1 | CL-01…04, SC-09 | Longueur de `unique_code` égale à celle du code généré ; `public_id` dans les URL (F-05) ; année scolaire en V3 (F-19) |
| `teacher_classrooms` | `teacher_classrooms` | V1 | CL-09 | Table vivante, contrairement à ce que disait l'inventaire |
| `classroom_students` | `classroom_students` | V1 | ID-01, ID-02, CL-06, CL-07 | Une seule adhésion `primary: true` par élève, garantie par index partiel |
| `materials` | `materials` | V1 (équipe) | CA-20…22, CA-26 | `category` renseignée (la palette de couleurs en dépend, CA-26) |
| `courses` | `courses` | V1 | CA-01…08 | Énumération de statut et `published_at` (F-13), auteur (F-13) |
| `essentials` | `essentials` | V1 | CA-10…15 | Libellé à l'écran selon F-32 ; `validated_at` et `validated_by` **non** créés avant F-33 |
| `classroom_courses` | — | **écartée** | — | N'existe plus : fusionnée dans `classroom_assignments` (C-35) |
| `classroom_essentials` | — | **écartée** | — | Idem |
| `exercises` | `exercises` | V1 | AS-01…05, AS-38 | `essential_id` obligatoire (F-34) ; statut de publication (F-13). Colonnes mortes non reprises : `import_data`, `recurrence_rate`, `source_exam` |
| `questions` | `questions` | V1 | AS-03, AS-09, AS-39 | `position` réellement écrite (l'ancien ne l'écrivait jamais) |
| `answers` | `answers` | V1 | AS-09, AS-10, AS-39 | Jamais servies à un élève hors correction (securite n° 29) |
| `classroom_exercises` | — | **écartée** | — | Idem `classroom_courses` |
| `exercise_sessions` | `exercise_sessions` | V1 | AS-07…13 | Avancement et score en deux champs (F-11) ; `classroom_id` si F-26 le retient (C-25) |
| `question_attempts` | `question_attempts` | V1 | AS-09, AS-10 | Une par question et par session, garantie en base ; réponse structurée (F-34) |
| `exercise_badges` | `exercise_badges` | V1 | AS-11, AS-12 | Barème selon F-10 ; `exercise_sessions.badge_level`, lue mais jamais écrite dans l'ancien, n'est pas reprise |
| `messages` | `messages` | V6 | CO-01…13 | Audience `school_admin` réelle (F-23) ; publication différée par job |
| `AddInstallBannerStatusToUsers` | colonnes `users.install_banner_status` et `users.install_banner_last_changed_at` | V4 | ID-26, TR-25 | Le serveur n'accepte que les transitions prévues, et « installée » n'est enregistré que sur un signal réel du navigateur |
| `school_roles` | `school_roles` | V2 | SC-11, SC-12 | Rôles de référence (F-22), toujours scopés à leur école |
| `school_staffs` | `school_staffs` | V2 | SC-13…16 | Index unique ; le nombre d'écoles par personne est tranché par F-22 (C-30) |
| `knowledge_gaps` | `knowledge_gaps` | V5 | AS-14…17 | Clé `bigint` (C-15) ; une seule lacune en attente, garantie en base (F-21) |
| `classroom_assignments` | `classroom_assignments` | V1 | CL-16, CL-17, CL-20, CL-22 | Deux statuts (F-26) ; réassigner réactive la ligne au lieu de lever `RecordNotUnique` |
| `solid_cache_entries` | idem | V0 | TR-32 | Même store en dev et en production, sinon le cache n'est jamais testé |
| `solid_cable_messages` | idem | **écartée** : le temps réel est retiré du plan | CO-08, TR-33 | Jamais écrite dans l'ancien |
| `solid_queue_jobs`, `_ready_executions`, `_claimed_executions`, `_failed_executions`, `_processes`, `_recurring_tasks`, `_recurring_executions`, `_scheduled_executions` | idem | V0 | TR-28, TR-31 | Worker selon F-30 ; les échecs doivent être visibles |
| `solid_queue_blocked_executions`, `_pauses`, `_semaphores` | idem | V0 (installées par le générateur) | — | Jamais écrites dans l'ancien : aucun `limits_concurrency` ni pause. Aucune feature ne les exige |

### 7.2 Tables du schéma absentes du listing

| Table | Créée en | Features | Remarque |
|---|---|---|---|
| `teacher_schools` | V1 | ID-03, SC-27, ID-27 | Drapeau « principale » (F-06) ; le sélecteur arrive en V3 |
| `action_text_rich_texts` | V1 | CA-04, CA-05, CO-01 | Table vivante, contrairement à ce que disait l'inventaire |
| `active_storage_blobs`, `_attachments`, `_variant_records` | V1 si un téléversement y entre, sinon V2 (avatar) | ID-19, CO-01, TR-37 | Stockage objet (F-25) ; type et taille validés. Couverture de cours et de fiche jamais écrite dans l'ancien (`image_cover` absent des `permit`) |
| `friendly_id_slugs` | **écartée** | — | Morte : aucun modèle n'utilise `:history` ; les slugs de contenu n'ont pas d'historique à conserver avant décision contraire |
| `schema_migrations`, `ar_internal_metadata` | V0 | — | Tables internes de Rails |

### 7.3 Tables nouvelles exigées par les décisions

| Table | Vague | Exigée par |
|---|---|---|
| Journal d'audit (connexions, changements de secret, suppressions, rattachements) | V1 | [PRD cadre §4](prd.md#4-exigences-transverses--valables-dès-la-vague-1) |
| Échecs de connexion et verrouillage | V1 | ADR-0025, F-28 |
| Codes de récupération du PIN | V1 | F-08 |
| Secrets TOTP et codes de secours de l'équipe | V1 | F-07 |
| Invitations (équipe en V1, direction en V2) | V1, V2 | F-16, F-22 |
| Rapports d'import | V4 | F-17 |
| `message_dismissals` (l'ancien utilisait un cookie de session) | V6 | F-23 |

---

## 8. Risques du programme

| Risque | Parade |
|---|---|
| **Le registre des décisions ne se vide pas** : 3 décisions bloquent la V0 et 21 la V1 | Les trancher par lots thématiques : F-27/F-29/F-30 (dépôt et livraison) d'abord ; F-01/F-03/F-04/F-05/F-34 (contrats du domaine) en une session ; F-07/F-08/F-16/F-28 (comptes) en une autre ; F-09/F-31/F-32 (design) en parallèle — c'est le chemin critique de V1 |
| **Une feature « à reprendre » n'a jamais tourné** | Les états ❌ et 💀 de la table §6 imposent un chantier feature complet, grill compris ; ils ne s'estiment pas comme des portages |
| **Le seuil de couverture cède sous la pression** | Assouplir est permis, en silence non : un ADR daté ([`etat-et-plan.md` §7](etat-et-plan.md)) |
| **La V4 chevauche la V2 sur les mêmes fichiers** | Tableau de collision **entre vagues** avant de lancer le chevauchement |
| **Les contrats de V1 bougent en V3** | Contrat livré = contrat gelé ; le modifier est un ADR |

---

## 9. Portes de sortie du programme

- [ ] Dépôt amorcé : les 7 garde-fous de la phase 0 prouvés par un commit refusé
- [x] `memo.md` complet, grill fait, hors périmètre non vide
- [x] Inventaire complet : chaque table, route et branche non fusionnée rattachée ou déclarée morte (§6, §7 ; compléments du 2026-09-22)
- [x] `prd.md` cadre : matrice acteurs × permissions, exigences transverses
- [ ] Registre des décisions : chaque décision consommée par V1 est `Accepté`
- [ ] Registre des contradictions : aucune contradiction ouverte ne touche V1
- [x] Table de traçabilité : chaque feature a une vague ou une raison d'écart (213 features, §6)
- [ ] Chaque vague livrée : chantiers clos, recette sur `Staging` par un rôle distinct
- [ ] `feuille-de-route.md` et `journal.md` mis à jour après chaque vague
