// ⚡ FRONT · pwa — enregistre le programme d'arrière-plan (/service-worker.js) à la portée « / »
// Rôle : rend le site installable et donne la page « Pas de connexion » hors réseau ; rien si le navigateur ne sait pas
// ADR  : 0082 (§4.2), 0049 · Turbo garde le même document : l'enregistrement n'a lieu qu'au premier chargement
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" }).catch(() => {})
}
