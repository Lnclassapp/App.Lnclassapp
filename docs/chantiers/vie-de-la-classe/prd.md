# PRD — La vie de la classe : la modifier, la lire, la fermer pour de bon

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Statut : proposé.** Écrit sur les recommandations du [memo](memo.md) (Q1 à Q8). Une réponse contraire du porteur amende ce fichier avant le code.

## 1. Contexte

Une classe ne se corrige plus après sa création : ni son nom, ni son plafond (CL-02). L'enseignant ne voit pas les chiffres de sa classe que la direction voit déjà (CL-14). Une classe archivée garde des sous-pages lisibles par ses membres (dette d'`archivage-classes`).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Modifier le nom et le plafond de toute classe active de l'année en cours, quel que soit le statut de l'établissement ; lire les chiffres de toute classe | Changer le niveau, la série, l'année d'une classe |
| SchoolStaff (direction) | Modifier le nom et le plafond d'une classe active de l'année en cours, dans son seul établissement, s'il est actif | Toucher une classe d'un autre établissement (404) ; créer une classe au nom libre |
| Teacher | Lire les chiffres de sa classe (devoirs donnés, taux de rendu, moyenne) | Modifier une classe (aucune entrée ; requête directe refusée) |
| Student | Voir le nouveau nom de sa classe ; entrer dans une classe dont le plafond a été relevé | Tout geste de ce chantier |

Règles d'autorisation :

