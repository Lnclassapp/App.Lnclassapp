# Prompt commun des vagues

> Donné à chaque session enfant avec sa vague (niveau, matière, séries, liste des leçons, slug). Pour un niveau autre que la Tle, remplacer `Tle`/`tle-<série>` par le niveau visé.

La session enfant est d'une vague du programme `contenus-v3-tous-niveaux` (feuille de route : docs/chantiers/contenus-v3-tous-niveaux/feuille-de-route.md, décisions D1–D5 tranchées par le porteur le 2026-10-31). Suis CLAUDE.md et docs/workflows/README.md. Réponses courtes, en français.

Modèle à reprendre exactement : le programme `contenus-3e-autres-matieres` (feuille-de-route, journal) et ses vagues (`contenus-3e-svt`, `contenus-3e-physique-chimie`, …) ; maths : `refonte-contenus-maths` (ADR-0116, UDR-0141) ; figures : ADR-0117, UDR-0142 ; entraînement : `je-m-entraine-dans-la-fiche`. Prompt : docs/contenus/prompt-redaction-lot.md. Sources : `leçons/` (v1, à réécrire entièrement, jamais fusionner) et docs/contenus/progressions-2026-2027/.

Exigences par leçon (format lnclass.course-tree v3) : fiche par notion en 4 blocs (À retenir, La méthode, Un exemple corrigé, Le piège à éviter), figures paramétrées des sortes existantes, 1 exercice par notion (≥ 5 questions), 4 problèmes, corrections avec la méthode de raisonnement détaillée, « Je m'entraîne » comme en 3ème. `level_name` "Tle", `material_name` et `series_name` exacts. Une leçon commune à plusieurs séries est écrite une fois, puis déclinée en un fichier/cours par série (un cours = une série). Le fichier v3 remplace le fichier v1 du même intitulé dans docs/contenus/lecons-traitees/tle-<série>/<matière>/ (D4). Chaque fichier passe `ruby script/contenus/valider.rb` sans avertissement ; relecture indépendante par un sous-agent distinct de l'auteur. Les leçons restent en brouillon : note dans le journal du chantier ET dans la section « À faire valider par un enseignant » de docs/chantiers/contenus-v3-tous-niveaux/journal.md les points à faire valider. Mets à jour la section du niveau dans docs/contenus/README.md.

Si une figure exige une sorte ou un paramètre nouveau : amendement d'ADR d'abord, captures 390 px + ordinateur envoyées au porteur (jamais commitées), tests, code dans la même PR. Sinon, aucun code.

Livraison : chantier docs/chantiers/<slug>/ (memo avec `Programme : contenus-v3-tous-niveaux`, prd, plan, journal), branche feature/<slug>, 1 commit par lot, 40 commits max, PR prête (pas brouillon) vers `Develop` avec la ligne de preuve `bin/ci-quiet` ; sous-agents de revue seulement si du code est touché (règles CLAUDE.md). Ne fusionne pas toi-même. Ajoute ta ligne dans « Fin de vague » du journal du programme (dans ta PR). Ne supprime jamais de données de production. À la fin, réponds en une ligne : niveau, matière, nombre de leçons, PR.

Contrat de session (docs/workflows/contrat-de-session.md) : ta PR, tu la surveilles d'office jusqu'à ce qu'elle soit prête. Ne finis jamais sur une question : une décision réversible (libellé, choix de figure, ordre) est appliquée dans sa version prudente et notée dans `## À trancher` du journal de ton chantier ; une décision non réversible (donnée à supprimer, fait ou chiffre incertain à publier) y est écrite avec options et recommandation, et seul ce point attend. Aucun identifiant ni secret à demander : les comptes de recette sont ceux du jeu standard.

## Modèles et sobriété (décision du porteur, 2026-11-01, à partir de la 1ère)

- La session de vague tourne sur **Sonnet** : cadrage du chantier, rédaction, déclinaisons, contrôles, PR.
- La **relecture indépendante** de chaque leçon se fait avec un sous-agent **Opus** (`model: "opus"`), distinct de l'auteur ; puis le **validateur pédagogique** (`.claude/agents/validateur-pedagogique.md`, Opus, ni auteur ni relecteur) tranche chaque point délicat (philosophie, chiffres, faits, programme, barème) : il corrige ou confirme avec sa source, rien ne reste à faire valider par un enseignant.
- Les **vérifications de CI** (`bin/ci-quiet`, verdict) passent par l'agent `verificateur-ci` (**Haiku**).
- Au plus 3 sous-agents en même temps. Les leçons de Tle fusionnées (`docs/contenus/lecons-traitees/tle*/`) servent de modèle.
- Les tests qui lisaient les v1 de Tle D lisent désormais `test/fixtures/files/lecons_v1/` : remplacer une v1 dans `docs/` ne casse plus rien ; ne touche pas aux tests.
