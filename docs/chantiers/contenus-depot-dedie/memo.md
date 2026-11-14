# Memo — Les leçons vivent dans leur propre dépôt

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `feature/contenus-depot-dedie` |
| **Programme** | — |

---

## Le problème

Les leçons (plus de 460 fichiers relus, 275 à reprendre, les progressions, les prompts de rédaction) sont rangées dans le dépôt de l'application. Elles pèsent plus de 100 Mo, elles changent dix fois plus souvent que le code, et chaque correction de leçon passe par le même circuit que du code applicatif : même revue, même train, même historique. La rédaction et la publication d'une leçon ne sont pas outillées : chaque session refait le chemin à la main (prompt, relecture, contrôle, import en production), sans garde contre un remplacement en production.

## Pour qui

- **L'équipe pédagogique et les sessions de rédaction** : elles écrivent et corrigent des leçons dans un dépôt fait pour ça, sans toucher au code.
- **Le porteur** : il garde la main sur ce qui entre dans l'application et sur ce qui part en production.
- **Les sessions de code** : elles ne traînent plus 100 Mo de contenu à chaque clone, et une PR de code ne se mélange plus à une PR de contenu.

Élèves, enseignants, parents, direction : rien ne change pour eux (voir Hors périmètre).

## Pourquoi maintenant

Le rythme de rédaction monte (30 leçons de 5ème, 30 de 6ème en une semaine, une validation pédagogique par agent en cours) : chaque vague de leçons bloque une file de PR applicatives et alourdit le dépôt. La publication en production reste manuelle et sans garde.

## Hors périmètre

- **Ce que voient les élèves, enseignants, parents, direction** : aucun écran ne change. L'import de l'équipe (écran Imports) garde ses règles.
- **Le chargement automatique sur Develop et Staging** : ses règles restent celles des décisions en place ; seule change l'origine du dossier qu'il lit.
- **L'import automatique en production** : la production reste à l'import manuel, en création seule.
- **La réécriture des leçons à reprendre** : elles déménagent telles quelles.
- **La création du dépôt de contenus** : faite par le porteur le 2026-11-14 (`Lnclassapp/App.Lnclassapp-contenus`, public).
- **Changer le chemin où l'application lit ses leçons** : il reste le même, pour ne toucher ni le chargement, ni la CI ciblée, ni l'aperçu.

## Ce que le grill a révélé

> Session d'orchestration : pas d'échange direct avec le porteur. Questions adverses posées contre l'existant ; chaque réponse vient du code ou d'une décision en place, et ce qui reste au porteur est dans `journal.md` § À trancher.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| L'application lit-elle les leçons seulement en test, ou aussi en marche ? | En marche : Develop et Staging chargent toutes les leçons relues au pré-déploiement, depuis l'image construite avec le dépôt de l'application. | L'application ne peut pas se contenter de fixtures de test : elle doit embarquer **toutes** les leçons relues, au moment du déploiement, sans accès réseau supplémentaire. Un sous-module privé ou un téléchargement au déploiement demanderait un jeton dans l'hébergeur. → copie figée versionnée dans l'application. |
| Le contrôle d'une leçon peut-il partir avec elle ? | Non : il lit les règles du domaine de l'application (types de question, figures), avec un test de parité contre l'import. | Le contrôle reste dans l'application, source unique des règles. Le dépôt de contenus l'emprunte (application récupérée à une version donnée) ; l'application rejoue le contrôle sur chaque synchronisation. |
| Des tests lisent-ils autre chose que les leçons relues ? | Oui : deux tests lisent une progression ; un test cite les leçons à reprendre. | Ces progressions restent dans l'application comme données de test figées ; tout le reste (progressions, leçons à reprendre, prompts, mode d'emploi) part. |
| Que se passe-t-il si quelqu'un corrige une leçon directement dans l'application après le déménagement ? | La correction serait écrasée à la synchronisation suivante, sans trace. | La copie dans l'application est en lecture seule : la CI refuse une leçon modifiée sans changement de la version synchronisée. On corrige dans le dépôt de contenus, puis on synchronise. |
| Qui décide qu'une leçon entre dans Develop ? | Aujourd'hui : la fusion de la PR qui la contient. | Toujours une PR dans l'application (« synchronisation des contenus à telle version »), CI verte, fusionnée comme les autres. Staging suit le train ; la production ne suit jamais seule. |
| Une publication en production peut-elle écraser une leçon déjà présente ? | L'import manuel refuse une leçon publiée, mais remplace une leçon en brouillon. | La préparation de publication ne retient que des créations ; toute leçon dont le titre existe déjà en production (brouillon compris) est écartée et listée, et ne part qu'avec la confirmation écrite du porteur. Aucune suppression. |
| L'historique des leçons survit-il au déménagement ? | Possible : les fichiers ont un historique propre, extractible. | Migration par extraction d'historique ; si l'outil manque, copie avec un commit qui cite le SHA d'origine (option prudente, réversible). |
| Une session de correction pédagogique travaille en ce moment sur ces mêmes fichiers. | Oui (validation pédagogique, PR non fusionnée au 2026-11-14). | Aucun fichier de contenu ne bouge avant sa fusion. Ce qui n'en dépend pas (décisions, outils de rédaction et de publication, outil de synchronisation) part maintenant. |

## Cas limites identifiés

- Dépôt de contenus pas encore créé : le chantier livre décisions et outils ; la migration attend.
- Synchronisation d'une version où une leçon échoue au contrôle : rien n'est copié, la liste des fichiers en échec est rendue.
- Leçon supprimée dans le dépôt de contenus : elle disparaît de la copie à la synchronisation suivante ; Develop et Staging ne suppriment jamais de leçon chargée (règles en place).
- Leçon renommée : vue comme une suppression plus une création ; en production, la nouvelle est une création, l'ancienne reste.
- Synchronisation à une version plus ancienne que la copie en place : refusée sauf demande explicite.
- Dépôt de contenus public : leçons et corrigés lisibles par tous, jamais de secret ni de donnée d'élève ; sa CI a besoin d'un accès en lecture à l'application (privée) pour emprunter le contrôle.
- Leçon déjà en brouillon en production : écartée de la publication, listée, confirmation du porteur requise.

## Questions encore ouvertes

- Dépôt privé ou public : tranché, **public** (porteur, 2026-11-14) ; corrigés lisibles par tous, jamais de secret ni de donnée d'élève.
- Clé de synthèse vocale pour les annonces audio : variable `GOOGLE_TTS_API_KEY`, absente ; n'empêche rien d'autre.