- Modifier : `Policies::School::ManageSchoolStructurePolicy` (celle de « + », « − » et de l'archivage), appelée une fois l'établissement lu.
- Lire les chiffres : `Policies::Classroom::ReadClassroomPolicy`, accès `show_roster` (enseignant de la classe, équipe).
- Sous-pages d'une classe : leurs policies actuelles, précédées du refus de toute classe archivée (404).

## 3. Parcours utilisateur

### Chemin nominal — modifier une classe

1. L'équipe ouvre la fiche d'un établissement (ou la direction, la page d'un niveau).
2. Elle ouvre le menu ⋮ de la carte « 6ème 3 » et choisit « Modifier la classe ».
3. La modale « Modifier la classe 6ème 3 » s'ouvre : le préfixe « 6ème » est affiché, fixe ; le suffixe « 3 » et le plafond « 80 » sont remplis.
4. Elle saisit « A » et « 95 », puis « Enregistrer ».
5. La modale se ferme, la carte affiche « 6ème A », un toast dit « Classe 6ème A enregistrée ».

### Chemin nominal — chiffres de la classe

1. L'enseignant ouvre la page de sa classe.
2. Sous l'en-tête, trois tuiles : « Devoirs donnés », « Taux de rendu », « Moyenne », mêmes chiffres que la page de la direction pour la même classe.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Suffixe vide | Erreur sous le champ : « Saisissez la fin du nom. » ; modale re-rendue en 422 avec la saisie |
| Nom complet de plus de 15 caractères | Erreur sous le champ : « Le nom complet tient en 15 caractères au plus (6ème + 9). » |
| Nom déjà pris dans l'établissement et l'année, archivées comprises | Erreur sous le champ : « Ce nom est déjà pris dans l'établissement cette année (classes archivées comprises). » |
| Plafond hors de 1 à 150 | Erreur sous le champ : « Entre 1 et 150 élèves. » |
| Plafond sous l'effectif présent | Erreur sous le champ : « La classe compte déjà 42 élèves : le plafond ne peut pas être plus bas. » |
| Rien de changé | Succès, toast, aucune ligne d'audit |
| Classe archivée entre l'ouverture et l'envoi | Toast neutre « Cette classe est archivée : restaurez-la pour la modifier. », page rafraîchie |
| Direction d'un autre établissement, classe d'une année passée | 404 |
| Enseignant, élève | 403 (rôle refusé par le contrôleur) |
| Sans JavaScript | La modale est une page complète ; succès → redirection vers la fiche ou le niveau avec un message flash |
| Sous-page d'une classe archivée (cours, essentiel, suivi, jours de séance) | 404, quel que soit le rôle ; de nouveau lisible après restauration |
| Classe de moins de 5 élèves ayant rendu | Tuile « Moyenne » : « — » et son texte pour lecteur d'écran, comme chez la direction |

## 4. Critères d'acceptation

```gherkin
# Lot A — modifier une classe

Étant donné que l'équipe gère le Lycée Classique d'Abidjan, dont la classe « 6ème 3 » compte 12 élèves
Quand elle remplace le suffixe par « A » et le plafond par 95, puis enregistre
Alors la classe s'appelle « 6ème A » et son plafond vaut 95
Et une ligne d'audit « school.changed » porte change « classroom_updated », le nom avant et après, le plafond avant et après
Et les élèves de la classe voient « 6ème A » dans leur en-tête

Étant donné qu'une direction est rattachée au Lycée Classique d'Abidjan, établissement actif
Quand elle modifie le plafond de sa classe « Tle D 2 » à 60
Alors le plafond vaut 60

Étant donné qu'une direction est rattachée au Lycée Classique d'Abidjan
Quand elle envoie une modification pour une classe du Collège Moderne de Cocody
Alors elle reçoit une page 404
Et la classe n'a pas changé

Étant donné qu'un enseignant enseigne en « 6ème 3 »
Quand il ouvre la page de sa classe
Alors aucune entrée « Modifier la classe » n'existe
Et une requête directe de modification lui est refusée

Étant donné que la classe « Tle D 3 » est de niveau Tle et de série D
Quand l'équipe tente de la nommer « Tle C 3 »
Alors le formulaire n'offre que le suffixe : le préfixe « Tle D » n'est pas modifiable
Et une requête qui envoie un suffixe vide est refusée avec « Saisissez la fin du nom. »

Étant donné que l'établissement a déjà une classe « 6ème A », archivée cette année
Quand l'équipe renomme « 6ème 3 » en « 6ème A »
Alors la modification est refusée avec « Ce nom est déjà pris dans l'établissement cette année (classes archivées comprises). »

Étant donné que la classe « 6ème 3 » compte 42 élèves présents
Quand la direction fixe son plafond à 40
Alors la modification est refusée avec « La classe compte déjà 42 élèves : le plafond ne peut pas être plus bas. »
Et le plafond reste à 80

Étant donné que la classe « 6ème 3 » compte 79 élèves présents et un plafond de 80
Et qu'un élève la rejoint pendant que la direction fixe son plafond à 79
Alors les deux opérations passent l'une après l'autre, sous le verrou de la classe
Et si l'élève est entré le premier, le plafond à 79 est refusé (80 élèves présents)
Et si le plafond est passé le premier, l'élève est refusé (classe complète)

Étant donné que la classe « 6ème 2 » est complète (80 élèves pour un plafond de 80)
Quand l'équipe relève son plafond à 90
Alors la cascade de l'élève ne la marque plus « Complète »

Étant donné que la classe « 6ème 3 » est archivée
Quand l'équipe ouvre son menu ⋮
Alors seule l'entrée « Restaurer la classe » est proposée
Et une requête directe de modification reçoit « Cette classe est archivée : restaurez-la pour la modifier. »

Étant donné que les classes de 6ème sont « 6ème 1 », « 6ème 2 » et « 6ème A » (ancienne « 6ème 3 »)
Quand l'équipe clique sur « + » du niveau 6ème
Alors la classe ajoutée s'appelle « 6ème 3 »

Étant donné que l'équipe enregistre la classe sans rien changer
Alors un toast confirme l'enregistrement
Et aucune ligne d'audit n'est écrite

# Lot B — chiffres de la classe

Étant donné qu'un enseignant enseigne en « Tle D 1 », où 3 devoirs ont été donnés à 10 élèves
Quand il ouvre la page de sa classe
Alors il voit trois tuiles « Devoirs donnés », « Taux de rendu », « Moyenne »
Et leurs valeurs sont celles de la page de la direction pour la même classe

Étant donné que moins de 5 élèves de la classe ont rendu un devoir
Quand l'enseignant ouvre la page de sa classe
Alors la tuile « Moyenne » affiche « — » et le texte « non calculé » pour les lecteurs d'écran

Étant donné qu'un élève est inscrit en « Tle D 1 »
Quand il demande la page de la classe
Alors il reçoit 403, comme aujourd'hui

# Lot C — une classe archivée n'a plus de page

Étant donné que la classe « Tle D 1 » est archivée
Quand son enseignant ouvre l'un de ses cours, un essentiel, le suivi d'un exercice assigné ou ses jours de séance
Alors il reçoit une page 404
Et l'équipe aussi

Étant donné que la classe « Tle D 1 » est restaurée
Quand son enseignant ouvre le suivi d'un exercice assigné
Alors la page s'affiche comme avant l'archivage
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::ClassroomNumbering.full_name(prefix:, suffix:)` et `.suffix_of(name:, prefix:)` ; `Dtos::Classroom::ClassroomSettingsInput` (suffixe, plafond) ; `UseCases::Classroom::UpdateClassroom` ; port `ClassroomRepositoryPort#update_settings(id:, name:, max_students:)` |
| Infrastructure | `ClassroomRepository#update_settings` : verrou de ligne, effectif présent, statut, `UPDATE`, index unique → `name_taken` ; `StudentWorkQuery#figures(public_id:)` (Lot B). Aucune migration |
| Delivery | `Teams::ClassroomSettingsController` et `SchoolAdmin::ClassroomSettingsController` (`edit`, `update`) ; routes `classroom-settings` ; contrôle « classe archivée » dans quatre contrôleurs de sous-pages (Lot C) |
| UI | Modale « Modifier la classe » (UDR-0110) ; entrée du menu ⋮ des cartes (UDR-0111) ; tuiles de la page d'une classe (UDR-0112) |

## 6. Décisions rattachées

- [ADR-0098](../../decisions/adr/0098-modifier-une-classe-nom-au-prefixe-du-bareme-et-plafond.md) — Modifier une classe : suffixe du nom et plafond, par la direction et l'équipe *(Proposé)*
- [UDR-0110](../../decisions/udr/0110-modale-modifier-la-classe.md) — Modale « Modifier la classe » *(Proposé)*
- [UDR-0111](../../decisions/udr/0111-entree-modifier-du-menu-de-la-carte-de-classe.md) — Entrée « Modifier la classe » du menu ⋮ des cartes *(Proposé)*
- [UDR-0112](../../decisions/udr/0112-chiffres-de-la-classe-pour-l-enseignant-et-l-equipe.md) — Chiffres de la classe sur la page de l'enseignant et de l'équipe *(Proposé)*

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL de la page d'une classe (enseignant, 30 élèves, 5 devoirs) | à mesurer au Lot B | avant + 2 au plus, quel que soit le nombre d'élèves | |
| Sous-pages d'une classe archivée lisibles | 4 | 0 | |
