%% Participation-profile clustering for the V2 analysis
% This script uses only the five prespecified platform-trace variables.
% The four-cluster solution and random seed are fixed for reproducibility.
% Cluster labels are descriptive profile names, not causal or ability labels.

scriptPath = mfilename("fullpath");
repoRoot = fileparts(fileparts(scriptPath));
dataFile = fullfile(repoRoot, "data", "anonymised_student_level_dataset.csv");
outputDir = fullfile(repoRoot, "outputs");
if ~isfolder(outputDir)
    mkdir(outputDir);
end

T = readtable(dataFile, "TextType", "string");
featureNames = ["improving_transition_ratio"; "mean_practice_time"; ...
    "model_revision_rounds"; "first_practice_score"; "practice_gain_ratio"];
missingNames = setdiff(featureNames, string(T.Properties.VariableNames));
assert(isempty(missingNames), "Missing clustering variables: %s", ...
    strjoin(missingNames, ", "));

% Transform time and count features to reduce their right-skew before scaling.
X = double(T{:, featureNames});
idxTime = find(featureNames == "mean_practice_time");
idxRevision = find(featureNames == "model_revision_rounds");
X(:, idxTime) = log1p(X(:, idxTime));
X(:, idxRevision) = log1p(X(:, idxRevision));

% Median-impute missing feature values and use median/MAD scaling.
for j = 1:size(X, 2)
    replacement = median(X(:, j), "omitnan");
    assert(isfinite(replacement), ...
        "Feature %s has no finite observations.", featureNames(j));
    X(isnan(X(:, j)), j) = replacement;
end
center = median(X, 1);
scale = mad(X, 1, 1) * 1.4826;
for j = 1:numel(scale)
    if ~isfinite(scale(j)) || scale(j) == 0
        scale(j) = std(X(:, j), 0);
    end
    if ~isfinite(scale(j)) || scale(j) == 0
        scale(j) = 1;
    end
end
Xz = (X - center) ./ scale;
Xz = max(-3, min(3, Xz));

% Fit the fixed four-profile solution. Repeated starts reduce local-minimum risk.
nProfiles = 4;
rng(2026, "twister");
[clusterID, centroid] = kmeans(Xz, nProfiles, ...
    "Distance", "sqeuclidean", "Start", "plus", ...
    "Replicates", 500, "MaxIter", 1000, "Display", "off");
clusterID = clusterID(:);

% Give clusters stable descriptive names from their trace signatures.
% The one-to-one assignment keeps each semantic name attached to one cluster.
iImprove = find(featureNames == "improving_transition_ratio");
iTime = find(featureNames == "mean_practice_time");
iRevision = find(featureNames == "model_revision_rounds");
iFirst = find(featureNames == "first_practice_score");
iGain = find(featureNames == "practice_gain_ratio");
improve = centroid(:, iImprove);
time = centroid(:, iTime);
revision = centroid(:, iRevision);
firstScore = centroid(:, iFirst);
gain = centroid(:, iGain);

profileScore = [ ...
    gain + improve - 0.20 * abs(revision), ... % Low-start deliberate improvers
    firstScore - 0.30 * revision - 0.20 * time, ... % High-start plateau learners
    revision - 0.50 * improve + 0.20 * gain, ... % Intensive model optimizers
    -time - revision - gain - firstScore]; % Minimal-time completers
profileNames = ["Low-start deliberate improvers"; ...
    "High-start plateau learners"; ...
    "Intensive model optimizers"; ...
    "Minimal-time completers"];

clusterToProfile = strings(nProfiles, 1);
usedCluster = false(nProfiles, 1);
usedProfile = false(nProfiles, 1);
for assignmentStep = 1:nProfiles
    candidateScores = profileScore;
    candidateScores(usedCluster, :) = -Inf;
    candidateScores(:, usedProfile) = -Inf;
    [~, linearIndex] = max(candidateScores(:));
    [clusterRow, profileColumn] = ind2sub(size(candidateScores), linearIndex);
    clusterToProfile(clusterRow) = profileNames(profileColumn);
    usedCluster(clusterRow) = true;
    usedProfile(profileColumn) = true;
end

profile = clusterToProfile(clusterID);
profile = profile(:);
profileCategorical = categorical(profile, profileNames, "Ordinal", true);
assignmentTable = table((1:height(T))', clusterID, profile, ...
    'VariableNames', ["StudentRow", "ClusterID", "ParticipationProfile"]);
writetable(assignmentTable, fullfile(outputDir, ...
    "participation_profile_assignment.csv"));

% Export transparent descriptive means/medians on the source measurement scales.
summaryVariables = ["pretest_score"; "standard_exam_score"; ...
    "engineering_test_score"; "report_score"; "process_understanding"; ...
    "variable_selection"; "modelling_workflow"; "model_evaluation"; ...
    "engineering_recommendation"; "first_practice_score"; ...
    "practice_gain_ratio"; "improving_transition_ratio"; ...
    "mean_practice_time"; "model_revision_rounds"; ...
    "effective_modelling_time"; "valid_modelling_attempts"];
summaryVariables = summaryVariables(ismember(summaryVariables, ...
    string(T.Properties.VariableNames)));
profileN = zeros(nProfiles, 1);
profileSummary = table(profileNames, profileN, ...
    'VariableNames', ["ParticipationProfile", "N"]);
for j = 1:numel(summaryVariables)
    source = double(T.(summaryVariables(j)));
    meanName = matlab.lang.makeValidName("Mean_" + summaryVariables(j));
    medianName = matlab.lang.makeValidName("Median_" + summaryVariables(j));
    profileMean = nan(nProfiles, 1);
    profileMedian = nan(nProfiles, 1);
    for k = 1:nProfiles
        inProfile = profileCategorical == profileNames(k);
        profileMean(k) = mean(source(inProfile), "omitnan");
        profileMedian(k) = median(source(inProfile), "omitnan");
        if j == 1
            profileSummary.N(k) = nnz(inProfile);
        end
    end
    profileSummary.(meanName) = profileMean;
    profileSummary.(medianName) = profileMedian;
end
writetable(profileSummary, fullfile(outputDir, ...
    "participation_profile_statistics.csv"));

fprintf("Participation profiles assigned: %d rows, %d profiles.\\n", ...
    height(assignmentTable), nProfiles);
disp(profileSummary);

