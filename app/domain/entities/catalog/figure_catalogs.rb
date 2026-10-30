# 🧠 DOMAINE · Entities::Catalog::FigureCatalogs
# Rôle : listes fermées des identifiants (aires et lieux) de chaque fond de carte d'une figure `map` et des parties de chaque planche d'une figure `plate` ; Ruby pur, lu par Figure et par le script de contenus
# ADR  : 0117-figures-des-matieres-de-3eme (§4.2, §4.3) · UDR : 0142-dessin-des-figures-de-3eme (§3)
module Entities
  module Catalog
    module FigureCatalogs
      COTE_D_IVOIRE_AREAS = %w[
        abidjan yamoussoukro bas_sassandra comoe denguele goh_djiboua lacs lagunes montagnes sassandra_marahoue savanes vallee_du_bandama woroba zanzan
        dense_forest savanna coastal_strip mountain_west
      ].freeze
      COTE_D_IVOIRE_PLACES = %w[
        abidjan yamoussoukro bouake daloa korhogo san_pedro man gagnoa abengourou bondoukou odienne divo sassandra grand_bassam bingerville assinie grand_lahou
        dabou agboville kong seguela ferkessedougou katiola dimbokro aboisso tabou soubre toumodi tiassale danane boundiali touba guiglo duekoue bouafle adzope
        issia kossou taabo buyo ayame
      ].freeze

      AFRICA_AREAS = %w[
        dza ago ben bwa bfa bdi cmr cpv caf tcd com cod cog civ dji egy gnq eri swz eth gab gmb gha gin gnb ken lso lbr lby mdg mwi mli mrt mus mar moz nam ner
        nga rwa stp sen syc sle som zaf ssd sdn tza tgo tun uga zmb zwe
      ].freeze
      AFRICA_PLACES = %w[
        algiers luanda porto_novo gaborone ouagadougou gitega yaounde praia bangui ndjamena moroni kinshasa brazzaville yamoussoukro djibouti cairo malabo asmara
        mbabane addis_ababa libreville banjul accra conakry bissau nairobi maseru monrovia tripoli antananarivo lilongwe bamako nouakchott port_louis rabat
        maputo windhoek niamey abuja kigali sao_tome dakar victoria freetown mogadishu pretoria juba khartoum dodoma lome tunis kampala lusaka harare
        abidjan lagos johannesburg casablanca alexandria mombasa douala suez
      ].freeze

      WORLD_AREAS = %w[
        afg ago alb are arg arm atf aus aut aze bdi bel ben bfa bgd bgr bhs bih blr blz bol bra brn btn bwa caf can che chl chn civ cmr cod cog col cri cub cyp cze
        deu dji dnk dom dza ecu egy eri esh esp est eth fin fji flk fra gab gbr geo gha gin gmb gnb gnq grc grl gtm guy hnd hrv hti hun idn ind irl irn irq isl isr
        ita jam jor jpn kaz ken kgz khm kor kos kwt lao lbn lbr lby lka lso ltu lux lva mar mda mdg mex mkd mli mmr mne mng moz mrt mwi mys nam ncl ner nga nic nld
        nor npl nzl omn pak pan per phl png pol pri prk prt pry pse qat rou rus rwa sau sdn sen slb sle slv som srb ssd sur svk svn swe swz syr tcd tgo tha tjk
        tkm tls tto tun tur twn tza uga ukr ury usa uzb ven vnm vut yem zaf zmb zwe
        africa asia europe north_america south_america oceania
      ].freeze
      WORLD_PLACES = %w[
        pearl_harbor hiroshima nagasaki stalingrad normandy berlin london paris moscow washington tokyo rome el_alamein midway warsaw yalta brazzaville new_york
        san_francisco geneva the_hague abidjan
      ].freeze

      MAP_BASES = {
        "cote_d_ivoire" => { areas: COTE_D_IVOIRE_AREAS, places: COTE_D_IVOIRE_PLACES }.freeze,
        "africa" => { areas: AFRICA_AREAS, places: AFRICA_PLACES }.freeze,
        "world" => { areas: WORLD_AREAS, places: WORLD_PLACES }.freeze
      }.freeze

      # Parties de chaque planche : SVT (PRD contenus-3e-svt §5) puis PC (PRD contenus-3e-physique-chimie §4), dans l'ordre de lib/figures/plates/<planche>.js (test de parité).
      PLATES = {
        "digestive_system" => %w[mouth salivary_glands oesophagus stomach liver gallbladder pancreas small_intestine large_intestine rectum anus].freeze,
        "blood_smear" => %w[red_blood_cell neutrophil lymphocyte monocyte platelet plasma].freeze,
        "heart" => %w[right_atrium left_atrium right_ventricle left_ventricle septum aorta pulmonary_artery superior_vena_cava inferior_vena_cava
                      pulmonary_veins tricuspid_valve mitral_valve].freeze,
        "double_circulation" => %w[right_heart left_heart lungs organs pulmonary_artery pulmonary_veins aorta vena_cava].freeze,
        "female_reproductive_system" => %w[ovary oviduct infundibulum uterus endometrium cervix vagina].freeze,
        "hiv_virus" => %w[envelope gp120 gp41 matrix capsid rna reverse_transcriptase].freeze,
        "soil_profile" => %w[litter humus_horizon accumulation_horizon weathered_rock bedrock roots].freeze,
        "root_hairs" => %w[collar main_root lateral_root root_hair_zone elongation_zone root_cap root_hair soil_particle soil_water].freeze,
        "dynamometer" => %w[ring tube spring scale pointer hook load].freeze,
        "electrolyser" => %w[generator vessel electrolyte anode cathode oxygen_tube hydrogen_tube oxygen hydrogen].freeze,
        "eudiometer" => %w[tube scale electrodes spark gas_mixture water trough].freeze
      }.freeze

      # → Array<String> ; vide pour un fond inconnu.
      def self.areas(base) = MAP_BASES.dig(base, :areas) || []
      def self.places(base) = MAP_BASES.dig(base, :places) || []
      # → Array<String> ; vide pour une planche inconnue.
      def self.parts(plate) = PLATES[plate] || []
    end
  end
end
