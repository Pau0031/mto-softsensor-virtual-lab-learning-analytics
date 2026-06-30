%% Learning-mode clustering based on five trace features
%
% Required table:
%   T
%
% Required variables:
%   improving_transition_ratio
%   mean_practice_time
%   model_revision_rounds
%   first_practice_score
%   practice_gain_ratio
%
% Output:
%   LearningMode_Cluster_Assignment.xlsx
%   LearningMode_Cluster_Profile.xlsx
%   LearningMode_Cluster_Figure.png
%   LearningMode_Cluster_Figure.pdf

clearvars -except T; clc;


%% ------------------------------------------------------------------------
% 1. Define clustering features
% -------------------------------------------------------------------------

featureVars = [ ...
    "improving_transition_ratio"
    "mean_practice_time"
    "model_revision_rounds"
    "first_practice_score"
    "practice_gain_ratio" ];

featureLabels = [ ...
    "Improving transition ratio"
    "Mean practice time"
    "Model-revision rounds"
    "First practice score"
    "Practice gain ratio" ];

K = 4;   % five intended learning modes


%% ------------------------------------------------------------------------
% 2. Check variable availability
% -------------------------------------------------------------------------

tableVars = string(T.Properties.VariableNames);
missingVars = setdiff(featureVars, tableVars);

if ~isempty(missingVars)
    error("The following clustering variables are missing from T:\n%s", ...
        strjoin(missingVars, newline));
end


%% ------------------------------------------------------------------------
% 3. Extract feature matrix
% -------------------------------------------------------------------------

Xraw = T{:, featureVars};

% Convert all selected variables to double
Xraw = double(Xraw);


%% ------------------------------------------------------------------------
% 4. Handle ratio variables if stored as percentages
% -------------------------------------------------------------------------
% If ratio variables were stored as 0-100 instead of 0-1,
% convert them to 0-1 scale automatically.

ratioVarNames = ["improving_transition_ratio", "practice_gain_ratio"];

for i = 1:numel(ratioVarNames)

    j = find(featureVars == ratioVarNames(i));

    if isempty(j)
        continue;
    end

    xj = Xraw(:,j);

    % If most valid values are larger than 1.5, assume percentage scale.
    if median(xj(~isnan(xj)), "omitnan") > 1.5
        Xraw(:,j) = Xraw(:,j) ./ 100;
    end
end


%% ------------------------------------------------------------------------
% 5. Transform skewed time/count variables
% -------------------------------------------------------------------------
% mean_practice_time and model_revision_rounds are usually right-skewed.
% log1p transformation reduces their dominance in distance calculation.

Xtrans = Xraw;

idx_mean_practice_time = find(featureVars == "mean_practice_time");
idx_model_revision     = find(featureVars == "model_revision_rounds");

Xtrans(:, idx_mean_practice_time) = log1p(Xtrans(:, idx_mean_practice_time));
Xtrans(:, idx_model_revision)     = log1p(Xtrans(:, idx_model_revision));


%% ------------------------------------------------------------------------
% 6. Median-impute missing values
% -------------------------------------------------------------------------

missingFlag = isnan(Xtrans);

for j = 1:size(Xtrans,2)

    xj = Xtrans(:,j);
    medj = median(xj, "omitnan");

    if isnan(medj)
        error("Variable %s contains only missing values.", featureVars(j));
    end

    xj(isnan(xj)) = medj;
    Xtrans(:,j) = xj;
end


%% ------------------------------------------------------------------------
% 7. Robust standardization
% -------------------------------------------------------------------------
% Use median and MAD rather than mean and standard deviation.
% This reduces the influence of outliers and skewed distributions.

medX = median(Xtrans, 1, "omitnan");
madX = mad(Xtrans, 1, 1) * 1.4826;   % robust estimate of std

% If MAD is zero for any feature, fall back to standard deviation.
for j = 1:numel(madX)
    if madX(j) == 0 || isnan(madX(j))
        madX(j) = std(Xtrans(:,j), "omitnan");
    end

    if madX(j) == 0 || isnan(madX(j))
        madX(j) = 1;
    end
end

Xz = (Xtrans - medX) ./ madX;

