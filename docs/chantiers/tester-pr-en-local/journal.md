# Journal — tester-pr-en-local

## 2026-10-21

- Le porteur écarte les environnements de PR Railway (coût) et ne peut plus se connecter à Railway depuis le 2026-10-20. Le tunnel public depuis la session cloud de l'agent est impossible : le proxy ne laisse sortir que du HTTPS sur le port 443, et le tunnel Cloudflare répond 530. Il retient « sur ma machine ».
- `bin/tester-pr` : le code de la PR est récupéré détaché (`git fetch origin pull/<n>/head`, puis `git switch --detach`). Aucune branche locale ne reste, et `git switch -` ramène le porteur où il était. Le script refuse de démarrer sur des modifications non commitées. Son corps est lu en entier avant de s'exécuter, parce que le checkout peut remplacer le script lui-même.
- Essai : sans `BINDING`, le serveur n'écoute que `127.0.0.1`. Avec `BINDING=0.0.0.0`, la page répond 200 quand on l'appelle par l'adresse IP, et Rails accepte en développement un hôte qui est une adresse IP. D'où `--telephone`.
- **Demande du porteur, en cours de chantier** : des enseignants et des élèves de test pour une simulation complète, puis 3 établissements, 3 classes par niveau de la 6ème à la Tle, 35 à 45 élèves par classe, 6 enseignants par classe, des enseignants à plusieurs matières et d'autres dans plusieurs établissements. Le référentiel n'a que 6 matières (pas d'anglais) : ce sont les 6 enseignants de chaque classe, au collège compris.
- `db/seeds/demo/trois_etablissements.rb` écrit par insertions groupées, sans passer par les use cases, pour rester rapide : 4 s pour 2 555 élèves, 63 enseignants et 63 classes. Il ne simule aucune activité.
- `db/seeds/demo/saint_michel.rb` était cassé sur `Develop` depuis les chantiers des annonces : `CreateMessage` exige `illustrations:`, et `MessageInput` n'a plus `visible_until` (la date de fin est calculée, ADR-0081 §4.1). Réparé et rejoué jusqu'au bout. Aucun test ne le joue, parce qu'il dure environ 20 minutes : la prochaine dérive ne se verra qu'à l'usage.
