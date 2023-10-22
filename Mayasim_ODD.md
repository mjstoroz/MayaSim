# MayaSim: Model Documentation

@Scott Heckbert

This model documentation describes MayaSim, an agent-based, cellular automata, and network model of the ancient Maya social-ecological system. The documentation is organised into the updated ODD protocol.[^1] Agents, cells, and networks represent elements of the Maya social–ecological system including settlements and geography, demographics, trade, agriculture, soil degradation, provision of ecosystem services, climate variability, hydrology, primary productivity, and forest succession. Heckbert (2013) and Heckbert et al. (2015) present complete model descriptions including simulation results.[^2] The model, documentation and videos of model runs are available at CoMSES.[^3]

## 1. Purpose

The purpose of the model is to better understand the complex dynamics of social-ecological systems and to test quantitative indicators of resilience as predictors of system sustainability or decline. The ancient Maya are presented as an example. The model examines the relationship between population growth, agricultural production, pressure on ecosystem services, forest succession, value of trade, and the stability of trade networks. These combine to allow agents representing Maya settlements to develop and expand within a landscape that changes under climate variation and responds to anthropogenic pressure.  The model is able to reproduce spatial patterns and timelines somewhat analogous to that of the ancient Maya, although this proof of concept stage model requires refinement and further archaeological data for calibration.

## 2. Entities, state variables and scales

The MayaSim model represents settlements as agents and the geography of Central America in a cellular landscape. Additional agents include a ‘migrant’ agent who settle new locations and a ‘raindrop’ agent which routes hydrological surface flow. The model is constructed using the software Netlogo.[^4] The model interface of the software, shown in **Figure 1**, presents the spatial view of the model with figures tracking model data and a ‘control panel’ for interacting with the model. The view can be changed to observe different spatial data layers within the model. Table 1 presents state variables for global, agent, and cell variables in addition to those available on the user interface. The model operates at a spatial extent of 516,484 km² at a 5 km² resolution. Temporal extent is approximately 300 times steps, each representing roughly 10 years.  

 ![MayaSim Model](image.png)
_Figure 1: MayaSim model interface with interactive controls, spatial view, and figures tracking model data. Agents operate on a cellular landscape and are connected by links within a network._

| **Global**        | **Agents**     | **Cells** |
|--------------|-----------|------------|
| mask-dataset | birthrate      | original-rainfall        |
| elevation-dataset |trade-strength| rainfall       |
| soils-dataset      | centrality  | temp       |
| temp-dataset      | cluster-number  | elevation       |
| precip-dataset      | age  | soil-prod       |
| land-patches      | population  | slope       |
| vacant-lands      | gdp-per-cap  | flow       |
| traders      | trade-GDP  | pop-gradient       |
| border      | yield-GDP  | env-degrade       |
| visited-nodes      | ecoserv-GDP  | npp       |
| network-start      | death-rate  | yield       |
| failed-cities      | out-migration  | ag-suit       |
| crop1-yield      | out-migration-rate  | BCA-ag       |
| climate-cycle-counter      | settlement-yield  | is-ag       |
| abandoned-crops      | ecoserv-benefit  | ag-impact       |
| new-crops      | my-ag-patches  | forest-state       |
| total-migrant-population      | my-influence-patches  | succession-counter       |
| giant-component-size      | rank  | travel-cost       |
| giant-start-node      | trade-benefit  | overland-TC       |
| search-completed      | explored?  | freshwater-TC       |
| area      | city-travel-cost  | cropping-value       |
| total-migrant-utility|   | water-value       |
| Rainfall-Change      |   | forest-food-value       |
|       |   | rain-value       |
|       |   | ecosystem-services-value       |
|     |   | patch-migrant-utility       |
|     |   | Travel-Cost-ut       |
|     |   | ES-ut       |
|     |   | my-settlement       |
|     |   | is-land-patch   |
_Table 1: State variables for agents and cells_

## 3. Process overview and scheduling

The simulation begins with calculations of biophysical variables for precipitation, water flow, and net primary productivity, and these are further used to calculate forest succession, agricultural production, and ecosystem services. Settlement agents interact with the spatial landscape to generate agricultural yield through cropping, derive benefit from local ecosystem services, and generate trade benefits within their local trade network. The combined benefits of agriculture, ecosystem services, and trade drives demographic growth including migration. Simulating the integrated system reveals how the social-ecological system functions through time.  

