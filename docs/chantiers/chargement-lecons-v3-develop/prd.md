# PRD — Develop charge seul les leçons v3 du programme, entières

## 1. Contexte

Voir [memo](memo.md) et [ADR-0123](../../decisions/adr/0123-develop-charge-les-lecons-v3-du-programme-entieres.md), qui amende ADR-0122 pour Develop seul.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | voir dans Imports la ligne de chaque leçon chargée | déclencher le chargement depuis l'écran ; remplacer à la main une leçon publiée |
| Teacher, Student (Develop) | voir les leçons v3 | garder leurs résultats sur une leçon remplacée |

Aucune policy nouvelle (auteur : le plus ancien membre actif de l'équipe, ADR-0122 §4.5).

## 3. Parcours

1. Une vague du programme est fusionnée dans `Develop` ; Railway redéploie Develop.
2. Le pré-déploiement lance `contenus:charger` ; l'environnement s'appelle `Develop`.
3. Pour chaque fichier v3 sans sujet d'un dossier de la liste du programme : empreinte inchangée → rien (ou reprise de publication) ; sinon import en mode « leçon entière » : absente → créée, présente (même titre, niveau, matière, série), publiée ou non → remplacée entière.
4. La cascade publie la leçon ; le journal dit `created` ou `replaced`.

## 4. Critères d'acceptation

| # | Critère | Test |
|---|---|---|
| CA-1 | Develop (toute casse) remplace entière une leçon v1 publiée du même titre, efface ses résultats, publie la v3, dit `replaced` | intégration, use case |
| CA-2 | Develop crée une leçon absente et dit `created` | intégration, use case |
| CA-3 | Fichier inchangé : rien ; publication incomplète : reprise seule | use case, intégration |
| CA-4 | Staging, production, environnement de PR, nom inconnu : jamais de remplacement entier | entité, intégration |
| CA-5 | Une leçon à sujets garde le mode exercices seuls, sur Develop comme Staging | entité, use case |
| CA-6 | Hors des dossiers du programme (3ème), une leçon sans sujet n'est pas chargée | entité, use case |
| CA-7 | L'import à la main refuse toujours une leçon publiée (`lesson_already_published`) | intégration, adaptateur |
| CA-8 | Le pré-déploiement n'échoue jamais (inchangé, ADR-0122 §4.6) | intégration existante |
