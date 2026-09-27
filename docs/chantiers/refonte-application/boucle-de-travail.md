# Boucle de travail — Recodage de Lnclass (V0 → V6)

| | |
|---|---|
| **Programme** | `refonte-application` — cycle [programme](../../workflows/programme.md) |
| **Écrite le** | 2026-09-25 |
| **Dépôt cible** | `~/LnclassHQ/Lnclassapp/LnclassHQ/App.Lnclassapp` (GitHub `Lnclassapp/App.Lnclassapp`, déployé sur Railway) |
| **Référence fonctionnelle et visuelle** | `~/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp` — **lu, jamais copié** |
| **Objectif du porteur** | toutes les vagues V0 → V6, en 2 h, avec des sous-agents en parallèle |

> Ce document **applique** [`workflows/README.md`](../../workflows/README.md) et [`programme.md`](../../workflows/programme.md) au recodage : il ne les remplace pas, et il n'assouplit aucune de leurs règles. Le *quoi* est dans la [`feuille-de-route.md`](feuille-de-route.md). Ce fichier dit *comment on enchaîne* et *qui fait quoi*.

---

## 1. Décisions du porteur du 2026-09-25

| Sujet | Décision |
|---|---|
| Périmètre | **Tout le plan** : V0, V1, V2, V3, V4, V5, V6. Ce qui est retiré du plan (examens, démo, messagerie, Parent, LnclassAI) reste retiré |
| Décisions de fondation | Les recommandations de la feuille de route §3 sont **rédigées en ADR/UDR puis acceptées en bloc** par le porteur, après relecture |
| Design | **Mixte** : écrans, parcours et composants de l'ancienne app ; couleurs, polices et logo de la landing du nouveau dépôt (`@theme` actuel : `brand #00a0ff`, `DM Sans`, `Bricolage Grotesque`, couleurs de rôle) |
| Backend | Libre, **dans le cadre des ADR acceptés** et de [`conventions.md`](../../guide/conventions.md) |
| Rôle de Claude | Dev full-stack et **orchestrateur** : il tient les contrats, dispatche les sous-agents, intègre et prouve |

---

## 2. Qui fait quoi

| Rôle | Tenu par | Responsabilité | Ne fait jamais |
|---|---|---|---|
| **Porteur produit** | Kamkara | accepte les ADR/UDR, tranche les questions ouvertes, fait la recette sur `Staging`, autorise les push et les déploiements, **fait seul le passage `Develop` → `main`** | — |
| **Orchestrateur** | Claude (session principale) | ouvre les chantiers, **écrit les Lots 0** (contrats gelés), dispatche, merge, lance `bin/ci`, tient `journal.md` et la feuille de route | déléguer un Lot 0, merger un lot rouge |
| **Rédacteur de décisions** | 1 sous-agent | rédige les ADR/UDR de fondation d'après les recommandations | coder |
| **Planificateurs** | 1 sous-agent par vague à ouvrir | `memo.md` + `prd.md` + `plan.md` du chantier de la vague (`/feature` puis `/plan-lots`) | coder, toucher `app/` |
| **Exécutants de lot** | 1 sous-agent par lot, dans un **worktree isolé** | code d'un lot, test rouge d'abord, sur **ses** fichiers seulement | toucher un fichier hors de son lot, migrer, pousser, `SKIP_HOOKS` |
| **Challenger** | 1 sous-agent **distinct des auteurs** par vague | refait les parcours en navigateur réel, attaque les policies (refus), compare l'UI à l'ancienne | corriger lui-même : il **rapporte** |

---

## 3. Le graphe d'exécution

