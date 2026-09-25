# UDR-0007 : Vocabulaire d'interface — « Fiche essentielle », « Exercice », « Session », « Tentative », jamais « Quiz »

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-32**, étendue à C-48 ; bloque la V1 (Lot B) |
| **ADR lié** | [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (noms des badges) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) (sessions et tentatives) · [ADR-0053](../adr/0053-validation-collaborative-requalifiee.md) (aucun label de conformité) |
| **Remplacé par** | — |

---

## 1. Contexte

Un même objet porte cinq noms selon l'écran (**C-33**) :

- « Fiche essentielle » dans le glossaire ;
- « Habilité » (sic) et « Habiletés » dans l'interface ;
- « Notions clés » dans l'ADR-0022 ;
- « essentiels (habiletés) » dans l'UDR-0001 ;
- « habilletés » dans `feature_listing.md`.

Pour l'évaluation (**C-48**), l'UDR-0003 parle de « Quiz interactif », que le glossaire interdit, et l'écran enseignant intitule « Tentatives » un compteur de **sessions**. La landing promet un badge « Diamant » qui n'existe pas (ADR-0033). Un élève qui lit « Habileté » en classe et « Fiche » dans l'application ne sait pas qu'il s'agit de la même chose ; un agent qui lit trois mots écrit trois clés de locale.

## 2. Décision

**Un concept, un mot d'interface, écrit une fois dans la locale `fr`.** On retient le terme du glossaire, « Fiche essentielle », déjà rang 5, plutôt que « Habileté » : c'est un nom d'objet qu'on ouvre et qu'on lit. « Habileté » désigne une compétence, que l'élève n'ouvre pas. Le glossaire garde « tentative » pour la réponse à une question ; la session d'exercice s'appelle « session » à l'écran. Le compteur de l'enseignant compte des sessions et le dit.

| Concept (code) | Terme d'interface | Pluriel | Interdits à l'écran |
|---|---|---|---|
| `Essential` | Fiche essentielle | Fiches essentielles | Habileté, Habiletés, Notion clé, Notions clés, Essentiel, Leçon, Fiche seul dans un titre |
| `Exercise` | Exercice | Exercices | Quiz, Test, Flashcard |
| `ExerciseSession` | Session (« session d'exercice » quand le contexte ne suffit pas) | Sessions | Tentative, Essai, Partie |
| `QuestionAttempt` | Tentative | Tentatives | Essai |
| `Answer` | Proposition | Propositions | Réponse, comme nom d'objet (ambigu avec la tentative) ; le verbe « répondre » reste libre |
| `ExerciseBadge` | Badge Bronze · Badge Argent · Badge Or | Badges | Diamant, Platine, Médaille |
| Maîtrise (ADR-0033) | Acquis · Fragile · En difficulté | — | Validé, Échoué |
| Score | Score (en %) ; Note (sur 20) | — | Pourcentage, Moyenne |
| — | aucun label de conformité (ADR-0053) | — | Conforme au programme, Validé par la communauté |

La connexion ne dit jamais « session » : on écrit « Connexion » et « Se déconnecter ».

## 3. Règles d'implémentation

**Structure**

- Les noms de modèles vivent dans `config/locales/<contexte>/models.fr.yml`, sous `activemodel.models` et `activemodel.attributes`. Les écrans utilisent `Entities::…model_name.human(count:)` ou `t(".key")`, jamais le mot en dur dans une vue.
- Exemple : `activemodel.models.entities/catalog/essential: { one: "Fiche essentielle", other: "Fiches essentielles" }`.

**Tokens**

- Sans objet : cette UDR ne fixe aucune valeur visuelle. Les badges suivent les tokens de l'UDR-0005.

**Comportement**

- Les CTA de l'élève sont « Commencer l'exercice », « Reprendre » (session `started`) et « Recommencer » (ADR-0054).
- Le compteur de l'enseignant s'intitule « Sessions » ; « Tentatives » ne compte que des `QuestionAttempt`.

**États obligatoires**

- Vide : « Aucune fiche essentielle pour ce cours. » · « Aucun exercice publié pour cette fiche. »
- Erreur de soumission : « Tu as déjà répondu à cette question. » (`:conflict`, ADR-0054).

**Accessibilité**

- L'`aria-label` d'un badge nomme son palier en toutes lettres (« Badge Or »), jamais par la couleur seule.

## 4. Conséquences

- Le glossaire (§3, §4, §8) est mis à jour avec la colonne « Terme d'interface » et la liste des interdits d'écran.
- L'UDR-0001 (« essentiels (habiletés) ») et l'UDR-0003 (« Quiz interactif », « Diamant ») sont remplacées **pour leur vocabulaire** à l'acceptation de cette UDR.
- `test/i18n/vocabulary_test.rb` parcourt `config/locales/**/*.fr.yml` et `app/views/**/*`, et échoue sur les termes interdits, sans tenir compte de la casse : `quiz`, `habilet`, `notion(s) clé(s)`, `diamant`, `conforme au programme`.
- **Point à confirmer par le porteur** : « Fiche essentielle » plutôt que « Habileté », le terme des programmes ivoiriens.
- **Point à confirmer par le porteur** : « Session » pour `ExerciseSession`, et « Tentative » réservé à la réponse à une question, comme dans le glossaire.
