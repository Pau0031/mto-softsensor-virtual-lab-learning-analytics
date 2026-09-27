%% =========================================================================
% FINAL MAIN-TEXT FIGURES — NATURE-LIKE VISUAL GRAMMAR
%
% Manuscript:
%   Beyond Platform Scores ...
%
% Purpose:
%   Generate the four FINAL main-text figures with frozen terminology.
%
% Required workspace table:
%   T
%
% Required variables in T:
%   standard_exam_score          -> plotted as "Embedded platform score"
%   engineering_test_score       -> plotted as "Modified-scenario score"
%   process_understanding
%   variable_selection
%   modelling_workflow
%   model_evaluation
%   engineering_recommendation
%   first_practice_score
%   practice_gain_ratio
%   improving_transition_ratio
%   model_revision_rounds
%   mean_practice_time
%
% Existing profile variable (one is sufficient):
%   participation_pattern_final
%   learning_mode_final
%   learning_mode
%   participation_pattern
%
% IMPORTANT
%   1. This script DOES NOT re-cluster students.
%   2. Existing cluster memberships are reused and only their TEXT LABELS
%      are harmonized to the final terminology.
%   3. Fig. 3 reconstructs the same transformed/robust-standardized feature
%      representation used in the clustering script for visualization.
%
% Final terminology:
%   Familiar-task embedded score
%   Modified-scenario score
%   Participation profile
%
% Final profile names:
%   Low-start deliberate improvers
%   High-start plateau learners
%   Intensive model optimizers
%   Minimal-time completers
%
% Outputs:
%   Figures_Main_Final/Fig1_ScoreEquivalence.pdf/.png
%   Figures_Main_Final/Fig2_ReasoningHeterogeneity.pdf/.png
%   Figures_Main_Final/Fig3_ParticipationProfiles.pdf/.png
%   Figures_Main_Final/Fig4_ProcessOutcome.pdf/.png
%
%% =========================================================================

clearvars -except T;
clc;
%%
if ~exist('T','var')
    error('Table T must be loaded in the MATLAB workspace before running this script.');
end

OUTDIR = 'Figures_Main_Final';
if ~exist(OUTDIR,'dir')
    mkdir(OUTDIR);
end

FULL_SCORE = 100;
HIGH_SCORE_CUTOFF = 95;
SCORE_TOL = 1e-9;
N_PERM = 50000;
RANDOM_SEED = 2026;

% -------------------------------------------------------------------------
% Frozen terminology
% -------------------------------------------------------------------------
profileOrder = [ ...
    "Low-start deliberate improvers"
    "High-start plateau learners"
    "Intensive model optimizers"
    "Minimal-time completers" ];

profileShort = { ...
    sprintf('Low-start deliberate\nimprovers'), ...
    sprintf('High-start plateau\nlearners'), ...
    sprintf('Intensive model\noptimizers'), ...
    sprintf('Minimal-time\ncompleters') };

stratumOrder = ["<95", "95-99", "100"];

% -------------------------------------------------------------------------
% Consistent restrained palette
% -------------------------------------------------------------------------
COLOR_EMBEDDED = [0.20 0.55 0.52];   % muted teal
COLOR_MODIFIED = [0.78 0.34 0.27];   % muted vermillion
COLOR_RUBRIC   = [0.31 0.49 0.69];   % muted blue
COLOR_RAW      = [0.18 0.18 0.18];

profileColors = [ ...
    0.25 0.49 0.69;   % deliberate improvers
    0.52 0.52 0.52;   % plateau learners
    0.82 0.38 0.24;   % intensive model optimizers
    0.86 0.62 0.18];  % minimal-time completers

% -------------------------------------------------------------------------
% Core variables and final categorical variables
% -------------------------------------------------------------------------
embeddedScore = double(T.standard_exam_score(:));
modifiedScore = double(T.engineering_test_score(:));

T.embedded_score_stratum = createScoreStratum( ...
    embeddedScore, HIGH_SCORE_CUTOFF, FULL_SCORE, SCORE_TOL);

profileSource = firstExistingVariable(T, [ ...
    "participation_pattern_final", ...
    "learning_mode_final", ...
    "learning_mode", ...
    "participation_pattern"]);

profileString = normalizeParticipationLabels(string(T.(profileSource)));
T.participation_profile = categorical( ...
    profileString, profileOrder, profileOrder, 'Ordinal', true);

