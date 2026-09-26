# Cycle Hotfix

> Détail de la colonne **Hotfix** de la [table de routage](README.md#table-de-routage). Le processus maître en 5 phases est dans [`README.md`](README.md).

Branche : `hotfix/<slug>` · Commits : `fix(<contexte>): …` · Chantier : `docs/chantiers/<slug>/`

**Ce cycle est un chemin court assumé, pas une dispense.** On coupe le plan, l'ADR et l'UDR ; on ne coupe **jamais** le chantier de suivi qui les rattrape. Un hotfix sans chantier de suivi ouvert est un hotfix non terminé.

---

## Quand utiliser ce cycle

Les trois conditions doivent être vraies **en même temps** :

1. La production est cassée **maintenant** — ou une donnée se corrompt à chaque minute qui passe.
2. Il n'existe **aucun contournement** acceptable pour l'utilisateur.
3. Le correctif est **petit et localisé** : 1 à 2 fichiers, aucune migration, aucun nouveau contrat.

| C'est un **autre** cycle si… | |
|---|---|
| Un contournement existe (même pénible) → [bugfix](bugfix.md) | La journée peut attendre |
| Le correctif exige une migration, un port ou une nouvelle règle → [bugfix](bugfix.md) ou [feature](feature.md) | Le chemin court ne tient plus |
| C'est lent mais correct → [optimisation](optimisation.md) | Lent n'est pas cassé |
| C'est moche mais ça marche → [refactoring](refactoring.md) | Jamais en urgence |

Si tu hésites, ce n'est pas un hotfix. Le doute lui-même est le signal : un vrai hotfix ne se discute pas, il se constate.

---

## Ce qu'on accepte de dégrader, et comment on rembourse

| On saute | Risque accepté | Remboursement — dans le chantier de suivi |
|---|---|---|
| Le grill du memo | Un cas limite non vu peut rester cassé | Memo complet réécrit et grillé |
| Le PRD | Le comportement attendu n'est écrit nulle part | PRD rétroactif, ou référence au PRD existant |
| L'ADR | Une décision structurante prise sans trace | **ADR écrit sous 5 jours ouvrés** si le correctif a touché un contrat |
| L'UDR | Une vue modifiée hors design system | **UDR écrite sous 5 jours ouvrés** si le correctif a introduit un nouveau motif d'interface |
| `plan.md` | Aucun découpage — assumé, le correctif est minimal | Sans objet |
| Les tests exhaustifs | Couverture partielle | **Test de reproduction ajouté** + tests des cas voisins |
| Le challenger empirique | Vérification faite par l'auteur seul | Rejeu par un rôle distinct |

Ce qu'on **ne dégrade jamais**, même en urgence :

- Pureté du domaine, rubocop, en-tête HITL — ce sont des blocages pre-commit ([conventions §7](../guide/conventions.md#7-ce-qui-bloque)), pas des consignes.
- La branche : `hotfix/<slug>`, créée depuis `main`, PR vers `main`. **Jamais de commit direct sur `main`** ([conventions §3](../guide/conventions.md#3-branches)).
- Le report : une PR `main → Develop` **le jour même**. Sans elle, le prochain passage `Staging → main` efface le correctif.
- Le dossier `docs/chantiers/<slug>/`, même réduit à un memo de 3 lignes. Un chantier sans dossier n'existe pas.

---

## Les 5 phases pour ce cycle

### 1. Cadrer — `memo.md`, 3 lignes, écrit **avant** de coder

```markdown
| Type de cycle | hotfix |
| Statut | en cours |
| Branche | `hotfix/<slug>` |

**Constat** : depuis <heure>, <acteur> obtient <symptôme> sur <parcours>.
**Impact** : <combien d'utilisateurs, quelles données>. Aucun contournement.
**Hypothèse de cause** : <fichier / commit suspect>.
```

Trois lignes, pas zéro. Sans le constat écrit, personne ne saura dans deux mois ce qui s'est passé.

### 2. Décider — rien maintenant

Aucun ADR, aucune UDR, aucun PRD pendant l'incident. **Tout ce qui aurait mérité une décision est noté sur-le-champ dans `journal.md`**, section `Dette laissée derrière`, avec le chantier de suivi en regard. Noté pendant, pas reconstitué après.

### 3. Planifier — pas de plan

Pas de `plan.md`. Périmètre annoncé oralement/en clair avant de commencer : **quels fichiers, et rien d'autre**. Si le diff déborde ce périmètre, on s'arrête et on requalifie en bugfix.

### 4. Exécuter — correctif minimal

- **Le plus petit diff qui arrête l'hémorragie.** Pas de nettoyage, pas de renommage, pas d'amélioration adjacente.
- Le test de reproduction est **fortement recommandé maintenant**, obligatoire au plus tard dans le chantier de suivi. Si l'incident permet de l'écrire d'abord, on l'écrit d'abord.
- Aucune migration. Si une migration semble nécessaire, ce n'est plus un hotfix.
- En-tête HITL maintenu sur les fichiers touchés.

### 5. Prouver — vérification manuelle + **chantier de suivi obligatoire**

1. Vérification manuelle en production (ou sur l'environnement équivalent) : le parcours cassé fonctionne, le parcours voisin aussi.
2. Suite de tests du contexte borné lancée : rien d'autre n'a bougé.
3. PR `hotfix/<slug>` → `main`, référençant le chantier. **Le hotfix est le seul cycle autorisé à viser `main`** ([conventions §3](../guide/conventions.md#3-branches)) : il part de la production et y retourne.
4. 🔁 **Rétroporter dans `Develop` — non négociable.**

   ```bash
   git checkout Develop && git merge --no-ff hotfix/<slug>
   ```

   Sans ce rétroportage, le correctif **sera écrasé** à la prochaine livraison `Staging → main`, puisque ni `Staging` ni `Develop` ne le contiennent. Le bug réapparaît en production sans que personne ne comprenne pourquoi, et il est alors bien plus difficile à diagnostiquer — on cherche une régression là où il n'y a qu'un merge.

   Si `Staging` est en cours de recette au moment du hotfix, le rétroporter aussi.
5. **Ouvrir immédiatement le chantier de suivi** : `cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>-suivi`, type `bugfix`, et y reporter la table de remboursement ci-dessus.
6. `journal.md` du hotfix clos, avec le lien vers le chantier de suivi.

**Le hotfix n'est pas livré tant que le rétroportage est fait et que le chantier de suivi est ouvert et daté.** Un hotfix mergé sans suivi crée une dette invisible — le pire type. Un hotfix non rétroporté crée une régression programmée, ce qui est pire encore.

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Constatant** | oui | Écrit les 3 lignes du memo avant qu'on touche au code. C'est la seule trace de l'incident |
| **Exécutant** | oui | Diff minimal, périmètre annoncé |
| **Vérificateur** | oui | Rejoue le parcours cassé **et** un parcours voisin, en vrai, pas en test |
| **Explorer root cause** | **reporté, pas supprimé** | Se fait dans le chantier de suivi, avec le temps nécessaire |
| **Challenger empirique** | reporté | Dans le chantier de suivi |

L'équipage est volontairement réduit : la coordination coûte du temps qu'on n'a pas. En contrepartie, **tout ce qui est réduit est explicitement reporté**, jamais annulé.

---

## Portes de sortie — à copier dans `memo.md`

```markdown
## Portes de sortie (hotfix)

- [ ] Les 3 conditions du hotfix sont vraies (prod cassée · aucun contournement · correctif localisé)
- [ ] `memo.md` : constat, impact, hypothèse de cause — écrit **avant** le code
- [ ] Branche `hotfix/<slug>` — aucun commit direct sur `main`
- [ ] Diff minimal, dans le périmètre annoncé, aucune migration
- [ ] En-tête HITL présent · pureté domaine · rubocop : au vert
- [ ] Parcours cassé vérifié **à la main** en conditions réelles
- [ ] Parcours voisin vérifié : rien d'autre n'a bougé
- [ ] Suite de tests du contexte borné lancée
- [ ] PR `hotfix/<slug>` → `main`, référençant le chantier
- [ ] **Chantier de suivi ouvert et daté** : `docs/chantiers/<slug>-suivi/`
- [ ] **Rétroporté dans `Develop`** (et dans `Staging` s'il est en recette) — sinon le correctif sera écrasé à la prochaine livraison
- [ ] Table de remboursement reportée dans le suivi (test de repro · ADR · UDR · challenger)
- [ ] `journal.md` du hotfix clos, avec lien vers le chantier de suivi
```

---

## Exemple réel — `identity` : connexion refusée à tous les enseignants

- **Constat** (memo, 3 lignes) : depuis le déploiement de 14 h, tout enseignant dont le contact contient un espace obtient « identifiants invalides ». ~40 % des enseignants d'un établissement. Aucun contournement. Suspect : la normalisation du contact dans `UseCases::Identity::AuthenticateUser` ([ADR-0002](../decisions/adr/0002-authentification-native-contact-telephonique-sans-devise.md)).
- **Décision** : aucune. Noté au journal : « la normalisation du contact est dupliquée entre l'inscription et l'authentification → ADR à écrire ».
- **Correctif** : normalisation appliquée à la saisie avant comparaison. 1 fichier, 3 lignes.
- **Vérification** : connexion rejouée avec un contact espacé **et** avec un contact déjà normalisé (parcours voisin).
- **Chantier de suivi** `docs/chantiers/normalisation-contact/`, type bugfix, ouvert le jour même : test de reproduction, root cause complète (pourquoi aucun test ne couvrait l'espace), ADR sur le point unique de normalisation, tests des cas voisins (`register_teacher`, `register_student`).

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **Le faux hotfix** | On invoque l'urgence pour sauter le processus | Les 3 conditions, toutes vraies. Un contournement existe ⇒ bugfix |
| **Le hotfix qui gonfle** | Le diff passe de 3 à 30 lignes, puis touche une migration | Périmètre annoncé avant. Dépassement ⇒ on arrête et on requalifie |
| **Le suivi jamais ouvert** | La PR est mergée, on passe à autre chose | C'est une porte de sortie. Le hotfix n'est pas livré sans |
| **La dette reconstituée après** | Personne ne se souvient de ce qu'on a sacrifié | Noter dans `journal.md` **pendant** l'incident, pas le lendemain |
| **Le correctif au symptôme** | Le bug revient sous une autre forme | Assumé sur le moment — la root cause est **obligatoire dans le suivi** |
| **Le commit sur `main`** | « C'était urgent » | Jamais. La branche + PR coûtent 30 secondes |
| **Le nettoyage au passage** | Un renommage glissé dans le hotfix | Chaque ligne non nécessaire est un risque supplémentaire en production |
