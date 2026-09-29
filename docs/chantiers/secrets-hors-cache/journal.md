# Journal — secrets-hors-cache

## 2026-09-29 — cadrage et recensement

- Point de départ : constat « Sécurité » de l'audit `finitions-ux` (§ 5c, § 8 lignes HTTP et Cache Turbo).
- Recensement par recherche des secrets rendus en clair dans `app/views` et des `Cache-Control` posés dans `app/controllers` : 5 actions retenues (voir `memo.md`).
- **Écartés**, avec la raison :
  - lien de parrainage (`identity/referrals/_invite`), code d'établissement (`teams/schools/_header`), code d'adhésion des classes : codes **partagés et durables**, faits pour circuler ; les retirer du cache n'apporte rien ;
  - page d'acceptation d'une invitation (`/invitations/:token`) : le jeton est dans l'URL, la page ne l'affiche pas ; l'en-tête Rails par défaut (`private`) interdit déjà les caches partagés. Si l'on veut aller plus loin (URL avec jeton hors historique), c'est un autre chantier ;
  - vérification du second facteur, réinitialisation du second facteur par l'équipe, remise à zéro du PIN par code : aucun secret affiché.

## Cause

Pas de mécanisme commun : `no-store` posé à la main dans trois contrôleurs (branche succès seule), oublié dans l'enrôlement ; aucune exemption du cache Turbo nulle part. Trou de test : chaque test vérifiait l'en-tête là où il avait été pensé ; aucun ne listait les écrans à secret ni ne regardait le cache Turbo.

## Tests de reproduction — rouges avant correctif

`COVERAGE=0 PARALLEL_WORKERS=1 bin/rails test` sur les 5 fichiers de contrôleur : 36 tests, **10 échecs, 1 erreur**, chacun pour la bonne raison :

- `SecretResponseTest` (garde) : `NoMethodError: undefined method 'secret_actions'` — aucun marquage n'existe ;
- enrôlement `new`, succès HTML, succès Turbo Stream : `Cache-Control` attendu `no-store`, reçu `max-age=0, private, must-revalidate` ;
- enrôlement 422 : attendu `no-store`, reçu `no-cache` (défaut Rails d'une erreur) ;
- code de récupération, invitation d'équipe, invitation de direction (Turbo Stream et HTML) : `Pragma` attendu `no-cache`, reçu `nil` (le `no-store` existait, l'exemption Turbo non plus).

Test système `test/system/identity/secret_back_navigation_test.rb`, joué contre le code de `Develop` : **rouge**, ligne 24 — après « J'ai noté mes codes » puis Retour, `main#main` (accueil équipe) introuvable : Turbo a restauré depuis son cache la page des codes de secours.

## Correctif

Concern `SecretResponse` + `SecretResponseHelper` (meta dans le layout, flux `append` sur `head`), marquage des 5 actions, retrait des trois `response.headers["Cache-Control"] = "no-store"` manuels. Amendement daté de l'ADR-0031.

Après correctif : les 36 tests de contrôleur verts ; test système vert (Retour redemande la page au serveur, qui renvoie le compte enrôlé à l'accueil) ; `team_invitation_test` et `staff_invitation_test` (chemin nominal voisin) verts.

**Cas symétrique** : `SecretResponseTest` vérifie qu'une page sans secret (`/session/new`) garde `max-age=0, private, must-revalidate`, sans `Pragma` ni meta d'exemption.

## Effets de bord écartés

- `no-store` désactive le bfcache du navigateur sur ces seules pages : voulu.
- Le meta ajouté au `<head>` par un flux disparaît à la navigation suivante (Turbo retire les éléments de tête non suivis absents de la nouvelle page) : les autres pages restent en cache.
- Le layout minimal des requêtes de frame n'est pas touché : les actions marquées répondent en flux Turbo ou en page complète, jamais en frame seul.

## Dette / suivi

- Aucune donnée à réparer (secrets stockés en empreinte).
- Préchargement au survol et cache applicatif : chantier `optimize` issu du § 8 de l'audit.
