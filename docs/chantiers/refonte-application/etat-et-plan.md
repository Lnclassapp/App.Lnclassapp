# État actuel et plan — Refonte Lnclass

> **Document de reprise.** Il se lit seul, sans contexte préalable. Écrit le 2026-09-18.
> Les détails vivent dans les fichiers cités ; ici, seulement ce qu'il faut pour décider et démarrer.
>
> **Mis à jour le 2026-09-22** : le plan de recodage **complet** (vagues V0 à V8, décisions de fondation, contradictions entre sources, traçabilité de chaque feature) est dans [`feuille-de-route.md`](feuille-de-route.md). Ce document-ci reste le résumé de la vague 1.

---

## 1. La situation en une page

**Lnclass est reconstruit dans un nouveau projet Rails. Mise en ligne dans 72 h, date ferme, avec de vrais élèves et de vrais enseignants.**

L'application actuelle ne sera pas mise en ligne. Elle reste la référence fonctionnelle — c'est d'elle qu'on tire les règles métier — mais son code n'est pas repris.

**Pourquoi on ne la corrige pas plutôt que de la refaire.** Une réécriture est normalement une mauvaise idée : on redécouvre les règles une par une, on réintroduit les bugs corrigés, on livre moins bien et plus tard. Quatre choses rendent ce cas différent :

1. **Le métier est documenté** — 25 ADR, et surtout l'inventaire exhaustif produit ici, qui décrit chaque feature avec ses règles chiffrées.
2. **97 % du code est écrit par des agents.** Ce qui coûte, ce n'est pas de taper, c'est de décider.
3. **Le passif est architectural**, pas cosmétique : namespaces dupliqués, contrat de retour des use cases jamais figé, ports qui ne déclarent pas ce que leurs adaptateurs exposent. Le corriger sur place revient à réécrire, sans le bénéfice d'un départ propre.
4. **La fenêtre de couverture ne se représentera pas.** 100 % de couverture coûte peu sur un projet neuf et énormément en rattrapage.

---

## 2. Ce qui a été fait

| Livrable | Contenu |
|---|---|
| [`inventaire/`](inventaire/) — 6 fichiers, **5 582 lignes** | **~95 features** recensées. Chacune : acteur, parcours, règles métier avec valeurs exactes, tables, et état réel (✅ marche · ⚠️ fragile · ❌ cassé · 💀 mort) |
| [`securite.md`](securite.md) — 147 lignes | **18 constats vérifiés**, classés par gravité, chacun avec la règle à appliquer dans le nouveau projet |
| [`plan.md`](plan.md) — 239 lignes | Le graphe de lots détaillé, lot par lot, au format gelé des conventions |
| [`memo.md`](memo.md) | Le cadrage et la justification de la réécriture |
| [ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md) | Couverture à 100 %, bloquante dès le premier commit du nouveau projet |
| [ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md) | PIN à 4 chiffres conservé, **sous six compensations indissociables** |

---

## 3. Ce que l'inventaire a révélé

### Trois fonctionnalités qu'on croyait acquises n'ont jamais tourné

C'est la découverte qui change le budget de la refonte.

| Fonctionnalité | Ce qui se passe réellement |
|---|---|
| **Remédiation et lacunes** | Le parcours réel de l'élève passe par `SubmitQuestionAttempt`, qui n'appelle ni la détection ni la résolution. Le seul use case qui pilote le cycle n'est appelé que par un job **jamais mis en file**. Table, écrans et code existent ; rien ne les atteint |
| **Création d'exercice** | Le formulaire lève une `NameError` **avant de s'afficher** (`Entities::Question` au lieu de `Entities::Assessment::Question`). Et `questions_attributes` n'est pas dans la liste blanche : les questions n'auraient de toute façon jamais été enregistrées |
| **« La messagerie »** | C'est un système d'**annonces unidirectionnelles** de l'équipe vers une audience de rôle. Pas de destinataire, pas de fil, pas de réponse, pas d'accusé de lecture. La branche `feature/ticket-5-messaging` ne contient aucun commit absent de la nôtre : c'est l'état final |

> **Ces trois-là sont à *concevoir*, pas à reprendre.** Les budgéter comme des portages aurait été le plus gros raté de la refonte.

### Le motif transverse : authentification oui, autorisation non

