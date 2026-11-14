# Journal — Les 9 leçons de SVT de 1ère A1 et A2

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Leçons écrites dans `1ere-a1/`, copiées dans `1ere-a2/` avec la seule `series_name` changée (même rang, même `subtitle`) | Progressions A1 et A2 identiques ; pas de série « A » en 1ère | Non |
| 2026-11-02 | Aucune leçon reprise de la 1ère D (#435) | Aucun des 9 intitulés n'y figure | Non |
| 2026-11-02 | Auteurs Sonnet, relecteurs Opus (au plus 3 sous-agents) ; Ruby 3.4.9 installé dans le conteneur pour `valider.rb` | Section « Modèles et sobriété » du prompt de vague ; le conteneur n'avait que Ruby 3.3 | Non |

## Ce qui a dérapé

- **Erreurs de fond trouvées seulement en relecture Opus** : « 23 paires » contredisant la méthode (L3) ; DIU présenté sans hormones, alors que des DIU hormonaux existent (L5) ; glycogène des muscles dit fournir le glucose aux muscles via le sang (L9) ; donnée de CO₂ incohérente avec le rapport respiration/fermentation (L8) ; feu rouge donné comme réflexe conditionnel (L1) ; Rokia / Adjoua avec deux durées de cycle différentes selon les parties (L4) ; « quatrième enfant » pour un couple de deux enfants (L7). La relecture indépendante reste indispensable.
- **Recopies entre fiche, exercice noté et entraînement** : relevées dans les 9 leçons et corrigées en relecture (déjà noté en Tle A).
- **Questions qui ne tiennent pas seules** (allèles, dominance, notation définis ailleurs) : L6, L7, L9. Corrigé en relecture.
- **Corrections qui citent une étape inexistante** : L1, L5, L6, L9.
- **Étape manquante** : la section « Modèles et sobriété » du prompt de vague n'était pas dans la branche locale avant `git merge --ff-only origin/Develop` ; la session était sur un clone en retard.

## Ce qu'on a appris sur la codebase

- Le conteneur n'a que Ruby 3.3 ; `valider.rb` exige 3.4 (`it`) : installer 3.4.9 avec `rbenv install 3.4.9` (≈ 5 min), puis `LANG=C.UTF-8` (sinon `JSON.parse` échoue sur l'encodage).
- Rails ne démarre pas sans bundle : le contrôle d'entraînement (`NotionPractice.errors_for`) est joué en Ruby pur avec `activesupport` seul et les fichiers de `app/domain/entities` chargés dans l'ordre (`statement_blocks`, `content_node`, `notion_practice`).
- Les questions `fill_blank` à plusieurs cases et les indices ne sont acceptés que dans « Je m'entraîne » (`practice`), pas dans les exercices ni les problèmes.
- Aucune sorte ne dessine un caryotype, une coupe d'ovaire, un échiquier en tableau ni une courbe de température (valeurs décimales proches) ; la `plate` `female_reproductive_system` et la `plate` appareil digestif servent pour L4, L5 et L9.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague P6) — **soldé le 2026-11-14 par le validateur pédagogique** ([`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur)) | Programme officiel détaillé non accessible ici | — (avant publication) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-02 |
| **PR** | #440 (`feature/contenus-1ere-a-svt` vers `Develop`) |
| **ADR produits** | aucun |
| **UDR produits** | aucune |