| **Event sequence**       | **Module** | **Function name** | **Description** |
|--------------|-----------|------------|--|
|1 | Biophysical      | Climate-variation        | Varies rainfall on diagonal northwest gradient   |
|2 | Biophysical      | Rain-surface-flow        |  Calculates water flow  |
|3 | Biophysical      |  Net-primary-prod       |  Calculates net primary productivity |
|4 | Biophysical      |  Forest-succession     |Forest succession modelled as cellular automata   |
|5 | Biophysical      |   Soil-degradation      | Cropped cells incur degradation  |
|6 | Biophysical      |   Ecosystem-services      |Subset of ecosystem services calculated from water, soil, forest condition |
|7 | Anthropogenic      |   Agriculture      |Benefit cost of sowing and abandoning individual crops and calculation of total settlement yield|
|8 | Anthropogenic      |  Demographics       |Birth, death, migration, founding of new settlements |
|9 | Anthropogenic      |  Population-density       |Calculates population density gradient |
|10 | Anthropogenic      | Travel-cost        |Calculates ‘friction’ of cells |
|11 | Anthropogenic      |  Trade       |Arranges settlements in network and calculates trade values |
|12 | Anthropogenic      |  Real-income       |Agriculture, ecosystem services, and trade combine for total real income per person for each settlement |
_Table 2. Event sequence for biophysical and social processes executed each time step._

## 4. Model design concepts

The model sequence organizes the execution of functions for settlements, cells, and network links. These events are organized into two categories, with functions relating to biophysical processes and functions relating to anthropogenic processes, further described in the following sections.

The model is constructed using the software Netlogo.[^5] The software interface presents the spatial view of the model with graphs tracking model output and a user interface for interacting with the model. The view can be changed to visually observe different spatial data and output layers within the model such as the topography, precipitation, soils, population density, forest condition, and so on. The model operates at a spatial extent of 516,484 km² with a 5 km² cell resolution. Imported spatial data include elevation and slope, soil productivity, temperature, and precipitation [^6]

The simulation begins with calculations of biophysical variables for water flow and net primary productivity, and these are further used to calculate forest succession, agricultural production, and ecosystem services. Settlement agents interact with the spatial landscape to generate agricultural yield through cropping, derive benefit from local ecosystem services, and generate trade benefits within their local trade network. The combined benefits of agriculture, ecosystem services, and trade drives demographic growth including migration. Simulating the integrated system reveals how the social-ecological system functions through time.

Spatial data for precipitation and temperature[^7] representing current conditions (1950 to present day) is adjusted within the model with a multiplier which increased and decreased rainfall cyclically by a set percentage for all locations across the landscape, such that:

$$R_{j, t}=R_{j, T} \cdot R C_t \cdot\left(\frac{\operatorname{maxDF}}{\mathrm{DF}_{\mathrm{j}}}\right)+\delta \cdot \sum_n C L_n
$$

Where as _Rⱼ,ₜ_ is precipitation [mm] for cell _j_  at initial time step _T_, and _CLₙ_ is a localized rainfall effect due to the presence of cleared land on neighbouring cells _n_ = 1...8, with weighting parameter _δ_ determining the strength of this effect.  _DFⱼ_ is the distance [km] of each cell from the top northwest corner of the map and _maxDFⱼ_ is the furthest distanced cell from this point. _RCt_ cycles from + 20% to -10% linearly over a 56 time step cycle, and _t_ = 1...650.

This function serves to reduce and increase rainfall cyclically, with a more pronounced effect further towards the northwest. These data are used to calculate surface flow and location of potential seasonal standing water, consistent with Reaney (2008).[^8] The function serves to move water based on elevation, and can generate the spatial distribution and surface water flow as precipitation varies across the climate cycle.

Forest succession operates as a cellular automata model, where the state of a cell is dependent on internal conditions and is influenced by the condition of neighbouring cells. Cells take on one of three general forest states that represent climax forest, secondary regrowth, and cleared/cropped land, referred to as state 1, 2 and 3 respectively. The forest state is decremented for 3.5% of randomly selected cells, to represent natural disturbance. The disturbance rate is linearly amplified by population density of nearby settlements to represent local wood harvesting, to a maximum of 15%. Cells advance in their forest state based on the time since last disturbance and the relative net primary productivity of the cell.

