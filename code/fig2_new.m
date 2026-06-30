%% Fig. 2. Score distributions across assessment stages
%
% Required table:
%   T
%
% Accepted variable names:
%   pretest_score / PretestScore
%   standard_exam_score / StandardExamScore
%   engineering_test_score / EngineeringTestScore
%   report_score / ReportScore
%
% Output:
%   Fig2_Score_Distributions_NatureStyle.png
%   Fig2_Score_Distributions_NatureStyle.pdf

clearvars -except T; clc;

%% ------------------------------------------------------------------------
% 1. Extract score data
% -------------------------------------------------------------------------

pretest         = getVariable(T, ["pretest_score", "PretestScore"]);
standardExam    = getVariable(T, ["standard_exam_score", "StandardExamScore"]);
engineeringTest = getVariable(T, ["engineering_test_score", "EngineeringTestScore"]);
reportScore     = getVariable(T, ["report_score", "ReportScore"]);

pretest         = pretest(~isnan(pretest));
standardExam    = standardExam(~isnan(standardExam));
engineeringTest = engineeringTest(~isnan(engineeringTest));
reportScore     = reportScore(~isnan(reportScore));

%% ------------------------------------------------------------------------
% 2. Restrained Nature-style colour palette
% -------------------------------------------------------------------------

color_pretest     = [0.43, 0.54, 0.70];   % muted blue-grey
color_standard    = [0.20, 0.55, 0.52];   % muted teal
color_engineering = [0.76, 0.32, 0.25];   % muted vermillion
color_report      = [0.43, 0.38, 0.63];   % muted purple

colors_post = [
    color_standard
    color_engineering
    color_report
];

%% ------------------------------------------------------------------------
% 3. Main figure layout
% -------------------------------------------------------------------------

fig = figure("Color", "w", ...
    "Units", "centimeters", ...
    "Position", [3 3 18.0 7.2]);

clf;

