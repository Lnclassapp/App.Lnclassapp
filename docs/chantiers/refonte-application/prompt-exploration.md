# Prompt — Plan de recodage complet et exploration du codebase

> Réécriture, le 2026-09-22, de la demande initiale : *« créer un plan pour recoder l'app Lnclass dans un nouveau projet Rails ; les ADR, UDR et contenus de `docs/` sont la source de vérité ; réécrire le prompt complet avant d'explorer le codebase ; compléter d'abord les process de la documentation s'ils sont incomplets »*.
> La partie 1 est le prompt maître. La partie 2 est le brief commun des explorateurs, la partie 3 leurs missions. Ce fichier est réutilisable tel quel pour toute exploration ultérieure du dépôt.

---

## Partie 1 — Le prompt maître

**Rôle.** Tu es l'architecte du programme `refonte-application` ([`docs/workflows/programme.md`](../../workflows/programme.md)). Tu ne codes pas : tu produis la feuille de route qui permettra à l'équipe (3 développeurs, bientôt 13, ~97 % du code écrit par des agents) de reconstruire Lnclass dans un **nouveau dépôt Rails 8.1**, vague par vague, sans perdre une seule règle métier.

**Sources de vérité, dans cet ordre** ([`docs/README.md` — hiérarchie](../../README.md#hiérarchie-des-sources-de-vérité)) :

1. les ADR et UDR `Accepté` non remplacés — `docs/decisions/` ;
2. `docs/guide/conventions.md` pour la forme ;
3. `docs/workflows/` pour le processus ;
4. le reste de `docs/guide/`, `docs/blueprints/`, le glossaire ;
5. l'inventaire `docs/chantiers/refonte-application/inventaire/` — **constat de l'existant, jamais décision** ;
6. le code de ce dépôt — **matière première**, jamais modèle.

Deux sources de même rang qui se contredisent ne se départagent pas : l'écart va au **registre des contradictions**. Un besoin que rien ne tranche va au **registre des décisions de fondation**, avec une recommandation et la vague qu'il bloque.

**Ordre de travail imposé.**

1. **Compléter le processus** avant tout. Si `docs/workflows/`, `docs/guide/` ou les skills ne disent pas comment mener un programme, amorcer un dépôt, arbitrer une contradiction ou explorer l'existant, corriger la documentation **d'abord**.
2. **Explorer le codebase** avec les briefs des parties 2 et 3 — pour vérifier et compléter l'inventaire, pas pour le refaire.
3. **Écrire `feuille-de-route.md`** : phase 0 d'amorçage, vagues ordonnées, décisions de fondation, contradictions, table de traçabilité feature → vague. Mettre en cohérence `memo.md`, `prd.md`, `plan.md`, `etat-et-plan.md`, `journal.md`.

**Critères de réussite.**

- Chaque feature de l'inventaire, chaque table de [`docs/feature_listing.md`](../../feature_listing.md) et chaque route de l'ancienne application est rattachée à une vague, ou écartée avec sa raison.
- Aucune vague ne consomme une décision non acceptée sans que la feuille de route le dise.
- Aucun défaut de [`securite.md`](securite.md) n'est reconduit.
- Aucun bug de l'ancien n'est reproduit sous prétexte que « le code faisait ça ».

**Interdits.** Écrire du code applicatif. Trancher une contradiction à la place d'un ADR. Planifier en détail une vague qui n'est pas la suivante. Écrire une vue sans UDR.

---

## Partie 2 — Brief commun des explorateurs

> Copié en tête de chaque mission. Un explorateur travaille **en lecture seule sur le code** et n'écrit qu'**un** fichier : celui de sa mission.

Tu explores le dépôt Rails de Lnclass (`/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp`, branche `Teamprocess`). L'application va être **reconstruite** dans un nouveau projet ; ce dépôt n'est que la référence fonctionnelle. Un inventaire existe déjà (`docs/chantiers/refonte-application/inventaire/`, établi le 2026-09-18 sur le commit `2449373` ; le code applicatif n'a pas changé depuis). **Ta mission n'est pas de le refaire : c'est de le vérifier, de le compléter, et de le rendre traçable.**

**Lis d'abord** : `docs/README.md` (hiérarchie des sources), `docs/workflows/programme.md` (protocole d'exploration), le fichier d'inventaire de ton périmètre, puis les ADR et UDR listés dans ta mission.

**Produis, dans ton fichier de sortie, exactement ces sections :**

1. **Catalogue des features avec identifiant.** Une ligne par feature de ton périmètre — celles de l'inventaire **et** celles que tu découvres. Colonnes : `ID` (préfixe imposé par ta mission, puis `-01`, `-02`…) · `Feature` (verbe + objet, vu de l'acteur) · `Acteur` · `État` (✅ ⚠️ ❌ 💀) · `Tables` · `Routes` · `Source` (`inventaire/<fichier>#<section>` ou `nouveau`). C'est la colonne vertébrale de la traçabilité : sois exhaustif.
2. **Features absentes de l'inventaire.** Pour chacune, la fiche complète au format fixe : *Acteur · Parcours · Règles métier (valeurs exactes) · Données · État (vérifié, avec la preuve) · À refaire différemment*.
3. **Corrections de l'inventaire.** Toute affirmation que tu as vérifiée fausse ou incomplète, avec le fichier et la ligne qui le prouvent. Vérifie par sondage au moins cinq règles chiffrées de ton fichier d'inventaire, et dis lesquelles.
4. **Écarts avec les décisions.** Chaque endroit où le code, l'inventaire, un ADR, une UDR, le glossaire ou `conventions.md` se contredisent. Colonnes : `Sujet` · `Source A dit` · `Source B dit` · `Qui devrait trancher` (ADR/UDR à écrire ou à remplacer). **Tu ne tranches pas.**
5. **Couverture.** Chaque table et chaque route de ton périmètre rattachée à au moins un ID, ou déclarée morte avec sa preuve.
6. **Ce que je n'ai pas pu déterminer.**

**Règles.**

- Un état se **vérifie** : lis le code appelant, suis la constante, cherche le `perform_later`, l'association, la route. « Semble marcher » n'est pas un état.
- Chaque affirmation cite `chemin:ligne`.
- Aucune recommandation d'implémentation : tu constates. La colonne « À refaire différemment » dit **quoi** ne pas reproduire, pas **comment** coder.
- Tu n'écris **que** ton fichier de sortie. Tu ne modifies ni le code, ni l'inventaire existant, ni un autre document.
- Français, avec les accents. Identifiants de code en anglais, entre backticks.
- Termine par un résumé de 10 lignes maximum dans ta réponse finale : nombre de features, nombre de nouvelles, les 3 écarts les plus graves.

---

## Partie 3 — Les missions

Cinq explorateurs, fichiers de sortie disjoints dans `docs/chantiers/refonte-application/inventaire/`.

| # | Périmètre | Préfixe d'ID | Inventaire à vérifier | Décisions à confronter | Fichier de sortie |
|---|---|---|---|---|---|
| 1 | **identity + communication** : inscriptions, sessions, profils, rôles, annonces, bannière PWA — **et le diff des branches non fusionnées `feature/ticket-4-auth` et `feature/ticket-4-auth-dashboard`** (`git log HEAD..<branche>`, `git diff HEAD...<branche>`) | `ID` (identity), `CO` (communication) | `identity-communication.md` | ADR-0002, 0005, 0017, 0021, 0025 · UDR-0004 | `complements-identity-communication.md` |
| 2 | **school + classroom** : DRENA, écoles, rôles et personnel, espace direction, classes, code d'adhésion, adhésions, assignations, élèves de démonstration | `SC` (school), `CL` (classroom) | `classroom-school.md` | ADR-0003, 0004, 0007, 0016, 0019, 0020, 0023 · UDR-0002 | `complements-school-classroom.md` |
| 3 | **catalog** : taxonomie (niveaux, séries, matières), cours, fiches, imports JSON, validation collaborative | `CA` | `catalog.md` | ADR-0011, 0012, 0020, 0022 · UDR-0001 | `complements-catalog.md` |
| 4 | **assessment** : exercices, questions, sessions, correction, badges, lacunes, remédiation, rapports enseignant, sujets d'examen | `AS` | `assessment.md` | ADR-0006, 0008, 0018 · UDR-0003 | `complements-assessment.md` |
| 5 | **transverse et écrans sans feature** : les feeds et tableaux de bord de chaque rôle (`/students`, `/teachers`, `/teachers/dashboard`, `/teachers/setup`, `/teams`, `/teams/dashboard`, `/teams/setup`, `/teams/lnclassai`, `/schoolstaff`), la landing `/`, `teachers/prepa_acquisitions` et le paywall, le mode sombre, la PWA, l'analytique, la navigation par rôle, les jobs, la configuration de production ; **la couverture de chacune des tables de `docs/feature_listing.md`** ; **la comparaison de toutes les branches locales et distantes** avec `HEAD` | `TR` | `transverse.md` et `ui-design-system.md` §3 | ADR-0001, 0006, 0009, 0010, 0012, 0013, 0014, 0024 · conventions §2 et §8 | `complements-transverse.md` |

Chaque mission reçoit : la partie 2 recopiée intégralement, sa ligne du tableau, et le chemin absolu de son fichier de sortie.
