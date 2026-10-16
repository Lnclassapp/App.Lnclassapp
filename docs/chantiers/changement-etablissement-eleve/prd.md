# PRD — Un élève change de classe ou d'établissement en cours de scolarité

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **État : proposé.** Écrit sur les recommandations du [memo](memo.md#ce-que-le-grill-a-révélé) ; à relire après les réponses du porteur aux questions 1 à 9.

## 1. Contexte

Un élève dont la classe est active ne peut rejoindre aucune autre classe : seul un retrait par son ancienne classe le libère, et la plupart des classes n'ont personne sur Lnclass pour le faire. Ce chantier lui donne un geste à lui, « Changer de classe », vers une classe de son établissement ou d'un autre, par la cascade ou par le lien d'une classe, après une confirmation qui dit ce qui change. Ses résultats le suivent ; l'ancienne classe le perd de ses listes sans le marquer « retiré » ([ADR-0095](../../decisions/adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student avec une classe active | Changer de classe vers toute classe active de l'année que la cascade propose, ou vers celle d'un lien valide ; revenir plus tard dans une ancienne classe par la voie standard | Rejoindre une classe complète ou archivée ; revenir par la cascade dans une classe dont il a été retiré ; garder deux classes |
| Student sans classe active | Choisir sa classe par « Choisis ta classe » (`JoinAsStudent`, inchangé) | Utiliser « Changer de classe » (renvoyé à « Choisis ta classe ») |
| Teacher (ancienne ou nouvelle classe) | Voir l'élève arrivé (« nouveau » 7 jours) ; retirer un élève (inchangé) | Déplacer un élève vers une autre classe |
| SchoolStaff (direction) | Voir l'élève parti dans « Anciens élèves » ; retirer un élève (inchangé) | Valider ou refuser une arrivée ; déplacer un élève |
| Team | Lire la trace `classroom.student_moved` ; retirer un élève (inchangé) | Déplacer un élève (hors périmètre) |
| Visiteur | — | Toute page de ce chantier (redirigé vers la connexion) |

Règles d'autorisation : `allow_roles :student` sur le contrôleur ; `UseCases::Classroom::ChangeClassroom` refuse tout acteur non élève et l'élève sans classe active ; `Policies::Classroom::JoinPolicy` (inchangée) refuse classe archivée, complète, retiré sans lien.

## 3. Parcours utilisateur

### Chemin nominal — par la cascade

1. L'élève ouvre son profil et touche la ligne « Classe » (« Changer »).
2. La page « Changer de classe » s'ouvre : son établissement actuel est replié en étape 1, sa classe est marquée « Ta classe » et désactivée en étape 3.
3. Il garde l'établissement ou touche « Changer » pour en choisir un autre, choisit un niveau, puis une classe, et touche « Continuer ».
4. La page « Changer de classe ? » montre « Tu quittes » (classe, niveau, établissement) et « Tu rejoins », ce qui le suit et ce qu'il quitte.
5. Il touche « Oui, changer de classe ».
6. Il arrive sur son accueil, dans sa nouvelle classe, avec le toast « Bienvenue en … ! ».

### Chemin nominal — par le lien d'une classe

1. L'élève, connecté et déjà dans une classe, ouvre le lien `/c/<jeton>` reçu de son nouvel enseignant.
2. Il arrive directement sur « Changer de classe ? », la classe du lien en « Tu rejoins », mention « par le lien de la classe ».
3. Il confirme ; il arrive sur l'accueil de la nouvelle classe.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Élève sans classe active ouvre « Changer de classe » | Redirection vers « Choisis ta classe » |
| La classe choisie est sa classe actuelle (envoi forcé) | Retour à « Changer de classe », alerte « Tu es déjà dans cette classe. » (422) |
| Classe devenue complète avant l'envoi | Retour à « Changer de classe », alerte « Cette classe est complète. » (403) ; l'élève reste dans sa classe |
| Classe archivée avant l'envoi | Alerte « Cette classe n'accepte plus d'élèves. » (403) ; l'élève reste dans sa classe |
| Classe dont il a été retiré, par la cascade | Alerte de retrait existante (« Tu ne peux pas rejoindre cette classe… ») (403) |
| Classe dont il a été retiré, par le lien | Changement accepté ; le retrait est levé (ADR-0085 §4.3) |
| Lien mort (jeton inconnu ou changé) | « Changer de classe » avec l'alerte « lien plus valable » |
| Lien de sa propre classe | Accueil, comme aujourd'hui |
| Classe hors de la cascade (paramètres falsifiés) | Erreur sous le champ classe (422) |
| Double envoi ou deux onglets | Une seule adhésion active ; le second envoi ne change rien de plus |
| Plus de 5 envois en une minute | 429 avec le message de débit existant |
| « Annuler » sur la confirmation | Retour à « Changer de classe » (cascade) ou à l'accueil (lien) ; rien n'est écrit |
| Sans JavaScript | Cascade par les boutons « Continuer » de chaque étape ; confirmation en GET ; envoi en POST |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Un élève change de classe ou d'établissement

  Contexte:
    Étant donné l'établissement « Lycée Moderne de Cocody » avec la classe active « 2nde A » de l'année en cours
    Et l'établissement « Collège Saint-Viateur » avec les classes actives « 2nde C » et « 2nde D » de l'année en cours
    Et l'élève Awa, inscrite en « 2nde A » du Lycée Moderne de Cocody par la voie standard

  Scénario: Awa change d'établissement par la cascade
    Quand Awa ouvre son profil et touche la ligne « Classe »
    Et elle change d'établissement pour « Collège Saint-Viateur », choisit le niveau « 2nde » puis la classe « 2nde C »
    Et elle touche « Continuer »
    Alors elle voit « Tu quittes 2nde A » et « Tu rejoins 2nde C » avec le badge « Autre établissement »
    Quand elle touche « Oui, changer de classe »
    Alors elle arrive sur son accueil dans la classe « 2nde C »
    Et son adhésion à « 2nde A » porte une date de départ et aucune date de retrait
    Et son adhésion à « 2nde C » est sa classe principale active, voie « standard »
    Et le journal d'audit contient « classroom.student_moved » de « 2nde A » vers « 2nde C »

  Scénario: Rien n'est écrit avant la confirmation
    Quand Awa choisit « 2nde C » et arrive sur « Changer de classe ? »
    Et elle touche « Annuler »
    Alors Awa est toujours en « 2nde A »
    Et aucune trace « classroom.student_moved » n'est écrite

  Scénario: Les résultats suivent l'élève
    Étant donné qu'Awa a terminé l'exercice « Équations du premier degré » assigné à « 2nde A » avec 15/20
    Quand Awa change pour « 2nde C »
    Alors « Mon historique » d'Awa montre « Équations du premier degré » avec 15/20
    Et « Mes classes » montre « 2nde C » avec le badge « Actuelle » et « 2nde A » avec sa période
    Et le suivi de l'exercice dans « 2nde A » ne compte plus Awa parmi les élèves
    Et l'enseignant de « 2nde C » ne voit pas ce résultat dans ses suivis

  Scénario: L'ancienne classe ne liste plus l'élève, la nouvelle la marque nouvelle
    Quand Awa change pour « 2nde C »
    Alors la liste de « 2nde A » ne contient plus Awa et son effectif baisse de 1
    Et la liste de « 2nde C » contient Awa avec la marque « Nouveau »
    Et la direction du Lycée Moderne de Cocody voit Awa dans « Anciens élèves »

  Scénario: Changer de classe dans le même établissement
    Étant donné la classe active « 2nde B » au Lycée Moderne de Cocody
    Quand Awa choisit « 2nde B » sans changer d'établissement et confirme
    Alors Awa est en « 2nde B »
    Et la confirmation ne montrait pas le badge « Autre établissement »

  Scénario: Arriver par le lien de la nouvelle classe
    Quand Awa, connectée, ouvre le lien de la classe « 2nde D »
    Alors elle voit « Changer de classe ? » avec « Tu rejoins 2nde D » et la mention « par le lien de la classe »
    Quand elle confirme
    Alors Awa est en « 2nde D », voie « link »

  Scénario: Le lien de sa propre classe ne propose rien
    Quand Awa, connectée, ouvre le lien de « 2nde A »
    Alors elle arrive sur son accueil

  Scénario: Sa classe actuelle n'est pas proposée
    Quand Awa ouvre « Changer de classe »
    Alors la case « 2nde A » est désactivée et porte « Ta classe »
    Et un envoi forcé vers « 2nde A » est refusé avec « Tu es déjà dans cette classe. »

  Scénario: Classe complète au moment de l'envoi
    Étant donné qu'Awa est sur la confirmation vers « 2nde C »
    Et que « 2nde C » atteint son plafond d'élèves
    Quand Awa touche « Oui, changer de classe »
    Alors elle voit « Cette classe est complète. »
    Et Awa est toujours en « 2nde A »

  Scénario: Retirée d'une classe, Awa n'y revient pas par la cascade
    Étant donné qu'Awa a été retirée de « 2nde C » puis est entrée en « 2nde A »
    Quand Awa choisit « 2nde C » dans la cascade et confirme
    Alors l'entrée est refusée avec le message de retrait
    Mais quand Awa ouvre le lien de « 2nde C » et confirme
    Alors Awa est en « 2nde C »

  Scénario: Revenir dans une ancienne classe rouvre la même adhésion
    Étant donné qu'Awa est passée de « 2nde A » à « 2nde C »
    Quand Awa revient en « 2nde A » par la cascade
    Alors Awa n'a qu'une seule adhésion à « 2nde A », rouverte à la date du retour

  Scénario: Élève sans classe active
    Étant donné que la classe d'Awa a été archivée
    Quand Awa ouvre « Changer de classe »
    Alors elle est redirigée vers « Choisis ta classe »

  Scénario: Autres rôles
    Quand un enseignant, une direction ou un membre de l'équipe ouvre « Changer de classe » ou envoie un changement
    Alors l'accès est refusé
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Classroom::ChangeClassroom` (nouveau) ; `Entities::Identity::AuditAction` + `classroom.student_moved` ; ports, entités et `JoinPolicy` **inchangés** |
| Infrastructure | **Aucune migration**. `Queries::Classroom::ClassroomChangePreviewQuery` (classe quittée et classe rejointe : nom, niveau, établissement) ; `StudentArchiveQuery::ClassroomRow` + `joined_at`, `left_at`, actuelle |
| Delivery | `Classroom::StudentClassroomChangesController` (`new`, `confirm`, `create`, débit 5/min par compte) ; `Classroom::JoinsController#new` redirige l'élève à classe active vers `confirm` ; routes `students/classroom/change` (GET, POST), `students/classroom/change/confirm` (GET) |
| UI | `classroom/student_classroom_changes/new` et `confirm` (UDR-0102) ; `_class_picker` + local `current_classroom_public_id:` ; `identity/profiles/_student_row` + local `frame:` et ligne Classe (UDR-0101) ; `classroom/student_archives/show` (UDR-0103) |

## 6. Décisions rattachées

- [ADR-0095](../../decisions/adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md) — l'élève change lui-même de classe, sans validation ; ancienne adhésion close sans retrait *(Proposé ; amende ADR-0040, ADR-0085 §4.3)*
- [UDR-0101](../../decisions/udr/0101-profil-eleve-ligne-classe-vers-changer-de-classe.md) — profil : la ligne Classe ouvre « Changer de classe » *(Proposé ; amende UDR-0089)*
- [UDR-0102](../../decisions/udr/0102-changer-de-classe-choix-et-confirmation.md) — « Changer de classe » : cascade puis confirmation ; lien d'une autre classe *(Proposé)*
- [UDR-0103](../../decisions/udr/0103-historique-eleve-periode-de-chaque-classe.md) — historique : période de chaque classe *(Proposé ; amende UDR-0090)*

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Élèves à classe active qui peuvent changer de classe sans intervention d'un tiers | 0 | tous | |
| Requêtes SQL de l'envoi du changement | — | ≤ celles de `JoinAsStudent` + 1 (trace d'audit) | |
| Requêtes de « Mon historique » | 3 | 3 | |
