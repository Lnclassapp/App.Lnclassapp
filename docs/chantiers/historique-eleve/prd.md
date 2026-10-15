# PRD — Historique de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

« Mon historique » (`/students/archive`) prend le cadre de l'accueil et s'ouvre depuis le menu de l'avatar (« Mon historique », sous « Mon profil », UDR-0084). Une carte bleue donne le nombre d'exercices terminés ; les exercices sont rangés par mois avec l'icône de leur matière, et la note est verte à partir de 14/20. Le contenu de l'historique ne change pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir ses classes (même quittées) et ses 200 derniers exercices terminés | Ouvrir le résultat d'un exercice depuis l'historique (UDR-0013, inchangé) ; voir l'historique d'un autre |

Règle inchangée : `allow_roles :student`.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Mon historique » depuis le menu de l'avatar.
2. Carte bleue : « 37 exercices terminés ».
3. « Mes exercices terminés » : un titre par mois (« Octobre 2026 »), puis chaque exercice avec l'icône de sa matière, son titre, sa date et sa note /20 (verte à partir de 14/20).
4. « Mes classes » : nom, niveau · établissement, année scolaire.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun exercice terminé | Carte bleue « Aucun exercice terminé pour l'instant », état vide actuel |
| Aucune classe | État vide actuel |
| Plus de 200 exercices | La carte donne le vrai total ; la liste montre les 200 derniers (actuel) |
| Beaucoup de lignes | « Voir plus » par pas de 10 (actuel) |
| ≥ 1 024 px | « Mes exercices terminés » à gauche en grand, « Mes classes » à droite |

## 4. Critères d'acceptation

```gherkin
# CA-1 Menu
Étant donné un élève sur n'importe quelle page élève
Quand il ouvre le menu de l'avatar
Alors « Mon historique » est sous « Mon profil »

# CA-2 Carte bleue
Étant donné un élève qui a terminé 37 exercices
Quand il ouvre « Mon historique »
Alors la carte bleue dit « 37 exercices terminés »

# CA-3 Par mois
Étant donné des exercices terminés en septembre et en octobre 2026
Alors ils sont groupés sous « Octobre 2026 » puis « Septembre 2026 »
Et chaque ligne porte l'icône de sa matière

# CA-4 Couleur de la note
Étant donné un exercice à 14/20 et un à 12/20
Alors 14/20 est en vert et 12/20 ne l'est pas, ni en rouge

# CA-5 Lignes non cliquables
Alors aucune ligne d'exercice n'est un lien

# CA-6 Ordinateur
Étant donné un écran de 1 280 px
Alors « Mes exercices terminés » est à gauche et « Mes classes » à droite
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | `StudentArchiveQuery::Archive` gagne `completed_count` (un `COUNT` sur les sessions terminées, sans limite) ; `ResultRow` gagne `material_slug` (l'illustration de la matière). |
| Delivery | — |
| UI | `classroom/student_archives/show` redessiné ; partials `_month` et `_result_row` ; seuil de couleur à 70 % (14/20), comme Ma classe et le résultat. |

## 6. Décisions rattachées

- Pas d'ADR : un compte ajouté à une query existante.
- [UDR-0090](../../decisions/udr/0090-historique-eleve-carte-bleue-exercices-par-mois.md) : historique redessiné.
- Le lien « Mon historique » du menu de l'avatar est livré par `accueil-eleve` (UDR-0084 §3.2).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de `GET /students/archive` | 8 (mesuré au Lot 0, 2026-10-15) | ≤ 9 | |
