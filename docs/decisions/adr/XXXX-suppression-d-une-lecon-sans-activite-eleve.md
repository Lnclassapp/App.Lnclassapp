# ADR-XXXX : Une leçon sans aucune activité d'élève se supprime physiquement, quel que soit son statut, sous verrou
<!-- index
titre: Suppression d'une leçon sans activité d'élève
statut: Accepté
problematique: une leçon publiée ou archivée à refaire ne peut ni être supprimée ni réimportée ; on permet sa suppression physique tant qu'aucun élève ne s'en est servi.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-14) |
| **Date** | 2026-11-14 |
| **Chantier** | `docs/chantiers/suppression-lecon` |
| **Remplace** | — |
| **Remplacé par** | — |
| **Amende** | ADR-0036 §4 (ligne « Cours, fiche, exercice… »), ADR-0035 §4 |

---

## 1. Contexte et problématique

ADR-0036 n'autorise la suppression physique d'un contenu que pour un brouillon jamais publié ; tout contenu publié s'archive (ADR-0035). ADR-0116 §4.4 fait refuser à l'import toute leçon déjà présente qui n'est plus entièrement en brouillon (`lesson_already_published`), archivée comprise, pour ne jamais effacer de résultats d'élève.

Les leçons de 6ème et 5ème importées en série (novembre 2026) montrent le coût : une leçon publiée qu'il faut refaire avant que les élèves ne l'ouvrent reste bloquée. L'archiver ne libère pas sa place à l'import ; la renommer pour réimporter laisse un doublon.

La protection voulue par ADR-0036 n'est pas le statut du contenu mais la production des élèves : une leçon qu'aucun élève n'a touchée peut disparaître sans rien coûter à personne.

## 2. Moteurs de décision

- Aucune donnée d'élève n'est jamais effacée (ADR-0036, inchangé).
- L'équipe doit pouvoir refaire une leçon par l'import, seul chemin d'écriture du contenu (ADR-0113 §4.6).
- La décision doit tenir face à un élève qui commence un exercice au même instant.
- Ne pas affaiblir la règle de l'import (ADR-0116 §4.4).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Suppression d'une leçon sans activité, tout statut, sous verrou | Couvre le besoin ; garde intacte la règle de l'import ; protège les élèves par construction | — retenue |
| B — L'import remplace aussi une leçon publiée sans activité | Un seul geste | Change en silence la règle de l'import ; un import peut écraser une leçon vivante par erreur de titre |
| C — Suppression logique (statut « supprimé ») et clé d'import ignorant ce statut | Réversible | Laisse des lignes que personne ne lit ; toutes les lectures du catalogue devraient filtrer un quatrième statut |

## 4. Décision

> **Nous permettons à l'équipe (ManageContentPolicy) de supprimer physiquement une leçon, quel que soit son statut, avec ses notions, exercices (de notion, de toute la leçon, de sujet), questions, réponses, images, sujets et texte de cours, si et seulement si aucune activité d'élève ne s'y rattache. Sinon nous refusons (`:conflict`, `student_activity`) et proposons de modifier la leçon.**

1. **Activité d'élève** — sept sources, toutes lues explicitement :
   séances d'exercice (`exercise_sessions`, tout statut), réponses (`question_attempts`, par question ou par séance), badges (`exercise_badges`), lectures de notion (`essential_reads`), lacunes (`knowledge_gaps`, par notion), packs hors ligne livrés (`offline_pack_deliveries`), devoirs envoyés à une classe (`classroom_assignments` de type `Exercise`, **actifs ou archivés**). « Je m'entraîne » n'écrit rien et ne compte pas.