tl = tiledlayout(fig, 1, 5, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");

%% ------------------------------------------------------------------------
% Panel A. Pre-class test
% -------------------------------------------------------------------------

ax1 = nexttile(tl, 1, [1 2]);
hold(ax1, "on");

plotRaincloud(ax1, ...
    {pretest}, ...
    ["Pre-class test"], ...
    color_pretest, ...
    [0 20], ...
    [0 20]);

ylabel(ax1, "Score");
ylim(ax1, [0 20]);
yticks(ax1, 0:5:20);

setNatureStyle(ax1);

text(ax1, -0.08, 1.04, "A", ...
    "Units", "normalized", ...
    "FontName", "Arial", ...
    "FontSize", 11, ...
    "FontWeight", "bold");

title(ax1, "Pre-class test", ...
    "FontName", "Arial", ...
    "FontSize", 9.5, ...
    "FontWeight", "normal");

%% ------------------------------------------------------------------------
% Panel B. Post-task assessments
% -------------------------------------------------------------------------

ax2 = nexttile(tl, 3, [1 3]);
hold(ax2, "on");

% Controlled empirical probability distribution.
% The short soft tail is applied only when exact ceiling scores are observed.
scoreBinEdges = 30:5:100;
interpMethod = "pchip";

upperTailEnd = 103;
tailMidPoint = 101.5;
tailRatio = 0.015;

plotRaincloudBinnedSoftTail(ax2, ...
    {standardExam, engineeringTest, reportScore}, ...
    ["Standard exam", "Engineering test", "Report score"], ...
    colors_post, ...
    [30 105], ...
    scoreBinEdges, ...
    interpMethod, ...
    upperTailEnd, ...
    tailMidPoint, ...
    tailRatio);

ylabel(ax2, "Score");
ylim(ax2, [30 105]);
yticks(ax2, 30:10:100);

setNatureStyle(ax2);

text(ax2, -0.06, 1.04, "B", ...
    "Units", "normalized", ...
    "FontName", "Arial", ...
    "FontSize", 11, ...
    "FontWeight", "bold");

title(ax2, "Post-task assessments", ...
    "FontName", "Arial", ...
    "FontSize", 9.5, ...
    "FontWeight", "normal");

%% ------------------------------------------------------------------------
% Ceiling annotation
% -------------------------------------------------------------------------

ceilTol = 1e-9;

std_ceiling_ratio = mean(standardExam >= 100 - ceilTol);
eng_ceiling_ratio = mean(engineeringTest >= 100 - ceilTol);
rep_ceiling_ratio = mean(reportScore >= 100 - ceilTol);

ceilingText = sprintf([ ...
    'Ceiling at 100\n' ...
    'Standard exam: %.1f%%\n' ...
    'Engineering test: %.1f%%\n' ...
    'Report score: %.1f%%'], ...
    100 * std_ceiling_ratio, ...
    100 * eng_ceiling_ratio, ...
    100 * rep_ceiling_ratio);

text(ax2, 1.53, 38, ceilingText, ...
    "HorizontalAlignment", "right", ...
    "VerticalAlignment", "bottom", ...
    "FontSize", 7.6, ...
    "FontName", "Arial", ...
    "Color", [0.15 0.15 0.15], ...
    "BackgroundColor", "w", ...
    "EdgeColor", [0.78 0.78 0.78], ...
    "LineWidth", 0.6, ...
    "Margin", 4);

% Reference line at maximum score
yline(ax2, 100, "--", ...
    "Color", [0.50 0.50 0.50], ...
    "LineWidth", 0.7);

%% ------------------------------------------------------------------------
% Export
% -------------------------------------------------------------------------

exportgraphics(fig, "Fig2_Score_Distributions_NatureStyle.png", ...
    "Resolution", 600);

exportgraphics(fig, "Fig2_Score_Distributions_NatureStyle.pdf", ...
    "ContentType", "vector");

%% ========================================================================
% Local helper function: getVariable
% ========================================================================

function x = getVariable(T, candidateNames)

    varNames = string(T.Properties.VariableNames);

    idx = find(ismember(varNames, candidateNames), 1);

    if isempty(idx)
        error("None of the following variables were found in T: %s", ...
            strjoin(candidateNames, ", "));
    end

    x = T.(varNames(idx));
    x = x(:);
end

%% ========================================================================
% Local helper function: ordinary bounded raincloud plot
% ========================================================================

function plotRaincloud(ax, dataCell, labels, colors, yLimits, densitySupport)

    if nargin < 6
        densitySupport = [];
    end

    axes(ax);
    hold(ax, "on");

    nGroup = numel(dataCell);
    densityWidth = 0.30;

    for i = 1:nGroup

        y = dataCell{i};
        y = y(:);
        y = y(~isnan(y));

        if isempty(y)
            continue;
        end

        xCenter = i;

        %% Kernel density cloud
        if numel(y) >= 5 && numel(unique(y)) >= 3
            try
                if ~isempty(densitySupport)
                    [f, yGrid] = ksdensity(y, ...
                        "Support", densitySupport, ...
                        "BoundaryCorrection", "reflection");
                else
                    [f, yGrid] = ksdensity(y);
                end

                f = f ./ max(f) .* densityWidth;

                xPoly = [xCenter - f, xCenter * ones(size(f))];
                yPoly = [yGrid, fliplr(yGrid)];

                patch(ax, xPoly, yPoly, colors(i,:), ...
                    "FaceAlpha", 0.26, ...
                    "EdgeColor", "none");

            catch
            end
        end

        %% Raw points
        rng(10 + i);
        jitter = (rand(size(y)) - 0.5) * 0.13;

        scatter(ax, ...
            xCenter + 0.08 + jitter, y, ...
            16, ...
            "MarkerFaceColor", colors(i,:), ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceAlpha", 0.46);

        %% Boxchart
        boxchart(ax, ...
            repmat(xCenter + 0.25, size(y)), y, ...
            "BoxWidth", 0.16, ...
            "MarkerStyle", "none", ...
            "BoxFaceColor", colors(i,:), ...
            "BoxFaceAlpha", 0.34, ...
            "LineWidth", 0.9);

        %% Mean marker
        mu = mean(y, "omitnan");

        plot(ax, xCenter + 0.25, mu, ...
            "d", ...
            "MarkerSize", 5.2, ...
            "MarkerFaceColor", "w", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 0.9);
    end

    xlim(ax, [0.45, nGroup + 0.65]);
    xticks(ax, 1:nGroup);
    xticklabels(ax, labels);

    if ~isempty(yLimits)
        ylim(ax, yLimits);
    end
end

%% ========================================================================
% Local helper function: binned empirical raincloud with conditional soft tail
% ========================================================================

function plotRaincloudBinnedSoftTail(ax, dataCell, labels, colors, yLimits, ...
    binEdges, interpMethod, upperTailEnd, tailMidPoint, tailRatio)

    if nargin < 8 || isempty(interpMethod)
        interpMethod = "pchip";
    end

    if nargin < 9 || isempty(upperTailEnd)
        upperTailEnd = 103;
    end

    if nargin < 10 || isempty(tailMidPoint)
        tailMidPoint = 101.5;
    end

    if nargin < 11 || isempty(tailRatio)
        tailRatio = 0.015;
    end

    axes(ax);
    hold(ax, "on");

    nGroup = numel(dataCell);
    densityWidth = 0.30;

    lowerEdge = binEdges(1);
    upperScore = binEdges(end);

    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;

    yFine = linspace(lowerEdge, upperTailEnd, 700);

    for i = 1:nGroup

        y = dataCell{i};
        y = y(:);
        y = y(~isnan(y));

        if isempty(y)
            continue;
        end

        xCenter = i;

        %% Empirical probability in score bins
        prob = histcounts(y, binEdges, "Normalization", "probability");

        %% Mild smoothing of empirical bin probabilities
        probSmooth = prob;

        if numel(probSmooth) >= 4
            probSmooth = smoothdata(probSmooth, "movmean", 3);
        end

        %% Preserve exact ceiling mass at 100
        ceilTol = 1e-9;
        ceilingMass = mean(y >= upperScore - ceilTol);

        lastBinMass = prob(end);

        pAtUpperScore = max([probSmooth(end), lastBinMass, ceilingMass]);

        %% Conditional soft tail
        % Add a soft tail only for score distributions with an observed ceiling.
        % For report score, if no student reaches 100, the density decays to zero at 100.
        if ceilingMass > 0
            yAnchor = [lowerEdge, binCenters, upperScore, tailMidPoint, upperTailEnd];
            pAnchor = [0, probSmooth, pAtUpperScore, tailRatio * pAtUpperScore, 0];
        else
            yAnchor = [lowerEdge, binCenters, upperScore, upperTailEnd];
            pAnchor = [0, probSmooth, 0, 0];
        end

        [yAnchor, uniqueIdx] = unique(yAnchor, "stable");
        pAnchor = pAnchor(uniqueIdx);

        pFine = interp1(yAnchor, pAnchor, yFine, char(interpMethod));

        pFine(pFine < 0) = 0;
        pFine(yFine < min(y) - 5) = 0;

        if ceilingMass == 0
            pFine(yFine > upperScore) = 0;
        end

        %% Normalize visual width
        if max(pFine) > 0
            widthFine = pFine ./ max(pFine) .* densityWidth;
        else
            widthFine = pFine;
        end

        %% Draw half-cloud
        xLeft = xCenter - widthFine;
        xRight = xCenter * ones(size(widthFine));

        xPoly = [xLeft, fliplr(xRight)];
        yPoly = [yFine, fliplr(yFine)];

        patch(ax, xPoly, yPoly, colors(i,:), ...
            "FaceAlpha", 0.26, ...
            "EdgeColor", "none");

        %% Raw data points
        rng(20 + i);
        jitter = (rand(size(y)) - 0.5) * 0.13;

        scatter(ax, ...
            xCenter + 0.08 + jitter, y, ...
            16, ...
            "MarkerFaceColor", colors(i,:), ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceAlpha", 0.46);

        %% Boxchart
        boxchart(ax, ...
            repmat(xCenter + 0.25, size(y)), y, ...
            "BoxWidth", 0.16, ...
            "MarkerStyle", "none", ...
            "BoxFaceColor", colors(i,:), ...
            "BoxFaceAlpha", 0.34, ...
            "LineWidth", 0.9);

        %% Mean marker
        mu = mean(y, "omitnan");

        plot(ax, xCenter + 0.25, mu, ...
            "d", ...
            "MarkerSize", 5.2, ...
            "MarkerFaceColor", "w", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 0.9);
    end

    xlim(ax, [0.45, nGroup + 0.65]);
    xticks(ax, 1:nGroup);
    xticklabels(ax, labels);

    if ~isempty(yLimits)
        ylim(ax, yLimits);
    end
end

%% ========================================================================
% Local helper function: Nature-style formatting
% ========================================================================

function setNatureStyle(ax)

    ax.FontName = "Arial";
    ax.FontSize = 8.5;
    ax.LineWidth = 0.8;
    ax.TickDir = "out";
    ax.Box = "off";
    ax.Color = "w";

    grid(ax, "on");
    ax.GridAlpha = 0.13;
    ax.XGrid = "off";
    ax.YGrid = "on";

    ax.TitleFontWeight = "normal";
end