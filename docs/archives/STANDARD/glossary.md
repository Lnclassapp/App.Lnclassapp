# Glossaire du Projet (Ubiquitous Language)

Consistent naming is critical for both Humans and Agents. Use these terms everywhere (Code, DB, UI).

## Acteurs (Users & Roles)
| Terme | Définition |
| :--- | :--- |
| **User** | Compte utilisateur de base (identifié par son contact/numéro). |
| **Student** | Élève inscrit à une classe et un niveau. |
| **Teacher** | Enseignant lié à une ou plusieurs classes et une matière. |
| **Team** | Membre de l'équipe Lnclass (administrateur/créateur de contenu). |
| **Parent** | Tuteur légal suivant la progression d'un élève. |

## Organisation Scolaire
| Terme | Définition |
| :--- | :--- |
| **School** | Établissement scolaire physique. |
| **Classroom** | Classe physique ou virtuelle regroupant des élèves. |
| **Level** | Niveau académique (6ème, 3ème, Terminale, etc.). |
| **Series** | Série de spécialisation (A1, C, D, etc.). |
| **Drena** | Direction Régionale de l'Éducation Nationale. |

## Contenu Pédagogique
| Terme | Définition |
| :--- | :--- |
| **Material** | Matière scolaire (Mathématiques, Physique-Chimie, etc.). |
| **Course** | Unité d'enseignement globale couvrant un chapitre. |
| **Essential** | Fiche de cours (résumé des notions clés). |
| **Exercise** | Série de questions liée à un Essential ou un Exam. |
| **Exam Subject** | Sujet d'examen officiel (BAC, BEPC) ou blanc. |

## Évaluation & Progression
| Terme | Définition |
| :--- | :--- |
| **Question** | Item d'évaluation (QCM, Vrai/Faux, etc.). |
| **Answer** | Réponse possible associée à une question. |
| **Exercise Session** | Tentative de réalisation d'un exercice par un élève. |
| **Question Attempt** | Réponse donnée par l'élève à une question spécifique lors d'une session. |
| **Exercise Badge** | Récompense (Bronze, Or, etc.) obtenue selon le score. |

## Règles de Nommage
1. **Langue** : Le code utilise l'anglais, mais les termes métier dans l'interface sont en français.
2. **Cohérence** : Ne jamais utiliser de synonymes (ex: ne pas mélanger `Lesson` et `Essential`).
3. **Public ID** : Utiliser les `public_id` (nanoid) pour les URLs et les échanges API.
