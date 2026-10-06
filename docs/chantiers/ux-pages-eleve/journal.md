# Journal — Amélioration UI/UX des pages élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-06 | Pas de mode focus en session : la barre du bas reste visible | Décision du porteur | Non |
| 2026-10-06 | Le filtre du catalogue s'affiche aussi sur téléphone | 19 cours font 4 560 px à 390 sans moyen de trier (décision du porteur) | UDR-0077, amendée |
| 2026-10-06 | « Refaire » au lieu de « Commencer » sur un exercice déjà fait | « Commencer » sur un exercice fait 6 fois trompe l'élève (décision du porteur) | UDR-0015, amendée |
| 2026-10-06 | Pas de 4e onglet « Annonces » dans la barre du bas : elles restent sur l'Accueil | Décision du porteur | Non |
| 2026-10-06 | Petits badges en 12 px au lieu de 11 | Illisibles sur téléphone | UDR-0005, amendée |
| 2026-10-06 | Sous 640 px, cartes bord à bord ; marge d'écran et rembourrage de carte à 16 px | 40 px perdus de chaque côté (décision du porteur) | UDR-0005, amendée |
| 2026-10-06 | Accueil sous lg : ni « Bonjour » ni bouton d'aide ; « Besoin d'aide ? » dans le menu du compte ; carte de classe en tête, coins du haut arrondis ; avatar collé à droite | Décision du porteur | UDR-0061, amendée |
| 2026-10-06 | « Mes matières » sous 640 px : abréviations (Math, PC, HG, Philo), sans « Tous les cours », titre remonté | Décision du porteur | UDR-0069, amendée |
| 2026-10-06 | Lot 10 : connecté, `/aide` se lit dans le shell du rôle ; visiteur et enseignant en attente gardent la page d'entrée. Liens « Vos données » à 48 px (18 px avant) | L'élève quittait son application pour lire la FAQ | UDR-0061, amendée |
| 2026-10-06 | Lot 10 : la page « Accès interdit » n'est pas touchée. La mettre dans le shell revient sur la règle « une page d'erreur se rend toujours dans le layout application » | Règle que le porteur rattache à l'ADR-0026 et à l'ADR-0028. Ses liens font déjà 48 px. Le porteur place le point au backlog (2026-10-06) | Backlog : `erreurs-dans-le-shell` |
| 2026-10-06 | Lot 11 : tutoiement de l'élève sur le profil, ses modales et ses messages, par des clés `_student` (`tone_t`) ; vouvoiement inchangé pour les autres rôles ; erreurs des formulaires sans pronom, pour tous | Charte §1, UDR-0063 et UDR-0064 : l'espace élève tutoie. Le profil sert à tous les rôles, et les erreurs viennent de DTO communs | UDR-0041, amendée |
| 2026-10-06 | Lot 11 : chez l'élève, les quatre actions du profil en `secondary`, taille `md` (48 px) ; « Changer mon PIN » quitte `primary` | Trois styles, dont des boutons de 40 px ; le profil n'a pas d'action principale (R1) | UDR-0041, amendée |
| 2026-10-06 | Deuxième passe : chaque point de l'audit est d'abord cherché sur `Develop` ; cinq étaient déjà livrés par la PR #186, deux déjà tranchés par une UDR | Demande du porteur : « vérifie avant d'implémenter que ces changements ne sont pas encore faits » | Non |
| 2026-10-06 | Point 13 : « Tous les cours » retiré à toutes les tailles, « Toutes les annonces » retiré de l'accueil élève | Demande du porteur ; l'onglet Cours mène au catalogue, et les annonces restent sur l'Accueil (pas d'onglet) | UDR-0069 et UDR-0071, amendées |
| 2026-10-06 | Point 13 : toutes masquées, la section des annonces reste rendue avec `hidden` ; toast « Elle n'apparaît plus sur ton accueil. » | « Annuler » remplace la section : sans elle, l'annulation ne se verrait pas sur l'accueil ; l'ancien toast renvoyait vers une page qui n'est plus liée | UDR-0071, amendée |
| 2026-10-06 | Point 14 : chez l'élève, toute page autre que l'Accueil porte un retour « Accueil » (Catalogue, Ma classe, Annonces) | Demande du porteur ; exception à « les destinations de la navigation n'ont pas de retour », pour l'élève seulement | UDR-0054, amendée |
| 2026-10-06 | Point 16 : « ton enseignant » au lieu de « ton professeur » (code de classe, FAQ) | Le reste de l'espace élève et le glossaire disent « enseignant » | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le premier audit, sans données, n'a vu ni le débordement de Ma classe ni la casse des formules : il faut auditer avec des titres longs et des sessions jouées (`db/seeds/demo/saint_michel.rb`).
- Le scratchpad est effacé à chaque reprise de session : le script d'audit vit dans `tmp/audit/audit.rb` (ignoré par git).
- Le seed de démo cherchait la DRENA `tiassale` : le slug réel est `drena-tiassale` (préfixe de l'ADR-0066). Il cassait sur une base neuve ; il lit désormais `Entities::School::Drena.slug_for("Tiassalé")`. Il passe aussi par `bin/rails db:seed` d'abord : sans les DRENA, rien ne se crée.
- Une sonde qui compare `scrollWidth` à `innerWidth` ne voit pas un débordement en mobile émulé : la fenêtre s'élargit avec la page. Il faut comparer `innerWidth` à la largeur demandée.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La règle « une page d'erreur se rend toujours dans le layout application » n'est écrite que dans `RendersResult` (`layout: "application"`) et dans l'en-tête des vues `errors/` ; le texte de l'ADR-0026 et de l'ADR-0028 ne la contient pas.
- Chaque worktree a sa propre base de développement (`app_lnclassapp_development_<worktree>`) : la démo se recharge par `bin/rails db:prepare`, `bin/rails db:seed`, puis `bin/rails runner db/seeds/demo/saint_michel.rb` (≈ 15 min).
- Le logo de l'en-tête du shell fait 36 px de haut, sous la cible de 44 px : hors des lots 10 et 11, noté ici.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Catalogue : Leçon 1 avant Leçon 2 | La table `courses` n'a pas de rang : il faut une migration | À ouvrir |
| Résultat : nommer la lacune et renvoyer vers sa fiche | `SessionResultQuery` ne porte pas la lacune | À ouvrir |
| Cours : avancée et lacune par fiche ; Catalogue : avancée sur la carte | Demandent une lecture d'avancée par fiche et par cours | À ouvrir |
| Annonces de l'élève : la page n'est plus liée ; une annonce masquée ne se réaffiche qu'avec « Annuler » | Conséquence acceptée du point 13 (pas d'onglet, pas de lien) | À décider par le porteur |
| « Mon historique » lié seulement depuis l'écran d'attente | Choix de navigation pour l'élève qui a une classe | À décider par le porteur |
| « Accès interdit » et « Page introuvable » dans le shell d'un compte connecté | Revient sur la règle des pages d'erreur dans le layout application : amendement de l'ADR-0026 | `erreurs-dans-le-shell` (backlog) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
