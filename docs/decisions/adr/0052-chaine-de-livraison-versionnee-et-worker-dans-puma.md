# ADR-0052 : Chaîne de livraison versionnée, worker toujours actif dans Puma, échecs de job visibles

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-24 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-30**, bloque la V0 |
| **Amende** | [ADR-0010](./0010-stack-ops-solid-suite-postgresql-railway.md) §3.1 (lancement du worker) et §5 (Thruster) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'[ADR-0010](./0010-stack-ops-solid-suite-postgresql-railway.md) retient Solid Queue avec un worker intégré à Puma, et un déploiement Railway déclenché par GitHub. Constat sur l'ancienne application au 2026-09-24 (écarts C-37, TR-31 et TR-36 de la feuille de route) :

1. **La configuration de déploiement n'est pas dans le dépôt.** Aucun `railway.json` : commande de démarrage, contrôle de santé et migrations vivent dans l'interface Railway. On ne sait pas dire, depuis le code, ce qui tourne en production. À l'inverse, `config/deploy.yml` et `.kamal/` décrivent un déploiement Kamal que personne n'utilise.
2. **Le worker n'a jamais tourné.** `config/puma.rb:38` ne charge le plugin que `if ENV["SOLID_QUEUE_IN_PUMA"]`, et cette variable n'est posée nulle part. Conséquence : la purge horaire de `config/recurring.yml` n'a jamais été exécutée, et un job mis en file attend pour toujours, sans erreur.
3. **Le développement ne ressemble pas à la production.** L'adaptateur `:solid_queue` n'est réglé que dans `production.rb`. En développement, les jobs s'exécutent en mémoire, dans le processus web : un job qui ne marche qu'ainsi passe inaperçu.
4. **Aucun échec de job n'est visible.** Un job qui lève une exception finit dans `solid_queue_failed_executions`, table que personne ne lit.
5. **Pas de route `/up`**, alors que `production.rb:44` la réduit déjà au silence dans les journaux. Railway ne peut vérifier qu'un déploiement a bien démarré.
6. **`force_ssl` et `assume_ssl` sont commentés** (`production.rb:28-34`), alors que le plan de refonte les suppose actifs.
7. **Le `Dockerfile` démarre via Thruster**, que l'ADR-0010 §5 déclare inutile.
8. **`main` a 70 commits de retard sur `Develop`**. C'est attendu par les conventions (`main` ne reçoit que `Staging`), mais aucune recette déployée n'existe entre les deux.

## 2. Moteurs de décision

Par ordre d'importance :

1. Ce qui tourne en production se lit dans le dépôt, et se relit en revue de code.
2. Un job mis en file s'exécute, et son échec se voit.
3. Le développeur exécute les jobs comme la production, sans procédure à retenir.
4. Coût d'hébergement minimal en V0 : un seul service par environnement.
5. Le budget réseau de l'[ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) tient en production, pas seulement dans la CI.

## 3. Options envisagées

Arbitrées le 2026-09-24 avec le porteur du produit, question par question.

| Question | Retenu | Écarté, et pourquoi |
|---|---|---|
| Lancement du worker | **Plugin Solid Queue dans Puma, sans condition** | Service Railway séparé (`bin/jobs`) : isole les jobs du web, mais un service de plus à payer et surveiller dès la V0. À reconsidérer par un nouvel ADR si un job lourd dégrade les temps de réponse |
| Visibilité des échecs | **Mission Control Jobs**, dans l'espace équipe | Alerte par e-mail : exige un envoi d'e-mails dès la V0. Alerte seule : ne permet pas de relancer un job |
| Thruster | **Gardé**, devant Puma | Retiré, conforme à l'ADR-0010 : il faudrait alors prouver que le proxy de Railway compresse, sinon le JavaScript commun part non compressé (environ 150 Ko au lieu de 47) |
| Recette | **Un environnement Railway de recette**, qui déploie `Staging` avec sa propre base | `main` seul : la recette décrite par les conventions n'existerait que sur le poste d'un développeur |

## 4. Décision

> **La configuration de déploiement est versionnée.** Un `railway.json` à la racine décrit la construction (le `Dockerfile`), la préparation de la base avant chaque déploiement et le contrôle de santé. Tout réglage Railway qui n'y figure pas se limite aux secrets et aux variables d'environnement. Les fichiers Kamal (`config/deploy.yml`, `.kamal/`, la gemme) ne sont pas repris.
>
> **Deux environnements Railway, deux branches** : `Staging` → recette, `main` → production. Chacun a sa propre base PostgreSQL. Aucune autre branche n'est déployée.
>
> **Le worker Solid Queue tourne toujours dans Puma**, sans variable pour l'activer : `plugin :solid_queue` est inconditionnel. `bin/rails server` lance donc le worker **en développement comme en production**, avec l'adaptateur `:solid_queue` dans les deux. En test, l'adaptateur `:test` est conservé : il vérifie ce qui est mis en file sans lancer de worker. Les tables `solid_queue_*` vivent dans la base principale (ADR-0010).
>
> **Les échecs de job se voient dans Mission Control Jobs**, monté sous `/teams/jobs` et protégé par l'authentification de l'espace équipe. On y lit l'erreur, on relance ou on écarte le job.
>
> **`/up` répond 200 quand l'application a démarré**, et Railway ne bascule le trafic sur un déploiement qu'après ce 200. `/up` est exclu de la redirection HTTPS.
>
> **Thruster reste devant Puma** : il compresse les réponses et met en cache les assets.
>
> **HTTPS est imposé** : `assume_ssl` et `force_ssl` sont actifs en recette et en production.

Amendements à l'ADR-0010 :

