# ADR-XXXX : GitHub déploie Develop, Staging et la production sur le VPS Hostinger à chaque push
<!-- index
titre: Déploiement continu GitHub → VPS Hostinger (Develop, Staging, production), secrets dans des Environments GitHub
statut: Accepté
problematique: Depuis le départ de Railway, aucun déploiement n'est automatique ; le jeton Hostinger qui l'automatise ouvre tout le VPS.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-21 |
| **Chantier** | `docs/chantiers/deploiement-continu-hostinger` |
| **Remplace** | — (amende ADR-0140 §5 : « pas encore de déploiement automatique ») |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Railway déployait seul chaque branche suivie. Depuis le 2026-11-17 (ADR-0140), les trois environnements tournent sur un VPS Hostinger et un déploiement se lance à la main, depuis une session Claude Code : `script/hostinger/deployer.py construction` (l'image `lnclass-app:<sha>` est construite sur le serveur), puis `deployer.py` (production) ou `deployer.py test … staging|develop`. Une fusion oubliée laisse l'ancienne image en ligne sans aucune alerte (déjà vu avec Railway, `retour-arriere.md` §6).

Le porteur a décidé le 2026-11-21 que GitHub déploie à chaque push : `Develop` → develop, `Staging` → staging, `main` → production. Pour cela, un job GitHub doit tenir le **jeton de l'API Hostinger**, et ce jeton n'a pas de portée : il pilote tout le VPS, production comprise (projets Docker, `.env` relus en clair, socket Docker de l'hôte par le projet de construction). C'est la menace à traiter d'abord.

## 2. Menace, écrite avant le code

**Bien protégé** : le jeton Hostinger (≈ racine du VPS : base de production, sauvegardes R2 par le `.env`, clé maîtresse Rails) ; secondairement `GH_DEPLOY_TOKEN` (lecture du dépôt privé) et les secrets applicatifs.

| # | Chemin d'attaque | Ce qui l'arrête | Reste ouvert |
|---|---|---|---|
| M1 | Une PR (fork ou branche) modifie un workflow pour afficher ou envoyer le jeton | Le workflow de déploiement n'a **aucun déclencheur de PR** (`push` sur les trois branches et `workflow_dispatch`). `pull_request_target` est interdit dans tout le dépôt (garde-fou). Un dépôt privé ne donne pas ses secrets aux forks. | — |
| M2 | Une branche de chantier poussée avec un workflow modifié (`on: push`) lit les secrets | Les secrets ne sont **jamais au niveau du dépôt** : ils sont dans les GitHub Environments `develop`, `staging`, `production`, chacun limité à sa branche (*deployment branches*). Un job d'une autre branche qui demande l'environnement est refusé avant de démarrer. | Si l'offre GitHub de l'organisation n'a pas les Environments pour un dépôt privé, on **ne** pose **pas** les secrets au niveau du dépôt : le déploiement reste manuel (§4.6). |
| M3 | Qui peut pousser sur `Develop` peut modifier `deploiement.yml` ou `deployer.py` et lire le jeton (le workflow d'un push est celui du commit poussé) | Rien dans le fichier ne peut l'empêcher. Ce pouvoir existe déjà : les sessions Claude Code qui poussent sur `Develop` utilisent aujourd'hui le même jeton par le proxy de l'environnement. L'action n'élargit pas le cercle : porteur et application Claude. | **Risque consenti** (§5). Réduit par trois jetons distincts, révocables séparément (§4.5), et par une règle de branche sur `Develop`, `Staging`, `main` (pas de suppression, pas de *force push*). |
| M4 | Une action tierce compromise (tag déplacé) lit l'environnement du job | Une seule action tierce, `actions/checkout`, **épinglée par SHA de commit** ; tout le reste est du shell et nos scripts. Garde-fou : toute `uses:` de `deploiement.yml` est un SHA de 40 caractères. | Les mises à jour de l'action se font à la main (SHA relu). |
| M5 | Le `GITHUB_TOKEN` du job sert à écrire dans le dépôt | `permissions: {}` au niveau du workflow ; le job reçoit `contents: read` (lire le code et les branches) et `actions: read` (lire la preuve `ci-tree-<arbre>`). Rien d'autre. | — |
| M6 | Injection de script par une entrée (`inputs.sha`, nom de branche), ou un tag nommé `main` lancé à la main | Les entrées passent par `env:`, aucune expression `${{ }}` dans un `run:` (garde-fou). La cible se lit sur `github.ref` (`refs/heads/…`), jamais sur `ref_name`. `deployer.py` refuse tout ce qui n'est pas un SHA de 40 caractères présent sur la branche de l'environnement. | — |
| M7 | Un secret s'imprime dans le journal du job | Chaque secret n'est donné qu'aux étapes qui appellent `deployer.py`, qui n'imprime que des noms (ADR-0140). GitHub masque en plus les secrets connus. Les erreurs Hostinger n'impriment que le message, jamais le corps renvoyé. | Les valeurs relues dans le `.env` du VPS ne sont pas connues de GitHub : seul `deployer.py` les protège. |
| M8 | Un code non vérifié part en production | `Staging` et `main` : le job vérifie la preuve de l'arbre (`script/ci/tested_tree`, statut `ci` vert, ADR-0069, ADR-0107) avant tout appel à Hostinger. `production` n'accepte que `main` (règle de l'Environment **et** condition du job). | `Develop` déploie au push : la CI n'y tourne pas (ADR-0107, preuve locale). |
| M9 | Deux déploiements simultanés se marchent dessus | `concurrency` par branche, sans annulation (`cancel-in-progress: false`) : un job interrompu laisserait le projet de construction sur le VPS. Entre environnements, le projet à usage unique `lnclass-construction` est partagé : `deployer.py` attend qu'il ait disparu avant d'en lancer un, n'accepte que le verdict qui nomme sa révision, et s'arrête sans rien supprimer si un autre déploiement a remplacé le projet. | Deux départs dans les mêmes 20 s : l'un échoue (à relancer), aucun ne déploie une image absente. |

## 3. Moteurs de décision

1. Le jeton Hostinger ne doit être lisible que par un job d'une des trois branches, jamais par une PR ni une branche de chantier.
2. Rien ne part en production ni en recette sans le `ci` vert de son arbre.
3. Réutiliser `deployer.py` tel quel : une seule façon de déployer, à la main comme dans GitHub.
4. Un retour arrière en une commande.

## 4. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Secrets au niveau du dépôt | Marche sur toutes les offres GitHub | Tout workflow poussé sur n'importe quelle branche lit le jeton (M2) |
| B — Environments par branche, `production` sur `main` seule | Le jeton n'existe que pour les jobs des trois branches ; marche dans un dépôt privé avec GitHub Pro, Team ou Enterprise | Retenue |
| C — B plus un relecteur requis sur `production` | Un clic humain avant la production | Pour un dépôt privé, GitHub ne l'offre qu'avec Enterprise ; la promotion vers `main` est déjà une fusion humaine, CI verte |
| D — `workflow_run` après la CI | La CI déclencherait le déploiement | La CI ne tourne pas au push (PR seulement, ADR-0069) ; la preuve de l'arbre suffit |

## 5. Décision

> **Nous déployons par `.github/workflows/deploiement.yml`, à chaque push sur `Develop`, `Staging` et `main`, en appelant `script/hostinger/deployer.py` ; les secrets ne vivent que dans les GitHub Environments `develop`, `staging` et `production`, chacun limité à sa branche.**

1. **Déclencheurs** : `push` sur les trois branches (un push qui ne touche que la documentation hors `docs/contenus/` ne déploie pas) et `workflow_dispatch` avec un `sha` (retour arrière, `docs/guide/retour-arriere.md`), lancé depuis la branche de l'environnement. Aucun déclencheur de PR ; `pull_request_target` interdit partout.
2. **Ordre** : preuve de l'arbre (Staging, main) → `--dry-run` de la construction et du déploiement → construction → déploiement → `/up` à 200 sur le site de l'environnement.
3. **Preuve** : `script/ci/tested_tree <sha>`, sans preuve locale. Une fusion vers `Staging` ou `main` dont l'arbre n'a pas eu son `ci` vert (CI coupée, base déplacée entre le test et la fusion, preuve expirée après 30 jours) **ne déploie pas** et le job échoue avec la raison.
4. **Concurrence** : groupe `deploiement-<branche>`, `cancel-in-progress: false` dans les trois environnements. Un push qui arrive pendant un déploiement attend ; s'il en arrive un troisième, il remplace le second en attente (le plus récent contient l'autre).
5. **Protection de `production`** : Environment `production`, *deployment branches* = `main` seule, et condition du job `github.ref_name == 'main'`. Pas de relecteur requis (option C). Le porteur peut l'ajouter plus tard sans toucher au code. Trois jetons Hostinger distincts, un par Environment, pour pouvoir en révoquer un seul.
6. **Secrets** (noms exacts, `docs/guide/configuration.md` §1) : `HOSTINGER_API_TOKEN` et `GH_DEPLOY_TOKEN` dans chaque Environment ; `LNCLASS_RAILS_MASTER_KEY`, `LNCLASS_R2_ACCESS_KEY_ID`, `LNCLASS_R2_SECRET_ACCESS_KEY`, `LNCLASS_CLAUDE_AGENTAI_SECRET` dans `production` seulement, facultatifs (le `.env` du VPS les garde ; posés, ils priment). Aucun secret au niveau du dépôt. Sans Environments disponibles, on ne déploie pas depuis GitHub.
7. **`deployer.py`** ne change que sur deux points : il envoie `Authorization: Bearer $HOSTINGER_API_TOKEN` quand la variable existe (dans une session Claude Code, c'est le proxy qui l'ajoute) ; un projet à usage unique attend que le précédent du même nom ait disparu (20 min au plus) avant d'être lancé.

## 6. Conséquences

### 🟢 Positives

- Chaque fusion est en ligne quelques minutes après, sans session ouverte ; un déploiement manqué se voit en rouge dans l'onglet *Actions*.
- La production ne reçoit qu'un arbre au `ci` vert, et le jeton Hostinger n'est lisible par aucune PR ni branche de chantier.

### 🔴 Coûts consentis

- **M3** : tout compte qui pousse sur `Develop` peut lire le jeton Hostinger, donc atteindre la production. C'est le cas aujourd'hui pour les sessions Claude Code ; l'action ne l'aggrave pas, mais ne le corrige pas non plus.
- Un déploiement prend des minutes GitHub : la construction d'image se fait sur le VPS, mais le job attend sa fin (100 min au plus : les plafonds de `deployer.py`, 20 min d’attente d’une autre construction, 60 de construction, 15 de démarrage). Ce n'est pas une tâche de CI : le plafond de 5 minutes d'ADR-0107 ne s'y applique pas.
- Les constructions de deux environnements passent l'une après l'autre (projet `lnclass-construction` partagé).
- Un retour arrière vers un SHA dont la preuve a expiré (plus de 30 jours) passe par `deployer.py` à la main depuis une session.

## 7. Notes d'implémentation

```yaml
# .github/workflows/deploiement.yml (extrait)
permissions: {}
concurrency:
  group: deploiement-${{ github.ref_name }}
  cancel-in-progress: false
jobs:
  deploiement:
    if: github.repository == 'Lnclassapp/App.Lnclassapp' && contains(fromJSON('["Develop","Staging","main"]'), github.ref_name)
    environment: ${{ github.ref_name == 'main' && 'production' || github.ref_name == 'Staging' && 'staging' || 'develop' }}
    permissions:
      contents: read
      actions: read
```

## 8. Comment vérifier que la décision est respectée

- `ruby -Itest test/guards/deploiement_workflow_test.rb` (groupe lint de `bin/ci`) échoue si : un workflow déclare `pull_request_target` ; `deploiement.yml` gagne un déclencheur de PR, une permission au-delà de `contents: read` et `actions: read`, une `uses:` non épinglée par SHA, une annulation de déploiement en cours, une expression `${{ }}` d'entrée ou d'événement dans un `run:`, un secret hors des étapes de `deployer.py`, ou perd la preuve de l'arbre avant Staging et la production.
- Réglages GitHub, non vérifiables par un test : *Settings › Environments*, trois Environments, chacun limité à sa branche ; *Settings › Secrets and variables › Actions*, aucun secret de déploiement au niveau du dépôt.
