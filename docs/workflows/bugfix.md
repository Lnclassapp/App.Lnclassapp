# Cycle Bugfix

> Détail de la colonne **Bugfix** de la [table de routage](README.md#table-de-routage). Le processus maître en 5 phases est dans [`README.md`](README.md).

Branche : `fix/<slug>` · Commits : `fix(<contexte>): …` · Chantier : `docs/chantiers/<slug>/`

**La règle qui domine tout le cycle** : le test de reproduction s'écrit **avant** le correctif et **doit échouer**. Patcher sans test de reproduction est un [interdit](README.md#les-interdits), pas une préférence.

---

## Quand utiliser ce cycle

| Utilise **bugfix** si… | C'est un **autre** cycle si… |
|---|---|
| Un comportement documenté (PRD, ADR, UDR) ne se produit pas | Le comportement n'a jamais été spécifié → c'est une [feature](feature.md) |
| Tu peux écrire « étant donné … quand … alors on obtient X au lieu de Y » | Le résultat est correct mais lent → [optimisation](optimisation.md) |
| Le correctif peut être démontré par un test qui passe du rouge au vert | Rien n'est cassé, le code est juste pénible à lire → [refactoring](refactoring.md) |
| La production tient, l'utilisateur a un contournement | La production est cassée **maintenant**, sans contournement → [hotfix](hotfix.md) |

**Test du bug déguisé** : si le correctif exige d'ajouter une colonne, un port ou une règle métier qui n'existait nulle part, ce n'est pas un bug — c'est une spec manquante. Ferme et rouvre en feature.

---

## Les 5 phases pour ce cycle

### 1. Cadrer — `memo.md`, allégé mais reproductible

Le memo tient en une page, mais trois blocs sont **non négociables** :

| Bloc | Contenu attendu |
|---|---|
| **Symptôme** | Ce que l'utilisateur voit, littéralement. Pas d'interprétation |
| **Reproduction** | Les étapes exactes, l'acteur, les données. Si tu ne sais pas reproduire, tu ne sais pas corriger |
| **Portée** | Depuis quand, combien d'acteurs touchés, données corrompues à réparer ou non |

`Hors périmètre` sert ici à interdire le « pendant que j'y suis » : tout ce qu'on remarque à côté part dans `journal.md` → chantier de suivi.

### 2. Décider — souvent rien à écrire

- **Pas de PRD.** Le comportement attendu existe déjà : cite la source (PRD antérieur, ADR, UDR, test existant).
- **ADR seulement si la cause est architecturale** : un port mal découpé, une règle métier logée dans un contrôleur, un contrat de retour ambigu. Dans ce cas l'ADR est écrit **avant** le correctif.
- **UDR** uniquement si la correction change ce que l'utilisateur voit (état d'erreur, libellé, parcours). Un bug purement backend n'en produit pas.

**Ce qui se joue vraiment ici** : le rapport de *root cause*, produit par l'explorer (voir équipage). Sans lui, la phase 2 est vide et le cycle échoue silencieusement.

### 3. Planifier — souvent un seul lot

