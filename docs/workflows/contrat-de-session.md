# Contrat de session

> Toute session lancée par une autre (vague, lot, vérification) reçoit ce contrat. Il est recopié ou cité dans chaque prompt de lancement : `.claude/agents/executant-lot.md`, `.claude/skills/plan-lots/SKILL.md` (étape 5), les `prompt-*.md` des programmes.
> Origine : 23 sessions sur 123 (19 %) restées bloquées sur une question entre le 26/09 et le 5/11/2026 (« Veux-tu que je surveille la PR ? », « A ou B ? »), et des identifiants de recette redonnés dans le chat (chantier `contrat-de-session`).

## 1. Zéro question en fin de session

Une session enfant **ne finit jamais sur une question**. Elle finit sur un résultat, ou sur un blocage décrit.

| Situation | Ce que fait la session |
|---|---|
| Elle a ouvert une PR | Elle la surveille d'office (CI, revues) jusqu'à ce qu'elle soit prête. On ne demande pas « je surveille ? ». |
| Une décision **réversible** n'est pas tranchée par le memo, le PRD, l'ADR ou l'UDR (libellé, ordre, couleur, choix entre deux rendus, détail de test) | Elle applique l'option la plus prudente, ou celle que la doc recommande. Elle l'écrit dans la section `## À trancher` du `journal.md` du chantier : la question, l'option appliquée, les autres options. Puis elle continue. |
| Une décision **non réversible** : droits d'accès, données (suppression, migration), sécurité, texte métier engageant, dépense | Elle s'arrête sur ce point seulement. Elle écrit la question dans `## À trancher` avec les options et sa recommandation. Elle termine ce qui ne dépend pas de la décision et le dit dans son rapport final. |
| Il manque un accès ou un secret | Elle nomme la variable attendue (section 3) dans `## À trancher` et continue sans elle, sans simuler le résultat. |
| Elle a fini | Une ligne de rapport à l'orchestrateur : résultat, PR, SHA, nombre d'entrées ajoutées à `## À trancher`. |

Format d'une entrée de `## À trancher` :

```markdown
- [ ] 2026-11-05 · <slug ou PR> · <question en une phrase> — appliqué : <option> ; autres : <options> ; recommandé : <option>
```

Le porteur coche `[x]` et écrit sa réponse à la suite. Si sa réponse contredit l'option appliquée, elle devient une tâche de la session ou du chantier suivant.

## 2. Décisions ouvertes : avant le lancement, puis une fois par jour

**Avant le lancement.** L'orchestrateur liste dans `plan.md` (section `## Décisions ouvertes`) tout ce qu'aucun lot ne peut trancher seul. Il les pose au porteur **en un seul `AskUserQuestion`**, chacune avec une option « Recommandé », avant de lancer la moindre session enfant. Une session ne part jamais avec une décision qu'on savait ouverte.

**Une fois par jour : la boîte de décisions.** Une tâche programmée part chaque jour à 12 h (heure d'Abidjan). Elle ouvre une session qui :

1. lance `script/docs/a_trancher` sur `Develop` à jour : la commande liste les entrées non cochées de chaque `## À trancher` ;
2. y ajoute les sessions Claude Code restées bloquées sur une question (`list_sessions`, état « bloqué ») ;
3. pose le tout au porteur en un seul `AskUserQuestion` : au plus 4 questions par écran, les plus anciennes d'abord, chacune avec son option recommandée ;
4. écrit les réponses dans les journaux (commit direct sur `Develop`, documentation seule) et transmet chaque réponse à la session concernée (`send_message`) quand elle existe encore.

S'il n'y a aucune entrée ouverte, la session s'arrête sans rien demander.

## 3. Secrets : dans l'environnement, jamais dans le chat

- **Aucun secret dans un message** : ni token, ni PIN, ni code TOTP. Une session qui en reçoit un ne le recopie nulle part (fichier, commit, PR, journal) et rappelle cette règle.
- Les secrets dont les sessions ont besoin sont des **variables de l'environnement cloud Claude Code**. On les pose dans le menu de l'environnement, dans la barre de titre de la session, puis *Edit*. Une nouvelle session les reçoit.

| Variable | Sert à |
|---|---|
| `RAILWAY_API_TOKEN` | Lire l'état des services, les journaux et les environnements de PR (Railway) |
| `LNCLASS_TEAM_CONTACT`, `LNCLASS_TEAM_PIN` | Recette connectée d'un compte équipe sur Develop et Staging. Le PIN est celui de `STANDARD_TEAM_PIN`, la variable scellée de l'environnement Railway. |

- Les comptes élève, enseignant et direction de recette sont ceux du jeu standard (PIN public `2468`). Ils existent sur Develop, Staging (chantier `comptes-de-test-staging`), Demo et chaque environnement de PR. `docs/recette/README.md` les liste : on ne les redemande pas au porteur.
- Si une variable manque, la session donne son nom en une ligne et ne la demande pas dans le chat.
