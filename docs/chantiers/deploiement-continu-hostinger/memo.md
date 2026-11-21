# Memo — Déploiement continu GitHub → VPS Hostinger

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-21 |
| **Branche** | `feature/deploiement-continu-hostinger` |
| **Programme** | — |

---

## Le problème

Depuis le départ de Railway (2026-11-17), aucune fusion ne se déploie seule : il faut ouvrir une session et lancer `deployer.py` deux fois (construction, puis démarrage). Une fusion oubliée laisse l'ancienne version en ligne sans alerte.

## Pour qui

L'équipe (`Team`) et le porteur, qui promeuvent `Develop` → `Staging` → `main` ; indirectement chaque acteur de l'application, qui reçoit la version fusionnée.

## Pourquoi maintenant

Décision du porteur du 2026-11-21 : le point ouvert « Déploiement de Staging et Develop à chaque fusion » du journal `hebergement-cloudflare` est tranché en faveur d'une action GitHub, étendue à la production.

## Hors périmètre

- Les environnements de PR (disparus avec Railway, ADR-0140) : une PR se teste en local (`bin/tester-pr`).
- Faire tourner la CI au push sur `Develop` : la preuve d'une PR vers `Develop` reste locale (ADR-0107).
- Réécrire `deployer.py`, ou piloter le VPS par SSH.
- Créer les secrets ou les Environments GitHub : c'est le porteur, dans les réglages du dépôt.
- Épingler par SHA les actions de `ci.yml` (sans secret du VPS) : dette notée au journal.
- Lancer un déploiement réel depuis ce chantier.

## Ce que le grill a révélé

> Session lancée par l'orchestrateur, sans question au porteur (contrat de session) : les questions ont été posées au code et à la doc, les réponses viennent de ce qu'ils disent.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le statut `ci` existe-t-il sur le commit poussé sur `Staging` ou `main` ? | Non : la CI ne tourne qu'aux PR vers `Staging` et `main` ; elle publie la preuve de l'**arbre** testé (`ci-tree-<arbre>`). | La garde lit la preuve de l'arbre (`script/ci/tested_tree`), pas un statut de commit. Une base déplacée entre le test et la fusion bloque le déploiement : voulu. |
| La CI tourne-t-elle pour `Develop` ? | Non (ADR-0107) : preuve locale. | `Develop` déploie au push, sans garde de preuve. |
| Qui peut lire le jeton Hostinger une fois dans GitHub ? | Au niveau du dépôt : tout workflow de n'importe quelle branche. | Secrets dans des Environments limités à leur branche, jamais au niveau du dépôt. |
| Deux environnements peuvent-ils construire en même temps ? | Le projet de construction `lnclass-construction` est unique : un second envoi le remplace pendant la première construction, et le premier job peut lire l'« OK » de l'autre. | `deployer.py` attend la disparition du projet à usage unique avant d'en lancer un ; `concurrency` sans annulation. |
| `deployer.py` s'authentifie-t-il auprès de Hostinger ? | Non : dans une session, le proxy ajoute le jeton. | Petit ajout : en-tête `Authorization` quand `HOSTINGER_API_TOKEN` existe. |
| Un retour arrière vers un vieux SHA marche-t-il avec le code de déploiement de ce SHA ? | Non si ce SHA précède le chantier (pas d'authentification). | Le job prend toujours le code de déploiement de la tête de branche et ne passe que le SHA à déployer. |
| Un relecteur requis sur `production` est-il disponible ? | Dans un dépôt privé, seulement avec GitHub Enterprise. | Protection retenue : `main` seule, plus la condition du job (ADR). |

## Cas limites identifiés

- Push de documentation seule : rien n'est déployé (sauf `docs/contenus/`).
- Preuve expirée (> 30 jours) ou CI coupée (`CI_ENABLED`) : Staging et production ne déploient pas ; le job dit pourquoi.
- Un job tué pendant la construction laisse `lnclass-construction` sur le VPS : le suivant attend 20 min puis échoue en le nommant.
- Organisation sans Environments pour un dépôt privé : on ne déploie pas depuis GitHub.

## Questions encore ouvertes

- Voir `journal.md` § À trancher.
