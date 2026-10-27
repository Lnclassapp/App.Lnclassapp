# Journal — La boucle pédagogique perd parfois un clic du Référentiel

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Le correctif attend `html[data-turbo-preview]` absent, plutôt que de désactiver le cache Turbo dans le test | Le cache est le comportement réel de l'application ; le test doit l'emprunter, en agissant sur la page et non sur sa copie | non |

## Ce qui a dérapé

- Première hypothèse (cliquer dans la copie suffit à perdre le clic) réfutée : Référentiel ralenti de 1,5 s, test vert.

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. **Chaîne** : `click_referential` (`test/system/boucle_pedagogique_test.rb:429`) → `navigate_to` (l. 423) clique le lien du Référentiel puis `assert_current_path` → Turbo 8.0.23 pousse l'URL **au début** de la visite et, la page étant en cache (trois visites plus tôt), affiche sa copie (`html[data-turbo-preview]`) → `assert_current_path` passe sur la copie → `within("#team_referential") { find(drenas).click }` trouve la tuile **dans la copie** → si la vraie page la remplace entre l'appui et le relâchement de la souris, le clic est envoyé à leur ancêtre commun, pas au lien : aucune visite → l. 432 lit encore `/teams/referential`.
2. **Cause** : `navigate_to`, ligne 425, tient l'URL pour la preuve que la page est là. Avec Turbo, l'URL change avant la page.
3. **Pourquoi rien ne l'a vu** : la fenêtre (remplacement de la copie pendant un clic) dure quelques millisecondes ; elle ne s'ouvre que sous charge, quand la réponse arrive pile pendant le clic.

En une phrase sans les mots du symptôme : l'aide de navigation du test agit dès que l'adresse change, alors que Turbo change l'adresse avant d'afficher la page demandée.

**Trou de test comblé** : `navigate_to` attend que la page ne soit plus une copie (`html[data-turbo-preview]` absent) ; aucune action ne part plus d'une copie. La scène qui perdait le clic est verte avec le nouveau `navigate_to`, rouge avec l'ancien.

**Effets de bord écartés** : l'attente est nulle quand Turbo n'a pas de copie (première visite) ; le test entier reste à ≈ 31 s.

**À retenir** : sous Turbo, `assert_current_path` après un clic ne prouve pas que la page est là ; elle peut encore être la copie en cache.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Même schéma (`assert_current_path` après un clic Turbo, puis un clic) possible ailleurs dans `test/system` | Hors de ce bug ; aucun autre échec observé | à ouvrir si un autre test le montre |
