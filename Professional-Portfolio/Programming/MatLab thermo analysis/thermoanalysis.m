%% MAE 2300 - Complex Problems Set #03, Problem 3
% Steam-turbine thermodynamics, configuration enumeration, and economics.
% Run this script in MATLAB. It creates MATLAB tables and exports them to
% an Excel workbook plus CSV files in the current working directory.
%
% IMPORTANT MODEL ASSUMPTIONS
% 1) Turbine isentropic efficiency: eta_t = (h1-h2_actual)/(h1-h2s).
% 2) Each listed capacity is rated electrical output; generator losses are
%    neglected because no generator efficiency is supplied.
% 3) Steady, adiabatic turbine; changes in kinetic and potential energy are
%    neglected, so actual specific work equals the actual enthalpy drop.
% 4) At the condenser pressure, the isentropic outlet is treated as a wet
%    saturated mixture. Actual outlet quality is calculated the same way.
% 5) Plant operates 8760 h/year at the target demand (300 MW now or 330 MW
%    after 10% growth), rather than automatically selling all installed
%    capacity. Part-load dispatch is allowed with no part-load penalty.
% 6) Economic dispatch uses B before A (same incremental $/kWh, B is more
%    efficient), then C (higher incremental operating cost). This is only a
%    transparent dispatch assumption; change dispatchForDemand() if needed.
% 7) Annual operating costs include only the two costs stated in the prompt:
%    $0.01/kWh for steam generation/condensing plus each turbine's added
%    operating cost. No labor, taxes, financing, fixed maintenance, or
%    construction schedule is included. Simple payback = capital cost divided
%    by annual revenue minus these operating costs.
%
% Steam properties are rounded table values for 5 MPa, 400 deg C and
% saturated water at 30 deg C. Sources:
% https://pressbooks.pub/thermo/chapter/superheated-vapor-tables/
% https://pressbooks.pub/thermo/chapter/saturation-properties-temperature-table/

clear; clc;

%% 1) User-editable plant assumptions
currentDemandMW       = 300;       % expected present demand, MW
futureDemandIncrease  = 0.10;      % up to 10% growth
futureDemandMW        = currentDemandMW * (1 + futureDemandIncrease);
minimumOutagePowerMW  = 250;       % minimum plant output after one turbine trips
annualOperatingHours  = 8760;      % continuous operation, 365 days/year
baseSteamCostPerkWh  = 0.01;      % steam generation + condensing cost, $/kWh
energyPricesPerkWh   = [0.04 0.05 0.06];
maxInstalledCapacityMW = 400;      % upper bound for configuration enumeration

%% 2) Steam-table states
% Turbine inlet: P1 = 5 MPa, T1 = 400 deg C (superheated steam)
h1_kJkg = 3196.7;                 % inlet specific enthalpy, kJ/kg
s1_kJkgK = 6.648;                 % inlet specific entropy, kJ/(kg K)

% Condenser at 30 deg C; saturated-water properties
Tcond_C = 30;
Pcond_kPa = 4.2469;
hf_kJkg = 125.73;
hfg_kJkg = 2429.8;
sf_kJkgK = 0.4368;
sfg_kJkgK = 8.0153;

% Isentropic turbine outlet (s2s = s1)
x2s = (s1_kJkgK - sf_kJkgK) / sfg_kJkgK;
if x2s < 0 || x2s > 1
    error('Isentropic outlet is not inside the saturated-mixture region. Recheck properties.');
end
h2s_kJkg = hf_kJkg + x2s * hfg_kJkg;
isentropicSpecificWork_kJkg = h1_kJkg - h2s_kJkg;

%% 3) Turbine design data from the assignment
Turbine = {'A'; 'B'; 'C'};
CapacityMW = [50; 100; 100];
EtaTurbine = [0.90; 0.92; 0.93];
EquipmentCost_MUSD = [5.0; 11.0; 10.5];
AdditionalOpexPerkWh = [0.010; 0.010; 0.015];

% Actual turbine work per kg = eta_t * isentropic work per kg.
ActualSpecificWork_kJkg = EtaTurbine .* isentropicSpecificWork_kJkg;
ActualExitEnthalpy_kJkg = h1_kJkg - ActualSpecificWork_kJkg;
ActualExitQuality = (ActualExitEnthalpy_kJkg - hf_kJkg) / hfg_kJkg;

