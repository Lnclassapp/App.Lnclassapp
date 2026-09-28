# Memo — Ajuster le nombre de classes par niveau d'un établissement

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/classes-par-niveau` |
| **Programme** | — |

---

## Le problème

Demande du porteur (2026-09-28) : « nous devons pouvoir ajuster le nombre de classes par niveau dans une école, soit supprimer, soit ajouter ».

Les classes d'un établissement viennent du barème, à l'import ou par la génération des classes manquantes : 4 sixièmes dans un lycée public, 6 classes par série en seconde… Le barème est une moyenne ; la réalité d'un établissement ne l'est pas. Un lycée qui a 7 sixièmes doit en ajouter 3, un lycée qui n'a que 2 terminales A2 doit en retirer. Aujourd'hui, l'équipe peut seulement « Ajouter une classe » une par une, en saisissant son nom à la main, sans voir combien de classes chaque niveau compte déjà ; et elle ne peut **rien** retirer : une classe générée en trop reste dans la liste des classes que les enseignants déclarent et que les élèves rejoignent.

## Pour qui

L'équipe (Team, tout sous-rôle), sur la fiche d'un établissement, quand un établissement lui signale ses effectifs réels (en début d'année surtout).

## Pourquoi maintenant

La rentrée est en cours et les 3 851 établissements viennent de recevoir leurs classes par le barème (chantier `generer-classes`). Les écarts remontent maintenant, avant que les enseignants ne déclarent leurs classes et que les élèves ne les rejoignent : c'est le moment où une classe en trop est encore vide, donc retirable sans rien perdre.

## Hors périmètre

- Saisir directement un nombre cible (« 7 sixièmes ») : on ajoute ou on retire une classe à la fois. Un champ nombre pourra venir ensuite sur les mêmes use cases.
- Retirer une classe **qui n'est pas la dernière** de son niveau (« 6ème 2 » quand il existe une « 6ème 4 ») : la numérotation resterait trouée.
- Archiver une classe utilisée, une à une : l'archivage reste celui de fin d'année (ADR-0041). Le refus le conseille, sans l'offrir.
- Renommer une classe, changer son plafond, régénérer son code.
- Modifier le barème lui-même (chantier parallèle « barème des classes modifiable »).
- Les classes d'une autre année scolaire que l'année en cours.
- La direction de l'établissement (V2) : l'équipe seule, comme pour « Ajouter une classe ».
- Le tableau des établissements n'a pas de nouvelle commande : il garde sa colonne « Classes », qui doit rester juste.

## Ce que le grill a révélé

| Question posée | Réponse (décision par défaut, **à confirmer par le porteur**) | Conséquence sur le chantier |
|---|---|---|
| « Par niveau », c'est quoi au second cycle ? Une Tle compte des C, des D, des A1… | Une ligne par couple niveau/série ouvert au référentiel (« Tle D », « 2nde A »), une ligne par niveau sans série (« 6ème »). | Les lignes viennent du référentiel (niveaux, séries liées), pas du barème : un couple ouvert sans classe apparaît à 0. |
| Un collège voit-il des lignes du second cycle ? | Non : premier cycle seulement, comme « Ajouter une classe » et le barème. | Lignes filtrées par le cycle de l'établissement. |
| Et une classe d'un couple qui n'est plus ouvert (série déliée après coup) ? | Sa ligne apparaît quand même, sans « + » : sinon la somme des lignes ne ferait plus le total de la fiche. | Lignes = couples ouverts ∪ couples qui ont des classes de l'année. |
| Que compte le nombre d'une ligne ? | Toutes les classes de l'année scolaire en cours du couple, archivées comprises, comme le titre « Classes (N) » de la fiche et la colonne du tableau. | Somme des lignes = total de la fiche = colonne « Classes » du tableau. |
| Quel nom pour la classe ajoutée ? | Le préfixe du barème, suivi du numéro suivant le plus grand numéro existant : « 6ème 5 » après « 6ème 4 », même s'il manque la « 6ème 2 ». Jamais un nom déjà pris. | Numérotation calculée dans le domaine, sur les noms de l'établissement et de l'année. |
| Et si deux membres de l'équipe cliquent « + » en même temps ? | Le second tombe sur le même nom : l'index unique refuse, on recalcule une fois. | Une seule reprise sur conflit de nom. |
| Mêmes règles que « Ajouter une classe » pour « + » ? | Oui : établissement actif seulement (ni désactivé, ni brouillon), premier cycle pour un collège, couple ouvert au référentiel, plafond 80 par défaut, code tiré à la création (ADR-0041). | Le contrôle du niveau et de la série est partagé avec « Ajouter une classe ». |
| Quelle classe « − » retire-t-elle ? | La dernière du couple (plus grand numéro). Jamais une autre : si la dernière est utilisée, on refuse, on ne cherche pas une classe vide plus haut dans la liste. | La confirmation nomme la classe ; la requête porte son identifiant ; si elle n'est plus la dernière au moment du clic, refus. |
| « Vide », c'est quoi ? | Aucune adhésion d'élève (même terminée), aucun enseignant déclaré, aucune assignation (même archivée — les sessions d'exercice pendent des assignations). | Trois refus distincts, chacun avec « archivez-la plutôt ». |
| Supprimer ou archiver la classe vide ? | **Supprimer** : l'ADR-0036 n'interdit la suppression qu'une fois qu'un élève l'a rejointe ou qu'une assignation existe, et `DeleteSchool` supprime déjà les classes jamais utilisées. Archiver une classe vide la laisserait comptée dans la fiche et le tableau, et bloquerait son nom. | Suppression physique d'une classe jamais utilisée ; ADR-0059 le fixe. |
| Et un élève qui rejoint la classe pendant qu'on la retire ? | La suppression verrouille la ligne de la classe avant de vérifier qu'elle est vide ; l'adhésion par code la verrouille aussi. L'un attend l'autre. | `SELECT … FOR UPDATE` dans la transaction du retrait. |
| « − » sur un établissement désactivé ou en brouillon ? | Permis : retirer une classe vide ne touche personne, et un brouillon doté par la génération peut être ajusté avant activation. « + » reste réservé aux établissements actifs. | Le bloc s'affiche pour tout statut ; « + » n'apparaît que pour un établissement actif. |
| Faut-il confirmer « + » ? | Non : il se défait par « − ». « − » se confirme toujours. | Une `<dialog>` par ligne, ouverte par « − ». |
| Qui peut ? | L'équipe, comme « Ajouter une classe » (`ManageClassroomPolicy`). | 403 pour tout autre rôle. |
| Faut-il tracer ? | Oui, chaque ajout et chaque retrait. L'action `school.changed` existe (modification, désactivation, suppression d'un établissement) : on la reprend avec `change: classroom_added` / `classroom_removed`, sujet l'établissement, puisque la classe retirée n'existe plus. | Aucune nouvelle action d'audit. |
| La fiche et le tableau restent-ils justes sans rechargement ? | La réponse Turbo Stream remplace le bloc tout de suite, puis re-demande la fiche (morphing) : titre « Classes (N) » et liste des classes à jour. Le tableau des établissements relit la base à chaque affichage. | Pas de compteur dénormalisé. |

## Cas limites identifiés

- Couple ouvert sans aucune classe : ligne à 0, « − » désactivé, « + » crée « Tle A2 1 ».
- La dernière classe du couple a des élèves : refus, rien ne change, même si une classe plus haut est vide.
- La classe nommée par la confirmation n'est plus la dernière (un autre membre a ajouté entre-temps) : refus « n'est plus la dernière », rien ne change.
- La classe a déjà été retirée (double envoi) : 404.
- Référentiel sans série liée à un niveau à séries : une ligne sans série pour ce niveau, comme « Ajouter une classe » l'accepte.
- Noms libres ajoutés à la main (« 6ème bilingue ») : ils comptent dans leur couple, mais pas dans la numérotation ; la « dernière » est celle au plus grand numéro, un nom sans numéro passant avant « 6ème 1 ».

## Questions encore ouvertes

- Toutes les décisions du grill ci-dessus sont des **décisions par défaut**, à confirmer par le porteur ; les plus engageantes sont la suppression physique (plutôt que l'archivage) d'une classe vide et le retrait permis sur un établissement non actif.
