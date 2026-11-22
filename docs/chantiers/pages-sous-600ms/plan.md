# Plan — pages-sous-600ms

> Cycle optimisation : un lot = un levier = un chiffre ; on s'arrête dès que la cible est atteinte. Mesure : [memo](memo.md).

**La cible (aucune page au-dessus de 600 ms p95 côté serveur, production locale, jeu standard, 3 rôles) est tenue dès la
mesure avant** (pire page : 200 ms p95). Sous les plafonds CPU de Develop, une page la dépasse (« Ma classe », 608 ms
p95) : seul le lot C se rouvre. Le lot B garde le résultat.

## Contrat d'exécution

1. Le bench est versionné : `script/mesure/pages` (temps serveur, SQL, allocations, poids) et
   `script/mesure/pages_navigateur.cjs` (Chromium à 390 px). Il a produit la valeur avant.
2. Les tests fonctionnels des pages concernées sont verts avant tout levier.
3. Un seul levier par lot, bench relancé, chiffre noté ; gain nul ou marginal → le pas est annulé.
4. **Le chantier ne se clôt pas sans mesure après** : même machine, même volume, même méthode, ≥ 3 exécutions, médiane.

## Lot A — Outil de mesure · livré

- **Fichiers** : `script/mesure/pages`, `script/mesure/pages.rb`, `script/mesure/pages_navigateur.cjs`
- **Done quand** : le tableau avant du memo sort de l'outil, rejouable par un autre (protocole du memo). Fait.

## Lot B — Garde : budget de requêtes SQL par page · livré

- **Couche** : tests (aucun code applicatif)
- **Fichiers** : `test/integration/budget_requetes_pages_test.rb`
- **Dépend de** : —
- **Test associé** : le fichier lui-même, dans la suite unitaire (donc dans `bin/ci` et sur chaque PR).
- **Contenu** : l'élève (accueil, ma classe, catalogue, matière, leçon, exercice), l'enseignant (accueil, classe, élève de
  la classe, leçon de la classe, suivi d'un devoir) et la direction (classes, classe, niveau, enseignants) sont visités une
  fois connectés, sur des données de test qui ont **au moins deux** devoirs dans **deux** leçons différentes ; le nombre de
  requêtes SQL (hors `SCHEMA` et `TRANSACTION`, hors cache) de chaque page est comparé à son budget. Budget = compte
  mesuré au moment du lot + 25 %, arrondi au-dessus, écrit dans une table `BUDGETS` en tête du fichier avec le compte du
  jeu standard en commentaire. Le message d'échec nomme la page, le compte et le budget, et renvoie à
  `script/mesure/pages`.
- **Done quand** : le test passe ; il échoue si on ajoute une requête par devoir à « Ma classe » (vérifié à la main en
  dupliquant un appel, puis retiré) ; durée du fichier < 10 s.

## Lot C — « Ma classe » : ne construire que les exercices assignés · livré (608 → 514 ms p95 sous plafonds)

`StudentAssignedSheetsQuery#exercises` relit toute la feuille d'une leçon (`PrepareSheetsQuery`) pour chaque leçon
assignée, et construit chaque exercice de la leçon (questions, choix, copies) pour n'en garder que les assignés :
91 requêtes, 115 000 allocations, 160 ms p50 / 200 ms p95 en production locale, **608 ms p95 sous les plafonds de
Develop** (au-dessus de la cible : le lot se rouvre, comme prévu).

- **Couche** : infrastructure (queries) ; aucune vue.
- **Fichiers** : `app/infrastructure/queries/catalog/prepare_sheets_query.rb`,
  `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb`, leurs tests.
- **Levier (un seul)** : `PrepareSheetsQuery` construit seulement les exercices demandés (`only:` liste de public_id),
  sans changer leur numéro (rang dans leur feuille, calculé sur toutes les lignes de la leçon). Les autres appelants
  ne passent rien : sortie inchangée.
- **Test associé** : équivalence stricte — pour les mêmes données, chaque `Sheet` de `StudentAssignedSheetsQuery`
  est égal (`==` des `Data`) avant et après ; plus le budget du lot B.
- **Done quand** : « Ma classe » passe sous 600 ms p95 sous les plafonds de Develop et descend d'au moins 30 % en
  allocations en production locale, mesuré par `script/mesure/pages` (même volume, 3 exécutions, médiane). Gain
  inférieur → le pas est annulé.

## Lot D — Leçon : lectures de notion en lot · fermé

`Catalog::CoursesController#record_reads` charge chaque notion par son slug puis écrit sa lecture (5 requêtes par notion,
42 en tout, 73 ms p50). Les grouper change le contrat du use case `RecordEssentialRead` (ADR obligatoire) pour un gain
sous la cible : **fermé**.

## Hors code — hébergement (recommandations, voir `journal.md` § À trancher)

- Plafonds CPU de Develop et Staging (`deploy/hostinger/test.yaml`).
- Démarrage de Develop (~16 min de 502 par déploiement).

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `test/integration/budget_requetes_pages_test.rb` | Lot B |

Aucun fichier des vues de /student, /students et de l'inscription (session `entree-et-accueil-eleve-allegees`).

## Portes de sortie

- [x] `memo.md` : métrique nommée, **valeur avant chiffrée**, volume de données précisé, cible chiffrée
- [x] Protocole de mesure écrit et reproductible par quelqu'un d'autre
- [x] Explorer coût rendu : où part réellement le temps (pas une hypothèse)
- [x] ADR écrit si un contrat change — aucun contrat changé
- [x] Bench versionné, produisant la valeur avant
- [x] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé — lots C et D fermés avant d'être joués
- [x] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [x] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [x] `journal.md` : leviers abandonnés et pourquoi