% Since 1 MW = 1000 kJ/s, m_dot = P / w in kg/s.
RatedSteamFlow_kg_s = CapacityMW .* 1000 ./ ActualSpecificWork_kJkg;
EnergyExtracted_MW = RatedSteamFlow_kg_s .* ActualSpecificWork_kJkg ./ 1000;

TurbineTable = table(Turbine, CapacityMW, EtaTurbine, ...
    repmat(isentropicSpecificWork_kJkg, 3, 1), ActualSpecificWork_kJkg, ...
    repmat(x2s, 3, 1), ActualExitEnthalpy_kJkg, ActualExitQuality, ...
    RatedSteamFlow_kg_s, EnergyExtracted_MW, ...
    'VariableNames', {'Turbine','RatedCapacity_MW','Efficiency', ...
    'IsentropicSpecificWork_kJ_kg','ActualSpecificWork_kJ_kg', ...
    'IsentropicExitQuality','ActualExitEnthalpy_kJ_kg','ActualExitQuality', ...
    'SteamFlowAtRatedPower_kg_s','EnergyExtractedAtRatedPower_MW'});

fprintf('\n--- Steam-state calculation ---\n');
fprintf('Condenser temperature: %.1f deg C; saturation pressure: %.4f kPa\n', Tcond_C, Pcond_kPa);
fprintf('Isentropic exit quality x2s = %.5f\n', x2s);
fprintf('Isentropic exit enthalpy h2s = %.2f kJ/kg\n', h2s_kJkg);
fprintf('Isentropic specific work = %.2f kJ/kg\n', isentropicSpecificWork_kJkg);
fprintf('\n--- Turbine results ---\n');
disp(TurbineTable);

%% 4) Enumerate configurations up to maxInstalledCapacityMW
% Each combination is represented by counts of A, B, and C turbines.
% The N-1 capacity is installed capacity minus the largest single unit,
% i.e., the worst loss of one turbine.
maxA = floor(maxInstalledCapacityMW / CapacityMW(1));
maxB = floor(maxInstalledCapacityMW / CapacityMW(2));
maxC = floor(maxInstalledCapacityMW / CapacityMW(3));
configRows = zeros(0, 14);

for nA = 0:maxA
    for nB = 0:maxB
        for nC = 0:maxC
            totalUnits = nA + nB + nC;
            installedMW = nA*CapacityMW(1) + nB*CapacityMW(2) + nC*CapacityMW(3);
            if totalUnits == 0 || installedMW > maxInstalledCapacityMW
                continue;
            end

            largestUnitMW = 0;
            if nA > 0, largestUnitMW = max(largestUnitMW, CapacityMW(1)); end
            if nB > 0, largestUnitMW = max(largestUnitMW, CapacityMW(2)); end
            if nC > 0, largestUnitMW = max(largestUnitMW, CapacityMW(3)); end
            postOutageMW = installedMW - largestUnitMW;
            capitalCostMUSD = nA*EquipmentCost_MUSD(1) + ...
                              nB*EquipmentCost_MUSD(2) + ...
                              nC*EquipmentCost_MUSD(3);
            nameplateSteamFlow = nA*RatedSteamFlow_kg_s(1) + ...
                                 nB*RatedSteamFlow_kg_s(2) + ...
                                 nC*RatedSteamFlow_kg_s(3);

            meetsCurrentDemand = installedMW >= currentDemandMW;
            meetsOutageRequirement = postOutageMW >= minimumOutagePowerMW;
            meetsFutureDemand = installedMW >= futureDemandMW;
            feasibleCurrent = meetsCurrentDemand && meetsOutageRequirement;
            feasibleFuture = meetsFutureDemand && meetsOutageRequirement;

            configRows(end+1,:) = [nA, nB, nC, totalUnits, installedMW, ...
                largestUnitMW, postOutageMW, capitalCostMUSD, nameplateSteamFlow, ...
                meetsCurrentDemand, meetsOutageRequirement, meetsFutureDemand, ...
                feasibleCurrent, feasibleFuture]; %#ok<SAGROW>
        end
    end
end

ConfigurationTable = array2table(configRows, 'VariableNames', ...
    {'nA','nB','nC','TotalTurbines','InstalledCapacity_MW', ...
    'LargestUnit_MW','CapacityAfterLargestUnitOutage_MW','CapitalCost_MUSD', ...
    'SteamFlowAtNameplate_kg_s','Meets300MWDemand','MeetsN1_250MW', ...
    'Meets330MWFutureDemand','FeasibleCurrent','FeasibleFuture'});