fprintf('\nFrozen participation-profile counts:\n');
disp(groupcounts(T.participation_profile));


%% =========================================================================
% FIGURE 1
% SCORE COMPRESSION AND ADAPTIVE-PERFORMANCE HETEROGENEITY
%
% a. Exact familiar-task embedded-score distribution
% b. Modified-scenario score across embedded-score strata
% c. Modified-scenario score distribution among embedded score = 100
%% =========================================================================

fig1 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 18.3 6.4]);

tl = tiledlayout(fig1,1,3, ...
    'Padding','compact', ...
    'TileSpacing','compact');

% ------------------------------- panel a ---------------------------------
ax1 = nexttile(tl,1);
hold(ax1,'on');

validEmbedded = ~isnan(embeddedScore);
[uScore,~,gScore] = unique(embeddedScore(validEmbedded),'sorted');
scoreN = accumarray(gScore,1);

bh = bar(ax1,uScore,scoreN,0.74);
bh.FaceColor = COLOR_EMBEDDED;
bh.EdgeColor = 'none';

nEmbedded = sum(validEmbedded);
nFull = sum(abs(embeddedScore - FULL_SCORE) <= SCORE_TOL);

xlabel(ax1,'Embedded platform score');
ylabel(ax1,'Students (n)');
xlim(ax1,[min(uScore)-0.8, FULL_SCORE+0.8]);
xticks(ax1,min(uScore):2:FULL_SCORE);

yTop = max(scoreN)*1.18;
ylim(ax1,[0 yTop]);

text(ax1,FULL_SCORE,max(scoreN)*1.03, ...
    sprintf('%d/%d (%.1f%%)',nFull,nEmbedded,100*nFull/nEmbedded), ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom', ...
    'FontName','Arial', ...
    'FontSize',7.2);

applyNatureAxes(ax1);
addPanelLabel(ax1,'a');

% ------------------------------- panel b ---------------------------------
ax2 = nexttile(tl,2);
hold(ax2,'on');

plotRawBoxByOrderedGroup( ...
    ax2, ...
    modifiedScore, ...
    T.embedded_score_stratum, ...
    stratumOrder, ...
    COLOR_MODIFIED, ...
    [55 102]);

xlabel(ax2,'Embedded-score stratum');
ylabel(ax2,'Modified-scenario score');
ylim(ax2,[55 102]);
yticks(ax2,60:10:100);

validPair = ~isnan(embeddedScore) & ~isnan(modifiedScore);
[tauB,pTau] = corr( ...
    embeddedScore(validPair), ...
    modifiedScore(validPair), ...
    'Type','Kendall', ...
    'Rows','complete');

text(ax2,0.04,0.96, ...
    sprintf('Kendall \\tau_b = %.3f\np = %.3f',tauB,pTau), ...
    'Units','normalized', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'FontName','Arial', ...
    'FontSize',7.0, ...
    'Interpreter','tex');

applyNatureAxes(ax2);
addPanelLabel(ax2,'b');

% ------------------------------- panel c ---------------------------------
ax3 = nexttile(tl,3);
hold(ax3,'on');

idx100 = abs(embeddedScore - FULL_SCORE) <= SCORE_TOL & ~isnan(modifiedScore);
y100 = modifiedScore(idx100);

min100 = floor(min(y100));
max100 = ceil(max(y100));

edges = (min100-0.5):1:(max100+0.5);

hh = histogram(ax3,y100, ...
    'BinEdges',edges, ...
    'FaceColor',COLOR_MODIFIED, ...
    'FaceAlpha',0.82, ...
    'EdgeColor','w', ...
    'LineWidth',0.35);

xlabel(ax3,'Modified-scenario score');
ylabel(ax3,'Students (n)');
xlim(ax3,[min100-1, max100+1]);
xticks(ax3,60:10:100);

text(ax3,0.04,0.96, ...
    sprintf('n = %d\nrange = %g-%g\n%d distinct scores', ...
    numel(y100),min(y100),max(y100),numel(unique(y100))), ...
    'Units','normalized', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'FontName','Arial', ...
    'FontSize',7.0);

applyNatureAxes(ax3);
addPanelLabel(ax3,'c');

exportFigure(fig1,OUTDIR,'Fig1_ScoreEquivalence');


