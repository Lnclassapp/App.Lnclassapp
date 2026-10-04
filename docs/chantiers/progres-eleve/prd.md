# PRD — L'élève voit son propre progrès

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

L'élève qui recommence un exercice voit sa note, jamais son progrès. Ce chantier ajoute, sur la page de résultat d'une session qui n'est pas son premier essai, **une phrase qui lui dit où il en est par rapport à ses essais précédents, et quoi faire ensuite**. Il réutilise les règles du signe de progrès de l'ADR-0079 et sert la mission de Lnclass : aider chaque acteur à progresser. Voir le [memo](memo.md).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student (propriétaire de la session) | Lire sa phrase de progrès sur le résultat de sa session | Voir le progrès d'un autre élève |
| Teacher, Team | Lire le résultat d'un élève comme aujourd'hui (UDR-0023) | Voir la phrase : elle parle à l'élève |

Règle d'autorisation : `Policies::Assessment::ReadSessionPolicy`, **inchangée**. La phrase n'est rendue que pour `@owner`.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève termine un exercice qu'il a déjà fait une fois.
2. La page de résultat affiche, dans la carte, sous la note sur 20, une phrase de progrès :
   - « Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui. »
3. Sous la carte, la correction reste à sa place. Les phrases « stagne » et « baisse » y renvoient.

### Chemins alternatifs

| Situation | Comportement attendu |
|---|---|
| Premier essai | Aucune phrase |
| Pas de progrès, meilleur résultat sous 14/20 (70 %) | « Tu restes autour de 12/20. Relis la correction ci-dessous avant de recommencer. » |
| Pas de progrès, meilleur résultat à 14/20 ou plus | « Tu confirmes ta maîtrise : 16/20. » |
| Cette session est 10 points ou plus sous son meilleur essai | « Ton meilleur résultat reste 18/20. Relis la correction, tu peux le retrouver. » |
| Ancien résultat rouvert | Le progrès se lit jusqu'à cette session incluse |
| Enseignant ou équipe sur le résultat d'un élève | Aucune phrase |

## 4. Critères d'acceptation

```gherkin
Scénario: aucune phrase au premier essai
  Étant donné un élève qui termine un exercice pour la première fois
  Quand il ouvre son résultat
  Alors aucune phrase de progrès n'est affichée

Scénario: progrès
  Étant donné un élève dont les sessions terminées valent 30 % puis 90 %
  Quand il ouvre le résultat de la seconde
  Alors il lit « Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui. »

Scénario: stagne sans le mot
  Étant donné des sessions à 60 % puis 60 %
  Alors il lit « Tu restes autour de 12/20. Relis la correction ci-dessous avant de recommencer. »
  Et la page ne contient ni « stagne » ni « baisse »

Scénario: maîtrise confirmée
  Étant donné des sessions à 80 % puis 80 %
  Alors il lit « Tu confirmes ta maîtrise : 16/20. »

Scénario: meilleur résultat à retrouver
  Étant donné des sessions à 30 %, 90 % puis 40 %
  Quand il ouvre le résultat de la troisième
  Alors il lit « Ton meilleur résultat reste 18/20. Relis la correction, tu peux le retrouver. »

Scénario: ancien résultat
  Étant donné des sessions à 30 %, 90 % puis 40 %
  Quand il ouvre le résultat de la deuxième
  Alors il lit « Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui. »

Scénario: sessions qui ne comptent pas
  Étant donné une session commencée, une session abandonnée et une session de remédiation sur l'exercice
  Alors aucune ne compte dans l'historique

Scénario: une seule histoire toutes classes confondues
  Étant donné un élève qui a fait l'exercice depuis deux assignations de deux classes
  Alors ses sessions des deux forment un seul historique

Scénario: l'enseignant ne voit pas la phrase
  Quand l'enseignant de la classe ouvre le résultat de la seconde session de l'élève
  Alors aucune phrase de progrès n'est affichée

Scénario: pas de couleur de sanction
  Alors la phrase « progrès » porte l'icône verte du progrès, et les autres une icône neutre
  Et aucune n'utilise le rouge ni l'ambre
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Rien de nouveau : `Entities::Assessment::Comprehension.trend_for` et `Grading.grade_on_20` (ADR-0079, chantier `rapports-exercices`) |
| Infrastructure | `Queries::Assessment::SessionResultQuery::Row` gagne `progress` : `Progress(trend, first_grade, best_grade, current_grade)` ou `nil` au premier essai ; une requête de plus, sur l'index `(student_id, completed_at)` |
| Delivery | Rien : `@owner` existe déjà |
| UI | Partiel `assessment/session_results/_progress.html.erb`, rendu dans `show` ; locales `assessment.session_results.progress.*` |

## 6. Décisions rattachées

- **Pas d'ADR** : aucun port, aucune table, aucune dépendance. Les règles du signe sont celles de l'ADR-0079 ; la seule décision nouvelle (l'historique de l'élève = toutes ses sessions standard terminées sur l'exercice, jusqu'à la session regardée) est une règle de lecture écrite ici et dans l'UDR-0073.
- [UDR-0073](../../decisions/udr/0073-progres-de-l-eleve-sur-son-resultat.md) — phrase de progrès sur le résultat de session ; amende l'UDR-0023.
- Dépend de : [ADR-0079](../../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md), livré avec `rapports-exercices`.
