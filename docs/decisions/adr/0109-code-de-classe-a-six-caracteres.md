# ADR-0109 : Le code de classe à six caractères revient, à côté du lien, vérifié à débit limité
<!-- index
titre: Code de classe à six caractères, vérifié à débit limité
statut: Accepté *(porteur, 2026-10-23)*
problematique: L'ADR-0085 a retiré le code de classe au profit de la cascade et du lien ; pour le pilote, le porteur veut qu'un élève puisse taper le code que son enseignant écrit au tableau. Le code revient en base, à côté du lien, avec une vérification qui ne révèle que le nom de la classe et qui ne se laisse pas énumérer.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : « oui, accepte l'ADR ») |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **Amende** | [ADR-0085](0085-inscription-eleve-sans-code-de-classe.md) (le code retiré revient ; la cascade et le lien restent) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le 2026-10-08, l'ADR-0085 a retiré le code de classe (colonne `join_code`, 5 caractères) : un élève dont l'enseignant n'est pas sur Lnclass n'avait pas de code, et la cascade DRENA → établissement → niveau → classe le remplaçait, avec un lien de classe (`link_token`, 12 hexadécimaux) à partager sur WhatsApp.

Pour le pilote du 27 octobre, le porteur veut aussi la voie la plus directe en classe : l'enseignant écrit un code au tableau, l'élève le tape (memo, grill du 2026-10-22). Le lien ne se dicte pas ; la cascade demande quatre choix. La vérification d'un code est une surface d'énumération déjà relevée (ID-07) : elle doit rester sous contrôle.

## 2. Moteurs de décision

1. **Ne rien révéler de plus que le lien** : la vérification ne renvoie que ce qu'affiche déjà l'aperçu du lien (nom de la classe, niveau, établissement).
2. **Rendre l'énumération inutile** : grand espace de codes, débit limité, aucune donnée d'élève exposée.
3. **Réutiliser** : le motif du code d'établissement (`Entities::School::SchoolCode`, 6 symboles sans caractères ambigus) et le compteur de débit du lien (`classroom/joins`).
4. **Tenir en un jour** avant le 27, revue de sécurité comprise.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| **A. Code de 6 caractères en base, à côté du lien** (retenue) | Se dicte et s'écrit au tableau ; même motif que le code d'établissement ; vérifiable sans compte | Une colonne, une migration, une route de vérification à protéger |
| B. Dériver le code du `link_token` (6 premiers caractères) | Pas de colonne | Alphabet hexadécimal, espace réduit à 16⁶ ; changer le lien change le code sans le dire ; couplage caché |
| C. Pas de code, seulement le lien et la cascade (statu quo ADR-0085) | Zéro travail | Refusé par le porteur pour le pilote |

## 4. Décision

1. **Colonne `classrooms.join_code`**, `string(6)`, non nulle, unique, contrainte `join_code ~ '^[a-hj-np-z2-9]{6}$'` (31 symboles, sans `i`, `l`, `o`, `0`, `1`). Stockée en minuscules, **affichée en majuscules groupées par trois** (« K7M 4Q2 »), saisie insensible à la casse et aux espaces.
2. **Valeur** : `Entities::Classroom::JoinCode` (calqué sur `SchoolCode`), `generate` par `SecureRandom`, 5 essais en cas de collision. Générée à la création de la classe ; la migration remplit les classes existantes.
3. **Un seul geste pour changer** : l'action existante « Changer le lien » devient « Changer le lien et le code » et régénère les deux. Elle reste réservée à `ManageClassroomMembersPolicy` et journalisée.
4. **Vérification** : `GET /classroom-codes/:code` (Turbo Frame, pas de JSON public) → `Queries::Classroom::JoinCodePreviewQuery`. Réponse « trouvée » : nom de la classe, niveau, établissement (sigle ou nom), et si elle est complète. Réponse « inconnue » : la même page, sans distinguer « archivée » de « inexistante ». Aucun élève, aucun enseignant, aucun identifiant interne dans la réponse.
5. **Débit** : le même compteur que le lien (`scope: "classroom/joins"`, 10 par minute et par IP), partagé entre `/c/:token`, la vérification de code et l'envoi de l'inscription. Au-delà : 429 et message « Trop de tentatives ».
6. **Inscription** : le formulaire envoie le code ; `RegisterStudent` résout la classe par le code (ou le jeton, ou le choix de la cascade) et marque l'inscription `joined_via: "code"` (valeur déjà admise par la contrainte de `classroom_students`). Une classe archivée ou complète refuse comme aujourd'hui.
7. **Élève connecté sans classe** : la même vérification sert l'état « Choisis ta classe » de l'accueil ; l'adhésion passe par `POST /students/classroom` existant, qui accepte désormais un code.

## 5. Conséquences

### 🟢 Positives

- L'élève en classe tape 6 caractères et voit sa classe confirmée avant de donner son nom.
- L'enseignant a un code à dicter et un lien à partager, changés d'un seul geste.
- Le code d'établissement et le code de classe suivent le même motif : un seul objet de valeur à comprendre.

### 🔴 Coûts consentis

- **Énumération** : 31⁶ ≈ 887 millions de codes. Avec 10 000 classes, un essai au hasard tombe juste une fois sur 88 750 ; à 10 essais par minute et par IP, une IP trouve une classe en 6 jours en moyenne, et n'apprend que son nom et son établissement. Un réseau d'IP va plus vite : le risque accepté est l'inscription d'un faux élève dans une classe, que l'enseignant voit (« Par le code ») et retire.
- Une colonne et une migration de remplissage, contraires à l'ADR-0085.
- Un code régénéré invalide celui écrit au tableau : l'enseignant doit le réécrire.

## 6. Notes d'implémentation

- Migration réversible : ajout nullable, remplissage par lots avec le générateur, puis `NOT NULL`, index unique et contrainte de format. Test de migration comme `test/db/remove_classroom_join_codes_migration_test.rb`.
- Les tests d'absence du code de l'ADR-0085 (`student_classrooms_controller_test.rb:39`, test de migration) sont à remplacer, pas à supprimer sans équivalent.
- `config/initializers/filter_parameter_logging.rb` filtre déjà `:code`, qui couvre `join_code` (correspondance partielle) : rien à ajouter.
- Affichage enseignant : sur la **carte de la classe de l'accueil enseignant** seulement, « Code de la classe » et « Copier » (UDR-0134 §3.3). La page de classe n'a pas de ligne de code ; son action « Changer le lien » (menu ⋮ du bloc « Inscrire vos élèves ») devient « Changer le lien et le code ».
- **Revue de sécurité obligatoire** avant fusion (`security-reviewer`) : énumération, fuite dans la réponse, compteur partagé, journalisation.

## 7. Comment vérifier que la décision est respectée

- Test de domaine : `JoinCode.generate` ne produit que des symboles de l'alphabet, longueur 6.
- Test d'intégration : code valide → aperçu sans donnée d'élève ; code inconnu et code d'une classe archivée → même réponse ; 11ᵉ essai dans la minute → 429.
- Test de contrainte : une valeur hors format est refusée par la base.
- Test système : un élève tape le code, voit « 3e B · Collège Moderne 1 de Tiassalé », s'inscrit, et apparaît chez l'enseignant marqué « Par le code ».
