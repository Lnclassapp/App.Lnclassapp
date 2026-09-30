# Le runner auto-hébergé de la CI

> Pourquoi il existe : [ADR-0068](../decisions/adr/0068-ci-sur-runner-auto-heberge-et-promotions-par-preuve.md). Le quota de minutes GitHub d'un dépôt privé gratuit ne tient pas la cadence des PR. Les jobs de `bin/ci` tournent donc sur la machine du porteur, et seules les promotions (`Staging`, `main`) consomment des minutes GitHub.

## Ce qu'il faut

- Ubuntu 22.04 ou plus récent, en x86_64, avec **Docker** installé et démarré. Les tests lancent `postgres:17` en conteneur.
- 4 cœurs au moins. Deux instances du runner par défaut.
- Un accès administrateur au dépôt GitHub, pour générer le jeton d'enregistrement.

## Installer

1. Sur GitHub : **dépôt → Settings → Actions → Runners → New self-hosted runner**. Copier le jeton affiché après `--token` (il est valable une heure). Ne pas suivre les commandes proposées par GitHub : le script les remplace.
2. Sur la machine, dans une copie du dépôt :

   ```bash
   sudo script/ci/runner/install --token <jeton> --instances 2
   ```

3. Vérifier le résultat : `script/ci/runner/check` doit finir par « Le runner peut prendre un job ». Sur GitHub, les instances `<machine>-lnclass-1`, `-2` apparaissent **Idle**.

Le script est idempotent : le relancer avec un nouveau jeton répare et réenregistre les instances. Voici ce qu'il fait, et rien d'autre :

| Étape | Pourquoi |
|---|---|
| Paquets `libpq-dev`, `build-essential`, `libyaml-dev`, `libffi-dev`, Google Chrome, `gh`, `jq`, `ruby` | Ce que les images GitHub fournissent et que les jobs supposent |
| Utilisateur système `github-runner` (dossier `/opt/github-runner`), **sans `sudo`**, membre de `docker` | Le code des PR tourne sous cet utilisateur, jamais sous le tien (grill, question 5) |
| `chmod o-rwx` sur les dossiers personnels (`/home/…`) | Un job ne lit pas tes clés SSH, jetons et fichiers |
| `/opt/hostedtoolcache` appartenant à `github-runner` | `ruby/setup-ruby` n'installe ses Ruby précompilés que là |
| N instances du runner, étiquettes `self-hosted, linux, lnclass`, un service systemd chacune | Plusieurs jobs d'un même run tournent en même temps |

## Au quotidien

- **Machine éteinte** : les PR attendent leur verdict. GitHub annule un job resté 24 h en file ; le service de relance (chantier `ci-quota`, lot D) relance les runs annulés depuis moins de 48 h.
- **Urgence, machine indisponible** : *Actions → CI sur GitHub (secours) → Run workflow*, sur la branche de la PR. Un seul job, environ 9 minutes facturées.
- **Coût d'un run** : `script/ci/billed_minutes <run-id>` (les jobs auto-hébergés comptent 0).

## Entretenir

- Mises à jour d'Ubuntu, de Docker et de Chrome : à ta charge (hors périmètre de la CI).
- Le runner se met à jour tout seul. S'il reste trop longtemps éteint, GitHub peut le refuser : relancer `install` avec un nouveau jeton.
- Arrêter sans désinstaller : `sudo systemctl stop 'actions.runner.*'`.

## Désinstaller

Pour chaque instance, générer un jeton de suppression (même page GitHub, menu de l'instance → *Remove*), puis :

```bash
cd /opt/github-runner/runner-1
sudo ./svc.sh stop && sudo ./svc.sh uninstall
sudo -u github-runner ./config.sh remove --token <jeton de suppression>
```

Puis, une fois toutes les instances retirées : `sudo userdel -r github-runner && sudo rm -rf /opt/hostedtoolcache`.