Once the time since last disturbance is above a threshold,

$$40 \cdot(\frac{\operatorname{N P P_{max j, t}}}{\mathrm{N P P}_{\mathrm{j,t}}})$$

years for secondary growth, and

$$100 \cdot(\frac{\operatorname{N P P_{max j, t}}}{\mathrm{N P P}_{\mathrm{j,t}}})$$

years for climax growth, to account for variation in net primary productivity, the forest converts to the new state.

For conversion to climax forest, a cellular automata function is applied that requires a number of neighbouring cells to also contain climax forest. This rule represents the need to have local vegetation for seed dispersal.  

Net primary productivity _NPPⱼ,ₜ_ [gC m² ⁻¹ yr⁻¹], is a function of precipitation and temperature, calculated based on Lieth's (1972) Miami model:[^9]

$$
N P P_{j, t}=\min \left(\begin{array}{l}
3000 \cdot\left(1-\exp \left(-0.000664 \mathrm{R}_{\mathrm{j}, \mathrm{t}}\right)\right) \\
3000 /\left(1+\exp \left(1.315-\left(0.119 \cdot \mathrm{T}_{\mathrm{j}}\right)\right)\right)
\end{array}\right)
$$

Where _Rⱼ,ₜ_ is precipitation [mm] and _Tⱼ_ is temperature [degrees C].

For each cell, agricultural productivity _AGⱼ,ₜ_ is calculated as:

$$
A G_{j, t}=\beta_{N P P} \cdot N P P_{j, t}+\beta_{S P} \cdot S P_j-\beta_S \cdot S_j-\beta_{W F} \cdot W F_{j, t}-S D_{j, t}
$$

Where _SPⱼ_ is soil productivity[^10] [index 1-100], _Sⱼ_ is slope [%], _WFⱼ,ₜ_ is water flow calculated as the sum volume of water agents traversing any given cell _j_, as depicted in **Figure 2**, and _SDⱼ,ₜ_ is soil degradation [% loss of productivity]. Soil degradation occurs at a constant rate of 1.5% per time step for each cropped cell.

Ecosystem services are modelled by quantifying the availability provisioning services relating to water, food, and raw materials(as defined in the Millenimum Assessment, 2005, and The Economics of Ecosystems and Biodivsersity, 2010).[^11] This is a subset of ecosystem services and does not include a full set of indicators which would incorporate supporting services (for example erosion prevention), habitat services (such as maintenance of genetic diversity) or cultural services (such as inspiration for culture, art, and design). The current ecosystem services equation incorporates a subset of four important services provision based on arable soils, precipitation, access to available freshwater, and timber resources. Ecosystem services _ESⱼ_   are calculated as:

$$
E S_{j, t}=\delta_{A G} \cdot A G_{j, t}+\delta_R \cdot R_{j, t}+\delta_{W F} \cdot W F_{j, t}+\delta_F \cdot F_{j, t}-E S D_{j, t}
$$

Where _AGⱼ,ₜ_  is taken from equation 3, _Rⱼ,ₜ_ is taken from equation 1, _WFⱼ,ₜ_  is the simulated water flow volume, and _Fⱼ,ₜ_  is the forest state [1-3], _ESDⱼ,ₜ_ is a catch-all proxy variable for all other ecosystem services degradation [%] as a function of population density.

Each settlement agent _i_  maintains at least one cell _j_  for generating agricultural yield. Settlements perform an agriculture benefit-cost assessment considering the costs of production, travel cost given the distance of the cell from the settlement site, and with larger settlements achieving economies of scale, modelled as:

$$
B C A_{j, t}=\left(\kappa_j \cdot\left(1-\alpha \cdot \exp ^{-\phi \cdot A G_{j, t}}\right)-\gamma\right)-\frac{O_j}{\log P_{i, t}}
$$

Where _BCAⱼ,ₜ_ is the total benefit provided from agriculture yield, _κⱼ_ , _α_ , _φ_ and   are crop yield and slope parameters, _AGⱼ,ₜ_   is again taken from equation 3, _γ_ is the establishment cost of agriculture (annual variable costs), _Oⱼ_ is the agriculture travel cost as a function for distance from the city and a per km cost parameter, and _Pᵢ,ₜ_ is population of the settlement.  

