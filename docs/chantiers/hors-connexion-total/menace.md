# Menace — Hors connexion total après installation

Prolonge [`../hors-connexion/menace.md`](../hors-connexion/menace.md) (P1 à P6 restent vraies). Seules les menaces nouvelles sont ici.

| # | Menace | Parade | Test |
|---|---|---|---|
| T1 | Un compte sans abonnement lit, sur un appareil partagé, le contenu payant gardé pour un compte abonné | Le programme d'arrière-plan ne sert une page commune que si elle figure dans la liste **du compte connecté** (rangée sous sa clé) et avant sa date de fin d'accès ; sinon « Pas de connexion ». **Coût accepté** : le filtre est un filtre d'affichage, pas un chiffrement ; un utilisateur averti peut lire le Cache Storage avec les outils du navigateur | CA-9, `page_cache.test.js` |
| T2 | Un abonnement expiré garde le payant indéfiniment hors ligne | Date de fin d'accès dans la liste, contrôlée par l'appareil à chaque lecture ; effacement au retour du réseau (CA-11). Un appareil jamais reconnecté qui recule son horloge contourne la date : **coût accepté**, la copie reste rejugée par le serveur | CA-10, CA-11 |
| T3 | Une page commune contient une donnée de compte (nom, note, clé) et la fait fuiter à l'autre compte | Rendu neutre dédié (`Lnclass-Offline: catalog`) ; test qui échoue si un nom, une note ou la clé d'appareil apparaît | CA-4 |
| T4 | Le jeton de corrigé en lot ouvre un exercice non autorisé | Le use case rejoue `StartSessionPolicy` et l'accès Billing exercice par exercice ; au plus 200 jetons par appel ; 30 appels par minute | CA-13 |
| T5 | Une copie forge une ancienne version favorable | La version est lue sur le serveur par l'empreinte du jeton signé ; seule une version réellement servie (`first_served_at`) et remplacée depuis 30 jours au plus est acceptée | CA-15, CA-16 |
| T6 | Une action d'enseignant forgée crée un devoir sur une classe d'un autre | `SyncOfflineAction` n'accepte que 4 types d'action et passe par les use cases existants et leurs policies, avec l'acteur de la session ; rien n'est lu de l'identité dans le corps | CA-21 |
| T7 | Rejeu d'une action (double devoir) | Reçu unique `(user_id, client_action_id)`, écrit dans la même transaction que l'effet | CA-22 |
| T8 | Le téléchargement sature le serveur (des milliers d'appareils au même moment) | Liste servie par une query unique, pages servies comme en ligne ; l'appareil demande 2 pages à la fois au plus, et attend 1 s après un 429 ou un 503, puis le double, jusqu'à 60 s | CA-5 |
| T9 | Un bug du programme d'arrière-plan casse la navigation en ligne | Réseau d'abord inchangé pour toute page HTML ; les caches communs ne sont lus qu'en cas d'échec réseau | test existant `service_worker` + CA-8 |
