# Cycle Refactoring

> Détail de la colonne **Refactoring** de la [table de routage](README.md#table-de-routage). Le processus maître en 5 phases est dans [`README.md`](README.md).

Branche : `refactor/<slug>` · Commits : `refactor(<contexte>): …` · Chantier : `docs/chantiers/<slug>/`

**La règle qui domine tout le cycle** : le comportement observable est **identique** avant et après. Refactoring + changement de comportement dans le même lot = [interdit](README.md#les-interdits).

---

## Quand utiliser ce cycle

| Utilise **refactoring** si… | C'est un **autre** cycle si… |
|---|---|
| Tu peux écrire : « après, l'application fait exactement la même chose » | Un acteur pourra faire quelque chose de nouveau → [feature](feature.md) |
| Le motif est structurel : couplage, namespace, duplication, couche violée | Le comportement actuel est faux → [bugfix](bugfix.md) d'abord, refactoring ensuite |
| Le périmètre des fichiers est listable **à l'avance** | Le but est de réduire un temps ou un nombre de requêtes → [optimisation](optimisation.md) |
| Aucune migration destructive de données n'est nécessaire | La prod brûle → [hotfix](hotfix.md) |

**Test de la feature déguisée** — si au moins une réponse est « oui », ce n'est plus un refactoring :

- Un écran change, même légèrement ? (alors il faut une UDR → feature)
- Un message d'erreur, un libellé, un tri, un arrondi change ?
- Une permission devient plus ou moins permissive ?
- Un champ apparaît ou disparaît d'une réponse ?

Deux chantiers valides, jamais un seul : `refactor/<slug>` d'abord (iso-comportement, mergé), puis `feature/<slug>` qui change le comportement sur une base propre.

---

## Les 5 phases pour ce cycle

### 1. Cadrer — `memo.md` : motif + périmètre gelé

| Bloc | Contenu attendu |
|---|---|
| **Motif** | Quel coût concret paie-t-on aujourd'hui : bug récurrent, lot impossible à paralléliser, règle dupliquée en 3 endroits, `app/domain/` qui frôle l'ORM |
| **Périmètre gelé** | La **liste exhaustive des fichiers** touchés, écrite avant de commencer. C'est le contrat |
| **Hors périmètre** | Explicitement : « aucun changement de comportement observable » |

Un refactoring sans périmètre écrit à l'avance dérive systématiquement. Tout fichier non listé qu'on découvre nécessaire → on l'ajoute au memo **par une modification explicite**, on ne l'ajoute pas en silence.

### 2. Décider — **ADR obligatoire**

C'est le seul cycle où l'ADR est obligatoire même si « on ne fait que déplacer du code ». Un refactoring sans ADR se refait à l'envers six mois plus tard par quelqu'un qui ignorait pourquoi.

L'ADR ([`TEMPLATE.md`](../decisions/adr/TEMPLATE.md)) doit trancher :

- §3 **Options envisagées** — y compris « ne rien faire », avec son coût.
- §5 **Coûts consentis** — un ADR sans coût consenti n'a pas été écrit honnêtement.
- §7 **Comment vérifier** — le test, le cop ou la commande qui échoue si quelqu'un revient en arrière. Un refactoring qui ne laisse pas de garde-fou sera défait.

Pas de PRD. Pas d'UDR — **si une UDR devient nécessaire, ce n'est pas un refactoring** (voir plus haut).

### 3. Planifier — lots par zone, tous iso-comportement

- Un lot = une **zone** (un contexte borné, une couche, un namespace), pas un cas d'usage.
- Chaque lot est mergeable seul et laisse l'application fonctionnelle. Pas de « lot intermédiaire cassé rattrapé au lot suivant ».
- Fichiers partagés (`config/routes.rb`, `config/locales/*.yml`, layouts) → Lot 0, comme toujours ([conventions §6](../guide/conventions.md#6-format-dun-lot)).
- Le champ `Done quand` d'un lot de refactoring s'écrit toujours de la même manière : **« les characterization tests de la zone passent, inchangés »**.

### 4. Exécuter — characterization tests d'abord

1. **Écrire les characterization tests** : ils décrivent le comportement **actuel**, y compris ses bizarreries. Ils sont verts avant toute modification.
   - Si une bizarrerie est en fait un bug : on la fige telle quelle et on ouvre un chantier bugfix. On ne la corrige **pas** ici.
   - Si un test est impossible à écrire sans toucher le code, c'est la zone la plus risquée : c'est là qu'il faut le plus d'effort, pas moins.
2. **Lancer, tout est vert.** C'est le filet.
3. Refactoriser par petits pas, en relançant les characterization tests à chaque pas.
4. **Les characterization tests ne sont jamais modifiés pendant le refactoring.** Un test qu'il faut adapter est la preuve qu'un comportement a changé → on annule le pas.

Exception unique et documentée : le renommage d'une constante ou d'un namespace oblige à changer l'`include`/le nom de classe dans le test. Le renommage est mécanique et le corps des assertions reste identique — sinon ce n'est plus un renommage.

### 5. Prouver — le challenger vérifie l'ISO-COMPORTEMENT

Le challenger de ce cycle **ne juge pas l'esthétique du code**. Sa seule question : est-ce que quoi que ce soit a changé pour un utilisateur ?

Ce qu'il fait :

- Rejoue dans l'application les parcours de la zone touchée, avant / après.
- Compare les sorties : mêmes libellés, même tri, mêmes erreurs, mêmes permissions, même contenu de réponse.
- Vérifie que le diff **n'ajoute aucun comportement** : lit le diff en cherchant les `if` nouveaux, les valeurs par défaut nouvelles, les `rescue` nouveaux.
- Vérifie le garde-fou de l'ADR §7 : il échoue bien si on revient en arrière.

« Le code est plus lisible » n'est pas une preuve. « Les 41 tests de la zone passent sans avoir été modifiés, et les 3 parcours rejoués donnent le même écran » en est une.

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Explorer « périmètre »** | oui | Recense tous les appelants avant de bouger quoi que ce soit : `grep` des constantes, des routes, des fixtures, des vues |
| **Rédacteur ADR** | oui | Écrit l'ADR **avant** le code, options + coûts consentis + garde-fou |
| **Exécutant** | 1 par zone | Characterization tests puis petits pas |
| **Challenger ISO** | **OUI** | Vérifie que **rien** n'a changé fonctionnellement. Interdit de commenter le style |
| **Griller** | non | Il n'y a pas de spec à casser |

---

## Portes de sortie — à copier dans `plan.md`

```markdown
- [ ] `memo.md` : motif chiffré ou nommé, **liste exhaustive des fichiers** du périmètre
- [ ] Explorer périmètre rendu : tous les appelants recensés (code, vues, fixtures, routes)
- [ ] ADR écrit **avant** le code, avec §3 options, §5 coûts consentis, §7 garde-fou vérifiable
- [ ] ADR indexé dans `decisions/adr/README.md`
- [ ] Characterization tests écrits et **verts** avant la première modification
- [ ] Aucune UDR nécessaire — si une vue change, le chantier est requalifié en feature
- [ ] Chaque lot laisse l'application fonctionnelle seul
- [ ] Characterization tests **non modifiés** à l'arrivée (hors renommage mécanique documenté)
- [ ] Challenger a rejoué les parcours de la zone : sorties identiques avant/après
- [ ] Diff relu : aucun `if`, `rescue` ou valeur par défaut ajouté
- [ ] Garde-fou de l'ADR §7 testé : il échoue bien si on revient en arrière
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : bizarreries figées, bugs découverts → chantiers bugfix ouverts
```

---

## Exemple réel — namespaces dupliqués (`catalog`, `classroom`, …)

Écart connu, non tranché ([conventions §8](../guide/conventions.md#8-écarts-connus-entre-la-doc-et-le-code)) : ~13 entités et 5 repositories existent **à la fois** à la racine de `app/domain/entities/` et dans leur contexte borné.

- **Motif** : deux définitions vivantes pour un même concept ; un agent qui suit le code voisin propage le legacy.
- **Périmètre gelé** : la liste des doublons + tous leurs appelants (use cases, queries, contrôleurs, fixtures).
- **ADR** : quelle version fait foi, quel ordre de migration, et **§7** — un test qui échoue si un fichier réapparaît à la racine de `entities/`.
- **Characterization tests** : sur les use cases appelants, pas sur les entités elles-mêmes — ce sont les appelants qui doivent rester iso.
- **Lots** : un lot par contexte borné (`catalog`, puis `classroom`, puis `school`…), chacun mergeable seul.
- **Iso-comportement** : le fil élève (`student_feed_query`) et le rapport de classe (`classroom_report_query`) rendent exactement le même écran avant et après.

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **« Tant qu'on y est »** | Un bug corrigé, un libellé amélioré au passage | Interdit. Note au `journal.md` → chantier séparé |
| **Test adapté au nouveau code** | On modifie l'assertion pour faire passer | C'est la preuve d'un changement de comportement. Annuler le pas |
| **Zone non testable sautée** | On refactorise là où c'était déjà propre | Une zone sans test est la zone la plus risquée : l'effort va là |
| **Big bang** | Un seul lot qui touche 60 fichiers | Un lot par zone, chacun mergeable et fonctionnel seul |
| **Challenger qui commente le style** | La revue parle de nommage | Son mandat est l'iso-comportement. Le style est couvert par rubocop |
| **Appelant oublié** | Une vue ou une fixture référence l'ancien nom | L'explorer périmètre cherche aussi dans `app/views/`, `test/fixtures/`, `config/` |
| **ADR écrit après** | L'ADR justifie au lieu de décider | L'ADR est une porte de la phase 2, pas un compte-rendu de la phase 5 |