% Winsorize standardized values to avoid one extreme student dominating.
Xz(Xz >  3) =  3;
Xz(Xz < -3) = -3;


%% ------------------------------------------------------------------------
% 8. Stable K-means clustering
% -------------------------------------------------------------------------
% K is fixed at 5 because the five learning modes are theoretically defined.
% Many replicates are used to stabilize the solution.

rng(2026);

[idx, C, sumd, D] = kmeans(Xz, K, ...
    "Distance", "sqeuclidean", ...
    "Start", "plus", ...
    "Replicates", 500, ...
    "MaxIter", 1000, ...
    "Display", "final");

T.learning_mode_cluster_raw = idx;


%% ------------------------------------------------------------------------
% 9. Check stability across repeated K-means runs
% -------------------------------------------------------------------------
% Adjusted Rand Index close to 1 indicates stable clustering.

nRepeat = 100;
ARI = nan(nRepeat,1);

for b = 1:nRepeat

    rng(2026 + b);

    idx_b = kmeans(Xz, K, ...
        "Distance", "sqeuclidean", ...
        "Start", "plus", ...
        "Replicates", 100, ...
        "MaxIter", 1000, ...
        "Display", "off");

    ARI(b) = adjustedRandIndex(idx, idx_b);
end

fprintf("Mean ARI across repeated clustering runs: %.3f\n", mean(ARI, "omitnan"));
fprintf("Minimum ARI across repeated clustering runs: %.3f\n", min(ARI));
fprintf("Maximum ARI across repeated clustering runs: %.3f\n", max(ARI));


%% ------------------------------------------------------------------------
% 10. Compute cluster profiles
% -------------------------------------------------------------------------

clusterID = (1:K).';

ClusterSize = accumarray(idx, 1, [K,1], @sum, 0);

centerZ = nan(K, numel(featureVars));
centerRaw = nan(K, numel(featureVars));

for k = 1:K
    centerZ(k,:) = mean(Xz(idx == k, :), 1, "omitnan");
    centerRaw(k,:) = mean(Xraw(idx == k, :), 1, "omitnan");
end

ClusterProfileZ = array2table(centerZ, ...
    "VariableNames", cellstr(featureVars));

ClusterProfileRaw = array2table(centerRaw, ...
    "VariableNames", cellstr(featureVars));

ClusterProfileZ.Cluster = clusterID;
ClusterProfileZ.N = ClusterSize;

ClusterProfileRaw.Cluster = clusterID;
ClusterProfileRaw.N = ClusterSize;

ClusterProfileZ = movevars(ClusterProfileZ, ["Cluster","N"], "Before", 1);
ClusterProfileRaw = movevars(ClusterProfileRaw, ["Cluster","N"], "Before", 1);


%% ------------------------------------------------------------------------
% 11. Assign preliminary semantic mode labels
% -------------------------------------------------------------------------
% The automatic labels are based on cluster centroids.
% You should verify them against ClusterProfileRaw and ClusterProfileZ.

modeNames = assignLearningModeLabels(centerZ, featureVars);

ClusterProfileZ.Mode = modeNames;
ClusterProfileRaw.Mode = modeNames;

ClusterProfileZ = movevars(ClusterProfileZ, "Mode", "After", "Cluster");
ClusterProfileRaw = movevars(ClusterProfileRaw, "Mode", "After", "Cluster");

T.learning_mode = strings(height(T),1);

for k = 1:K
    T.learning_mode(idx == k) = modeNames(k);
end

T.learning_mode = categorical(T.learning_mode, modeNames, "Ordinal", true);

disp("Cluster profile in robust z-score scale:");
disp(ClusterProfileZ);

disp("Cluster profile in original feature scale:");
disp(ClusterProfileRaw);


%% ------------------------------------------------------------------------
% 12. Export cluster results
% -------------------------------------------------------------------------

writetable(T, "LearningMode_Cluster_Assignment_4.xlsx");
writetable(ClusterProfileRaw, "LearningMode_Cluster_Profile_Raw_4.xlsx");
writetable(ClusterProfileZ, "LearningMode_Cluster_Profile_Zscore_4.xlsx");

fprintf("Cluster assignment and profiles exported.\n");



