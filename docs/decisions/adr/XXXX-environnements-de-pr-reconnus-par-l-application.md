# ADR-XXXX : L'application reconnaît un environnement de PR Railway, le ferme par un mot de passe, y sème les données de test et s'y passe du worker
<!-- index
titre: Environnements de PR Railway reconnus par l'application : mot de passe, données de test, sans worker
statut: Accepté — *amende [0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) §4 et [0034](./0034-reprise-des-donnees-et-referentiel-seede.md) (seeds par environnement)*
problematique: Une PR s'essaie sur une adresse Railway, à partir de Develop, sur des données fictives, derrière un mot de passe, et peut se mettre en veille.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-21 |
| **Chantier** | `docs/chantiers/environnements-de-pr` |
| **Amende** | [ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) §4 (worker toujours dans Puma) · [ADR-0034](./0034-reprise-des-donnees-et-referentiel-seede.md) (seeds par environnement) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur essaie les PR sur sa machine (`bin/tester-pr`). Il veut aussi les essayer depuis un téléphone hors de son Wi-Fi et les montrer, sans payer un environnement allumé par PR. Railway crée un environnement par PR, copie de l'environnement de base (Develop, choisi le 2026-10-21), et le supprime à la fusion ou à la fermeture. Tel quel, il ne sert à rien et coûte cher :

- **Il ne dort jamais.** Railway endort un service 5 à 10 minutes après son dernier paquet sortant (documentation « Serverless »). Le worker Solid Queue, toujours dans Puma (ADR-0052), et Solid Cable (`polling_interval: 0.1.seconds`) interrogent la base en continu.
- **On ne s'y connecte pas.** Railway fait tourner l'application en `production`. Les bases d'une PR partent vides (la copie des volumes a été retirée par Railway en 2025), et la production ne sème que l'identité (ADR-0034).
- **Il est public.** L'adresse Railway est ouverte à tous, et les comptes de test ont un PIN connu.

Railway n'offre aucun moyen durable de régler une PR à part. Le bloc `environments.pr` de `railway.json` existe, mais Railway cesse de lire ce fichier le 2026-12-01. Son remplaçant, `.railway/railway.ts`, n'a pas d'équivalent documenté. Aucune variable fournie par Railway ne signale non plus un environnement de PR (`docs.railway.com/variables/reference`).

## 2. Moteurs de décision

