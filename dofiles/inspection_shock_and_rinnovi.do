import excel "/home/group/main/892fl/policy/2026/2026_nota_drift/rawdata/Data_OIL_ELE_GAS.xlsx", sheet("Foglio1") firstrow clear
gen date=ym(real(substr(Date,1,4)),real(substr(Date,6,7)))
format date %tm
tsset date 

*oil
gen delta_oil=100*(OilSpotUSDBarrel-l12.OilSpotUSDBarrel)/l12.OilSpotUSDBarrel


*gas 
gen delta_gas=100*(TTFSpotEURMWH-l12.TTFSpotEURMWH)/l12.TTFSpotEURMWH

*ele
gen delta_ele=100*(ELE_ItalyEURMWH-l12.ELE_ItalyEURMWH)/l12.ELE_ItalyEURMWH

graph twoway (connect delta_oil delta_gas delta_ele date, yline(0))
