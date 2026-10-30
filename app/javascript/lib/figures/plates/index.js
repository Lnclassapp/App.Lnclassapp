// ⚡ FRONT · lib/figures/plates/index — la liste fermée des planches de la sorte plate
// Rôle : `PLATES` associe l'identifiant d'une planche à son module (TITLE, PARTS, draw) ; une planche de plus = un fichier et une ligne ici
// ADR  : XXXX-figures-des-matieres-de-3eme (§4.2 plate) · UDR : XXXX-figures-des-matieres-de-3eme (§3 plate) · lu par lib/figures/plate

import * as digestive_system from "./digestive_system"
import * as blood_smear from "./blood_smear"
import * as heart from "./heart"
import * as double_circulation from "./double_circulation"
import * as female_reproductive_system from "./female_reproductive_system"
import * as hiv_virus from "./hiv_virus"
import * as soil_profile from "./soil_profile"
import * as root_hairs from "./root_hairs"

export const PLATES = {
  digestive_system,
  blood_smear,
  heart,
  double_circulation,
  female_reproductive_system,
  hiv_virus,
  soil_profile,
  root_hairs
}
