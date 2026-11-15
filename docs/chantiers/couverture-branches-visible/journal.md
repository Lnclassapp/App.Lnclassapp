# Journal — couverture-branches-visible

## 2026-11-15

- Piste retenue : réutiliser les tests unitaires que le niveau `pr` joue déjà, en leur rendant la mesure. Aucune tâche ajoutée, aucun test de plus.
- Piste écartée : lancer toute la suite avec mesure au niveau `pr` (déplace le seuil global, contraire à l'ADR-0107).
- Piste écartée : une tâche GitHub sur les PR vers `Develop` (pas de CI GitHub vers `Develop`, ADR-0069).
- Faux positifs : un sous-ensemble de la suite ne peut que sous-estimer la couverture. Une branche signalée peut être jouée par un test hors du périmètre (ligne 99 de `courses_controller.rb` sur la PR #627). Jamais l'inverse. D'où l'avertissement.
- Piège corrigé en route : une clé de branche SimpleCov est `[type, id, ligne début, colonne, ligne fin, colonne]` ; la ligne est le 3e élément, pas le 2e.
- Preuve rejouée dans un worktree à `5f6d5bf4` : `bin/ci-quiet` affiche l'avertissement des trois branches (les deux du train #631 comprises). Les autres étapes y sont rouges pour des raisons de poste (pas de Chrome, locale), sans lien.

## À trancher

- **Bloquer ou avertir ?** Option prudente appliquée : avertir seulement, parce que le sous-ensemble produit des faux positifs (1 sur 3 sur le cas réel). Pour bloquer, il suffit de retirer le `|| true` de la commande de l'étape dans `bin/ci-quiet` ; à décider après quelques semaines de relevé du taux de faux positifs.