ConfigurationTable.Meets300MWDemand = logical(ConfigurationTable.Meets300MWDemand);
ConfigurationTable.MeetsN1_250MW = logical(ConfigurationTable.MeetsN1_250MW);
ConfigurationTable.Meets330MWFutureDemand = logical(ConfigurationTable.Meets330MWFutureDemand);
ConfigurationTable.FeasibleCurrent = logical(ConfigurationTable.FeasibleCurrent);
ConfigurationTable.FeasibleFuture = logical(ConfigurationTable.FeasibleFuture);
ConfigurationTable = sortrows(ConfigurationTable, {'CapitalCost_MUSD','InstalledCapacity_MW'});

CurrentFeasibleTable = ConfigurationTable(ConfigurationTable.FeasibleCurrent, :);
FutureFeasibleTable = ConfigurationTable(ConfigurationTable.FeasibleFuture, :);

fprintf('\n--- Lowest-capital-cost options meeting the current 300 MW + N-1 criteria ---\n');
disp(CurrentFeasibleTable(1:min(10,height(CurrentFeasibleTable)), ...
    {'nA','nB','nC','InstalledCapacity_MW','CapacityAfterLargestUnitOutage_MW','CapitalCost_MUSD'}));
fprintf('\n--- Lowest-capital-cost options meeting the future 330 MW + N-1 criteria ---\n');
disp(FutureFeasibleTable(1:min(10,height(FutureFeasibleTable)), ...
    {'nA','nB','nC','InstalledCapacity_MW','CapacityAfterLargestUnitOutage_MW','CapitalCost_MUSD'}));

%% 5) Annual financial sensitivity for robust configurations
% Economic results are calculated only for configurations that meet the
% nominal demand and the 250 MW single-turbine-outage criterion for that case.
% Output is dispatched to the demand target, so spare installed capacity is
% not counted as sold electricity.
economicRows = cell(0, 21);
scenarioNames = {'Current'; 'Future10PercentGrowth'};
scenarioTargetsMW = [currentDemandMW, futureDemandMW];
scenarioConfigTables = {CurrentFeasibleTable, FutureFeasibleTable};

