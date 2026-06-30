%% Blockwise modelling of scaffolding effects
%
% Required table:
%   T
%
% Required variables:
%   report_score
%   engineering_test_score
%   model_evaluation
%   engineering_recommendation
%   pretest_score
%   gender
%   instructional_design_condition
%   learning_mode_final
%   selected_highest_R2_model
%   reported_model
%
% Optional process variables:
%   first_practice_score
%   practice_gain_ratio
%   effective_modelling_time
%   model_revision_rounds

clearvars -except T; clc;


%% ------------------------------------------------------------------------
% 1. Convert categorical variables
% -------------------------------------------------------------------------

T.gender = categorical(T.gender);
T.instructional_design_condition = categorical(T.instructional_design_condition);
T.learning_mode_final = categorical(T.learning_mode_final);
T.reported_model = categorical(T.reported_model);
T.selected_highest_R2_model = categorical(T.selected_highest_R2_model);


%% ------------------------------------------------------------------------
% 2. Define scaffold factors from instructional_design_condition
% -------------------------------------------------------------------------
% Actual coding:
%   RA = engineering scaffold + process-assessment scaffold
%   N  = none
%   A  = process-assessment scaffold only
%   R  = engineering scaffold only

designStr = string(T.instructional_design_condition);
designStr = upper(strtrim(designStr));

% Check whether all design labels are valid
validDesignLabels = ["N", "R", "A", "RA"];

invalidDesign = ~ismember(designStr, validDesignLabels) & ~ismissing(designStr);

if any(invalidDesign)
    warning("The following instructional_design_condition labels are not recognized:");
    disp(unique(designStr(invalidDesign)));
end

% Store cleaned instructional design condition
T.instructional_design_condition = categorical(designStr, ...
    ["N", "R", "A", "RA"], ...
    ["N", "R", "A", "RA"]);

% Initialize scaffold indicators
T.engineering_scaffold = zeros(height(T),1);
T.process_assessment_scaffold = zeros(height(T),1);

% Engineering-reasoning scaffold:
%   R and RA contain engineering scaffold
T.engineering_scaffold(designStr == "R" | designStr == "RA") = 1;

% Process-oriented assessment scaffold:
%   A and RA contain assessment scaffold
T.process_assessment_scaffold(designStr == "A" | designStr == "RA") = 1;

% Convert to categorical factors for fitlm
T.engineering_scaffold = categorical(T.engineering_scaffold, ...
    [0 1], ...
    ["No", "Yes"]);

T.process_assessment_scaffold = categorical(T.process_assessment_scaffold, ...
    [0 1], ...
    ["No", "Yes"]);

%% Check mapping
disp("Scaffold design mapping check:");
disp(groupsummary(T, ...
    ["instructional_design_condition", ...
     "engineering_scaffold", ...
     "process_assessment_scaffold"]));

%% ------------------------------------------------------------------------
% 3. Define outcome variables
% -------------------------------------------------------------------------

outcomes = [ ...
    "report_score"
    "engineering_test_score"
    "model_evaluation"
    "engineering_recommendation" ];


%% ------------------------------------------------------------------------
% 4. Fit blockwise models for each outcome
% -------------------------------------------------------------------------

ModelSummary = table;

for i = 1:numel(outcomes)

    y = outcomes(i);

    fprintf("\n\n====================================================\n");
    fprintf("Outcome: %s\n", y);
    fprintf("====================================================\n");

    %% ------------------------------------------------------------
    % Model 1: total scaffold effect
    % -------------------------------------------------------------

    formula1 = sprintf("%s ~ engineering_scaffold * process_assessment_scaffold + pretest_score", y);

    mdl1 = fitlm(T, formula1, ...
        "RobustOpts", "on");

    disp("Model 1: total scaffold effect");
    disp(mdl1);

    %% ------------------------------------------------------------
    % Model 2: trace-adjusted model
    % -------------------------------------------------------------

    formula2 = sprintf("%s ~ engineering_scaffold * process_assessment_scaffold + pretest_score + first_practice_score + practice_gain_ratio + effective_modelling_time + model_revision_rounds", y);

    mdl2 = fitlm(T, formula2, ...
        "RobustOpts", "on");

    disp("Model 2: trace-adjusted model");
    disp(mdl2);

    %% ------------------------------------------------------------
    % Model 3: learning-mode model
    % -------------------------------------------------------------

    formula3 = sprintf("%s ~ engineering_scaffold * process_assessment_scaffold + pretest_score + learning_mode_final", y);

    mdl3 = fitlm(T, formula3, ...
        "RobustOpts", "on");

    disp("Model 3: learning-mode model");
    disp(mdl3);

    %% ------------------------------------------------------------
    % Model 4: decision-behaviour model
    % -------------------------------------------------------------

    formula4 = sprintf("%s ~ engineering_scaffold * process_assessment_scaffold + pretest_score + selected_highest_R2_model + reported_model", y);

    mdl4 = fitlm(T, formula4, ...
        "RobustOpts", "on");

    disp("Model 4: decision-behaviour model");
    disp(mdl4);

    %% ------------------------------------------------------------
    % Store summary
    % -------------------------------------------------------------

    tmp = table;
    tmp.Outcome = repmat(y, 4, 1);
    tmp.Model = ["Total scaffold"; "Trace-adjusted"; "Learning-mode"; "Decision-behaviour"];
    tmp.Rsquared = [mdl1.Rsquared.Adjusted; mdl2.Rsquared.Adjusted; mdl3.Rsquared.Adjusted; mdl4.Rsquared.Adjusted];
    tmp.AIC = [mdl1.ModelCriterion.AIC; mdl2.ModelCriterion.AIC; mdl3.ModelCriterion.AIC; mdl4.ModelCriterion.AIC];
    tmp.BIC = [mdl1.ModelCriterion.BIC; mdl2.ModelCriterion.BIC; mdl3.ModelCriterion.BIC; mdl4.ModelCriterion.BIC];

    ModelSummary = [ModelSummary; tmp]; %#ok<AGROW>

    %% Save models
    Models.(y).mdl1_total_scaffold = mdl1;
    Models.(y).mdl2_trace_adjusted = mdl2;
    Models.(y).mdl3_learning_mode = mdl3;
    Models.(y).mdl4_decision_behaviour = mdl4;
end

disp(ModelSummary);

writetable(ModelSummary, "Scaffold_Model_Comparison_Summary.xlsx");
save("Scaffold_Models.mat", "Models", "ModelSummary");

fprintf("Model comparison summary exported.\n");