Sur six contextes inventoriés, le même défaut partout. L'application vérifie systématiquement qu'on est connecté, et presque jamais qu'on a le droit.

Le cas le plus grave : **`/team-signup` est une route publique sans aucun `before_action`**, qui crée un compte au rôle le plus privilégié. Trois requêtes suffisent à un inconnu pour supprimer tous les comptes de la plateforme. `/staff-signup` permet de la même façon de se déclarer direction de n'importe quel établissement, et d'accéder à la liste nominative d'élèves mineurs avec leurs numéros de téléphone.

`app/domain/policies/` est annoncé dans `CLAUDE.md` et ne contient aucune policy pour `identity` ni `communication`.

> **Règle qui ouvre le nouveau projet : chaque use case déclare sa policy, chaque policy a son test, un use case sans policy ne passe pas la revue.** C'est la seule contre-mesure qui tienne à 97 % de code écrit par des agents — un garde-fou au niveau du métier, testé, plutôt qu'une ligne à ne pas oublier en haut d'un contrôleur.

### Le design system existe et personne ne s'en sert

30 briques recensées, toutes contournées. Le chiffre qui résume : **0 usage conforme sur 927 rayons posés.**

Et un enseignement contre-intuitif, qui a corrigé le plan : **l'adoption suit la tolérance de l'API, pas sa qualité.** Les deux composants aux API les plus strictes totalisent 0 appel ; les deux plus adoptés ont les API les plus laxistes.

---

## 4. Les décisions prises

| Sujet | Décision |
|---|---|
| **Architecture** | Hexagonale **conservée**, corrigée sur les points du §2 de `plan.md` |
| **PIN à 4 chiffres** | **Conservé**, sous les six compensations de l'ADR-0025 |
| **Périmètre à 72 h** | **~25 features sur 95** |
| **Multi-établissements enseignant** | **Une école par enseignant en v1** — l'ancien ne l'exploitait pas non plus (`schools.first`, sans école courante) |
| **Espace direction d'établissement** | **Coupé.** Premier à rattraper après la livraison |
| **Nouveau projet** | Créé par Kamkara, qui y copie `docs/` v2 |
| **Couverture** | 100 % (ADR-0024) — **à réexaminer au moment de livrer**, voir §7 |

---

## 5. Le plan à 72 h

### Le périmètre retenu

```
l'équipe publie un cours, une fiche, un exercice
        ↓
un enseignant déclare ses classes et leur assigne le contenu
        ↓
un élève rejoint sa classe avec un code, voit ce qui lui est assigné,
fait l'exercice, obtient son résultat
```

Les **deux parcours qui auront de vrais utilisateurs au jour 1**, et rien d'autre.

### Ce qui est coupé, et pourquoi c'est tenable

| Coupé | Raison |
|---|---|
| Espace direction d'établissement | Aucun parcours élève ni enseignant n'en dépend |
| Multi-établissements enseignant | Une école par enseignant — **ADR à écrire**, il doit remplacer l'ADR-0004 |
| Rapports de classe détaillés | L'enseignant assigne et voit sa classe ; les tableaux de bord attendent |
| Remédiation et lacunes | **N'a jamais tourné** — à concevoir, pas à reprendre |
| Sujets d'examen | Reporté par décision produit |
| Imports JSON en masse | Saisie manuelle au volume du lancement |
| Annonces | Aucun parcours utilisateur n'en dépend |
| Élèves de démonstration | Générait des milliers de comptes en effet de bord d'un import |
| Validation collaborative | Feature d'équipe |

### Le graphe de lots

```
Lot 0 — SOCLE  (séquentiel · bloquant · ~24 h)
  0a schéma · entités · ports · policies      ┐  0c est indépendant
  0b authentification 3 rôles + récupération  │  et démarre en même
  0c baseline design + bibliothèque UI        ┘  temps que 0a
        │
        ├──► Lot A — Inscription et connexion élève      ┐
        ├──► Lot B — Publication de contenu (équipe)     ├─ parallèle
        ├──► Lot C — Passage d'un exercice               │  fichiers disjoints
        └──► Lot D — Espace enseignant et assignation    ┘
                        │
                        └──► Lot E — Prouver et livrer
```

