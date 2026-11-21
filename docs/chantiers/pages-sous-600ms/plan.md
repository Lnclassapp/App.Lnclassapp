# Plan — pages-sous-600ms

> Cycle optimisation : un lot = un levier = un chiffre ; on s'arrête dès que la cible est atteinte. Mesure : [memo](memo.md).

**La cible (aucune page au-dessus de 600 ms p95 côté serveur, production locale, jeu standard, 3 rôles) est tenue dès la
mesure avant** (pire page : 199 ms). Les leviers de code sont donc fermés ; reste la garde, pour que ça le reste.

## Contrat d'exécution

1. Le bench est versionné : `script/mesure/pages` (temps serveur, SQL, allocations, poids) et
   `script/mesure/pages_navigateur.cjs` (Chromium à 390 px). Il a produit la valeur avant.
2. Les tests fonctionnels des pages concernées sont verts avant tout levier.
3. Un seul levier par lot, bench relancé, chiffre noté ; gain nul ou marginal → le pas est annulé.
4. **Le chantier ne se clôt pas sans mesure après** : même machine, même volume, même méthode, ≥ 3 exécutions, médiane.

## Lot A — Outil de mesure · livré

- **Fichiers** : `script/mesure/pages`, `script/mesure/pages.rb`, `script/mesure/pages_navigateur.cjs`
- **Done quand** : le tableau avant du memo sort de l'outil, rejouable par un autre (protocole du memo). Fait.

## Lot B — Garde : budget de requêtes SQL par page

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

## Lot C — « Ma classe » : une lecture de feuille par leçon assignée · fermé

`StudentAssignedSheetsQuery#exercises` relit toute la feuille d'une leçon (`PrepareSheetsQuery`, ~14 requêtes) pour chaque
leçon assignée : 91 requêtes, 177 ms p50 en production locale, 468 ms sous les plafonds de Develop. Sous la cible :
**fermé**. À rouvrir si une mesure de Develop ou de la production dépasse 600 ms sur cette page.

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
- [ ] Tests de non-régression fonctionnelle verts **avant** le premier levier
- [x] Un lot = un levier = un chiffre
- [x] Chaque levier sans gain mesuré a été **annulé**, pas conservé — lots C et D fermés avant d'être joués
- [ ] Bench après : même machine, même volume, même méthode, ≥ 3 exécutions, médiane
- [ ] Tableau `Mesures` complété (Avant / Cible / Après)
- [ ] **Challenger a relancé le bench lui-même** et obtenu le gain annoncé
- [x] Résultat fonctionnel strictement identique (aucun écran, aucune sortie modifiés)
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] `journal.md` : leviers abandonnés et pourquoi