for iScenario = 1:numel(scenarioNames)
    targetMW = scenarioTargetsMW(iScenario);
    scenarioTable = scenarioConfigTables{iScenario};

    for iConfig = 1:height(scenarioTable)
        nA = scenarioTable.nA(iConfig);
        nB = scenarioTable.nB(iConfig);
        nC = scenarioTable.nC(iConfig);
        installedMW = scenarioTable.InstalledCapacity_MW(iConfig);
        postOutageMW = scenarioTable.CapacityAfterLargestUnitOutage_MW(iConfig);
        capitalCostMUSD = scenarioTable.CapitalCost_MUSD(iConfig);

        % Economic dispatch: lower variable-cost types first; among A and B,
        % dispatch B first because its higher efficiency reduces steam flow.
        dispatchMW = dispatchForDemand(nA, nB, nC, targetMW, CapacityMW);
        generatedMW = sum(dispatchMW);
        annualEnergy_kWh = generatedMW * 1000 * annualOperatingHours;
        annualEnergy_GWh = generatedMW * annualOperatingHours / 1000;
        steamFlowUsed_kg_s = sum(dispatchMW .* 1000 ./ ActualSpecificWork_kJkg');

        for iPrice = 1:numel(energyPricesPerkWh)
            price = energyPricesPerkWh(iPrice);
            annualRevenueMUSD = annualEnergy_kWh * price / 1e6;
            annualSteamCostMUSD = annualEnergy_kWh * baseSteamCostPerkWh / 1e6;
            annualAdditionalOpexMUSD = sum(dispatchMW .* 1000 .* annualOperatingHours .* ...
                AdditionalOpexPerkWh') / 1e6;
            annualOperatingCostMUSD = annualSteamCostMUSD + annualAdditionalOpexMUSD;
            annualNetCashFlowMUSD = annualRevenueMUSD - annualOperatingCostMUSD;

            if annualNetCashFlowMUSD > 0
                simplePaybackYears = capitalCostMUSD / annualNetCashFlowMUSD;
            else
                simplePaybackYears = Inf;
            end

            economicRows(end+1,:) = {scenarioNames{iScenario}, targetMW, price, ...
                nA, nB, nC, installedMW, postOutageMW, capitalCostMUSD, ...
                dispatchMW(1), dispatchMW(2), dispatchMW(3), generatedMW, ...
                steamFlowUsed_kg_s, annualEnergy_GWh, annualRevenueMUSD, ...
                annualSteamCostMUSD, annualAdditionalOpexMUSD, ...
                annualOperatingCostMUSD, annualNetCashFlowMUSD, simplePaybackYears}; %#ok<SAGROW>
        end
    end
end

EconomicSensitivityTable = cell2table(economicRows, 'VariableNames', ...
    {'DemandCase','TargetDemand_MW','ElectricityPrice_per_kWh','nA','nB','nC', ...
    'InstalledCapacity_MW','CapacityAfterLargestUnitOutage_MW','CapitalCost_MUSD', ...
    'DispatchA_MW','DispatchB_MW','DispatchC_MW','GeneratedPower_MW', ...
    'SteamFlow_kg_s','AnnualEnergy_GWh','AnnualRevenue_MUSD', ...
    'SteamGenerationCondensingCost_MUSD','AdditionalTurbineOpex_MUSD', ...
    'AnnualOperatingCost_MUSD','AnnualNetCashFlow_MUSD','SimplePayback_yr'});
EconomicSensitivityTable.DemandCase = categorical(EconomicSensitivityTable.DemandCase, scenarioNames);
EconomicSensitivityTable = sortrows(EconomicSensitivityTable, ...
    {'DemandCase','ElectricityPrice_per_kWh','CapitalCost_MUSD'});

fprintf('\n--- Economic sensitivity: first 15 rows ---\n');
disp(EconomicSensitivityTable(1:min(15,height(EconomicSensitivityTable)), :));

%% 6) Export tables for use in the final report
outputWorkbook = 'MAE2300_Problem3_Results.xlsx';
if exist(outputWorkbook, 'file')
    delete(outputWorkbook);
end
writetable(TurbineTable, outputWorkbook, 'Sheet', 'TurbineProperties');
writetable(ConfigurationTable, outputWorkbook, 'Sheet', 'AllConfigurations');
writetable(CurrentFeasibleTable, outputWorkbook, 'Sheet', 'CurrentFeasible');
writetable(FutureFeasibleTable, outputWorkbook, 'Sheet', 'FutureFeasible');
writetable(EconomicSensitivityTable, outputWorkbook, 'Sheet', 'EconomicSensitivity');

writetable(TurbineTable, 'MAE2300_P3_TurbineProperties.csv');
writetable(ConfigurationTable, 'MAE2300_P3_AllConfigurations.csv');
writetable(CurrentFeasibleTable, 'MAE2300_P3_CurrentFeasible.csv');
writetable(FutureFeasibleTable, 'MAE2300_P3_FutureFeasible.csv');
writetable(EconomicSensitivityTable, 'MAE2300_P3_EconomicSensitivity.csv');

fprintf('\nExport complete. Files created in the current folder:\n');
fprintf('  %s\n', outputWorkbook);
fprintf('  MAE2300_P3_TurbineProperties.csv\n');
fprintf('  MAE2300_P3_AllConfigurations.csv\n');
fprintf('  MAE2300_P3_CurrentFeasible.csv\n');
fprintf('  MAE2300_P3_FutureFeasible.csv\n');
fprintf('  MAE2300_P3_EconomicSensitivity.csv\n');

%% Local function: simple part-load dispatch for a selected configuration
function dispatchMW = dispatchForDemand(nA, nB, nC, targetMW, capacityMW)
    remainingMW = targetMW;
    dispatchB = min(nB * capacityMW(2), remainingMW); % B and A tie on added OPEX
    remainingMW = remainingMW - dispatchB;
    dispatchA = min(nA * capacityMW(1), remainingMW);
    remainingMW = remainingMW - dispatchA;
    dispatchC = min(nC * capacityMW(3), remainingMW); % C costs more per kWh
    remainingMW = remainingMW - dispatchC;

    if remainingMW > 1e-8
        error('Configuration cannot supply target demand. Check feasibility filtering.');
    end
    dispatchMW = [dispatchA, dispatchB, dispatchC];
end