- Un lot, un correctif, un test. Format de lot inchangé ([conventions §6](../guide/conventions.md#6-format-dun-lot)).
- **On peut sauter `plan.md`** si et seulement si : un seul lot, aucun fichier partagé touché, aucune migration. Les portes de sortie migrent alors dans `memo.md`.
- Deux lots ou plus dès qu'il y a une migration de réparation de données : Lot 0 = correctif de code, Lot A = tâche de réparation des données déjà corrompues.

### 4. Exécuter — rouge d'abord, toujours

Ordre strict, sans exception :

1. **Écrire le test de reproduction** au niveau le plus bas qui reproduit le bug (domaine > infrastructure > contrôleur > intégration).
2. **Le lancer. Il doit échouer**, et échouer *pour la bonne raison* — vérifier le message, pas seulement le rouge.
3. Corriger, **à la cause**, dans la couche où vit la cause.
4. Relancer : le test passe au vert.
5. Relancer la suite du contexte borné : rien d'autre n'a bougé.

Un test qui passe du premier coup ne reproduit pas le bug : il ne prouve rien, il est à jeter et à réécrire.

Le correctif appartient à la couche de la **cause**, pas à celle du symptôme : un mauvais rendu de vue causé par une règle métier se corrige dans `app/domain/`, pas dans le `.erb`.

### 5. Prouver — le rouge devient vert

- Le challenger **rejoue les étapes de reproduction du memo dans l'application**, pas seulement la suite de tests.
- Il vérifie aussi le **cas symétrique** : la correction n'a pas cassé le chemin nominal voisin.
- Portes CI habituelles ([conventions §7](../guide/conventions.md#7-ce-qui-bloque)).
- Commit référençant le chantier en pied de message ([conventions §4](../guide/conventions.md#4-messages-de-commit)) :

```
fix(identity): reject login when contact is blank

Chantier: docs/chantiers/login-contact-vide
```

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Explorer « root cause »** | **OUI, sans exception** | Remonte du symptôme à la cause. Rend un rapport : chaîne d'appels, fichier et ligne fautifs, pourquoi le test existant ne l'a pas attrapé |
| **Exécutant** | oui | Écrit le test rouge, puis le correctif. Jamais l'inverse |
| **Challenger** | oui | Rejoue la reproduction dans l'app + vérifie le chemin nominal voisin |
| **Griller** | non | Un memo de bug n'a pas besoin d'être grillé, il a besoin d'être reproduit |

Le rapport de l'explorer doit répondre à : **pourquoi aucun test existant n'a détecté ça ?** La réponse dicte où placer le test de reproduction.

---

## Portes de sortie — à copier dans `plan.md` (ou `memo.md` si lot unique)

```markdown
- [ ] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [ ] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [ ] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
```

---

## Exemple réel — `assessment` : tentative comptée deux fois

- **Symptôme** : un élève relance un exercice interrompu, son score initial est écrasé ; la lacune détectée disparaît du suivi enseignant.
- **Reproduction** : élève de 3ème A, exercice démarré, onglet fermé, reprise depuis le fil → 2 `question_attempt` pour la même question.
- **Root cause** (explorer) : la garde d'unicité vivait dans le contrôleur, pas dans `UseCases::Assessment::SubmitQuestionAttempt` ; l'entrée par la reprise de session ne passait pas par ce contrôleur. Trou de test : aucun test domaine ne couvrait la double soumission.
- **Test rouge** : `test/domain/use_cases/assessment/submit_question_attempt_test.rb` — deux soumissions de la même question dans une session → doit lever, échoue d'abord.
- **Correctif** : la garde remonte dans le use case. Le contrôleur ne fait plus que traduire.
- **Symétrique vérifié** : `CompleteExerciseSession` et la détection de lacunes ([ADR-0018](../decisions/adr/0018-remediation-just-in-time-et-historique-lacunes.md)) donnent toujours le même résultat.

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **Traiter le symptôme** | Le bug revient ailleurs deux semaines plus tard | Le rapport root cause est une porte, pas une formalité. Pas de rapport = pas de correctif |
| **Test écrit après** | « Je corrige d'abord, je teste ensuite » | Interdit explicite. Le test doit avoir été rouge |
| **Test vert du premier coup** | On se félicite | Il ne reproduit pas le bug. Le réécrire plus bas dans la pile |
| **Correctif dans la vue** | Un `if` défensif dans le `.erb` | Le correctif va dans la couche de la cause. Un garde-fou d'affichage n'est pas un correctif |
| **Bug élargi en cours de route** | Le diff touche 14 fichiers | Un bug, un correctif. Le reste part en chantier de suivi via `journal.md` |
| **Données corrompues oubliées** | Le code est corrigé, la base reste fausse | Décider explicitement : tâche de réparation, ou dette assumée au journal |
| **Multi-appartenance ignorée** | Corrigé pour un élève à une classe, cassé pour un élève multi-classes | Rejouer la reproduction sur un élève rattaché à plusieurs classes |