%% =========================================================================
% FIGURE 2
% ARTICULATED MODELLING REASONING AMONG FULL-SCORE STUDENTS
%
% Single-panel figure:
%   raw observations + box summaries for five 20-point rubric dimensions.
%% =========================================================================

rubricVars = [ ...
    "process_understanding"
    "variable_selection"
    "modelling_workflow"
    "model_evaluation"
    "engineering_recommendation"];

rubricLabels = { ...
    sprintf('Process\nunderstanding'), ...
    sprintf('Variable\nselection'), ...
    sprintf('Modelling\nworkflow'), ...
    sprintf('Model\nevaluation'), ...
    sprintf('Engineering\nrecommendation')};

fig2 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 15.8 7.1]);

ax = axes(fig2);
hold(ax,'on');

for j = 1:numel(rubricVars)

    y = double(T.(rubricVars(j))(idx100));
    y = y(~isnan(y));

    rng(400 + j);
    jitter = (rand(size(y)) - 0.5) * 0.28;

    scatter(ax,j+jitter,y,16, ...
        'MarkerFaceColor',COLOR_RUBRIC, ...
        'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha',0.34);

    boxchart(ax,repmat(j,size(y)),y, ...
        'BoxWidth',0.42, ...
        'MarkerStyle','none', ...
        'BoxFaceColor',COLOR_RUBRIC, ...
        'BoxFaceAlpha',0.18, ...
        'LineWidth',0.9);
end

xlim(ax,[0.5 5.5]);
xticks(ax,1:5);
xticklabels(ax,rubricLabels);

ylim(ax,[0 20]);
yticks(ax,0:5:20);
ylabel(ax,'Rubric score (0-20)');

applyNatureAxes(ax);

exportFigure(fig2,OUTDIR,'Fig2_ReasoningHeterogeneity');


%% =========================================================================
% FIGURE 3
% PARTICIPATION PROFILES DERIVED FROM PRACTICE TRACES
%
% a. Student-level robust-z heatmap, ordered by frozen profile
% b. Profile-centroid signatures in the same transformed feature space
%
% NOTE:
%   This section reproduces the transformations used in the clustering file
%   but DOES NOT run k-means again.
%% =========================================================================

featureVars = [ ...
    "first_practice_score"
    "practice_gain_ratio"
    "improving_transition_ratio"
    "model_revision_rounds"
    "mean_practice_time"];

featureLabels = { ...
    sprintf('First practice\nscore'), ...
    sprintf('Practice gain\nratio'), ...
    sprintf('Improving-transition\nratio'), ...
    sprintf('Model-revision\nrounds'), ...
    sprintf('Mean practice\ntime')};

assert(all(ismember(featureVars,string(T.Properties.VariableNames))), ...
    'One or more participation features are missing from T.');

Xraw = double(T{:,featureVars});
Xtrans = Xraw;

% Ratio-scale harmonization used in the original clustering workflow.
ratioVars = ["practice_gain_ratio","improving_transition_ratio"];
for i = 1:numel(ratioVars)
    j = find(featureVars == ratioVars(i));
    xj = Xtrans(:,j);
    if median(xj(~isnan(xj)),'omitnan') > 1.5
        Xtrans(:,j) = Xtrans(:,j) ./ 100;
    end
end

% Same log1p transforms as the clustering script.
jRev = find(featureVars == "model_revision_rounds");
jTime = find(featureVars == "mean_practice_time");
Xtrans(:,jRev)  = log1p(Xtrans(:,jRev));
Xtrans(:,jTime) = log1p(Xtrans(:,jTime));

% Same median imputation.
for j = 1:size(Xtrans,2)
    medj = median(Xtrans(:,j),'omitnan');
    if isnan(medj)
        error('Feature %s contains only missing values.',featureVars(j));
    end
    xj = Xtrans(:,j);
    xj(isnan(xj)) = medj;
    Xtrans(:,j) = xj;
end

% Same robust standardization + winsorization.
medX = median(Xtrans,1,'omitnan');
madX = mad(Xtrans,1,1) * 1.4826;

for j = 1:numel(madX)
    if madX(j) == 0 || isnan(madX(j))
        madX(j) = std(Xtrans(:,j),'omitnan');
    end
    if madX(j) == 0 || isnan(madX(j))
        madX(j) = 1;
    end
