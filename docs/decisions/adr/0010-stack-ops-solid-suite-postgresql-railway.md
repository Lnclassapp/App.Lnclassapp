# ADR-0010 : Infrastructure Native Rails 8 — Solid Suite (Queue, Cache, Cable) & Déploiement PaaS Railway
<!-- index
titre: Infrastructure native Rails 8 — Solid Suite (Queue, Cache, Cable) & Railway
statut: Accepté — *amendé par [0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md), complété par [0047](./0047-stockage-objet-s3-sur-railway.md)*
problematique: Abandonner Redis et Sidekiq au profit des tables SQL de la Solid Suite, réduisant les coûts et simplifiant le déploiement.
-->

| | |
|---|---|
| **Statut** | Accepté — *en production (schémas Solid intégrés à PostgreSQL)* |
| **Date** | 2026-07-25 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |
| **Amendé par** | [ADR-0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) : §3.1 (worker sans condition) et §5 (Thruster requis) |
| **Complété par** | [ADR-0047](./0047-stockage-objet-s3-sur-railway.md) : stockage de fichiers sur un bucket Railway compatible S3 |

---

> ✅ **Ambiguïté tranchée le 2026-09-18.** Le champ Statut d'origine indiquait « configuration Kamal active », en contradiction avec la décision § 3.4 et les notes § 5. L'arbitrage est rendu : **le déploiement est assuré par GitHub et Railway**. Kamal n'est pas utilisé — la gem reste au `Gemfile` sans rôle opérationnel. Tout le reste de cet ADR (Solid Queue / Cache / Cable sur PostgreSQL, suppression de Redis) demeure en vigueur.

## 1. Contexte et problématique
Dans l'architecture Rails traditionnelle (jusqu'à Rails 7), le déploiement d'une application professionnelle nécessitait la gestion de plusieurs infrastructures distinctes :
* Un serveur Web (Puma) exécutant l'application Rails.
* Un serveur de base de données (PostgreSQL ou MySQL).
* Un serveur **Redis** en mémoire pour stocker les fragments de cache, les sessions Action Cable (WebSockets en temps réel) et les files d'attente d'arrière-plan (via des gems comme **Sidekiq** ou Resque).

Cette multiplication d'infrastructures présentait plusieurs inconvénients lourds pour une startup ou une plateforme régionale comme Lnclass :
* **Coût d'hébergement accru :** Louer et maintenir une instance Redis managée hautement disponible coûte cher et ajoute un point de défaillance supplémentaire.
* **Complexité DevOps :** Synchroniser les déploiements entre le code Rails, les workers Sidekiq et la mémoire Redis complexifie le pipeline CI/CD et l'onboarding d'un développeur local.

---

## 2. Moteurs de décision
* **Simplicité Opérationnelle ("One Database to Rule Them All") :** Conserver un écosystème où une seule base de données relationnelle (PostgreSQL) gère l'ensemble des besoins de l'application.
* **Réduction des Coûts d'Hébergement :** Éliminer la facture et la maintenance de Redis en s'appuyant sur les performances modernes des disques SSD NVMe et de PostgreSQL.
* **Déploiement GitOps Automatisé :** S'appuyer sur l'hébergeur PaaS **Railway** et ses GitHub hooks pour déclencher automatiquement des déploiements fluides à chaque push sur la branche principale, simplifiant drastiquement l'infrastructure.

---

## 3. Décision
Nous avons pris la décision de basculer à 100% sur la **Solid Suite** native de Rails 8, adossée à notre base de données PostgreSQL principale :
1. **Solid Queue :** Remplace Sidekiq. Les tâches en arrière-plan (ex: envoi de SMS de confirmation, calculs lourds d'agrégation de classe) sont stockées dans les tables SQL `solid_queue_*`. Un processus de worker léger intégré à Puma dépile les tâches.
2. **Solid Cache :** Remplace Redis pour Rails.cache. Les fragments de vues et calculs de progression mis en cache sont persistés dans la table SQL `solid_cache_entries`.
3. **Solid Cable :** Remplace l'adaptateur Redis d'Action Cable pour gérer les notifications instantanées (toasts, mises à jour Turbo Stream broadcastées) via la table `solid_cable_messages`.
4. **Déploiement Railway :** L'application est poussée sur GitHub et déployée automatiquement via les Webhooks natifs de Railway, en s'appuyant sur leur infrastructure managée plutôt que sur Kamal.

---

## 4. Conséquences

### 🟢 Positives
* **Économies Financières Radicales :** Zéro serveur Redis à louer ni à surveiller.
* **Développement Local En 1 Clic :** Un développeur n'a besoin que de PostgreSQL installé sur sa machine pour faire tourner l'intégralité des fonctionnalités en temps réel et des jobs asynchrones.
* **Robustesse Transactionnelle :** Les jobs d'arrière-plan bénéficient des transactions ACID de PostgreSQL (impossible de perdre un job lors d'un crash mémoire).

### 🔴 Coûts consentis
* **Charge Supplémentaire sur PostgreSQL :** La base de données gère à la fois les requêtes relationnelles et les I/O de cache/queue. Cependant, avec l'indexation de Rails 8 et la séparation de nos requêtes de lecture (ADR-0006), PostgreSQL encaisse cette charge sans aucune difficulté jusqu'à plusieurs millions de requêtes par jour.

---

## 5. Notes d'implémentation

Extrait du `Gemfile` officiel de Lnclass validant l'adoption de la Solid Suite et des outils de déploiement :
```ruby
# Gemfile
# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Le déploiement est géré de manière transparente par les hooks GitHub de Railway.
# Kamal et Thruster ne sont pas requis dans cette configuration PaaS.
```

Extrait de `config/cache.yml`, `config/queue.yml` et `config/cable.yml` reliant les moteurs à PostgreSQL :
```yaml
# config/queue.yml
default: &default
  adapter: solid_queue

development:
  <<: *default

production:
  <<: *default
```