1. Staging et production restent strictement identiques : aucune donnée de test, aucun mot de passe, et un oubli de variable ne peut rien y déclencher.
2. Un oubli ferme l'accès plutôt que de l'ouvrir.
3. Rien ne doit dépendre d'un mécanisme Railway qui disparaît le 2026-12-01.
4. L'environnement de PR doit pouvoir dormir.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Bloc `environments.pr` de `railway.json` (variables, mise en veille) | Natif, sans code | Fichier plus lu après le 2026-12-01, aucun équivalent documenté dans `railway.ts` |
| B — Reconnaître une PR à la forme de `RAILWAY_ENVIRONMENT_NAME` (`…-pr-123`) | Aucune variable à poser | Forme non documentée : un changement chez Railway la casse sans bruit |
| C — **Une variable posée sur Develop, `PR_BASE_ENVIRONMENT=Develop`**, copiée dans ses PR, comparée au nom de l'environnement courant | Repose sur deux comportements documentés (copie des variables de la base, `RAILWAY_ENVIRONMENT_NAME`) ; absente de Staging et production, elle ne peut rien y déclencher | Retenue |
| D — Worker gardé, sans veille | Comportement identique à Develop | Une PR ouverte coûte un environnement allumé en permanence |
| E — Tâches de fond jamais exécutées dans une PR | Le plus simple | Un import lancé dans une PR attendrait pour toujours, sans erreur (le défaut que l'ADR-0052 a corrigé) |

## 4. Décision

> **Nous reconnaissons un environnement de PR à `PR_BASE_ENVIRONMENT` posée et différente de `RAILWAY_ENVIRONMENT_NAME` (présente).** Dans un tel environnement, et là seulement :
>
> 1. **Un mot de passe commun ferme toute l'application** (Basic HTTP, avant le routeur), lu dans `PR_ACCESS_PASSWORD`. Sans cette variable, tout est refusé. Seul `/up` passe, pour le contrôle de santé de Railway.
> 2. **Les tâches de fond s'exécutent dans le processus web** (adaptateur Active Job `:async`). Puma ne charge pas le worker Solid Queue, et les tâches planifiées (`config/recurring.yml`) ne tournent pas. **Les mises à jour en direct passent par le processus web** (adaptateur Action Cable `async`). Puma n'a qu'un processus (`WEB_CONCURRENCY` non lu par `config/puma.rb`), donc rien ne se perd.
> 3. **Le pré-déploiement sème les données de test** : référentiel, DRENA, comptes fictifs et trois établissements de test, en plus de l'identité. Ces seeds restent refusés en production, en Staging et à Develop.
>
> **Amendement de l'ADR-0052** : le worker tourne toujours dans Puma, **sauf dans un environnement de PR**. C'est la seule condition admise sur `plugin :solid_queue`.

## 5. Conséquences

### 🟢 Positives

- Une PR s'essaie depuis n'importe quel appareil, sur les mêmes données que `bin/tester-pr --demo`.
- Une PR sans visite s'endort, à condition que le porteur active la mise en veille (Serverless) sur le service de Develop, dont elle hérite. Develop, lui, garde son worker et reste éveillé.
- Staging et production ne portent pas la variable : rien n'y change, même si le code est livré.

### 🔴 Coûts consentis

- **Une condition revient sur le worker**, celle-là même qui l'avait empêché de tourner (ADR-0052 §1). Pour la borner, la garde de `test/guards/repository_rules_test.rb` n'admet qu'une ligne exacte, et le démarrage de production est testé avec et sans la variable.
- **Les tâches planifiées ne tournent pas dans une PR** : un message programmé n'y est jamais publié à son heure, et les purges nocturnes n'y passent pas.
- **Les tâches `:async` se perdent si le processus s'arrête** : en veille, au redéploiement. Une PR n'a que des données fictives.
- **La première visite d'une PR endormie peut répondre 502** le temps du réveil (documentation « Serverless »).
- **Le mot de passe est partagé** : il se change sur Develop et ne vaut que pour les PR (re)déployées ensuite.
- **Deux variables à tenir sur Develop**, à ne pas sceller : Railway ne copie pas les variables scellées dans les PR.

## 6. Notes d'implémentation

```ruby
# config/pr_environment.rb — Ruby pur : config/puma.rb le lit avant Rails, config/application.rb ensuite.
module PrEnvironment
  def self.active?(env = ENV)
    base = env["PR_BASE_ENVIRONMENT"].to_s.strip
    name = env["RAILWAY_ENVIRONMENT_NAME"].to_s.strip
    !base.empty? && !name.empty? && name != base
  end
end
```

```ruby
# config/puma.rb — ADR-0052, amendé par ADR-XXXX : le worker tourne toujours, sauf dans un environnement de PR.
require_relative "pr_environment"
plugin :solid_queue unless PrEnvironment.active?
```

```ruby
# config/environments/production.rb
config.active_job.queue_adapter = PrEnvironment.active? ? :async : :solid_queue
config.middleware.insert_before 0, PrEnvironment::Gate if PrEnvironment.active?
```

```yaml
# config/cable.yml
production:
  adapter: <%= PrEnvironment.active? ? "async" : "solid_cable" %>
```

```ruby
# db/seeds.rb — ADR-0034, amendé par ADR-XXXX : un environnement de PR sème comme le développement, plus la démo.
stage = PrEnvironment.active? ? "pr" : Rails.env
SEEDS = { "identity" => :all, "catalog" => %w[development test pr], "school" => %w[development test pr],
          "development" => %w[development pr], "demo/trois_etablissements" => %w[pr] }.freeze
```

## 7. Comment vérifier que la décision est respectée

- `test/config/pr_environment_test.rb` : table de vérité de `PrEnvironment.active?`, et le contrôle d'accès (401 sans mot de passe, avec un mauvais ou si la variable manque ; 200 avec le bon ; `/up` libre).
- `test/integration/production_configuration_test.rb` : démarrage de production réel, avec les variables d'une PR (adaptateurs `async`, 401 sans mot de passe) et sans elles (Solid Queue, Solid Cable, aucune demande de mot de passe).
- `test/guards/repository_rules_test.rb` : `config/puma.rb` charge le worker par la seule ligne `plugin :solid_queue unless PrEnvironment.active?`.
- `test/db/pr_environment_seeds_test.rb` : une base vide d'environnement de PR reçoit les données de test, deux fois sans doublon. La production ne reçoit que l'identité.
- Ce qu'aucun test ne prouve, la mise en veille effective, est à constater par le porteur sur Railway, à la première PR (journal du chantier).