end

Xz = (Xtrans - medX) ./ madX;
Xz(Xz > 3) = 3;
Xz(Xz < -3) = -3;

% Order students by frozen profile and then first-practice score.
profileCode = double(T.participation_profile);
sortTable = table(profileCode,Xraw(:,1),(1:height(T))', ...
    'VariableNames',{'ProfileCode','FirstPractice','RowID'});

[~,ord] = sortrows(sortTable,{'ProfileCode','FirstPractice'});
XzSorted = Xz(ord,:);
profileSorted = T.participation_profile(ord);

% Group midpoints and boundaries.
groupMid = nan(4,1);
boundaryY = [];

for i = 1:4
    rowNow = find(string(profileSorted) == profileOrder(i));
    if ~isempty(rowNow)
        groupMid(i) = mean(rowNow);
    end
    if i < 4 && ~isempty(rowNow)
        boundaryY(end+1) = max(rowNow) + 0.5; %#ok<SAGROW>
    end
end

% Profile centroids in the same robust-z space.
centerZ = nan(4,numel(featureVars));
profileN = zeros(4,1);

for i = 1:4
    idx = string(T.participation_profile) == profileOrder(i);
    profileN(i) = sum(idx);
    centerZ(i,:) = mean(Xz(idx,:),1,'omitnan');
end

fig3 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 18.3 8.5]);

tl = tiledlayout(fig3,1,2, ...
    'Padding','compact', ...
    'TileSpacing','compact');

cmap = makeDivergingColormap(256);

% ------------------------------- panel a ---------------------------------
ax31 = nexttile(tl,1);
imagesc(ax31,XzSorted);
colormap(ax31,cmap);
clim(ax31,[-2.5 2.5]);

xticks(ax31,1:numel(featureLabels));
xticklabels(ax31,featureLabels);
xtickangle(ax31,26);

yticks(ax31,groupMid);
yticklabels(ax31,profileShort);
ylabel(ax31,'Students grouped by participation profile');

hold(ax31,'on');
for b = 1:numel(boundaryY)
    yline(ax31,b,'-','Color',[0.15 0.15 0.15],'LineWidth',0.55);
end

applyHeatmapAxes(ax31);
addPanelLabel(ax31,'a');

% ------------------------------- panel b ---------------------------------
ax32 = nexttile(tl,2);
hold(ax32,'on');

for i = 1:4
    for j = 1:numel(featureVars)
        z = centerZ(i,j);
        dotSize = 26 + 92 * min(abs(z),2.5)/2.5;

        scatter(ax32,j,i,dotSize,z, ...
            'filled', ...
            'MarkerEdgeColor',[0.18 0.18 0.18], ...
            'LineWidth',0.45);
    end
end

colormap(ax32,cmap);
clim(ax32,[-2.5 2.5]);

xlim(ax32,[0.5 5.5]);
ylim(ax32,[0.5 4.5]);
set(ax32,'YDir','reverse');

xticks(ax32,1:numel(featureLabels));
xticklabels(ax32,featureLabels);
xtickangle(ax32,26);

yticks(ax32,1:4);
profileLabelsN = cell(4,1);
for i = 1:4
    profileLabelsN{i} = sprintf('%s (n=%d)',profileShort{i},profileN(i));
end
yticklabels(ax32,profileLabelsN);

text(ax32,0.98,0.02,'circle size proportional to |z|', ...
    'Units','normalized', ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','bottom', ...
    'FontName','Arial', ...
    'FontSize',6.5, ...
    'Color',[0.35 0.35 0.35]);

applyNatureAxes(ax32);
addPanelLabel(ax32,'b');

cb = colorbar(ax32);
cb.Label.String = 'Robust z score';
cb.FontName = 'Arial';
cb.FontSize = 7.0;
cb.LineWidth = 0.6;

exportFigure(fig3,OUTDIR,'Fig3_ParticipationProfiles');


%% =========================================================================
% FIGURE 4
% PARTICIPATION PROFILES BEHIND SCORE-EQUIVALENT OUTCOMES
%
% a. Profile composition across embedded-score strata
% b. Modified-scenario score by profile among embedded score = 100
%% =========================================================================

% --------------------- panel a data + association -------------------------
countMatrix = zeros(3,4);

