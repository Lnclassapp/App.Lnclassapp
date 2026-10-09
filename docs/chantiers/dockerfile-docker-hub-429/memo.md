# Memo — Dockerfile et limite de Docker Hub (429)

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-09 |
| **Branche** | `fix/dockerfile-docker-hub-429` |
| **Programme** | — |

---

## Symptôme

Le déploiement Railway `2b3e2eee-d31f-4858-a906-eaea9d51c457` de `Develop` (commit `992c3f31`, documentation seule) échoue en 15 s à l'étape `BUILD_IMAGE` :
`unexpected status from HEAD request to https://registry-1.docker.io/v2/library/ruby/manifests/3.4.9-slim: 429 Too Many Requests`.

## Reproduction

Redéployer `2b3e2eee` : nouvel échec identique en 10 s (`a0fa4234`, même erreur). Le dernier build réussi (`086efbd9`) continue de servir : pas de panne.

## Portée

3 déploiements échoués depuis le 2026-10-07, dont un sur `main` (production, redéploiement du 2026-10-07, cause non vérifiée). Aucune donnée corrompue.

## Cause

`Dockerfile:12` tire `docker.io/library/ruby` sans identifiant. Le constructeur de Railway partage son adresse : Docker Hub plafonne les tirages anonymes. Aucun test ne regardait d'où viennent les images.

## Correctif

Image de base tirée du miroir AWS `public.ecr.aws/docker/library/ruby:3.4.9-slim` (étiquette vérifiée, HTTP 200). Garde `test_the_dockerfile_pulls_no_base_image_from_docker_hub` dans `test/guards/repository_rules_test.rb` : rouge avant, vert après.

## Hors périmètre

- La ligne `# syntax=docker/dockerfile:1` tire aussi son frontend depuis Docker Hub, et ce frontend n'existe pas sur le miroir AWS. Elle reste, car `# check=error=true` en dépend ; le builder l'avait en cache. **Risque résiduel** : si ce tirage reçoit un 429, le même échec revient. Réponse à ce moment : identifiants Docker Hub dans les secrets Railway, ou construire l'image ailleurs.
- Les 2 autres échecs du 2026-10-07 : causes non examinées.

## Preuve

Le prochain déploiement de `Develop` après la fusion doit finir en `SUCCESS` et rester sain. Le `bin/ci` complet n'a pas pu tourner dans la session (gems absents) : la garde et rubocop ont été exécutés seuls.
