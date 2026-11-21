# Retour arrière

> Comment revenir à la version précédente de l'application sur le VPS Hostinger, quand c'est sans risque, quand c'est impossible, et que faire quand un déploiement n'est pas parti.
> Les trois environnements tournent sur le VPS depuis l'[ADR-0140](../decisions/adr/0140-hebergement-hostinger.md) ; GitHub les déploie à chaque push ([ADR-XXXX-deploiement-continu-hostinger](../decisions/adr/XXXX-deploiement-continu-hostinger.md)). Railway n'existe plus.

---

## 1. Ce qui se passe à un déploiement

Chaque push sur `Develop`, `Staging` ou `main` lance le workflow *Déploiement* ([`configuration.md`](configuration.md) §2) : `Develop` → develop, `Staging` → staging, `main` → production. Dans l'ordre :

1. **Preuve de l'arbre** (`Staging` et `main`) : le `ci` vert de l'arbre, sinon rien n'est envoyé.
2. **Construction** de l'image `lnclass-app:<sha>` sur le VPS (`deployer.py construction`). Une image déjà construite pour ce SHA est réutilisée (« déjà là »).
3. **Démarrage** du projet de l'environnement avec cette image. Au démarrage, le conteneur joue `bin/rails db:prepare db:seed` : les migrations passent sur la base de l'environnement.
4. **Contrôle** de `/up` sur le site de l'environnement, jusqu'à un 200.

Il en découle la seule règle à retenir :

> **Revenir à l'image précédente ne défait pas les migrations.** L'ancienne image tourne sur la base telle que la nouvelle l'a laissée.

## 2. Revenir à l'image précédente

1. Relever le SHA précédent : l'historique des runs du workflow (onglet *Actions › Déploiement*), ou `git log --first-parent origin/main` pour la production.
2. *Actions › Déploiement › Run workflow* : choisir la branche de l'environnement (`main` pour la production) et coller le SHA complet dans `sha`. Un run manuel qui attend derrière un déploiement en cours est remplacé si un push arrive entre-temps (règle de `concurrency` de GitHub) : vérifier qu'il est bien parti, sinon le relancer.

L'image `lnclass-app:<sha>` est encore sur le VPS : la construction répond « déjà là » et le démarrage est rapide. Le workflow a toujours le code de déploiement de la tête de la branche ; seule la révision déployée est celle du SHA.

Preuve expirée (arbre testé il y a plus de 30 jours, `Staging` et `main`) : le workflow refuse. Lancer alors `python3 -I script/hostinger/deployer.py …` à la main, depuis une session Claude Code (usage en tête du script).

Après un retour arrière, la branche porte toujours le code fautif : **le prochain push la redéploie**. Le correctif suit le chemin normal, `Develop` → `Staging` → `main` ([`conventions.md`](conventions.md) §3).

## 3. Quand c'est sans risque

Le retour arrière est sûr quand **toutes** les migrations jouées depuis l'image précédente sont additives :

- une table ou une colonne **ajoutée**, nullable ou avec une valeur par défaut : l'ancien code ne la lit pas ;
- un index ajouté ;
- des données **recopiées** vers un nouvel endroit, l'ancien restant en place.

C'est le cas de toute première livraison d'une migration en deux temps ([`conventions.md`](conventions.md) §7). Pour savoir ce que la dernière promotion a joué, il suffit de comparer `db/migrate/` entre les deux commits déployés, ou de lire la liste des fichiers de la PR vers `main`.

**Avant de revenir en arrière, il faut vérifier les contraintes ajoutées.** Une colonne devenue `NOT NULL` ou une nouvelle contrainte `CHECK` peut refuser les écritures de l'ancien code, qui ne connaît pas la colonne. Dans ce cas, le retour arrière est possible, mais certaines écritures échoueront jusqu'au correctif.

## 4. Quand c'est impossible

Le retour arrière ne répare rien quand la livraison a **supprimé ou renommé** ce que l'ancien code lit : `remove_column`, `remove_columns`, `drop_table`, `remove_reference`, `rename_column` ou `rename_table`. L'ancienne image démarre, puis échoue sur la première requête qui touche la colonne disparue.

La garde `test/guards/migration_rules_test.rb` empêche le cas le plus dangereux : recopier une colonne et la supprimer dans la même livraison, comme la PR #268 avec `teacher_profiles.material_id`. Une suppression seule reste permise, parce que l'image précédente ne lisait plus la colonne. Le retour arrière d'une livraison qui ne fait que supprimer reste donc sûr, **à une image près** : revenir deux livraisons en arrière ne l'est plus.

Si la suppression est déjà jouée et que l'ancien code est indispensable :

1. **Corriger en avant**, c'est-à-dire livrer un correctif sur le code actuel. C'est la voie par défaut.
2. **Restaurer la base** depuis une sauvegarde de la base (voir ADR-0140 pour les sauvegardes du VPS). Toutes les écritures faites depuis la sauvegarde sont perdues.

`down` dans une migration ne sert pas de retour arrière en production : aucune commande du déploiement ne le joue, et il ne rend pas les données supprimées (`RemoveMaterialIdFromTeacherProfiles#down` rajoute la colonne, mais la remplit par déduction).

## 5. Quand Railway met les déploiements en pause

Historique : Railway n'héberge plus Lnclass depuis le 2026-11-17 ; plus de pause de déploiement à gérer.

## 6. Quand une fusion ne déclenche aucun déploiement

Un push sur `Develop`, `Staging` ou `main` déploie, sauf s'il ne touche que de la documentation hors `docs/contenus/`. Après chaque fusion dans `Staging` ou `main` :

1. **Vérifier le run** *Déploiement* dans l'onglet *Actions* : vert jusqu'au pas `/up`.
2. **S'il est rouge**, lire l'étape en échec. Sans preuve de l'arbre, la raison est écrite dans le journal et rien n'a été envoyé au VPS. Pour un secret manquant, voir [`configuration.md`](configuration.md) §1.
3. **S'il n'est pas parti**, le lancer à la main : *Run workflow* avec le SHA de la fusion (§2).

## 7. Avant chaque promotion vers `main`

- [ ] Les migrations de la livraison sont additives, ou chaque suppression porte sur une colonne que l'image en ligne ne lit plus (`bin/rails test test/guards/migration_rules_test.rb`).
- [ ] Le SHA en ligne est noté (dernier run vert du workflow *Déploiement* sur `main`) : c'est la cible du retour arrière en cas de problème.
- [ ] Après la fusion : le run *Déploiement* de `main` est vert, `/up` compris (§6).