for i = 1:3
    for j = 1:4
        countMatrix(i,j) = sum( ...
            string(T.embedded_score_stratum) == stratumOrder(i) & ...
            string(T.participation_profile) == profileOrder(j));
    end
end

rowTotals = sum(countMatrix,2);
percentMatrix = 100 .* countMatrix ./ rowTotals;

[V,pAssoc] = cramerPermutationFromTable(countMatrix,N_PERM,RANDOM_SEED);

% --------------------- panel b data + permutation KW ----------------------
valid100Profile = ...
    idx100 & ...
    ~isundefined(T.participation_profile) & ...
    ~isnan(modifiedScore);

yB = modifiedScore(valid100Profile);
gBString = string(T.participation_profile(valid100Profile));

gBCode = zeros(numel(yB),1);
for j = 1:4
    gBCode(gBString == profileOrder(j)) = j;
end

[pPermKW,eps2] = kwPermutation(yB,gBCode,N_PERM,RANDOM_SEED);

fig4 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 18.3 8.7]);

tl = tiledlayout(fig4,1,2, ...
    'Padding','compact', ...
    'TileSpacing','compact');

% ------------------------------- panel a ---------------------------------
ax41 = nexttile(tl,1);
hold(ax41,'on');

b = bar(ax41,percentMatrix,'stacked','BarWidth',0.67);

for j = 1:4
    b(j).FaceColor = profileColors(j,:);
    b(j).EdgeColor = 'none';
end

% Count labels for sufficiently large segments.
for i = 1:3
    cumulative = 0;
    for j = 1:4
        h = percentMatrix(i,j);
        if h >= 8
            text(ax41,i,cumulative+h/2,sprintf('%d',countMatrix(i,j)), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontName','Arial', ...
                'FontSize',6.7, ...
                'FontWeight','bold', ...
                'Color','w');
        end
        cumulative = cumulative + h;
    end
end

xlim(ax41,[0.45 3.55]);
ylim(ax41,[0 100]);
xticks(ax41,1:3);
xticklabels(ax41,stratumOrder);

xlabel(ax41,'Embedded-score stratum');
ylabel(ax41,'Students within stratum (%)');

text(ax41,0.04,0.97, ...
    sprintf('Cramer''s V = %.3f\npermutation p = %.3f',V,pAssoc), ...
    'Units','normalized', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'FontName','Arial', ...
    'FontSize',6.9);

lgd = legend(ax41,b,cellstr(profileOrder), ...
    'Location','southoutside', ...
    'Box','off', ...
    'FontName','Arial', ...
    'FontSize',6.4);
try
    lgd.NumColumns = 2;
catch
end

applyNatureAxes(ax41);
addPanelLabel(ax41,'a');

% ------------------------------- panel b ---------------------------------
ax42 = nexttile(tl,2);
hold(ax42,'on');

