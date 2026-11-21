# PRD — Déploiement continu GitHub → VPS Hostinger

## 1. Contexte

Memo et [ADR-XXXX-deploiement-continu-hostinger](../../decisions/adr/XXXX-deploiement-continu-hostinger.md). Pas d'écran, pas de règle métier : un workflow GitHub, deux retouches de `deployer.py`, un garde-fou.

## 2. Acteurs et permissions

| Acteur | Peut |
|---|---|
| Qui pousse sur `Develop` / `Staging` / `main` (porteur, application Claude) | Déclencher le déploiement de l'environnement de la branche |
| Qui a l'écriture sur le dépôt | Relancer un SHA (`workflow_dispatch`) depuis la branche de l'environnement |
| PR, fork, branche de chantier | Rien : aucun déclencheur, aucun secret |

## 3. Parcours

### Chemin nominal

Fusion dans `Staging` → le job lit la preuve de l'arbre → `--dry-run` → construction de `lnclass-app:<sha>` → démarrage de `lnclass-staging` → `/up` à 200.

### Chemins alternatifs et erreurs

- Arbre sans preuve → échec avant tout appel à Hostinger.
- Push de documentation seule → pas de run.
- Construction en cours pour un autre environnement → attente.

## 4. Critères d'acceptation

```gherkin
Scénario: aucune PR ne peut lire le jeton
  Étant donné les workflows du dépôt
  Alors aucun ne déclare pull_request_target
  Et deploiement.yml ne se déclenche que sur push (Develop, Staging, main) et workflow_dispatch

Scénario: production sur main seule, sans annulation
  Alors le job de deploiement.yml choisit l'Environment production pour main seulement
  Et la concurrence est par branche avec cancel-in-progress à false

Scénario: preuve avant Staging et production
  Alors une étape lance script/ci/tested_tree avant la première étape qui appelle deployer.py
  Et elle s'applique à Staging et main, pas à Develop

Scénario: permissions et épinglage
  Alors les permissions du workflow sont vides et celles du job sont contents: read et actions: read
  Et chaque uses: est épinglée par un SHA de 40 caractères

Scénario: secrets et entrées
  Alors seuls les run: qui appellent deployer.py reçoivent des secrets
  Et aucun run: n'interpole ${{ inputs.* }} ni ${{ github.event.* }}

Scénario: dry-run avant envoi
  Alors deployer.py --dry-run est appelé avant la construction réelle

Scénario: deployer.py s'authentifie dans GitHub
  Étant donné HOSTINGER_API_TOKEN posé
  Alors chaque appel à l'API Hostinger porte Authorization: Bearer
```

## 5. Modélisation préliminaire

Aucune table, aucun port.

## 6. Décisions rattachées

- [ADR-XXXX-deploiement-continu-hostinger](../../decisions/adr/XXXX-deploiement-continu-hostinger.md). Pas d'UDR : aucune vue.

## 7. Mesures

Délai fusion → `/up` à 200, lu dans l'onglet *Actions* aux premiers déploiements.
