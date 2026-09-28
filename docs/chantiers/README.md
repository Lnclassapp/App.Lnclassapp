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
| [`boucle-pedagogique`](boucle-pedagogique/memo.md) | livré | V1 : équipe → contenu → enseignant → élève → résultat, en production depuis le 2026-09-27, clos le 2026-09-28 ; recette `Staging` par un rôle distinct en cours |
| [`profil-utilisateur`](profil-utilisateur/memo.md) | livré | « Mon profil » pour tous : nom, numéro et PIN modifiables sous PIN actuel (ADR-0055, UDR-0041) |
| [`generer-classes`](generer-classes/memo.md) | livré | Générer après coup les classes des établissements qui n'en ont aucune de l'année (ADR-0056, UDR-0043) |
| [`photo-de-profil`](photo-de-profil/memo.md) | en production, durcissement livré (#65, #75) ; memo encore « en cours », à clore | Photo de profil pour tous : recadrée par le navigateur, vérifiée par le serveur, visible de soi, de ses enseignants et de l'équipe (ADR-0060, UDR-0047) |
| [`classes-par-niveau`](classes-par-niveau/memo.md) | livré | Ajuster les classes d'un établissement niveau par niveau : ajouter la suivante, retirer la dernière si elle n'a jamais servi (ADR-0059, UDR-0046) |
| [`finitions-generation-menu`](finitions-generation-menu/memo.md) | livré | « Déjà en cours » en toast d'information vers le rapport, badge « Génération en cours », ⋮ collé à droite des tableaux au téléphone (amendements UDR-0042, UDR-0043) |
| [`bareme-classes`](bareme-classes/memo.md) | livré | Barème des classes générées en base, modifiable par l'équipe à l'écran ; menu « Classes » des établissements (ADR-0058, UDR-0045) |
| [`afficher-pin`](afficher-pin/memo.md) | livré | Bouton œil dans les 13 champs de PIN (connexion, inscriptions, profil, PIN oublié), masqué par défaut et avant l'envoi (UDR-0051, amendement UDR-0005) |
| [`actions-en-menu`](actions-en-menu/memo.md) | livré | Actions de modification et de suppression des écrans de l'équipe dans un menu ⋮ (UDR-0042) |
| [`cycles-en-radio`](cycles-en-radio/memo.md) | livré | Cycle d'un niveau et d'un établissement en boutons radio, 1er cycle par défaut (UDR-0005 ter) |
| [`code-etablissement`](code-etablissement/memo.md) | livré | L'enseignant s'inscrit avec le code secret de son établissement (ADR-0057, UDR-0044) |
| [`pilotage-equipe`](pilotage-equipe/memo.md) | livré | V4 : page Pilotage de l'équipe, indicateurs lus en direct, recherche d'un élève ou d'un enseignant (ADR-0062, UDR-0049) |
| [`croissance-parrainage`](croissance-parrainage/memo.md) | livré | Parrainage entre enseignants, démarrage à froid par le code national, page Croissance de l'équipe (ADR-0063, UDR-0050) |

## Backlog

Travail mis de côté par le porteur. Les vagues V2 à V6 y sont placées le 2026-09-28 : aucune n'est ouverte avant une décision datée du porteur ; leur périmètre, leurs chantiers et leurs questions sont au [§5 de la feuille de route](refonte-application/feuille-de-route.md#5-les-vagues). Pour un chantier, le memo dit où reprendre.

| Chantier | En une phrase |
|---|---|
| **V2 — Organisation scolaire et espace direction** | 29 features : `espace-direction`, puis `annuaire-equipe`. Questions Q1 à Q3 ouvertes ([feuille de route §5](refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) |
| **V3 — Suivi pédagogique enseignant** | 11 features : `rapports-de-classe`, `vie-de-la-classe` (dont CL-02), `multi-etablissements-enseignant` ; `multi-classes-eleve` si Q5 le confirme |
| **V4 — Contenu à l'échelle et back-office** | 9 features : `catalogue-complet`, `installation-pwa`, `sous-roles-equipe` ; Q9 et Q10 ouvertes |
| **V5 — Remédiation** | 2 features : AS-16 (remédiation ciblée), AS-17 (suivi par l'enseignant) |
| **V6 — Communication** | 10 features : `annonces`, puis `canal-whatsapp` ([PR #70](https://github.com/Lnclassapp/App.Lnclassapp/pull/70)) ; Q11 à Q14 ouvertes |
| [`verification-whatsapp`](verification-whatsapp/memo.md) | Prouver le numéro par un code WhatsApp (hook n8n) à l'inscription sans code ; grill interrompu à la question 2. Rattaché à la V4 s'il reprend ([feuille de route §5](refonte-application/feuille-de-route.md#chantiers-hors-plan)) |

## Cycle de vie

Un chantier livré reste en place. Son `memo.md` porte `Statut: livré` et son `journal.md` est clos. On ne supprime pas un chantier : c'est la mémoire du projet.

Un chantier abandonné passe en `Statut: abandonné` avec la raison dans le journal. C'est une information, pas un échec à cacher.
