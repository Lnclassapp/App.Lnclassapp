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
| [`boucle-pedagogique`](boucle-pedagogique/memo.md) | en recette | V1 : équipe → contenu → enseignant → élève → résultat, en production depuis le 2026-09-27 |
| [`profil-utilisateur`](profil-utilisateur/memo.md) | livré | « Mon profil » pour tous : nom, numéro et PIN modifiables sous PIN actuel (ADR-0055, UDR-0041) |
| [`generer-classes`](generer-classes/memo.md) | livré | Générer après coup les classes des établissements qui n'en ont aucune de l'année (ADR-0056, UDR-0043) |
| [`classes-par-niveau`](classes-par-niveau/memo.md) | livré | Ajuster les classes d'un établissement niveau par niveau : ajouter la suivante, retirer la dernière si elle n'a jamais servi (ADR-0059, UDR-0046) |
| [`finitions-generation-menu`](finitions-generation-menu/memo.md) | livré | « Déjà en cours » en toast d'information vers le rapport, badge « Génération en cours », ⋮ collé à droite des tableaux au téléphone (amendements UDR-0042, UDR-0043) |
| [`afficher-pin`](afficher-pin/memo.md) | livré | Bouton œil dans les 13 champs de PIN (connexion, inscriptions, profil, PIN oublié), masqué par défaut et avant l'envoi (UDR-0051, amendement UDR-0005) |

## Cycle de vie

Un chantier livré reste en place. Son `memo.md` porte `Statut: livré` et son `journal.md` est clos. On ne supprime pas un chantier : c'est la mémoire du projet.

Un chantier abandonné passe en `Statut: abandonné` avec la raison dans le journal. C'est une information, pas un échec à cacher.
