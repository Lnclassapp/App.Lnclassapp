# Retour arrière

> Comment revenir à la version précédente de l'application, quand c'est sans risque, quand c'est impossible, et que faire quand Railway ne déploie plus.
> Chantier [`acceleration-du-flux`](../chantiers/acceleration-du-flux/memo.md). Les règles de déploiement viennent de l'[ADR-0052](../decisions/adr/0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) et de [`railway.json`](../../railway.json).
>
> ⚠️ **Les gestes Railway marqués « à vérifier par le porteur » viennent de la documentation de Railway, pas d'un essai sur nos projets.** Le premier retour arrière en recette (`Staging`) les confirme ou les corrige, et cette page est mise à jour à ce moment-là.

---

## 1. Ce qui se passe à un déploiement

Chaque environnement Railway déploie seul la branche qu'il suit ([`configuration.md`](configuration.md) §2) : `Staging` → recette, `main` → production. Pour chaque déploiement, `railway.json` fixe l'ordre suivant :

1. **Construction** de l'image depuis le `Dockerfile`.
2. **Pré-déploiement** : `bin/rails db:prepare db:seed`. Les migrations sont jouées sur la base de l'environnement **avant** que la nouvelle image reçoive du trafic. Pendant ce temps, l'ancienne image sert toujours, donc sur la base déjà migrée.
3. **Démarrage**, puis contrôle de santé sur `/up` (120 s au plus). Railway ne bascule le trafic qu'après une réponse 200. Une image qui ne démarre pas ne reçoit jamais de trafic, et l'ancienne continue de servir (ADR-0052 §5).

Il en découle la seule règle à retenir :

> **Revenir à l'image précédente ne défait pas les migrations.** L'ancienne image tourne sur la base telle que la nouvelle l'a laissée.

## 2. Revenir à l'image précédente

**Au tableau de bord** (documentation Railway, *Deployment Actions › Rollback*) : service de l'environnement › onglet *Deployments* › les trois points au bout du déploiement précédent › *Rollback*, puis confirmer. Railway restaure l'image et les variables de ce déploiement. — *à vérifier par le porteur.*

Points ouverts, *à vérifier par le porteur* au premier essai en recette :

- Un *Rollback* rejoue-t-il le pré-déploiement (`db:prepare db:seed`) ? S'il le rejoue, c'est sans effet : `db:migrate` ignore les migrations de la base que l'ancien code ne connaît pas, et `db:seed` ne fait rien quand l'équipe a déjà un membre (`test/config/railway_deployment_test.rb`).
- La CLI n'offre pas de commande de retour arrière documentée : `railway redeploy` reconstruit **la même** source, et `railway restart` relance **la même** image. Le retour arrière passe par le tableau de bord.

Après un retour arrière, la branche suivie (`main` ou `Staging`) porte toujours le code fautif : le prochain déploiement le remettrait en ligne. Le correctif suit le chemin normal, `Develop` → `Staging` → `main` ([`conventions.md`](conventions.md) §3).

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
2. **Restaurer la base** depuis une sauvegarde Railway (documentation Railway, *Back Up and Restore Postgres* : onglet *Backups* du service PostgreSQL › *Restore* › relire le changement préparé › *Deploy*). Toutes les écritures faites depuis la sauvegarde sont perdues. — *à vérifier par le porteur : les sauvegardes sont-elles activées sur la base de production, et à quelle fréquence ?*

`down` dans une migration ne sert pas de retour arrière en production : aucune commande du déploiement ne le joue, et il ne rend pas les données supprimées (`RemoveMaterialIdFromTeacherProfiles#down` rajoute la colonne, mais la remplit par déduction).

## 5. Quand Railway met les déploiements en pause

Le 2026-10-20, Railway a suspendu les nouveaux déploiements. Dans ce cas :

1. **Ce qui tourne continue de tourner.** Une pause bloque les nouveaux déploiements, pas l'image en ligne. — *à vérifier par le porteur, sur la page d'état de Railway au moment de la pause.*
2. **Ne rien promouvoir.** Pas de fusion vers `Staging` ni vers `main` pendant la pause : les déploiements s'accumuleraient et partiraient tous à la reprise, sans recette entre eux. Le travail continue sur les branches et sur `Develop`.
3. **Pas de retour arrière non plus**, puisqu'un *Rollback* est un déploiement. — *à vérifier par le porteur.* Si la production est cassée pendant la pause, il n'existe aujourd'hui **aucune voie de secours** : Lnclass n'a ni second hébergeur ni image prête ailleurs. En choisir une est une décision du porteur, qui demande un ADR.
4. **À la reprise**, promouvoir une seule fois, puis vérifier le déploiement : le pré-déploiement réussi, `/up` à 200 et une page connectée qui répond.

## 6. Avant chaque promotion vers `main`

- [ ] Les migrations de la livraison sont additives, ou chaque suppression porte sur une colonne que l'image en ligne ne lit plus (`bin/rails test test/guards/migration_rules_test.rb`).
- [ ] Le numéro du déploiement en ligne est noté : c'est la cible du *Rollback* en cas de problème.
- [ ] Railway déploie normalement : pas de pause en cours.