%% ------------------------------------------------------------------------
% 13. Prepare order for heatmap visualization
% -------------------------------------------------------------------------

% Sort students by assigned learning mode, then by first practice score.
[~, orderIdx] = sortrows([double(T.learning_mode), T.first_practice_score]);

Xz_sorted = Xz(orderIdx,:);
mode_sorted = T.learning_mode(orderIdx);

% Boundary positions between modes
modeCodes = double(mode_sorted);
changePos = find(diff(modeCodes) ~= 0);
boundaryY = changePos + 0.5;


%% ------------------------------------------------------------------------
% 14. Create impressive cluster figure
% -------------------------------------------------------------------------

figure("Color", "w", "Position", [100 100 1280 720]);

tl = tiledlayout(1,2, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");

cmap = makeDivergingColormap(256);


%% Panel A: individual heatmap sorted by learning mode
ax1 = nexttile(tl, 1);

imagesc(ax1, Xz_sorted);
colormap(ax1, cmap);
clim(ax1, [-2.5 2.5]);

title(ax1, "A. Student-level learning-trace patterns", ...
    "FontWeight", "bold", ...
    "FontSize", 13);

xticks(ax1, 1:numel(featureLabels));
xticklabels(ax1, featureLabels);
xtickangle(ax1, 35);

yticks(ax1, []);
ylabel(ax1, "Students ordered by learning mode");

ax1.FontName = "Arial";
ax1.FontSize = 10;
ax1.LineWidth = 1.0;
ax1.TickDir = "out";
box(ax1, "off");

% Draw cluster boundary lines
hold(ax1, "on");
for b = 1:numel(boundaryY)
    yline(ax1, boundaryY(b), "k-", "LineWidth", 1.0);
end

% Add mode labels along the right side of heatmap
modeCats = categories(T.learning_mode);

for m = 1:numel(modeCats)
    idx_m = find(mode_sorted == modeCats{m});
    if isempty(idx_m)
        continue;
    end

    yMid = mean(idx_m);

    text(ax1, numel(featureLabels) + 0.35, yMid, ...
        sprintf("%s (n=%d)", modeCats{m}, numel(idx_m)), ...
        "FontSize", 9.5, ...
        "FontName", "Arial", ...
        "VerticalAlignment", "middle");
end

xlim(ax1, [0.4, numel(featureLabels) + 2.3]);


%% Panel B: cluster centroid dot plot
ax2 = nexttile(tl, 2);
hold(ax2, "on");

% Reorder cluster profiles according to modeNames
centerZ_plot = centerZ;
modeNames_plot = modeNames(:);
clusterSize_plot = ClusterSize(:);

nMode = K;
nFeat = numel(featureVars);

for iMode = 1:nMode
    for jFeat = 1:nFeat

        value = centerZ_plot(iMode, jFeat);

        % Dot size represents deviation magnitude from overall median.
        dotSize = 70 + 180 * min(abs(value), 2.5) / 2.5;

        scatter(ax2, jFeat, iMode, dotSize, value, ...
            "filled", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 0.6);
    end
end

colormap(ax2, cmap);
clim(ax2, [-2.5 2.5]);

xlim(ax2, [0.5, nFeat + 0.5]);
ylim(ax2, [0.2, nMode + 0.2]);

xticks(ax2, 1:nFeat);
xticklabels(ax2, featureLabels);
xtickangle(ax2, 35);

yticks(ax2, 1:nMode);

modeLabelsWithN = strings(nMode,1);
for iMode = 1:nMode
    modeLabelsWithN(iMode) = sprintf("%s (n=%d)", ...
        modeNames_plot{iMode}, clusterSize_plot(iMode));
end

yticklabels(ax2, modeLabelsWithN);

title(ax2, "B. Cluster-centroid feature signatures", ...
    "FontWeight", "bold", ...
    "FontSize", 13);

ax2.FontName = "Arial";
ax2.FontSize = 10;
ax2.LineWidth = 1.0;
ax2.TickDir = "out";
ax2.Box = "off";
ax2.XGrid = "on";
ax2.YGrid = "on";
ax2.GridAlpha = 0.12;

cb = colorbar(ax2);
cb.Label.String = "Robust z-score";
cb.FontName = "Arial";
cb.FontSize = 10;


%% Overall title
sgtitle(tl, "Learning modes derived from practice traces", ...
    "FontWeight", "bold", ...
    "FontSize", 16);

exportgraphics(gcf, "LearningMode_Cluster_Figure.png", "Resolution", 600);
exportgraphics(gcf, "LearningMode_Cluster_Figure.pdf", "ContentType", "vector");

fprintf("Learning-mode cluster figure exported.\n");
%% External validation of learning-mode clusters

% Use your current cluster labels
% If the variable name is different, replace learning_mode accordingly.

clusterVar = "learning_mode";

%% Convert selected_highest_R2_model to numeric indicator
% This variable is important for detecting score/R2-driven decisions.

r2tag = string(T.selected_highest_R2_model);
r2tag = lower(strtrim(r2tag));

selectedHighestR2 = double( ...
    r2tag == "yes" | ...
    r2tag == "1" | ...
    r2tag == "true" | ...
    r2tag == "y" | ...
    contains(r2tag, "yes") | ...
    contains(r2tag, "highest") | ...
    contains(r2tag, "最高") );

selectedHighestR2(ismissing(r2tag) | r2tag == "" | r2tag == "<undefined>") = NaN;

T.selected_highest_R2_numeric = selectedHighestR2;

%% Define validation variables

validationVars = [ ...
    "pretest_score"
    "standard_exam_score"
    "engineering_test_score"
    "test_score_gain"
    "report_score"
    "process_understanding"
    "variable_selection"
    "modelling_workflow"
    "model_evaluation"
    "engineering_recommendation"
    "effective_modelling_time"
    "valid_modelling_attempts"
    "best_practice_score"
    "final_practice_score"
    "practice_gain_ratio"
    "test_gain_ratio"
    "mean_practice_time"
    "consecutive_improvement_count"
    "improving_transition_ratio"
    "selected_highest_R2_numeric" ];

if ismember("final_best_gap", string(T.Properties.VariableNames))
    validationVars = [validationVars, "final_best_gap"];
end

% Keep only variables that exist
validationVars = validationVars(ismember(validationVars, string(T.Properties.VariableNames)));

%% Calculate cluster-wise means and medians

ValidationMean = groupsummary(T, clusterVar, "mean", validationVars);
ValidationMedian = groupsummary(T, clusterVar, "median", validationVars);
ValidationStd = groupsummary(T, clusterVar, "std", validationVars);

disp("Cluster-wise validation means:");
disp(ValidationMean);

disp("Cluster-wise validation medians:");
disp(ValidationMedian);

writetable(ValidationMean, "LearningMode_ExternalValidation_Mean_4.xlsx");
writetable(ValidationMedian, "LearningMode_ExternalValidation_Median_4.xlsx");
writetable(ValidationStd, "LearningMode_ExternalValidation_Std_4.xlsx");
%% Raincloud plots for four learning modes
%
% Purpose:
%   Visualize how the four learning modes differ in key trace and outcome variables.
%
% Required table:
%   T
%
% Required variables:
%   learning_mode
%   first_practice_score
%   practice_gain_ratio
%   improving_transition_ratio
%   model_revision_rounds
%   effective_modelling_time
%   engineering_test_score
%
% Output:
%   LearningMode_Raincloud_KeyVariables.png
%   LearningMode_Raincloud_KeyVariables.pdf

clearvars -except T; clc;


%% ------------------------------------------------------------------------
% 1. Standardize / rename the four learning-mode labels
% -------------------------------------------------------------------------

modeStr = string(T.learning_mode);
modeStr = strtrim(modeStr);

% Map old cluster names to final recommended names
modeStr(contains(modeStr, "Deliberate", "IgnoreCase", true)) = ...
    "Low-start deliberate improvers";

modeStr(contains(modeStr, "plateau", "IgnoreCase", true) | ...
        contains(modeStr, "High-start", "IgnoreCase", true)) = ...
    "High-start plateau learners";

modeStr(contains(modeStr, "Invested", "IgnoreCase", true) | ...
        contains(modeStr, "Optimizers", "IgnoreCase", true)) = ...
    "High-investment model optimizers";

modeStr(contains(modeStr, "Minimal", "IgnoreCase", true)) = ...
    "Minimal-time efficient completers";

modeOrder = [ ...
    "Low-start deliberate improvers"
    "High-start plateau learners"
    "High-investment model optimizers"
    "Minimal-time efficient completers" ];

T.learning_mode_final = categorical(modeStr, modeOrder, "Ordinal", true);

disp("Learning-mode counts:");
disp(groupcounts(T.learning_mode_final));


%% ------------------------------------------------------------------------
% 2. Define variables for visualization
% -------------------------------------------------------------------------

plotVars = [ ...
    "first_practice_score"
    "practice_gain_ratio"
    "improving_transition_ratio"
    "model_revision_rounds"
    "effective_modelling_time"
    "engineering_test_score" ];

plotLabels = [ ...
    "First practice score"
    "Practice gain ratio"
    "Improving transition ratio"
    "Model-revision rounds"
    "Effective modelling time"
    "Engineering test score" ];

% Fixed y-axis limits requested
yLimits = { ...
    [40 100], ...    % first_practice_score
    [0 1], ...       % practice_gain_ratio
    [0 1], ...       % improving_transition_ratio
    [0 35], ...      % model_revision_rounds
    [0 250], ...     % effective_modelling_time
    [55 100] ...     % engineering_test_score
    };
%% ------------------------------------------------------------------------
% 3. Define Nature-like colours for four learning modes
% -------------------------------------------------------------------------
% Muted and publication-friendly palette.

modeColors = [ ...
    0.20 0.47 0.72;   % Deliberate improvers: muted blue
    0.55 0.55 0.55;   % Routine plateau learners: neutral grey
    0.80 0.36 0.27;   % Intensive model optimizers: vermillion
    0.90 0.62 0.15];  % Minimal explorers: ochre


%% ------------------------------------------------------------------------
% 4. Create multi-panel box-rain figure
% -------------------------------------------------------------------------

figure("Color", "w", "Position", [80 80 1450 820]);

tl = tiledlayout(2,3, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");

for i = 1:numel(plotVars)

    ax = nexttile(tl, i);

    varName = plotVars(i);

    plotBoxRainByMode(ax, ...
        T, ...
        varName, ...
        "learning_mode_final", ...
        modeOrder, ...
        modeColors, ...
        yLimits{i});

    % Kruskal-Wallis test for group difference
    [pKW, eps2] = kruskalEffect(T, varName, "learning_mode_final");

    title(ax, sprintf("%s\nKruskal-Wallis {\\it p} = %.3g, {\\it \\epsilon}^{2} = %.3f", ...
    plotLabels(i), pKW, eps2), ...
    "FontSize", 12, ...
    "FontWeight", "bold", ...
    "Interpreter", "tex");

    ylabel(ax, plotLabels(i));
    setNatureAxes(ax);
end

sgtitle(tl, "Learning-mode differences in practice traces and engineering-test performance", ...
    "FontSize", 16, ...
    "FontWeight", "bold");

exportgraphics(gcf, "LearningMode_BoxRain_KeyVariables.png", "Resolution", 600);
exportgraphics(gcf, "LearningMode_BoxRain_KeyVariables.pdf", "ContentType", "vector");

fprintf("Figure saved as LearningMode_BoxRain_KeyVariables.png and .pdf\n");
%% ------------------------------------------------------------------------
% 5. Optional: export group descriptive statistics for these six variables
% -------------------------------------------------------------------------
% Summarize selected variables by learning mode

StatsByMode = table();

for i = 1:numel(plotVars)

    varName = string(plotVars(i));

    % Compute group statistics for the current variable
    S = groupsummary(T, "learning_mode_final", ...
        {"mean","median","std","min","max"}, varName);

    % groupsummary generates variable-specific names, such as:
    % mean_practice_gain_ratio, median_practice_gain_ratio, etc.
    % Rename them to generic names so that all tables can be concatenated.
    oldNames = [ ...
        "mean_"   + varName
        "median_" + varName
        "std_"    + varName
        "min_"    + varName
        "max_"    + varName ];

    newNames = [ ...
        "Mean"
        "Median"
        "Std"
        "Min"
        "Max" ];

    S = renamevars(S, oldNames, newNames);

    % Add the original variable name as a column
    S.Variable = repmat(varName, height(S), 1);

    % Move Variable column to the first column
    S = movevars(S, "Variable", "Before", 1);

    % Now all S tables have identical variable names and can be concatenated
    StatsByMode = [StatsByMode; S]; %#ok<AGROW>
end

disp(StatsByMode);

writetable(StatsByMode, "LearningMode_Raincloud_KeyVariables_Stats.xlsx");

fprintf("Statistics saved as LearningMode_Raincloud_KeyVariables_Stats.xlsx\n");


%% ========================================================================
% Local helper function: raincloud plot by learning mode
% ========================================================================

function plotBoxRainByMode(ax, T, varName, groupVar, modeOrder, modeColors, yLimNow)
    % Box-rain plot for learning modes.
    %
    % This function intentionally removes the density cloud.
    % It is more appropriate when some clusters have small sample sizes.
    %
    % Components:
    %   - raw jittered points = "rain"
    %   - boxplot = median, IQR, spread
    %   - mean marker = white diamond

    axes(ax);
    hold(ax, "on");

    nMode = numel(modeOrder);

    for iMode = 1:nMode

        modeName = modeOrder(iMode);

        idx = T.(groupVar) == modeName;
        y = T.(varName)(idx);
        y = double(y(:));
        y = y(~isnan(y));

        if isempty(y)
            continue;
        end

        xCenter = iMode;
        thisColor = modeColors(iMode,:);

        %% --------------------------------------------------------------
        % 1. Raw jittered points: the "rain"
        % ---------------------------------------------------------------

        rng(100 + iMode);

        % Controlled horizontal jitter
        jitter = (rand(size(y)) - 0.5) * 0.22;

        scatter(ax, ...
            xCenter + jitter, y, ...
            22, ...
            "MarkerFaceColor", thisColor, ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceAlpha", 0.55);

        %% --------------------------------------------------------------
        % 2. Boxplot
        % ---------------------------------------------------------------

        boxchart(ax, ...
            repmat(xCenter, size(y)), y, ...
            "BoxWidth", 0.38, ...
            "MarkerStyle", "none", ...
            "BoxFaceColor", thisColor, ...
            "BoxFaceAlpha", 0.28, ...
            "LineWidth", 1.2);

        %% --------------------------------------------------------------
        % 3. Mean marker
        % ---------------------------------------------------------------

        mu = mean(y, "omitnan");

        plot(ax, xCenter, mu, ...
            "d", ...
            "MarkerSize", 6, ...
            "MarkerFaceColor", "w", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 1.0);

        %% --------------------------------------------------------------
        % 4. Optional: sample size label
        % ---------------------------------------------------------------

        if ~isempty(yLimNow)
            yText = yLimNow(2) - 0.05 * range(yLimNow);
        else
            yText = max(y) - 0.05 * range(y);
        end

        text(ax, xCenter, yText, sprintf("n=%d", numel(y)), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "top", ...
            "FontSize", 8.5, ...
            "Color", [0.25 0.25 0.25]);
    end

    %% --------------------------------------------------------------
    % Axis settings
    % ---------------------------------------------------------------

    xlim(ax, [0.45, nMode + 0.55]);
    xticks(ax, 1:nMode);

    shortLabels = [ ...
        "Deliberate"
        "Plateau"
        "Investment"
        "Minimal" ];

    xticklabels(ax, shortLabels);
    xtickangle(ax, 25);

    if ~isempty(yLimNow)
        ylim(ax, yLimNow);
    end

    % Warn if some observations are outside the chosen y-limits
    if ~isempty(yLimNow)
        yy = T.(varName);
        yy = double(yy(:));
        nOut = sum(yy < yLimNow(1) | yy > yLimNow(2), "omitnan");

        if nOut > 0
            warning("%s: %d observations are outside the selected y-limits [%g, %g].", ...
                varName, nOut, yLimNow(1), yLimNow(2));
        end
    end
end

%% ========================================================================
% Local helper function: Kruskal-Wallis effect size
% ========================================================================

function [pKW, eps2] = kruskalEffect(T, varName, groupVar)
    % Calculate Kruskal-Wallis p-value and epsilon-squared effect size.

    y = double(T.(varName));
    g = T.(groupVar);

    valid = ~isnan(y) & ~isundefined(g);

    y = y(valid);
    g = g(valid);

    if numel(unique(g)) < 2 || numel(y) < 5
        pKW = NaN;
        eps2 = NaN;
        return;
    end

    [pKW, tbl] = kruskalwallis(y, g, "off");

    % Chi-square statistic is stored in tbl{2,5}
    chi2 = tbl{2,5};

    n = numel(y);
    k = numel(categories(removecats(g)));

    eps2 = max((chi2 - k + 1) / (n - k), 0);
end


%% ========================================================================
% Local helper function: Nature-style axes
% ========================================================================

function setNatureAxes(ax)
    % Apply a restrained scientific plotting style.

    ax.FontName = "Arial";
    ax.FontSize = 10.5;
    ax.LineWidth = 1.0;
    ax.TickDir = "out";
    ax.Box = "off";

    grid(ax, "on");
    ax.GridAlpha = 0.15;
    ax.XGrid = "off";
    ax.YGrid = "on";

    ax.Color = "w";
end
%% Compare K = 3 to 6 for learning-mode clustering
% This helps decide whether 4 or 5 modes are more appropriate.

KList = 3:6;

KSummary = table;
KSummary.K = KList(:);
KSummary.MeanSilhouette = nan(numel(KList),1);
KSummary.MinClusterSize = nan(numel(KList),1);
KSummary.MaxClusterSize = nan(numel(KList),1);
KSummary.MeanARI = nan(numel(KList),1);

nRepeat = 80;

for iK = 1:numel(KList)

    K_now = KList(iK);

    rng(2026);

    idx_ref = kmeans(Xz, K_now, ...
        "Distance", "sqeuclidean", ...
        "Start", "plus", ...
        "Replicates", 500, ...
        "MaxIter", 1000, ...
        "Display", "off");

    sil = silhouette(Xz, idx_ref);
    KSummary.MeanSilhouette(iK) = mean(sil, "omitnan");

    clusterSizes = accumarray(idx_ref, 1, [K_now,1], @sum, 0);
    KSummary.MinClusterSize(iK) = min(clusterSizes);
    KSummary.MaxClusterSize(iK) = max(clusterSizes);

    ARI = nan(nRepeat,1);

    for b = 1:nRepeat

        rng(3000 + 100*K_now + b);

        idx_b = kmeans(Xz, K_now, ...
            "Distance", "sqeuclidean", ...
            "Start", "plus", ...
            "Replicates", 100, ...
            "MaxIter", 1000, ...
            "Display", "off");

        ARI(b) = adjustedRandIndex(idx_ref, idx_b);
    end

    KSummary.MeanARI(iK) = mean(ARI, "omitnan");
end

disp(KSummary);

writetable(KSummary, "LearningMode_K_Selection_Summary.xlsx");
%% ========================================================================
% Local helper functions
% ========================================================================

function modeNames = assignLearningModeLabels(centerZ, featureVars)
    % Assign preliminary semantic labels to clusters based on centroid profiles.
    %
    % Feature order:
    %   improving_transition_ratio
    %   mean_practice_time
    %   model_revision_rounds
    %   first_practice_score
    %   practice_gain_ratio
    %
    % These labels should be verified manually using the exported cluster
    % profile table. The function provides a reproducible first assignment.

    K = size(centerZ,1);

    idx_improveRatio = find(featureVars == "improving_transition_ratio");
    idx_time         = find(featureVars == "mean_practice_time");
    idx_revision     = find(featureVars == "model_revision_rounds");
    idx_firstScore   = find(featureVars == "first_practice_score");
    idx_gainRatio    = find(featureVars == "practice_gain_ratio");

    improveRatio = centerZ(:, idx_improveRatio);
    time         = centerZ(:, idx_time);
    revision     = centerZ(:, idx_revision);
    firstScore   = centerZ(:, idx_firstScore);
    gainRatio    = centerZ(:, idx_gainRatio);

    % Scoring rules for each conceptual mode.
    %
    % High-quality starters:
    %   high first score, relatively low need for revision/gain.
    score_HQS = firstScore - 0.30 * revision - 0.20 * time;

    % Deliberate improvers:
    %   strong gain and consistent improvement, not necessarily high first score.
    score_DI = gainRatio + improveRatio - 0.20 * abs(revision);

    % Unstable score chasers:
    %   many revision rounds but less consistent improvement.
    score_USC = revision - 0.50 * improveRatio + 0.20 * gainRatio;

    % Inefficient explorers:
    %   high time and revision, but weak gain and weak consistency.
    score_IE = time + revision - gainRatio - improveRatio;

    % Minimal completers:
    %   low time, low revision, low gain, and low first score.
    score_MC = -time - revision - gainRatio - firstScore;

    scoreMatrix = [score_HQS, score_DI, score_USC, score_IE, score_MC];

    labelList = ["Low-start deliberate improvers"
    "High-start plateau learners"
    "High-investment model optimizers"
    "Minimal-time efficient completers"];

    modeNames = strings(K,1);
    usedCluster = false(K,1);
    usedLabel = false(5,1);

    % Greedy one-to-one assignment based on highest remaining score.
    for step = 1:K

        scoreMatrixMasked = scoreMatrix;
        scoreMatrixMasked(usedCluster, :) = -Inf;
        scoreMatrixMasked(:, usedLabel) = -Inf;

        [~, maxIdx] = max(scoreMatrixMasked(:));
        [clusterIdx, labelIdx] = ind2sub(size(scoreMatrixMasked), maxIdx);

        modeNames(clusterIdx) = labelList(labelIdx);

        usedCluster(clusterIdx) = true;
        usedLabel(labelIdx) = true;
    end
end


function ari = adjustedRandIndex(labels1, labels2)
    % Compute adjusted Rand index between two cluster label vectors.

    labels1 = labels1(:);
    labels2 = labels2(:);

    valid = ~isnan(labels1) & ~isnan(labels2);
    labels1 = labels1(valid);
    labels2 = labels2(valid);

    n = numel(labels1);

    if n < 2
        ari = NaN;
        return;
    end

    [~,~,g1] = unique(labels1);
    [~,~,g2] = unique(labels2);

    k1 = max(g1);
    k2 = max(g2);

    contingency = zeros(k1,k2);

    for i = 1:n
        contingency(g1(i), g2(i)) = contingency(g1(i), g2(i)) + 1;
    end

    nij = contingency;
    ai = sum(nij, 2);
    bj = sum(nij, 1);

    sumCombNij = sum(nchoosekVector(nij(:), 2));
    sumCombAi  = sum(nchoosekVector(ai, 2));
    sumCombBj  = sum(nchoosekVector(bj, 2));
    totalComb  = nchoosek(n, 2);

    expectedIndex = sumCombAi * sumCombBj / totalComb;
    maxIndex = 0.5 * (sumCombAi + sumCombBj);

    if maxIndex - expectedIndex == 0
        ari = 0;
    else
        ari = (sumCombNij - expectedIndex) / (maxIndex - expectedIndex);
    end
end


function c = nchoosekVector(x, k)
    % Fast vectorized nchoosek for k = 2.

    if k ~= 2
        error("Only k = 2 is supported.");
    end

    x = double(x);
    c = x .* (x - 1) ./ 2;
end


function cmap = makeDivergingColormap(n)
    % Create a restrained diverging colour map:
    %   low values  = muted vermillion
    %   zero        = near-white
    %   high values = muted blue

    if nargin < 1
        n = 256;
    end

    neg = [178,  44,  36] ./ 255;
    mid = [247, 247, 247] ./ 255;
    pos = [ 33, 102, 172] ./ 255;

    n1 = floor(n/2);
    n2 = n - n1;

    cmap1 = [linspace(neg(1), mid(1), n1)', ...
             linspace(neg(2), mid(2), n1)', ...
             linspace(neg(3), mid(3), n1)'];

    cmap2 = [linspace(mid(1), pos(1), n2)', ...
             linspace(mid(2), pos(2), n2)', ...
             linspace(mid(3), pos(3), n2)'];

    cmap = [cmap1; cmap2];
end