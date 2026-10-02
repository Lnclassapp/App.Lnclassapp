# Chantiers

**C'est ici que vit le travail.** Un chantier sans dossier ici n'existe pas : ni pour l'équipe, ni pour les agents.

## Ouvrir un chantier

```
/feature <slug>    /bugfix <slug>    /refactor <slug>    /optimize <slug>    /hotfix <slug>
```

Sans Claude Code : `cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>`

Le `<slug>` est en kebab-case, court, sans type ni numéro : `messagerie-classe`, pas `feature-5-messagerie`.

## Contenu d'un chantier

| Fichier | Phase | Rôle |
|---|---|---|
| `memo.md` | 1 — Cadrer | Le problème, pour qui, hors périmètre, ce que le grill a révélé |
| `prd.md` | 2 — Décider | Les specs figées et les critères d'acceptation |
| `plan.md` | 3 — Planifier | Le graphe de lots et les portes de sortie |
| `journal.md` | tout du long | Ce qui a dérapé, ce qu'on a appris, la dette laissée |
| `pr-faq.md` | 1 — Cadrer | **Optionnel.** Pour les gros chantiers seulement : on rédige le communiqué de presse et la FAQ *avant* de construire (« working backwards »). Si le communiqué n'enthousiasme personne, la feature ne mérite pas d'être faite. |

Les ADR et UDR produits par un chantier ne vivent **pas** ici : ils vont dans [`../decisions/`](../decisions/), parce qu'ils survivent au chantier. Le chantier les référence.

## Programme ouvert

| Programme | En une phrase | Point d'entrée |
|---|---|---|
| [`refonte-application`](refonte-application/memo.md) | Recoder Lnclass dans un nouveau dépôt Rails, par vagues V0 → V8 | [`feuille-de-route.md`](refonte-application/feuille-de-route.md) — le plan complet, les décisions à prendre, la traçabilité de chaque feature |

Liste de travail des 213 features, rangée par vague et cochable : [`../features-refonte.md`](../features-refonte.md). Elle est générée à partir du §6 de la feuille de route, qui fait foi.

Un programme suit [`../workflows/programme.md`](../workflows/programme.md) : il ne produit pas de code, il ouvre vague par vague des chantiers ordinaires.

## Chantiers ouverts

Tous issus de l'audit du 2026-09-18, qui a remis la suite de tests en marche après une longue panne silencieuse. Chaque memo contient le diagnostic et la reproduction — la phase 1 est déjà à moitié faite.

| Gravité | Chantier | En une phrase |
|---|---|---|
| 🔴🔴 | [`queries-constantes-orm-disparues`](queries-constantes-orm-disparues/memo.md) | **Aucun élève ni enseignant ne peut se connecter.** Constantes ORM disparues + association manquante + deux boucles de redirection infinies |
| 🔴 | [`catalog-lecture-ecriture-incompatibles`](catalog-lecture-ecriture-incompatibles/memo.md) | Deux familles d'entités Course incompatibles → édition et suppression de cours cassées |
| 🟠 | [`classroom-assignment-belongs-to-casses`](classroom-assignment-belongs-to-casses/memo.md) | Trois `belongs_to` scopés qui lèvent `PG::UndefinedTable` (3 tests attendent en `skip`) |
| 🟠 | [`message-repository-fuite-activerecord`](message-repository-fuite-activerecord/memo.md) | Des objets ActiveRecord dans `Entities::Message` → violation de la Règle d'Or |
| 🟡 | [`classroom-code-adhesion-trop-long`](classroom-code-adhesion-trop-long/memo.md) | Code d'adhésion de 6 caractères pour une colonne `limit: 5` |
| 🟡 | [`dette-contrats-ports-et-injection`](dette-contrats-ports-et-injection/memo.md) | Quatre cas où le contrat déclaré n'est pas le contrat consommé |
| 🔵 | [`acteurs-fantomes-parent-examsubject`](acteurs-fantomes-parent-examsubject/memo.md) | `Parent` et `ExamSubject` déclarés partout, persistés nulle part — décision produit |
| 🟢 | [`hitl-refs-adr-obsoletes`](hitl-refs-adr-obsoletes/memo.md) | 36 fichiers citent les anciens numéros d'ADR (0014→0022, 0015→0023) |