| Section | Disait | Dit désormais |
|---|---|---|
| §3.1 | « Un processus de worker léger intégré à Puma dépile les tâches. » | Idem, **sans condition d'activation**, et de la même façon en développement |
| §5 | « Kamal et Thruster ne sont pas requis dans cette configuration PaaS. » | Kamal n'est pas requis. **Thruster est requis** pour la compression (ADR-0051) |

## 5. Conséquences

### 🟢 Positives

- Une revue de code voit tout changement de déploiement : `railway.json`, `Dockerfile`, `config/puma.rb`.
- Un job mis en file s'exécute, y compris la purge horaire de `recurring.yml`.
- Un job qui ne marche qu'en mémoire casse **sur le poste du développeur**, pas en production.
- Un job en échec se voit et se relance sans console Rails.
- Un déploiement qui ne démarre pas ne reçoit pas de trafic : l'ancienne version continue de servir.
- La recette existe vraiment : ce qui part en production a tourné sur une base et une configuration identiques.

### 🔴 Coûts consentis

- **Les jobs partagent la mémoire et le processeur du serveur web.** Un import lourd (TR-28) peut ralentir les pages. On s'en aperçoit par les temps de réponse ; la parade est un service séparé, par un nouvel ADR.
- **Deux environnements Railway à payer**, chacun avec sa base.
- **Mission Control Jobs est une page qu'il faut aller regarder.** Personne n'est prévenu d'un échec. Une alerte par e-mail pourra s'ajouter quand l'application enverra des e-mails.
- **Mission Control Jobs doit respecter la CSP de l'ADR-0049.** Il charge ses propres scripts par importmap : sa compatibilité avec une CSP sous nonce n'est pas vérifiée à ce jour. Le test CSP de la V0 couvre `/teams/jobs` ; s'il échoue, l'écart se règle dans le chantier `amorcage-depot`, jamais en assouplissant la CSP de toute l'application.
- **`/up` ne vérifie que le démarrage**, pas la base de données : c'est le comportement de `Rails::HealthController`. Suffisant pour la bascule d'un déploiement, insuffisant comme supervision continue, qui n'est pas couverte en V0.
- **Thruster ajoute un intermédiaire** entre Railway et Puma, et un port à régler (`HTTP_PORT`).

## 6. Notes d'implémentation

Pour le nouveau dépôt (Rails 8.1), à livrer par le chantier `amorcage-depot`. **Les réglages propres à Railway (expansion de `$PORT`, contrôle de santé) sont à confirmer au premier déploiement de recette**, avant tout déploiement en production.

`railway.json` (JSON n'accepte pas de commentaire) :

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": { "builder": "DOCKERFILE", "dockerfilePath": "Dockerfile" },
  "deploy": {
    "preDeployCommand": "bin/rails db:prepare",
    "healthcheckPath": "/up",
    "healthcheckTimeout": 120,
    "restartPolicyType": "ON_FAILURE"
  }
}
```

```dockerfile
# Dockerfile (fin) — ADR-0052 : Thruster écoute sur le port fourni par Railway ; Puma écoute sur TARGET_PORT (3000), que Thruster lui passe via PORT.
CMD ["sh", "-c", "HTTP_PORT=${PORT:-80} exec ./bin/thrust ./bin/rails server"]
```

```ruby
# config/puma.rb — ADR-0052 : le worker tourne toujours, en développement comme en production.
plugin :solid_queue
```

```ruby
# config/environments/development.rb et production.rb
config.active_job.queue_adapter = :solid_queue

# config/environments/production.rb
config.assume_ssl = true
config.force_ssl  = true
config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
```

```ruby
# config/routes.rb
get "up" => "rails/health#show", as: :rails_health_check

namespace :teams do
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
```

```ruby
# config/application.rb — l'authentification de l'espace équipe protège Mission Control.
# Teams::BaseController : contrôleur parent de l'espace équipe (namespace `teams`, comme aujourd'hui), créé en V0.
config.mission_control.jobs.base_controller_class  = "Teams::BaseController"
config.mission_control.jobs.http_basic_auth_enabled = false
```

Les tables `solid_queue_*` sont créées par une migration de la base principale (et non par un `db/queue_schema.rb` sur une base séparée, que génère Rails par défaut).

## 7. Comment vérifier que la décision est respectée

Livrés en V0, **bloquants en CI** :

```ruby
# test/integration/health_check_test.rb
require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "/up answers 200 without authentication" do
    get rails_health_check_path

    assert_response :ok
  end
end
```

```ruby
# test/jobs/recurring_tasks_test.rb
require "test_helper"

class RecurringTasksTest < ActiveSupport::TestCase
  test "every recurring task of production points to an existing job or command" do
    tasks = Rails.application.config_for(:recurring, env: "production")

    assert_not_empty tasks
    tasks.each do |key, options|
      task = SolidQueue::RecurringTask.from_configuration(key, **options)
      assert task.valid?, "#{key} : #{task.errors.full_messages.to_sentence}"
    end
  end
end
```

(Vérifié le 2026-09-24 sur l'application actuelle : la tâche de purge est valide, et une tâche pointant vers une classe inexistante est refusée avec « Class name doesn't correspond to an existing class ».)

```ruby
# test/integration/mission_control_access_test.rb
require "test_helper"

class MissionControlAccessTest < ActionDispatch::IntegrationTest
  test "the jobs dashboard is closed to anyone outside the team" do
    get "/teams/jobs"

    assert_response :redirect
  end
end
```

- Un test vérifie que `config/puma.rb` charge `plugin :solid_queue` **sans condition** : une ligne `if ENV[...]` sur ce plugin fait échouer la CI.
- **Premier déploiement de recette** : `/up` répond 200 en HTTPS ; un job mis en file depuis la console de recette apparaît comme terminé dans `/teams/jobs`, et un job qui lève une exception y apparaît en échec.