The benefit-cost of agriculture function generates yields that are spatially distributed based on individual conditions of the cells and the location of settlements. Costs of production, including distance from settlements, results in adding cropped cells, generating yield and increasing population, which in turn add more cropped cells, but causes soil degradation. The system adjusts over time in response to the spatially-explicit agricultural benefit-cost.

A series of functions represent trade within a spatially connected network of agents. It is assumed that through the process of specialization, settlements that are connected to one another within a network will generate benefits from trade. It is assumed a larger network produces greater trade benefits, and also the more central a settlement is within the network, the greater the trade benefits for that individual settlement. To model these benefits, settlements are connected via a network of links that represent trade routes. As a simplifying assumption of how they connect together, it is assumed when a settlement reaches (or drops below) a certain size, they will add routes (or allow routes to degrade) to nearby settlements within a radius proportional to the size of the settlement’s population (40 km for small settlements). At each time step, the size of the local network is calculated as well as each settlement’s centrality within that local network, further discussed below.

Combining the functions for agriculture, ecosystem services, and trade benefit, total real income per capita  is calculated as:

$$
R I_{i, t}=\vartheta_{A G} \cdot \sum_{A G J_{i, t}} B C A_{j, t}+\vartheta_{E S} \cdot \sum_{I J_{i, t}} E S_{j, t}+\vartheta_{T R_t} \cdot \frac{N_{i, t}}{C_{i, t} \cdot T C_{i, t}}
$$