**21 tables sur les 27 de l'ancienne app.** Écartées : `school_roles`, `school_staffs`, `teacher_schools`, `drenas`, `knowledge_gaps`, `messages`.

### Les prérequis non négociables du socle

Ce ne sont pas des features, ce sont des propriétés. Aucune livraison sans elles.

- Aucune route publique ne crée un rôle privilégié
- `force_ssl` actif dès le premier déploiement
- `rate_limit` sur l'authentification
- `reset_session` à la connexion et à la déconnexion, et une expiration de session
- Une policy par use case, testée
- 100 % de couverture lignes et branches, `# :nocov:` interdit

---

## 6. Les trois risques

| Risque | Parade |
|---|---|
| **Le Lot 0 déborde.** Il est séquentiel et tout en dépend. S'il n'est pas fini fin du jour 1, le parallélisme n'a plus la place de s'exprimer | 0c démarre en parallèle de 0a — le design ne dépend pas du schéma |
| **Le Lot D est déséquilibré.** Il porte un rôle entier là où les autres portent un parcours, et il n'y a pas de repli puisque de vrais enseignants sont attendus | Le démarrer en premier parmi les lots parallèles, lui affecter le plus d'agents. Repli à décider **au jour 2** : assignation par l'équipe, enseignant en lecture seule |
| **Les features qui n'ont jamais tourné.** On croit reprendre, on construit | Signalées ⚠️ dans chaque lot. Un lot « à construire » ne s'estime pas comme une reprise |

---

## 7. Le point de vigilance numéro un

Il a été convenu de « voir avec la couverture des tests au moment venu ». C'est légitime, et c'est aussi le moment exact où ce chantier peut échouer.

> Si la règle des 100 % est assouplie le troisième soir sous la pression de la date, on aura reconstruit en trois jours **exactement l'application qu'on remplace** — celle dont la suite de tests ne se chargeait plus, et dont personne ne s'en était aperçu pendant des mois.
>
> **Assouplir est permis. Le faire en silence ne l'est pas.** Si assouplissement il y a, que ce soit une décision datée dans un ADR, pas un `--no-verify` à 23 h.

---

## 8. Quoi faire en reprenant

Rien n'est lancé. Dans l'ordre :

1. **Créer le nouveau projet** et y copier `docs/` v2 au premier commit — c'est ce qui fait que le processus naît *avec* le projet au lieu d'arriver après. C'était le défaut de v1.
2. **Activer les garde-fous avant la première ligne de code métier** : `bin/setup` qui pose `core.hooksPath`, le pre-commit, la CI, SimpleCov à 100 %. Dans l'ancienne app, `core.hooksPath` n'avait jamais été positionné — aucun hook ne s'est donc jamais exécuté, et c'est la cause racine de tout le reste.
3. **Lancer le Lot 0** : 0a et 0c en parallèle.
4. **Écrire les ADR qui manquent** avant leurs lots : le contrat de retour des use cases (l'ancien mélangeait `OpenStruct` réel et `Shared::Result` documenté mais inexistant), et le second facteur pour les comptes `team` exigé par l'ADR-0025.

### Un reste non tranché

Les **8 chantiers de bugs** ouverts sur l'application actuelle, qui ne sera pas mise en ligne. Ils ne servent plus tels quels — mais leurs memos décrivent des pièges que le nouveau projet peut reproduire. **À relire, pas à corriger.**

---

## 9. Où est quoi

```
docs/chantiers/refonte-application/
├── etat-et-plan.md          ce document
├── memo.md                  cadrage et justification de la réécriture
├── plan.md                  le graphe de lots, détaillé lot par lot
├── securite.md              18 constats, classés, avec la règle associée
├── journal.md               ce qui a été fait, décidé, et laissé ouvert
└── inventaire/
    ├── assessment.md            550 l. · exercices, sessions, badges, remédiation
    ├── catalog.md               458 l. · cours, fiches, taxonomie, imports
    ├── classroom-school.md      579 l. · classes, adhésions, assignations, écoles
    ├── identity-communication.md 878 l. · inscriptions, connexion, autorisation, annonces
    ├── transverse.md           1463 l. · routes, schéma, jobs, i18n, code mort
    └── ui-design-system.md     1654 l. · tokens, composants, écrans, Stimulus
```

Le processus lui-même est dans [`docs/README.md`](../../README.md), qui fait autorité.