for j = 1:4

    idx = ...
        valid100Profile & ...
        string(T.participation_profile) == profileOrder(j);

    y = modifiedScore(idx);
    y = y(~isnan(y));

    if isempty(y)
        continue;
    end

    rng(700+j);
    jitter = (rand(size(y)) - 0.5) * 0.28;

    scatter(ax42,j+jitter,y,18, ...
        'MarkerFaceColor',profileColors(j,:), ...
        'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha',0.48);

    boxchart(ax42,repmat(j,size(y)),y, ...
        'BoxWidth',0.42, ...
        'MarkerStyle','none', ...
        'BoxFaceColor',profileColors(j,:), ...
        'BoxFaceAlpha',0.22, ...
        'LineWidth',0.9);

    text(ax42,j,101.2,sprintf('n=%d',numel(y)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontName','Arial', ...
        'FontSize',6.7);
end

xlim(ax42,[0.5 4.5]);
xticks(ax42,1:4);
xticklabels(ax42,profileShort);

ylim(ax42,[55 103]);
yticks(ax42,60:10:100);

ylabel(ax42,'Modified-scenario score');
xlabel(ax42,'Participation profile');

text(ax42,0.04,0.97, ...
    sprintf('permutation p = %.3f\n\\epsilon^2 = %.3f',pPermKW,eps2), ...
    'Units','normalized', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','top', ...
    'FontName','Arial', ...
    'FontSize',6.9, ...
    'Interpreter','tex');

applyNatureAxes(ax42);
addPanelLabel(ax42,'b');

exportFigure(fig4,OUTDIR,'Fig4_ProcessOutcome');


fprintf('\n============================================================\n');
fprintf('FINAL FIGURES COMPLETE\n');
fprintf('============================================================\n');
fprintf('Output folder: %s\n',OUTDIR);
fprintf('Profile source variable reused: %s\n',profileSource);
fprintf('No reclustering was performed.\n');


%% =========================================================================
% LOCAL FUNCTIONS
%% =========================================================================

function v = firstExistingVariable(T,candidateNames)

    names = string(T.Properties.VariableNames);
    v = "";

    for i = 1:numel(candidateNames)
        if ismember(candidateNames(i),names)
            v = candidateNames(i);
            return;
        end
    end

    error('None of the requested variables exists in T: %s', ...
        strjoin(candidateNames,', '));
end


function profileStr = normalizeParticipationLabels(profileStr)
% Harmonize text only. Cluster membership is not changed.

    profileStr = strtrim(string(profileStr));

    profileStr(contains(profileStr,'Deliberate','IgnoreCase',true)) = ...
        "Low-start deliberate improvers";

    profileStr( ...
        contains(profileStr,'plateau','IgnoreCase',true) | ...
        contains(profileStr,'High-start','IgnoreCase',true)) = ...
        "High-start plateau learners";

    profileStr( ...
        contains(profileStr,'Invested','IgnoreCase',true) | ...
        contains(profileStr,'investment','IgnoreCase',true) | ...
        contains(profileStr,'optimizer','IgnoreCase',true)) = ...
        "Intensive model optimizers";

    profileStr(contains(profileStr,'Minimal','IgnoreCase',true)) = ...
        "Minimal-time completers";
end


function g = createScoreStratum(score,cutoff,fullScore,tol)

    score = double(score(:));
    s = strings(numel(score),1);
    s(:) = missing;

    idx1 = ~isnan(score) & score < cutoff;
    idx2 = ~isnan(score) & score >= cutoff & score < fullScore - tol;
    idx3 = ~isnan(score) & abs(score-fullScore) <= tol;

    s(idx1) = "<95";
    s(idx2) = "95-99";
    s(idx3) = "100";

    order = ["<95","95-99","100"];

    g = categorical(s,order,order,'Ordinal',true);
end


function plotRawBoxByOrderedGroup(ax,y,g,groupOrder,faceColor,yLimNow)

    axes(ax);
    hold(ax,'on');

    for i = 1:numel(groupOrder)

        idx = string(g) == groupOrder(i);
        yi = double(y(idx));
        yi = yi(~isnan(yi));

        if isempty(yi)
            continue;
        end

        rng(100+i);
        jitter = (rand(size(yi))-0.5)*0.24;

        scatter(ax,i+jitter,yi,15, ...
            'MarkerFaceColor',faceColor, ...
            'MarkerEdgeColor','none', ...
            'MarkerFaceAlpha',0.34);

        boxchart(ax,repmat(i,size(yi)),yi, ...
            'BoxWidth',0.42, ...
            'MarkerStyle','none', ...
            'BoxFaceColor',faceColor, ...
            'BoxFaceAlpha',0.18, ...
            'LineWidth',0.9);

        if ~isempty(yLimNow)
            text(ax,i,yLimNow(2)-1.2,sprintf('n=%d',numel(yi)), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','top', ...
                'FontName','Arial', ...
                'FontSize',6.7);
        end
    end

    xlim(ax,[0.5 numel(groupOrder)+0.5]);
    xticks(ax,1:numel(groupOrder));
    xticklabels(ax,groupOrder);

    if ~isempty(yLimNow)
        ylim(ax,yLimNow);
    end
end


function applyNatureAxes(ax)
% Restrained Nature-like visual grammar; no decorative styling.

    ax.FontName = 'Arial';
    ax.FontSize = 7.5;
    ax.LineWidth = 0.75;
    ax.TickDir = 'out';
    ax.TickLength = [0.018 0.018];
    ax.Box = 'off';
    ax.Color = 'w';
    ax.Layer = 'top';

    grid(ax,'off');

    ax.XColor = [0.10 0.10 0.10];
    ax.YColor = [0.10 0.10 0.10];
end


function applyHeatmapAxes(ax)

    ax.FontName = 'Arial';
    ax.FontSize = 7.1;
    ax.LineWidth = 0.65;
    ax.TickDir = 'out';
    ax.Box = 'off';
    ax.Layer = 'top';
end


function addPanelLabel(ax,labelText)

    text(ax,-0.12,1.055,labelText, ...
        'Units','normalized', ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','bottom', ...
        'FontName','Arial', ...
        'FontSize',9.5, ...
        'FontWeight','bold', ...
        'Color',[0 0 0], ...
        'Clipping','off');
end


function exportFigure(fig,outDir,baseName)

    exportgraphics(fig, ...
        fullfile(outDir,[baseName '.pdf']), ...
        'ContentType','vector');

    exportgraphics(fig, ...
        fullfile(outDir,[baseName '.png']), ...
        'Resolution',600);
end


function cmap = makeDivergingColormap(n)

    if nargin < 1
        n = 256;
    end

    neg = [178 54 43] ./ 255;
    mid = [247 247 247] ./ 255;
    pos = [49 105 168] ./ 255;

    n1 = floor(n/2);
    n2 = n-n1;

    cmap1 = [ ...
        linspace(neg(1),mid(1),n1)', ...
        linspace(neg(2),mid(2),n1)', ...
        linspace(neg(3),mid(3),n1)'];

    cmap2 = [ ...
        linspace(mid(1),pos(1),n2)', ...
        linspace(mid(2),pos(2),n2)', ...
        linspace(mid(3),pos(3),n2)'];

    cmap = [cmap1;cmap2];
end


function [V,pPerm] = cramerPermutationFromTable(obs,nPerm,seed)

    obs = double(obs);
    N = sum(obs(:));

    rowMarginal = sum(obs,2);
    colMarginal = sum(obs,1);
    expct = rowMarginal * colMarginal ./ N;

    chiObs = sum((obs(:)-expct(:)).^2 ./ expct(:));

    [R,C] = size(obs);
    V = sqrt(chiObs/(N*min(R-1,C-1)));

    rowCode = [];
    colCode = [];

    for i = 1:R
        for j = 1:C
            n = obs(i,j);
            rowCode = [rowCode; repmat(i,n,1)]; %#ok<AGROW>
            colCode = [colCode; repmat(j,n,1)]; %#ok<AGROW>
        end
    end

    rng(seed);
    chiPerm = nan(nPerm,1);

    for b = 1:nPerm

        permCol = colCode(randperm(N));

        permObs = accumarray( ...
            [rowCode permCol],1,[R C],@sum,0);

        chiPerm(b) = sum((permObs(:)-expct(:)).^2 ./ expct(:));
    end

    pPerm = (1 + sum(chiPerm >= chiObs - 1e-12))/(nPerm+1);
end


function [pPerm,eps2] = kwPermutation(y,g,nPerm,seed)

    y = double(y(:));
    g = double(g(:));

    valid = ~isnan(y) & ~isnan(g) & g>0;
    y = y(valid);
    g = g(valid);

    Hobs = kruskalHStatistic(y,g);

    N = numel(y);
    k = numel(unique(g));

    eps2 = max((Hobs-k+1)/(N-k),0);

    rng(seed);
    Hperm = nan(nPerm,1);

    for b = 1:nPerm
        gp = g(randperm(N));
        Hperm(b) = kruskalHStatistic(y,gp);
    end

    pPerm = (1 + sum(Hperm >= Hobs - 1e-12))/(nPerm+1);
end


function H = kruskalHStatistic(y,g)

    y = double(y(:));
    g = double(g(:));

    valid = ~isnan(y) & ~isnan(g) & g>0;
    y = y(valid);
    g = g(valid);

    N = numel(y);

    ranks = tiedrank(y);
    groupList = unique(g);

    Hraw = 0;

    for i = 1:numel(groupList)

        idx = g == groupList(i);
        ni = sum(idx);
        meanRank = mean(ranks(idx));

        Hraw = Hraw + ni*(meanRank-(N+1)/2)^2;
    end

    Hraw = 12*Hraw/(N*(N+1));

    [~,~,tieGroup] = unique(y);
    tieCounts = accumarray(tieGroup,1);

    tieCorrection = 1 - ...
        sum(tieCounts.^3-tieCounts)/(N^3-N);

    if tieCorrection > 0
        H = Hraw/tieCorrection;
    else
        H = Hraw;
    end
end