Where _Nᵢ,ₜ_  is the network size [# nodes],  _Cᵢ,ₜ_ is the centrality [degree] and _TCᵢ_ is the travel cost, and _𝜗_ parameters are prices for agriculture, ecosystem services, and trade, respectively. Benefits from agriculture are calculated only for cells under cropping production _AGJᵢ,ₜ_ = 1..._n_  whereas ecosystem services are calculated encompassing the entire ‘area of influence’ of each settlement _IJᵢ,ₜ_ = 1..._m_ which is based on the population size of the settlement, increasing linearly to a maximum of 40 km in diameter for the most populous settlements (those with populations greater than 15000 people), as taken from Heckbert et al. (2015) and interpreted from Chase and Chase (1998).[^12] Travel cost measures the relative ‘friction’ of different land cover types, and is represented as:

$$
T C_{i, t}=\sum_{I J_{i, t}}\left(v \cdot S_j-\rho \cdot W F_{j, t}\right)
$$

Where _Sⱼ_  is slope and _WFⱼ,ₜ_  is simulated water flow volume, both described in previous equations, resulting in areas of higher slope being relatively more costly to travel through, mitigated by the presence of flowing water for canoe transport.

After determining _RIᵢ,ₜ_ settlement demographics account for births, deaths, and migration. The birth rate is assumed to remain constant at 15%, while death rate and out-migration decrease linearly with increased _RIᵢ,ₜ_  per capita, with a maximum out-migration rate of 15% and a maximum death rate of 25% per annum. Settlements with a population below a minimum number required to maintain subsistence agriculture are deleted. Settlements that register out-migration above a minimum threshold of the number of people required to maintain subsistence agriculture create a ‘migrant agent’. The migrant agent uses a utility function to select locations to create a new settlement.[^13] The migration utility function is calculated as:

$$
M U_{i, j, t}=\lambda_{i, j}^{E S} \cdot E S_{j, t}+\lambda_{i, j}^D \cdot D_j
$$

Where _λ_  parameters are weightings for travel cost and ecosystem services, and _ESⱼ,ₜ_  is taken from equation 4, and _Dⱼ_  is the distance from the origin settlement to the potential new settlement site.

## 5. Initialisation

Upon model initialisation, base GIS layers are loaded using the Netlogo GIS extension. Static cell variables are set, dynamic variables are reset to default values and settlement agents are randomly initialised in the spatial landscape.

## 6. Input Data

Imported spatial data include elevation and slope, soil productivity, temperature and precipitation. Data is resampled using the Netlogo GIS extension. Results in this paper are reported for models run at a 5 km² resolution with an spatial extent of 516,484 km².

[^1]: Grimm, V., Berger, U., DeAngelise, D., Polhill, G., Giske, J., Railsback, S. (2010). The ODD Protocol: A review and first update. _Ecological Modelling, 221 2760-2768_. <https://doi.org/10.1016/j.ecolmodel.2010.08.019>

[^2]: **1.** For a description of the model's funtions and behaviors see the following resource: Heckbert, S. (2013). MayaSim: An agent-based model of the rise and fall of the Maya social-ecological system. _Journal of Artificial Societies and Social Simulation_. <https://doi.org/10.18564/jasss.2305>. **2.** For a description of the underlying archaeological assumptions see the following resource: Heckbert, S., Isendahl, C., Gunn, J., Brewer, S., Scarborough, V., Chase, A.F.,  Chase, D.Z., Costanza, R., Dunning, N., Beach, T., Luzzadder-Beach, S., Lentz, D., Sinclair, P.. (2015). Growing the ancient Maya social-ecological system from the bottom up. In: Isendahl, C., and Stump, D. (eds.), Applied Archaeology, Historical Ecology and the Useable Past. Oxford University Press. <https://doi.org/10.1093/oxfordhb/9780199672691.013.30>

[^3]: [The Network for Computational Modeling in the Social and Ecological Sciences (CoMSES Net)](https://www.comses.net)

[^4]:Wilenski, U. (1999) NetLogo. Center for Connected Learning and Computer-Based Modeling, Northwestern University. Evanston, IL. <http://ccl.northwestern.edu/netlogo/>
[^5]:Wilenski, U. (1999) NetLogo. Center for Connected Learning and Computer-Based Modeling, Northwestern University. Evanston, IL. <http://ccl.northwestern.edu/netlogo/>
[^6]:Farr, T. G., et al. (2007), The Shuttle Radar Topography Mission, Rev. Geophys., 45, RG2004, <https://doi.org//10.1029/2005RG000183> FAO 2007 Soil Production Index. <http://www.fao.org:80/geonetwork?uuid=f7a2b3c0-bdbf-11db-a0f6-000d939bc5d8> (this is incorrect / dead link). Hijmans, R.J., S.E. Cameron, J.L. Parra, P.G. Jones and A. Jarvis, 2005. Very high resolution interpolated climate surfaces for global land areas. International Journal of Climatology 25: 1965-1978. <https://doi.org/10.1002/joc.1276>
[^7]:Hijmans, R.J., S.E. Cameron, J.L. Parra, P.G. Jones and A. Jarvis, 2005. Very high resolution interpolated climate surfaces for global land areas. International Journal of Climatology 25: 1965-1978. <https://doi.org/10.1002/joc.1276>
[^8]: Reaney, S. M. (2008). The use of agent based modelling techniques in hydrology: determining the spatial and temporal origin of channel flow in semi‐arid catchments. Earth Surface Processes and Landforms: The Journal of the British Geomorphological Research Group, 33(2), 317-327. <https://doi.org/10.1002/esp.154>
[^9]:Lieth, H., 1975. Modeling the primary productivity of the world. In: Lieth, H., Whittaker, R.H. (Eds.), Primary Productivity of the Biosphere. Springer-Verlag, New York, pp. 237–263. <https://doi.org/10.1007/978-3-642-80913-2_12>
[^10]: FAO 2007 Soil Production Index. <http://www.fao.org:80/geonetwork?uuid=f7a2b3c0-bdbf-11db-a0f6-000d939bc5d8> (this is incorrect / dead link).
[^11]: The Economics of Ecosystems and Biodiversity <https://teebweb.org/>, The Millenium Ecosystem Assessment <https://www.millenniumassessment.org/en/index.html>
[^12]: Chase, A. F., & Chase, D. Z. (1998). Scale and intensity in classic period Maya agriculture: Terracing and settlement at the" garden city" of Caracol, Belize. Culture & Agriculture, 20(2‐3), 60-77. <https://doi.org/10.1525/cag.1998.20.2-3.60>
[^13]: Heckbert, S., Baynes, T. and Reeson, A., 2010. Agent‐based modeling in ecological economics. Annals of the New York Academy of Sciences, 1185(1), pp.39-53. <https://doi.org/10.1111/j.1749-6632.2009.05286.x>
