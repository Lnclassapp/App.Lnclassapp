# Memo — La CI rejouée dans le cloud Claude

| | |
|---|---|
| **Type de cycle** | feature (outillage) |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `Develop` (demande du porteur) |

---

## Le problème

Demande du porteur (2026-10-05) : installer un runner pour exécuter la CI du projet, déclenché à chaque pull request vers `Develop`, sur le cloud de Claude, depuis une routine qui redémarre la machine si elle est éteinte.

Un runner GitHub auto-hébergé dans une session Claude Code cloud a été essayé, puis écarté (voir « Ce que le grill a révélé »). Ce qui tient : une **routine** qui ouvre une session neuve, préparée par un **hook SessionStart**, joue `bin/ci` sur chaque PR ouverte vers `Develop` et poste le résultat en commentaire.

Contexte : depuis le 2026-10-04, GitHub n'attribue plus de runner aux jobs du dépôt et la CI est coupée par l'interrupteur `CI_ENABLED` ([ADR-0069, amendement du 2026-10-04](../../decisions/adr/0069-ci-en-un-job-sur-les-pr-et-promotions-par-preuve.md)). **Pendant la coupure, la preuve d'une PR est `bin/ci` joué, écrit dans la PR** : c'est exactement ce que la routine produit, à chaque nouveau commit de tête, sans qu'un agent ait à y penser.

## Pour qui

L'équipe et les agents qui ouvrent des PR vers `Develop` : un verdict `bin/ci` complet sur chaque commit de tête, pendant la coupure de la CI GitHub, puis à côté d'elle quand elle reprendra.

## Pourquoi maintenant

La CI GitHub ne tourne plus depuis le 2026-10-04 : chaque PR dépend aujourd'hui de la discipline de l'agent qui l'ouvre pour jouer `bin/ci` et l'écrire.

## Hors périmètre

- **Remplacer la CI GitHub.** Le statut `ci` que les branches protégées attendent reste celui de `.github/workflows/ci.yml` : les outils GitHub d'une session cloud ne savent pas écrire un statut de commit.
- **Un runner GitHub auto-hébergé.** Déjà écarté par l'ADR-0069 ; sur une machine permanente (VPS avec Docker), ce serait un autre chantier.
- **Publier la preuve d'arbre sur `ci/preuves`** (`script/ci/prove`, ADR-0069 §8). Elle ne sert que quand la CI GitHub tourne, et la publier depuis une routine sans agent qui suit la PR est une décision du porteur, pas de ce chantier.
- Toute modification de `config/ci.rb` ou de `bin/ci` : le cloud joue exactement les mêmes étapes qu'un développeur.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un runner GitHub peut-il vivre dans une session cloud ? | Non. Le proxy de la session ne sert sur GitHub que le dépôt Lnclass : `actions/checkout`, `ruby/setup-ruby`, `actions/setup-node`, `actions/cache` répondent 403. Chaque job échouerait à sa première étape. | On ne passe pas par GitHub Actions : la session joue `bin/ci` elle-même. |
| Qui inscrit le runner ? | Le jeton d'inscription vient de la page d'administration du dépôt, expire en une heure, et une session ne peut pas le fabriquer. Une session neuve repart sans runner inscrit. | Même raison : pas de runner. |
| Une routine peut-elle partir sur un événement de PR ? | Les routines créées depuis une session partent sur un horaire (au mieux toutes les heures) ou à la demande. Un déclencheur GitHub s'ajoute dans l'interface des routines de claude.ai. | Routine horaire + déclencheur GitHub facultatif ; le script est idempotent par SHA. |
| L'environnement d'une session neuve ressemble-t-il à celui de GitHub ? | Pas sans aide : aucune locale (Ruby lit les sources en US-ASCII, trois gardes tombent), `origin/Develop` d'il y a des heures (la garde du budget système compte tous les fichiers de `Develop` comme touchés), PostgreSQL 16 qui réécrit `db/schema.rb`. | Le hook pose `LANG=C.UTF-8` et remet `db/schema.rb` ; `cloud-check` rafraîchit `origin/Develop` et revient sur sa branche en abandonnant ce que le run a réécrit. |
| « Si la machine est éteinte, la redémarrer » ? | Chaque déclenchement ouvre une session neuve : il n'y a pas de machine à garder allumée. | Le hook SessionStart prépare la session à chaque fois. |
| Que manque-t-il à une session neuve pour `bin/ci` ? | Ruby 3.4.9 (3.3.6 installé), Node 24 (22 installé), PostgreSQL arrêté et sans rôle `dev-rails`, un chromedriver 147 pour un Chromium 141. | `.claude/hooks/session-start.sh` installe et démarre tout, puis lance `bin/setup --skip-server`. |
| Tester la tête de la PR ou sa fusion ? | GitHub teste la fusion (`refs/pull/N/merge`). | `script/ci/cloud-check` teste la fusion, ou la tête si GitHub n'en a pas (conflit). |
| Un commit déjà vérifié est-il rejoué à chaque heure ? | Non : le commentaire porte `<!-- ci-cloud:<sha de tête> -->`, la routine saute un SHA déjà commenté. | Pas de commentaires en double. |

## Cas limites identifiés

- PR en conflit avec `Develop` : pas de `refs/pull/N/merge`, la tête est testée et le commentaire le dit.
- PR en brouillon : vérifiée comme les autres.
- PR qui ne touche que `docs/` : vérifiée quand même (`bin/ci` complet) ; coût accepté.
- Plusieurs PR en attente : la routine les traite l'une après l'autre, au plus 3 par passage, les plus récentes d'abord.

## Questions encore ouvertes

- Ajouter, dans l'interface des routines, le déclencheur GitHub « pull request » pour ne pas attendre l'heure suivante.