Points mineurs non encore rattachés à un chantier : trois orthographes pour le même espace (`schoolstaff/`, `school_admins/`, `SchoolStaff`) ; `config/cable.yml` n'active `solid_cable` qu'en production, donc un broadcast Turbo Stream depuis la console locale n'atteint jamais le navigateur.

## Chantiers de la refonte

| Chantier | Statut | En une phrase |
|---|---|---|
| [`amorcage-depot`](amorcage-depot/memo.md) | livré | V0 : les garde-fous avant tout code métier (#6) ; garde-fous 1 et 5 en écarts assumés |
| [`boucle-pedagogique`](boucle-pedagogique/memo.md) | livré | V1 : équipe → contenu → enseignant → élève → résultat, en production depuis le 2026-09-27, clos le 2026-09-28 ; recette `Staging` par un rôle distinct : volet public accepté, D1-D2 corrigés, volet authentifié **en attente** d'un compte de recette (porteur, 2026-09-28) |
| [`profil-utilisateur`](profil-utilisateur/memo.md) | livré | « Mon profil » pour tous : nom, numéro et PIN modifiables sous PIN actuel (ADR-0055, UDR-0041) |
| [`generer-classes`](generer-classes/memo.md) | livré | Générer après coup les classes des établissements qui n'en ont aucune de l'année (ADR-0056, UDR-0043) |
| [`photo-de-profil`](photo-de-profil/memo.md) | en production, durcissement livré (#65, #75) ; memo encore « en cours », à clore | Photo de profil pour tous : recadrée par le navigateur, vérifiée par le serveur, visible de soi, de ses enseignants et de l'équipe (ADR-0060, UDR-0047) |
| [`classes-par-niveau`](classes-par-niveau/memo.md) | livré | Ajuster les classes d'un établissement niveau par niveau : ajouter la suivante, retirer la dernière si elle n'a jamais servi (ADR-0059, UDR-0046) |
| [`finitions-generation-menu`](finitions-generation-menu/memo.md) | livré | « Déjà en cours » en toast d'information vers le rapport, badge « Génération en cours », ⋮ collé à droite des tableaux au téléphone (amendements UDR-0042, UDR-0043) |
| [`bareme-classes`](bareme-classes/memo.md) | livré | Barème des classes générées en base, modifiable par l'équipe à l'écran ; menu « Classes » des établissements (ADR-0058, UDR-0045) |
| [`recette-v1-defauts`](recette-v1-defauts/memo.md) | livré | Recette V1, en production le 2026-09-28 (#81, #83) : `/join` refuse en 422 un code sans classe, sous la limite de débit de `/c/` (amendement UDR-0009) ; pages d'erreur statiques en français |
| [`afficher-pin`](afficher-pin/memo.md) | livré | Bouton œil dans les 13 champs de PIN (connexion, inscriptions, profil, PIN oublié), masqué par défaut et avant l'envoi (UDR-0051, amendement UDR-0005) |
| [`actions-en-menu`](actions-en-menu/memo.md) | livré | Actions de modification et de suppression des écrans de l'équipe dans un menu ⋮ (UDR-0042) |
| [`cycles-en-radio`](cycles-en-radio/memo.md) | livré | Cycle d'un niveau et d'un établissement en boutons radio, 1er cycle par défaut (UDR-0005 ter) |
| [`code-etablissement`](code-etablissement/memo.md) | livré | L'enseignant s'inscrit avec le code secret de son établissement (ADR-0057, UDR-0044) |
| [`pilotage-equipe`](pilotage-equipe/memo.md) | livré | V4 : page Pilotage de l'équipe, indicateurs lus en direct, recherche d'un élève ou d'un enseignant (ADR-0062, UDR-0049) |
| [`croissance-parrainage`](croissance-parrainage/memo.md) | livré | Parrainage entre enseignants, démarrage à froid par le code national, page Croissance de l'équipe (ADR-0063, UDR-0050) |
| [`tests-instables`](tests-instables/memo.md) | livré en PR, en attente de fusion | Q15 : trois tests instables reproduits puis corrigés à leur cause — requêtes préparées périmées après les tests de migration, menu ouvert sur l'aperçu de Turbo, attente de 2 s trop courte pour « Recommencer » |
| [`deploiement-seeds-variantes`](deploiement-seeds-variantes/memo.md) | livré | Premier déploiement sur base neuve : seeds joués deux fois (`db:prepare` semait avant `db:seed`), corrigé par `seeds: false` en production (amendement ADR-0052) ; processeur de variantes Active Storage désactivé, aucune variante n'étant utilisée (ADR-0060) |

| [`espace-direction-simple`](espace-direction-simple/memo.md) | livré (#86) | V2 en version simple (porteur, 2026-09-28) : la direction, invitée par l'équipe et connectée par PIN, lit « Enseignants » et « Travail des élèves » de son seul établissement (ADR-0065, UDR-0052, acceptés le 2026-09-29) |
| [`gestion-etablissement-direction`](gestion-etablissement-direction/memo.md) | planifié | V2 : sans fonction, la direction change le lien d'inscription des enseignants, a « + » et « − » sur ses niveaux, retire (devoirs actifs archivés) et réintègre un enseignant ; l'enseignant retiré rejoint un autre établissement par son code (ADR-0071, UDR-0056, proposés) |
| [`finitions-ux`](finitions-ux/memo.md) | planifié | Retour, auto-focus, infobulles, « Copier », envoi automatique, recherche dynamique et titre de page harmonisés par des briques communes ([audit](finitions-ux/audit.md)) ; le caching relève d'un chantier `optimize` séparé |
| [`secrets-hors-cache`](secrets-hors-cache/memo.md) | livré sur `fix/secrets-hors-cache`, sans PR | Codes de secours, clé TOTP, code de récupération du PIN et liens d'invitation hors de tout cache : `secret_response` pose `no-store` + `Pragma` et exempte la page du cache Turbo (amendement ADR-0031) |
| [`cache-ecrans-lourds`](cache-ecrans-lourds/memo.md) | lots 1 à 4 sur `perf/cache-ecrans-lourds`, sans PR ; lot 5 après les lots UX | Budgets gravés (ADR-0067 : p95 < 300 ms pilotage, < 100 ms ailleurs, HTML < 150 Ko). Index et requêtes, sans cache ni vue modifiée : Travail des élèves 213 → 56 ms, pilotage 7 j 338 → 199 ms, recherche 264 → 38 ms (p50) ; pilotage « année » gardé 5 min (36 ms à chaud, 312 ms à froid en p95) ; `pg_trgm` activée (amendements ADR-0062) |
| [`epuration-contenus`](epuration-contenus/memo.md) | livré sur `fix/epuration-entetes-contenus` | En-têtes cours, fiche et exercice épurés (statut seul, actions dans le menu ⋮), « Essentielles de la leçon », et « Tout publier » en cascade (amendements UDR-0042, UDR-0007, ADR-0035) |
| [`catalogue-niveau-eleve`](catalogue-niveau-eleve/memo.md) | livré sur `fix/catalogue-eleve-son-niveau` | L'élève ne voit, n'ouvre et ne commence que les cours de son niveau (et de sa série, ou communs) ; 404 ailleurs (amendements UDR-0013, ADR-0035) |

## Backlog

Travail mis de côté par le porteur. Les vagues V2 à V6 y sont placées le 2026-09-28 (la V2 en sort le jour même dans sa version simple, [`espace-direction-simple`](espace-direction-simple/memo.md)) : aucune n'est ouverte avant une décision datée du porteur ; leur périmètre, leurs chantiers et leurs questions sont au [§5 de la feuille de route](refonte-application/feuille-de-route.md#5-les-vagues). Pour un chantier, le memo dit où reprendre.

| Chantier | En une phrase |
|---|---|
| `espace-direction` (V2 complète) | Matricule MENA de l'élève, quatre fonctions de direction et leurs droits, personnel, retrait et réintégration d'enseignants, changement de classe, code d'établissement, ajout de classes, tableau de bord élaboré. À reprendre « quand on comprendra le fonctionnement de l'administration » (porteur, 2026-09-28). Conception (memo, PRD, ADR, UDR, plan, Lot 0a) sur la branche [`feature/espace-direction`](https://github.com/Lnclassapp/App.Lnclassapp/tree/feature/espace-direction) ; ses numéros ADR-0065 à 0067 et UDR-0052, 0053 sont à renuméroter |
| `annuaire-equipe` (V2) | Grill fait : l'équipe modifie nom, genre et numéro ; désactive puis anonymise automatiquement à 30 jours ; entrée « Comptes » qui remplace « Débloquer un compte » ; ni soi-même ni le dernier admin ; recherche par nom partiel, numéro ou matricule exacts. Memo sur la branche [`feature/annuaire-equipe`](https://github.com/Lnclassapp/App.Lnclassapp/tree/feature/annuaire-equipe). Il retirera aussi une direction |
| `multi-etablissements-enseignant` | Un enseignant rattaché à plusieurs établissements (ID-09, SC-23, ID-27, Q7) : chaque direction voit sa part. Reporté par le porteur le 2026-09-28 |
| `changement-etablissement-eleve` | Un élève change d'établissement en cours de scolarité ; aujourd'hui, un élève dont la classe est active ne rejoint aucune autre classe. Reporté par le porteur le 2026-09-28 |
| `regeneration-codes-en-masse` | L'équipe régénère d'un coup le code d'établissement (donc le lien d'inscription des enseignants) de plusieurs établissements, par exemple une DRENA. Demandé par le porteur le 2026-10-01, sorti de `gestion-etablissement-direction` |
| **V3 — Suivi pédagogique enseignant** | `rapports-de-classe`, `vie-de-la-classe` (dont CL-02) ; `multi-classes-eleve` si Q5 le confirme. `multi-etablissements-enseignant` est une ligne à part, ci-dessus |
| **V4 — Contenu à l'échelle et back-office** | 9 features : `catalogue-complet`, `installation-pwa`, `sous-roles-equipe` ; Q9 et Q10 ouvertes |
| **V5 — Remédiation** | 2 features : AS-16 (remédiation ciblée), AS-17 (suivi par l'enseignant) |
| **V6 — Communication** | 10 features : `annonces`, puis `canal-whatsapp` ([PR #70](https://github.com/Lnclassapp/App.Lnclassapp/pull/70)) ; Q11 à Q14 ouvertes |
| [`verification-whatsapp`](verification-whatsapp/memo.md) | Prouver le numéro par un code WhatsApp (hook n8n) à l'inscription sans code ; grill interrompu à la question 2. Rattaché à la V4 s'il reprend ([feuille de route §5](refonte-application/feuille-de-route.md#chantiers-hors-plan)) |
| [`ci-quota`](ci-quota/memo.md) | **En cours**, repris le 2026-10-02 : runner auto-hébergé abandonné ; CI en un job sur les PR prêtes, preuve d'arbre pour les promotions, Dependabot vers `Develop` (ADR-0069)

## Cycle de vie

Un chantier livré reste en place. Son `memo.md` porte `Statut: livré` et son `journal.md` est clos. On ne supprime pas un chantier : c'est la mémoire du projet.

Un chantier abandonné passe en `Statut: abandonné` avec la raison dans le journal. C'est une information, pas un échec à cacher.