Le chemin critique est **V0 → V1 → V2 → V3 → V5**. V4 et V6 ne dépendent que de V1 : elles courent en parallèle de V2, sur des fichiers disjoints ([`programme.md` §4](../../workflows/programme.md#4-exécuter--une-vague-à-la-fois)).

```
 ÉTAPE 0 ───────────────────────────────────────────────────────────────
  [décisions]  ADR 0026→0054 + UDR 0005→0007 (toutes vagues)  ──► acceptation en bloc
  [V0]         amorcage-depot : hooks, CI, SimpleCov 100 %, prod    ─┐
  [0c]         baseline design (UDR-0005/0006) : tokens + composants ─┤  en parallèle
  [plan V1]    chantier boucle-pedagogique : memo/prd/plan.md        ─┘
                                  │
 ÉTAPE 1 ── V1 Lot 0 (orchestrateur) : schéma V1, entités, ports, policies, auth (0a+0b)
                                  │
 ÉTAPE 2 ── V1 lots A · B · C · D · D' en parallèle   ‖  planif. V2 · V4 · V6
                                  │
 ÉTAPE 3 ── V1 prouvée (challenger)  ──►  Lot 0 commun V2+V4+V6 (orchestrateur)
                                  │
 ÉTAPE 4 ── lots V2 ‖ lots V4 ‖ lots V6 en parallèle  ‖  planif. V3 · V5
                                  │
 ÉTAPE 5 ── V2/V4/V6 prouvées ──► Lot 0 V3 ──► lots V3
                                  │
 ÉTAPE 6 ── Lot 0 V5 ──► lots V5 ──► preuve finale du programme
```

**Règle de pipeline** : pendant que les exécutants codent la vague *n*, les planificateurs ouvrent la vague *n+1*. Aucun agent n'attend un plan. Le planning reste roulant : on détaille au plus la vague en cours et la suivante.

---

## 4. La boucle — appliquée à chaque vague

```
┌─► 1. OUVRIR   chantier(s) de la vague : memo → prd → plan.md (lots au format §6 des conventions)
│   2. GELER    Lot 0 par l'orchestrateur : migrations, ORM, entités, ports, policies, routes, locales,
│               layouts, navigation. Commit sur la branche de chantier. CI verte.
│   3. DISPATCHER   1 sous-agent par lot sans dépendance en attente, tous dans UN seul message,
│               chacun dans son worktree (feature/<slug>-lot-<x>), avec le brief standard (§5)
│   4. INTÉGRER merge des lots un par un dans feature/<slug> ; bin/ci complet après chaque merge ;
│               un lot rouge retourne à son agent avec la sortie exacte, il n'est pas corrigé à côté
│   5. PROUVER  challenger distinct : parcours en navigateur réel (Chrome), refus de chaque policy,
│               écart visuel avec l'ancienne app, i18n ; couverture 100 % lignes et branches
│   6. LIVRER   PR feature/<slug> → Develop ; Develop → Staging ; recette porteur ;
│               feuille-de-route §6 (colonne livré), journal.md (une entrée par vague)
└── vague suivante
```

**Le nombre d'agents n'est jamais décidé** : il est égal au nombre de lots dont les dépendances sont levées ([conventions §6](../../guide/conventions.md#6-format-dun-lot)).

### Portes d'une vague — rien ne passe au rouge

- [ ] Décisions consommées par la vague au statut `Accepté`
- [ ] Pre-commit actif (`git config core.hooksPath` = `.githooks`) : aucun commit en `SKIP_HOOKS`
- [ ] `bin/ci` vert : rubocop, brakeman, bundler-audit, tests, **tests système Chrome headless**, SimpleCov 100 % lignes **et** branches, budget de poids de l'ADR-0051
- [ ] Chaque use case a sa policy et un test de refus
- [ ] Aucune valeur arbitraire (`[…]`, `#hex`) dans les vues, vérifié par le test du design system
- [ ] En-tête HITL sur chaque fichier de `app/`, interface 100 % `t(".key")` en `fr`
- [ ] Les défauts « Ne pas reproduire » de la feuille de route §6 sont des tests verts
- [ ] Rapport du challenger sans constat bloquant

> **Assouplir est permis, le faire en silence ne l'est pas.** Si le délai de 2 h menace une porte, on s'arrête et le porteur tranche : soit la vague glisse, soit un ADR daté assouplit la porte. Jamais un `SKIP_HOOKS` à la dernière minute.

---

## 5. Le brief standard d'un exécutant de lot

Chaque sous-agent reçoit **ce gabarit rempli**. Il ne voit pas la conversation. Tout ce dont il a besoin doit donc y être.

```markdown
Tu es l'exécutant du Lot <X> du chantier <slug> (programme refonte-application).
Dépôt : ~/LnclassHQ/Lnclassapp/LnclassHQ/App.Lnclassapp — ton worktree : <chemin>, branche feature/<slug>-lot-<x>.

## À lire avant d'écrire (dans cet ordre)
1. docs/guide/conventions.md
2. docs/chantiers/<slug>/prd.md, puis le Lot <X> dans docs/chantiers/<slug>/plan.md
3. Les blueprints des couches touchées : docs/blueprints/<couche>.md
4. Les ADR/UDR cités par le lot
5. Les fiches de l'inventaire : docs/chantiers/refonte-application/inventaire/<fichier> §<ID>
   → elles décrivent l'ANCIEN. Leur colonne « Ne pas reproduire » = tests à écrire.

## Référence visuelle (design mixte)
- Écrans et parcours de l'ancienne app : ~/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp/app/views/<chemins>
  et captures : docs/design/captures/<…> — reproduire la structure, la hiérarchie, les textes.
- Couleurs, polices, rayons, ombres : UNIQUEMENT les tokens @theme et les composants de app/views/components/.
  Aucune classe de l'ancienne app n'est recopiée telle quelle.

## Ton périmètre
Fichiers autorisés : <liste exacte du plan>. Tout autre fichier est interdit — s'il te manque un contrat,
une route, une clé de locale ou une migration, tu T'ARRÊTES et tu le signales (c'est un trou du Lot 0).

## Méthode
- Test rouge d'abord, puis domaine → infrastructure → delivery → UI.
- Chaque use case appelle sa policy en premier et renvoie un Result (ADR-0026) ; test de refus obligatoire.
- 100 % lignes et branches sur tes fichiers ; `# :nocov:` interdit.
- CRUD en Hotwire (ADR-0009) dès que l'écran s'y prête : création et édition en ligne dans un `turbo_frame_tag`, réponses `turbo_stream` pour create/update/destroy (liste mise à jour, toast, formulaire réinitialisé), modales chargées dans un frame, erreurs de validation re-rendues en `422` dans le frame. Chaque action garde sa réponse HTML de repli. Stimulus seulement pour le comportement que Turbo ne couvre pas. Un test système prouve le parcours sans rechargement de page.
- Commits Conventional Commits en anglais, pre-commit actif, jamais SKIP_HOOKS, jamais de push.

## Done quand
<critère du plan> ET `bin/rails test <tes tests>` vert ET couverture 100 % sur tes fichiers.

## Rapport final (format fixe, 30 lignes max)
Fichiers créés/modifiés · tests (nombre, verts) · couverture de tes fichiers · écarts avec le plan ·
trous du Lot 0 rencontrés · questions pour le porteur.
```

---

## 6. Règles de collision propres au recodage

Le backend est libre sous les ADR. Ces choix d'organisation permettent aux lots de ne jamais partager un fichier :

| Fichier partagé en temps normal | Parade | Propriétaire |
|---|---|---|
| `config/routes.rb` | `draw(:<contexte>)`. Un fichier `config/routes/<contexte>.rb` par contexte borné, **créé vide par le Lot 0** | Lot 0 crée, un lot remplit **son** fichier |
| `config/locales/fr.yml` | une locale par contexte et par écran : `config/locales/<contexte>/<ecran>.fr.yml` | le lot qui livre l'écran |
| `db/migrate/*`, `db/schema.rb` | **uniquement dans le Lot 0** de la vague | orchestrateur |
| layouts, navigation par rôle, toasts | UDR-0006, livrés au Lot 0 de la V1 | orchestrateur |
| `test/test_helper.rb`, fabriques de données | fabriques par contexte : `test/support/factories/<contexte>.rb` | Lot 0 crée, lot complète **les siennes** |
| `db/seeds.rb` | `db/seeds/<contexte>.rb` chargés par `seeds.rb` | Lot 0 |
| bases de données de dev et de test | `config/database.yml` suffixe le nom de base par le nom du dossier du worktree (`../lnclass-design` → `app_lnclassapp_test_lnclass_design`). Chaque agent a ses bases, sans configuration | fait le 2026-09-25 |

**Emplacement des worktrees** : à côté du dépôt, `~/LnclassHQ/Lnclassapp/LnclassHQ/lnclass-<nom>`. Chaque exécutant lance d'abord `bundle install && yarn install && bin/rails db:prepare` dans son worktree.

---

## 7. Étape 0 en détail — ce qui démarre dès l'acceptation de ce document

Toutes les branches de l'étape 0 partent de `feature/amorcage-depot`, qui porte le socle documentaire. Le dépôt principal reste sur `Develop`, pour l'orchestrateur.

| Agent | Livrable | Branche | Worktree |
|---|---|---|---|
| Rédacteur de décisions | ADR 0026 → 0048, 0050, 0053, 0054 et UDR 0005, 0006, 0007, rédigés au statut `Proposé` d'après les recommandations de la feuille de route §3 ; F-20 et F-24 restent retirées. Index `adr/README.md` et `udr/README.md` à jour | `docs/decisions-fondation` | `lnclass-decisions` |
| Amorçage (V0) | les 7 garde-fous de la feuille de route §2, chacun prouvé par un commit fautif refusé ; `bin/ci` = `.github/workflows/ci.yml` ; tests système dans la CI ; `railway.json` (ADR-0052) | `feature/amorcage-depot` | `lnclass-amorcage` |
| Baseline design (0c) | UDR-0005/0006 appliquées : `@theme` complété (espacements, ombres, rayons, états) à partir de la landing, composants substantiels (carte, champ, bouton, modale, états vide/chargement/erreur), shell par rôle, test anti-valeurs arbitraires | `feature/design-baseline` | `lnclass-design` |
| Planificateur V1 | chantier `boucle-pedagogique` : `plan.md` de la refonte déplacé et corrigé des 5 écarts listés en feuille de route §5 V1, lots A/B/C/D découpés sur fichiers disjoints (D coupé en deux) | `docs/boucle-pedagogique` | `lnclass-plan-v1` |

**Point de synchronisation** : dès que les ADR sont rédigés, le porteur les relit (~5 min) et répond « acceptés ». L'orchestrateur passe alors les statuts à `Accepté` et ouvre le Lot 0 de la V1.

---

## 8. L'horloge et ses points de contrôle

| Horloge | Attendu | Point de contrôle avec le porteur |
|---|---|---|
| T+0:20 | décisions rédigées, V0 prouvée, plan V1 écrit | **acceptation en bloc des ADR/UDR** |
| T+0:40 | Lot 0 V1 gelé, lots V1 dispatchés | — |
| T+1:00 | V1 intégrée et prouvée | **point de périmètre** : on mesure le rythme réel. On décide si V3 et V5 tiennent dans la séance ou passent à la suivante |
| T+1:30 | V2, V4 et V6 intégrées | recette `Staging` de la V1 |
| T+2:00 | V3, V5, preuve finale | recette `Staging`, décision de passage en `main` |

> L'horloge est une **cible**, pas une porte. Si elle glisse, c'est le périmètre qui bouge, jamais la qualité (§4).

---

## 9. Ce qui demande le feu vert du porteur

- Tout `git push` vers GitHub et toute PR : une autorisation **par vague** suffit.
- Toute action Railway : variables, environnement `Staging`, déploiement.
- Toute fusion vers `Staging` ou `main`. **Le passage `Develop` → `main` (par `Staging`) est fait par le porteur lui-même**, jamais par un agent.
- Toute contradiction nouvelle entre sources : elle est inscrite au registre §4 de la feuille de route et tranchée par le porteur. Un agent ne la tranche jamais seul.

> **Aucune protection de branche côté GitHub** (décision du porteur du 2026-09-25) : le dépôt est privé, en offre gratuite, et l'API de protection répond 403. Rien n'empêche techniquement un push direct sur `Develop`, `Staging` ou `main`. Ce qui protège : le hook pre-commit local, jamais contourné, et la discipline des PR ([conventions §3](../../guide/conventions.md#3-branches)). Un agent ne pousse **jamais** sans le feu vert de cette section. Écart consigné au [journal d'amorçage §5](../amorcage-depot/journal.md).