2. **Lecture explicite, pas confiance dans la base** — `essential_reads → essentials` est en `ON DELETE CASCADE` : supprimer une notion lue effacerait la lecture sans erreur. Et `classroom_assignments` est polymorphe, sans clé étrangère. Les autres liens sont en `RESTRICT` et servent de filet : si une trace échappait à la lecture, la suppression lèverait et la transaction serait annulée.
3. **Verrou puis vérification, dans une transaction** — le use case ouvre la transaction ; le repository verrouille (`FOR UPDATE`) la leçon, puis ses notions, exercices et questions, dans cet ordre (celui de `ContentTreeWriter#replace_draft`, pour ne pas s'interbloquer avec un import), puis lit l'activité. Une séance, une réponse, un badge, une lecture, une lacune ou un pack inséré en même temps prend un verrou `FOR KEY SHARE` sur la ligne parente (clé étrangère) : il attend la fin de la suppression et échoue ensuite, ou il était déjà engagé et la vérification le voit.
4. **Le devoir prend le même verrou** — `AssignmentRepository#create` verrouille l'exercice visé en `FOR KEY SHARE` avant d'écrire, et refuse (`:not_found`) un exercice disparu. Le lien polymorphe se comporte alors comme une clé étrangère.
5. **Ce qui reste** — le journal d'audit (`content.deleted`, nom, slug, statut et nombre de lignes supprimées), les rapports d'import et les autres leçons. Les fichiers d'images et les pièces du texte de cours sont détruits par Active Storage / Action Text (purge après validation).
6. **L'import ne change pas** — une leçon supprimée n'est plus dans `existing_keys` ni `ids_by_key` : son fichier se réimporte comme une leçon neuve (nouvel id, slug recalculé, tout en brouillon).

ADR-0036 §4, ligne « Cours, fiche, exercice, question, réponse », se lit désormais : *archiver dès qu'ils ont été publiés ; suppression physique d'une leçon entière, quel que soit son statut, tant qu'aucune activité d'élève ne s'y rattache (ADR-XXXX) ; jamais d'une notion, d'un exercice ou d'une question seuls*. ADR-0035 : le cycle `draft → published → archived` reste ; la suppression n'est pas une transition mais une sortie du cycle, réservée à une leçon jamais utilisée.

## 5. Conséquences

### 🟢 Positives

- L'équipe refait une leçon fautive en deux gestes : supprimer, réimporter.
- Aucune production d'élève ne peut disparaître, même en concurrence.
- La règle de l'import reste simple et inchangée.

### 🔴 Coûts consentis

- Une leçon supprimée ne se restaure pas : seul le fichier d'import la recrée, avec un nouveau slug possible ; les liens partagés vers l'ancienne page donnent 404.
- Un devoir envoyé puis archivé suffit à bloquer la suppression, même si aucun élève ne l'a ouvert. L'équipe modifie alors la leçon.
- L'envoi d'un devoir prend un verrou de plus sur l'exercice (une requête courte par exercice envoyé).
- La suppression a sa propre purge, qui ne touche que le contenu, à côté de celle de `ContentTreeWriter` (import hors production, qui efface aussi l'activité). Deux listes de tables à tenir à jour quand le contenu gagne une table ; mélanger les deux exposerait la suppression à effacer une trace d'élève.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/catalog/delete_course.rb
@transaction.call do
  activity = @courses.lock_for_deletion(id: course.id)
  next Shared::Result.failure(:not_found) if activity.nil?
  next Shared::Result.failure(:conflict, errors: { base: [ :student_activity ] }) if activity.any?

  deleted = @courses.delete(id: course.id)
  @audit_log.record(action: "content.deleted", actor_id: actor.user_id, subject_type: "Course", subject_id: course.id,
                    metadata: { slug:, name: course.name, status: course.status, deleted: }, at: @clock.now)
  Shared::Result.success(course)
end
```

```ruby
# app/infrastructure/repositories/classroom/assignment_repository.rb — avant l'insertion
return ::Shared::Result.failure(:not_found) unless lock_assignable(assignment.assignable)
```

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/repositories/catalog/course_repository_deletion_test.rb` : une activité par source (sept, plus le devoir archivé) bloque ; la suppression complète ne laisse aucune ligne du contenu ; la voisine est intacte.
- `test/domain/use_cases/catalog/delete_course_test.rb` : refus de la policy, refus sur activité, audit écrit.
- `test/domain/use_cases/catalog/import_course_tree_test.rb` (« imported again once deleted ») : réimport après suppression.
- `test/infrastructure/repositories/catalog/course_deletion_concurrency_test.rb` : une séance ou un devoir écrit pendant la suppression attend puis échoue ; rien d'orphelin.
- `test/infrastructure/repositories/classroom/assignment_repository_test.rb` : un devoir vers un exercice disparu est refusé.
