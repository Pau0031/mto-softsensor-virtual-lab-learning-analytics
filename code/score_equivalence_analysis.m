%% Score-equivalence and complementary-evidence analysis
% Reproduces the core score-stratum summaries from the anonymised dataset.
% Profile assignments are matched by row order, never by student identifiers.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
dataFile = fullfile(repoRoot, "data", "anonymised_student_level_dataset.csv");
assignmentFile = fullfile(repoRoot, "outputs", "participation_profile_assignment.csv");
outputDir = fullfile(repoRoot, "outputs");
assert(isfile(assignmentFile), ...
    "Run participation_profile_clustering.m before this analysis.");

T = readtable(dataFile, "TextType", "string");
A = readtable(assignmentFile, "TextType", "string");
assert(height(A) == height(T) && isequal(A.StudentRow, (1:height(T))'), ...
    "Profile assignments are not row-aligned with the analytical dataset.");
profileNames = ["Low-start deliberate improvers"; ...
    "High-start plateau learners"; ...
    "Intensive model optimizers"; ...
    "Minimal-time completers"];
T.ParticipationProfile = categorical(A.ParticipationProfile, ...
    profileNames, "Ordinal", true);

embedded = double(T.standard_exam_score);
modified = double(T.engineering_test_score);
n = height(T);
stratumNames = ["<95"; "95-99"; "100"];
stratumCode = nan(n, 1);
stratumCode(embedded < 95) = 1;
stratumCode(embedded >= 95 & embedded < 100) = 2;
stratumCode(embedded == 100) = 3;
assert(all(isfinite(stratumCode)), "Unexpected embedded-score value.");
T.ScoreStratum = categorical(stratumCode, 1:3, stratumNames, "Ordinal", true);

%% Familiar-score distribution and equivalence checks
scoreValues = unique(embedded);
scoreCounts = arrayfun(@(x) nnz(embedded == x), scoreValues);
exactScoreFrequency = table(scoreValues, scoreCounts, ...
    100 * scoreCounts / n, 100 * cumsum(scoreCounts) / n, ...
    'VariableNames', ["StandardScore", "N", "Percent", "CumulativePercent"]);
stratumCounts = accumarray(stratumCode, 1, [3, 1]);
scoreStrata = table(stratumNames, stratumCounts, 100 * stratumCounts / n, ...
    'VariableNames', ["ScoreStratum", "N", "Percent"]);
[tauB, tauP] = corr(embedded, modified, ...
    "Type", "Kendall", "Rows", "complete");
kendallResult = table(n, tauB, tauP, ...
    'VariableNames', ["N", "KendallTauB", "PValue"]);

[engP, engKW] = kruskalwallis(modified, T.ScoreStratum, "off");
engH = engKW{2,5};
engKWResult = table(n, 3, engH, engP, ...
    (engH - 2) / (n - 3), ...
    'VariableNames', ["N", "NumberOfGroups", "KruskalWallisH", ...
    "PValue", "EpsilonSquared"]);
engineeringByStratum = groupSummary(modified, stratumCode, stratumNames, ...
    "modified_scenario_score");

%% Perfect embedded-score subgroup: retained outcome spread and profiles
fullMask = embedded == 100;
fullValues = modified(fullMask);
fullGroups = double(T.ParticipationProfile(fullMask));
[profileP, profileKW] = kruskalwallis(fullValues, ...
    T.ParticipationProfile(fullMask), "off");
profileH = profileKW{2,5};
profileEpsilon2 = (profileH - numel(profileNames) + 1) / ...
    (nnz(fullMask) - numel(profileNames));
profileOutcome = table(nnz(fullMask), profileH, profileP, profileEpsilon2, ...
    'VariableNames', ["N", "KruskalWallisH", "AsymptoticPValue", ...
    "EpsilonSquared"]);
engineeringByProfile100 = groupSummary(fullValues, fullGroups, ...
    profileNames, "modified_scenario_score");

%% Profile composition across the three score strata
profileCode = double(T.ParticipationProfile);
observed = accumarray([stratumCode, profileCode], 1, ...
    [3, numel(profileNames)], @sum, 0);
expected = sum(observed,2) * sum(observed,1) / n;
chiSquare = sum((observed - expected).^2 ./ expected, "all");
df = (size(observed,1)-1) * (size(observed,2)-1);
asymptoticP = chi2cdf(chiSquare, df, "upper");
cramersV = sqrt(chiSquare / (n * min(size(observed)-1)));
nPermutations = 50000;
permutationP = permutationAssociation(stratumCode, profileCode, ...
    observed, nPermutations, 20260926);
association = table(n, chiSquare, df, asymptoticP, permutationP, cramersV, ...
    min(expected, [], "all"), nnz(expected < 5), ...
    100 * nnz(expected < 5) / numel(expected), nPermutations, ...
    'VariableNames', ["N", "ChiSquare", "DF", "AsymptoticPValue", ...
    "PermutationPValue", "CramersV", "MinimumExpectedCount", ...
    "NExpectedBelow5", "PercentExpectedBelow5", "NPermutations"]);

compositionStratum = strings(3 * numel(profileNames), 1);
compositionProfile = strings(3 * numel(profileNames), 1);
compositionN = zeros(3 * numel(profileNames), 1);
compositionPercent = zeros(3 * numel(profileNames), 1);
row = 0;
for g = 1:3
    for k = 1:numel(profileNames)
        row = row + 1;
        compositionStratum(row) = stratumNames(g);
        compositionProfile(row) = profileNames(k);
        compositionN(row) = observed(g,k);
        compositionPercent(row) = 100 * observed(g,k) / sum(observed(g,:));
    end
end
composition = table(compositionStratum, compositionProfile, compositionN, ...
    compositionPercent, 'VariableNames', ...
    ["ScoreStratum", "ParticipationProfile", "N", "RowPercent"]);
countsWide = array2table(observed, ...
    'VariableNames', matlab.lang.makeValidName(profileNames));
countsWide.ScoreStratum = stratumNames;
countsWide = movevars(countsWide, "ScoreStratum", "Before", 1);
percentWide = array2table(100 * observed ./ sum(observed,2), ...
    'VariableNames', matlab.lang.makeValidName(profileNames));
percentWide.ScoreStratum = stratumNames;
percentWide = movevars(percentWide, "ScoreStratum", "Before", 1);

%% Rubric dimensions by score stratum and BH-adjusted rank tests
rubricNames = ["process_understanding"; "variable_selection"; ...
    "modelling_workflow"; "model_evaluation"; "engineering_recommendation"];
rubricLabels = ["Process understanding"; "Variable selection"; ...
    "Modelling workflow"; "Model evaluation"; "Engineering recommendation"];
rubricSummary = table;
rubricP = nan(numel(rubricNames),1);
rubricKWVariable = strings(numel(rubricNames),1);
rubricKWN = repmat(n, numel(rubricNames),1);
rubricKWH = nan(numel(rubricNames),1);
rubricKWEpsilon2 = nan(numel(rubricNames),1);
for j = 1:numel(rubricNames)
    values = double(T.(rubricNames(j)));
    part = groupSummary(values, stratumCode, stratumNames, rubricNames(j));
    part.DimensionLabel = repmat(rubricLabels(j), height(part), 1);
    rubricSummary = [rubricSummary; part]; %#ok<AGROW>
    [rubricP(j), kw] = kruskalwallis(values, T.ScoreStratum, "off");
    H = kw{2,5};
    rubricKWVariable(j) = rubricNames(j);
    rubricKWH(j) = H;
    rubricKWEpsilon2(j) = (H - 2) / (n - 3);
end
rubricKW = table(rubricKWVariable, rubricKWN, rubricKWH, rubricP, ...
    rubricKWEpsilon2, 'VariableNames', ...
    ["Variable", "N", "KruskalWallisH", "PValue", "EpsilonSquared"]);
rubricKW.QValue_BH = bhAdjust(rubricP);

%% Export the recomputed core tables beside the frozen source workbooks
reproducedFile = fullfile(outputDir, "ScoreEquivalence_Reproduced.xlsx");
if isfile(reproducedFile)
    delete(reproducedFile);
end
writeSheet(exactScoreFrequency, reproducedFile, "ExactScoreFrequency");
writeSheet(scoreStrata, reproducedFile, "ScoreStrata");
writeSheet(kendallResult, reproducedFile, "KendallTauB");
writeSheet(engKWResult, reproducedFile, "EngStrata_KW");
writeSheet(engineeringByStratum, reproducedFile, "EngByScoreStratum");
writeSheet(profileOutcome, reproducedFile, "Full100ProfileTest");
writeSheet(engineeringByProfile100, reproducedFile, "Full100ByProfile");
writeSheet(composition, reproducedFile, "PatternComposition");
writeSheet(countsWide, reproducedFile, "PatternCounts");
writeSheet(percentWide, reproducedFile, "PatternPercent");
writeSheet(association, reproducedFile, "PatternAssociation");
writeSheet(rubricSummary, reproducedFile, "RubricByStratum");
writeSheet(rubricKW, reproducedFile, "RubricKW");

fprintf("N=%d; perfect embedded scores=%d (%.1f%%); Kendall tau-b=%.4f, p=%.4f.\\n", ...
    n, nnz(fullMask), 100*nnz(fullMask)/n, tauB, tauP);
fprintf("Profile composition: Cramer's V=%.4f, permutation p=%.4f.\\n", ...
    cramersV, permutationP);
fprintf("Recomputed core tables: %s\\n", reproducedFile);

%% Local functions
function summary = groupSummary(values, groupCode, groupNames, variableName)
% Return N, mean, sample SD, median, IQR and observed range by group.
gN = numel(groupNames);
N = zeros(gN,1); Mean = nan(gN,1); SD = nan(gN,1);
Median = nan(gN,1); Q1 = nan(gN,1); Q3 = nan(gN,1);
IQR = nan(gN,1); Minimum = nan(gN,1); Maximum = nan(gN,1);
for g = 1:gN
    x = values(groupCode == g);
    x = x(isfinite(x));
    N(g) = numel(x);
    if isempty(x), continue; end
    q = prctile(x,[25 50 75]);
    Mean(g) = mean(x); SD(g) = std(x,0);
    Q1(g) = q(1); Median(g) = q(2); Q3(g) = q(3);
    IQR(g) = q(3)-q(1); Minimum(g) = min(x); Maximum(g) = max(x);
end
summary = table(repmat(string(variableName),gN,1), string(groupNames(:)), ...
    N, Mean, SD, Median, Q1, Q3, IQR, Minimum, Maximum, ...
    'VariableNames', ["Variable","Group","N","Mean","SD", ...
    "Median","Q1","Q3","IQR","Min","Max"]);
end

function p = permutationAssociation(strata, profiles, observed, nPerm, seed)
% Shuffle profile labels while keeping score-stratum membership unchanged.
rng(seed,"twister");
n = numel(strata);
expected = sum(observed,2)*sum(observed,1)/n;
observedStat = sum((observed-expected).^2./expected,"all");
exceed = 0;
for b = 1:nPerm
    permProfiles = profiles(randperm(n));
    tab = accumarray([strata,permProfiles],1,size(observed),@sum,0);
    exceed = exceed + (sum((tab-expected).^2./expected,"all") >= observedStat);
end
p = (exceed+1)/(nPerm+1);
end

function q = bhAdjust(p)
% Benjamini-Hochberg adjustment in the original variable order.
[sortedP,idx] = sort(p(:));
m = numel(sortedP);
sortedQ = sortedP.*m./(1:m)';
for k = m-1:-1:1, sortedQ(k)=min(sortedQ(k),sortedQ(k+1)); end
sortedQ = min(sortedQ,1);
q = nan(size(p(:))); q(idx)=sortedQ;
end

function writeSheet(T,filename,sheet)
% Write one named table to the recomputed workbook.
writetable(T,filename,"Sheet",sheet);
end

