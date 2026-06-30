%% Update learning traces after duration correction and experiment filtering
% Raw input table:
% T_all with variables:
% exp_id, stu_id, stu_name, college, exp_name, start_time, end_time, score

T = T_all;

%% ------------------------------------------------------------
%  1. Parameters
% ------------------------------------------------------------

MAX_DURATION_MIN = 40;

EXP_919 = "10000919";
EXP_920 = "10000920";
EXP_921 = "10000921";

EXP_SCORE = [EXP_919, EXP_921];   % score-bearing records for analysis
EXP_COUNT_ONLY = EXP_920;         % count attempts, but exclude from score trace

ADD_SCORE_FOR_919_921 = 5;
CAP_SCORE_AT_100 = true;          % set false if you do not want score capping


%% ------------------------------------------------------------
%  2. Check required columns
% ------------------------------------------------------------

requiredVars = ["exp_id","stu_id","stu_name","college","exp_name", ...
                "start_time","end_time","score"];

missingVars = setdiff(requiredVars, string(T.Properties.VariableNames));

assert(isempty(missingVars), ...
    "T_all is missing required variables: %s", ...
    strjoin(missingVars, ", "));


%% ------------------------------------------------------------
%  3. Convert IDs and time variables
% ------------------------------------------------------------

T.stu_id_key = toIDKey(T.stu_id);
T.exp_id_key = toIDKey(T.exp_id);

T.start_time = toDatetimeColumn(T.start_time);
T.end_time   = toDatetimeColumn(T.end_time);


%% ------------------------------------------------------------
%  4. Calculate raw duration and capped duration
% ------------------------------------------------------------

% Preserve original end time
T.end_time_raw = T.end_time;

% If duration_min already exists, use it as the raw duration.
% Otherwise calculate it from original end_time - start_time.
if ismember("duration_min", string(T.Properties.VariableNames))
    T.duration_min_raw = T.duration_min;
else
    T.duration_min_raw = minutes(T.end_time_raw - T.start_time);
end

% Remove obviously invalid duration values
T.duration_min_raw(T.duration_min_raw < 0) = NaN;

% Winsorize duration at 40 min
T.duration_min = T.duration_min_raw;
T.duration_capped_flag = T.duration_min > MAX_DURATION_MIN;
T.duration_min(T.duration_capped_flag) = MAX_DURATION_MIN;

% Update end_time based on start_time + capped duration
T.end_time = T.start_time + minutes(T.duration_min);


%% ------------------------------------------------------------
%  5. Keep only the three relevant experiment IDs
% ------------------------------------------------------------

validExpMask = ismember(T.exp_id_key, [EXP_919, EXP_920, EXP_921]);

nIgnored = sum(~validExpMask);
if nIgnored > 0
    warning("%d rows with irrelevant exp_id were ignored.", nIgnored);
end

T = T(validExpMask, :);


%% ------------------------------------------------------------
%  6. Define score-bearing and count-only records
% ------------------------------------------------------------

T.is_score_exp = ismember(T.exp_id_key, EXP_SCORE);
T.is_920_count_only = T.exp_id_key == EXP_COUNT_ONLY;

% score_adjusted is only meaningful for 919 and 921.
% 920 is excluded from score-based traces.
T.score_adjusted = nan(height(T),1);

T.score_adjusted(T.is_score_exp) = T.score(T.is_score_exp) + ADD_SCORE_FOR_919_921;

if CAP_SCORE_AT_100
    T.score_adjusted(T.is_score_exp) = min(T.score_adjusted(T.is_score_exp), 100);
end


%% ------------------------------------------------------------
%  7. Remove invalid rows
% ------------------------------------------------------------

invalidRows = ismissing(T.stu_id_key) | isnat(T.start_time) | ...
              isnat(T.end_time) | isnan(T.duration_min);

if any(invalidRows)
    warning("%d invalid rows were removed.", sum(invalidRows));
    T = T(~invalidRows, :);
end

T = sortrows(T, {'stu_id_key','start_time','end_time'});


%% ------------------------------------------------------------
%  8. Build student-level table
% ------------------------------------------------------------

stuKeys = unique(T.stu_id_key, 'stable');
nStu = numel(stuKeys);

studentName = strings(nStu,1);
collegeName = strings(nStu,1);

attemptCount_all3   = zeros(nStu,1);
attemptCount_919    = zeros(nStu,1);
attemptCount_920    = zeros(nStu,1);
attemptCount_921    = zeros(nStu,1);
attemptCount_scored = zeros(nStu,1);

totalActiveTime_all3_min   = zeros(nStu,1);
totalActiveTime_scored_min = zeros(nStu,1);
totalActiveTime_919_min    = zeros(nStu,1);
totalActiveTime_920_min    = zeros(nStu,1);
totalActiveTime_921_min    = zeros(nStu,1);

totalSpanTime_all3_min = nan(nStu,1);

firstScore_adjusted = nan(nStu,1);
finalScore_adjusted = nan(nStu,1);
bestScore_adjusted  = nan(nStu,1);
scoreGain_adjusted  = nan(nStu,1);

finalScore_919_adjusted = nan(nStu,1);
bestScore_919_adjusted  = nan(nStu,1);
finalScore_921_adjusted = nan(nStu,1);
bestScore_921_adjusted  = nan(nStu,1);

durationCappedCount = zeros(nStu,1);
durationCappedRatio = nan(nStu,1);

TraceAll3Cell       = cell(nStu,1);
TraceScoredCell     = cell(nStu,1);
TimeByExperimentCell = cell(nStu,1);

ScoreSeriesCell    = cell(nStu,1);
DurationSeriesCell = cell(nStu,1);
IntervalSeriesCell = cell(nStu,1);

for i = 1:nStu

    Ti = T(T.stu_id_key == stuKeys(i), :);
    Ti = sortrows(Ti, {'start_time','end_time'});

    studentName(i) = firstString(Ti.stu_name);
    collegeName(i) = firstString(Ti.college);

    %% Full trace including 919, 920, and 921
    Ti_all3 = addTraceVariables(Ti, "score_adjusted");

    %% Score-based trace: only 919 and 921
    Ti_scored = Ti(Ti.is_score_exp, :);
    Ti_scored = sortrows(Ti_scored, {'start_time','end_time'});
    Ti_scored = addTraceVariables(Ti_scored, "score_adjusted");

    %% Attempt counts
    attemptCount_all3(i)   = height(Ti);
    attemptCount_919(i)    = sum(Ti.exp_id_key == EXP_919);
    attemptCount_920(i)    = sum(Ti.exp_id_key == EXP_920);
    attemptCount_921(i)    = sum(Ti.exp_id_key == EXP_921);
    attemptCount_scored(i) = height(Ti_scored);

    %% Time summaries
    totalActiveTime_all3_min(i) = sum(Ti.duration_min, 'omitnan');

    totalActiveTime_919_min(i) = sum(Ti.duration_min(Ti.exp_id_key == EXP_919), 'omitnan');
    totalActiveTime_920_min(i) = sum(Ti.duration_min(Ti.exp_id_key == EXP_920), 'omitnan');
    totalActiveTime_921_min(i) = sum(Ti.duration_min(Ti.exp_id_key == EXP_921), 'omitnan');

    totalActiveTime_scored_min(i) = ...
        totalActiveTime_919_min(i) + totalActiveTime_921_min(i);

    if height(Ti) >= 1
        totalSpanTime_all3_min(i) = minutes(max(Ti.end_time) - min(Ti.start_time));
    end

    %% Duration correction information
    durationCappedCount(i) = sum(Ti.duration_capped_flag);
    durationCappedRatio(i) = durationCappedCount(i) / height(Ti);

    %% Score summaries based only on 919 and 921, with +5 adjustment
    if height(Ti_scored) >= 1
        firstScore_adjusted(i) = Ti_scored.score_adjusted(1);
        finalScore_adjusted(i) = Ti_scored.score_adjusted(end);
        bestScore_adjusted(i)  = max(Ti_scored.score_adjusted, [], 'omitnan');
        scoreGain_adjusted(i)  = finalScore_adjusted(i) - firstScore_adjusted(i);

        ScoreSeriesCell{i}    = Ti_scored.score_adjusted(:);
        DurationSeriesCell{i} = Ti_scored.duration_min(:);
        IntervalSeriesCell{i} = Ti_scored.interval_from_prev_attempt_min(:);
    else
        ScoreSeriesCell{i}    = [];
        DurationSeriesCell{i} = [];
        IntervalSeriesCell{i} = [];
    end

    %% Per-experiment final and best adjusted scores
    T919 = Ti_scored(Ti_scored.exp_id_key == EXP_919, :);
    T921 = Ti_scored(Ti_scored.exp_id_key == EXP_921, :);

    if height(T919) >= 1
        finalScore_919_adjusted(i) = T919.score_adjusted(end);
        bestScore_919_adjusted(i)  = max(T919.score_adjusted, [], 'omitnan');
    end

    if height(T921) >= 1
        finalScore_921_adjusted(i) = T921.score_adjusted(end);
        bestScore_921_adjusted(i)  = max(T921.score_adjusted, [], 'omitnan');
    end

    %% Store traces
    TraceAll3Cell{i} = Ti_all3(:, {'attempt_no', ...
                                   'exp_id', 'exp_id_key', 'exp_name', ...
                                   'start_time', 'end_time_raw', 'end_time', ...
                                   'duration_min_raw', 'duration_min', ...
                                   'duration_capped_flag', ...
                                   'interval_from_prev_attempt_min', ...
                                   'score', 'score_adjusted', ...
                                   'score_delta'});

    TraceScoredCell{i} = Ti_scored(:, {'attempt_no', ...
                                       'exp_id', 'exp_id_key', 'exp_name', ...
                                       'start_time', 'end_time_raw', 'end_time', ...
                                       'duration_min_raw', 'duration_min', ...
                                       'duration_capped_flag', ...
                                       'interval_from_prev_attempt_min', ...
                                       'score', 'score_adjusted', ...
                                       'score_delta'});

    %% Time and score summary by experiment
    TimeByExperimentCell{i} = buildTimeByExperiment(Ti);

end


%% ------------------------------------------------------------
%  9. Final T_student table
% ------------------------------------------------------------

T_student = table(stuKeys, studentName, collegeName, ...
    attemptCount_all3, attemptCount_scored, ...
    attemptCount_919, attemptCount_920, attemptCount_921, ...
    totalActiveTime_all3_min, totalActiveTime_scored_min, ...
    totalActiveTime_919_min, totalActiveTime_920_min, totalActiveTime_921_min, ...
    totalSpanTime_all3_min, ...
    durationCappedCount, durationCappedRatio, ...
    firstScore_adjusted, finalScore_adjusted, bestScore_adjusted, scoreGain_adjusted, ...
    finalScore_919_adjusted, bestScore_919_adjusted, ...
    finalScore_921_adjusted, bestScore_921_adjusted, ...
    TraceAll3Cell, TraceScoredCell, TimeByExperimentCell, ...
    ScoreSeriesCell, DurationSeriesCell, IntervalSeriesCell, ...
    'VariableNames', {'stu_id_key','stu_name','college', ...
    'attempt_count_all3','attempt_count_scored', ...
    'attempt_count_919','attempt_count_920','attempt_count_921', ...
    'total_active_time_all3_min','total_active_time_scored_min', ...
    'total_active_time_919_min','total_active_time_920_min','total_active_time_921_min', ...
    'total_span_time_all3_min', ...
    'duration_capped_count','duration_capped_ratio', ...
    'first_score_adjusted','final_score_adjusted','best_score_adjusted','score_gain_adjusted', ...
    'final_score_919_adjusted','best_score_919_adjusted', ...
    'final_score_921_adjusted','best_score_921_adjusted', ...
    'learning_trace_all3','learning_trace_scored','time_by_experiment', ...
    'score_series_adjusted','duration_series_scored','interval_series_scored'});

T_student = sortrows(T_student, 'stu_id_key');


%% ------------------------------------------------------------
%  10. Optional export
% ------------------------------------------------------------

save('student_learning_trace_corrected.mat', 'T', 'T_student');

T_student_summary = removevars(T_student, ...
    {'learning_trace_all3','learning_trace_scored','time_by_experiment', ...
     'score_series_adjusted','duration_series_scored','interval_series_scored'});

writetable(T_student_summary, 'student_learning_summary_corrected.xlsx');


%% ------------------------------------------------------------
%  11. Optional checking
% ------------------------------------------------------------

fprintf("Rows after filtering to 919/920/921: %d\n", height(T));
fprintf("Duration-capped rows: %d, %.2f%%\n", ...
    sum(T.duration_capped_flag), 100 * mean(T.duration_capped_flag));

disp("Experiment ID counts:");
disp(groupsummary(T, "exp_id_key", "numel", "stu_id_key"));

% Inspect one student:
% T_student.learning_trace_all3{1}
% T_student.learning_trace_scored{1}
% T_student.time_by_experiment{1}


%% ============================================================
%  Local helper functions
% ============================================================

function key = toIDKey(x)
    % Convert numeric/string/cell/categorical IDs into stable string keys.
    % Numeric IDs stored as double are converted without decimal places.

    if isnumeric(x)
        key = string(compose('%.0f', x));
    elseif iscell(x)
        key = string(x);
    elseif isstring(x)
        key = x;
    elseif iscategorical(x)
        key = string(x);
    else
        key = string(x);
    end

    key = strtrim(key);
    key(key == "" | lower(key) == "nan" | lower(key) == "<missing>") = missing;
end


function dt = toDatetimeColumn(x)
    % Convert a column to datetime.
    % Expected format: yyyy-MM-dd HH:mm:ss

    if isdatetime(x)
        dt = x;
        dt.Format = 'yyyy-MM-dd HH:mm:ss';
        return;
    end

    s = string(x);
    s = strtrim(s);

    try
        dt = datetime(s, ...
            'InputFormat', 'yyyy-MM-dd HH:mm:ss', ...
            'Format', 'yyyy-MM-dd HH:mm:ss');
    catch
        dt = datetime(s, 'Format', 'yyyy-MM-dd HH:mm:ss');
    end
end


function y = firstString(x)
    % Return first non-missing string value from a column.

    s = string(x);
    idx = find(~ismissing(s) & strlength(strtrim(s)) > 0, 1, 'first');

    if isempty(idx)
        y = missing;
    else
        y = s(idx);
    end
end


function Ti = addTraceVariables(Ti, scoreVarName)
    % Add ordered attempt number, interval, and score delta to a trace table.

    if height(Ti) == 0
        Ti.attempt_no = zeros(0,1);
        Ti.interval_from_prev_attempt_min = zeros(0,1);
        Ti.score_delta = zeros(0,1);
        return;
    end

    Ti = sortrows(Ti, {'start_time','end_time'});
    Ti.attempt_no = (1:height(Ti)).';

    interval_from_prev_attempt_min = nan(height(Ti),1);

    if height(Ti) >= 2
        interval_from_prev_attempt_min(2:end) = ...
            minutes(Ti.start_time(2:end) - Ti.end_time(1:end-1));
    end

    Ti.interval_from_prev_attempt_min = interval_from_prev_attempt_min;

    scoreVals = Ti.(scoreVarName);

    if isnumeric(scoreVals)
        Ti.score_delta = [nan; diff(scoreVals)];
    else
        Ti.score_delta = nan(height(Ti),1);
    end
end


function T_exp = buildTimeByExperiment(Ti)
    % Build per-experiment attempt/time/score summary for one student.

    expKeys = unique(Ti.exp_id_key, 'stable');
    nExp = numel(expKeys);

    T_exp = table('Size', [nExp 12], ...
        'VariableTypes', {'string','string','double','double','double','double', ...
                          'double','double','double','double','double','double'}, ...
        'VariableNames', {'exp_id_key','exp_name','attempt_count', ...
                          'total_time_min','mean_time_min','median_time_min', ...
                          'raw_total_time_min','capped_count', ...
                          'first_score_raw','last_score_raw','best_score_raw', ...
                          'best_score_adjusted'});

    for j = 1:nExp
        Tij = Ti(Ti.exp_id_key == expKeys(j), :);
        Tij = sortrows(Tij, {'start_time','end_time'});

        T_exp.exp_id_key(j)        = expKeys(j);
        T_exp.exp_name(j)          = firstString(Tij.exp_name);
        T_exp.attempt_count(j)     = height(Tij);

        T_exp.total_time_min(j)    = sum(Tij.duration_min, 'omitnan');
        T_exp.mean_time_min(j)     = mean(Tij.duration_min, 'omitnan');
        T_exp.median_time_min(j)   = median(Tij.duration_min, 'omitnan');

        T_exp.raw_total_time_min(j) = sum(Tij.duration_min_raw, 'omitnan');
        T_exp.capped_count(j)       = sum(Tij.duration_capped_flag);

        T_exp.first_score_raw(j)   = Tij.score(1);
        T_exp.last_score_raw(j)    = Tij.score(end);
        T_exp.best_score_raw(j)    = max(Tij.score, [], 'omitnan');

        if any(~isnan(Tij.score_adjusted))
            T_exp.best_score_adjusted(j) = max(Tij.score_adjusted, [], 'omitnan');
        else
            T_exp.best_score_adjusted(j) = NaN;
        end
    end
end
%% 2026, 06, 18
%% Read and clean DMTO student learning dataset
% File: dmto学生学习数据.xlsx
%
% This script:
% 1. Reads the Excel sheet into a MATLAB table.
% 2. Renames Chinese column headers into professional English variable names.
% 3. Converts selected variables to categorical type.
% 4. Converts all remaining variables to double type.
% 5. Keeps the original Chinese names as variable descriptions.

clear; clc;

%% ------------------------------------------------------------------------
% 1. Read Excel file
% -------------------------------------------------------------------------

fileName = "dmto学生学习数据0619.xlsx";

% If the file has multiple sheets, change sheetName to the correct sheet.
% For example: sheetName = "Sheet1";
sheetName = 1;

% Preserve the original Chinese column names when reading the table.
opts = detectImportOptions(fileName, ...
    "Sheet", sheetName, ...
    "VariableNamingRule", "preserve");

T_raw = readtable(fileName, opts);

fprintf("Raw table loaded: %d rows, %d columns.\n", height(T_raw), width(T_raw));


%% ------------------------------------------------------------------------
% 2. Define Chinese names and English variable names
% -------------------------------------------------------------------------

chNames = [ ...
    "学号"
    "姓名"
    "性别"
    "班级"
    "学生标记"
    "课前预测"
    "标准考试"
    "过程理解"
    "变量选择"
    "建模流程"
    "模型评价"
    "方案建议"
    "报告成绩"
    "总试验次数"
    "工艺熟悉次数"
    "总实验时间"
    "有效建模时间"
    "总实验间隔"
    "初次练习分数"
    "最终练习分数"
    "最高练习分数"
    "练习提升分数"
    "练习提升比率"
    "有效练习次数"
    "工程考试"
    "考试提升"
    "考试提升比率"
    "教学设计"
    "报告模型"
    "报告R2"
    "报告计算时间"
    "报告误差"
    "模型改进轮次"
    "是否选择最高"
    "平均练习时间"
    "连续改进次数"
    "改进比例" ];

engNames = [ ...
    "student_id"
    "student_name"
    "gender"
    "class_id"
    "student_tag"
    "pretest_score"
    "standard_exam_score"
    "process_understanding"
    "variable_selection"
    "modelling_workflow"
    "model_evaluation"
    "engineering_recommendation"
    "report_score"
    "total_experiment_attempts"
    "process_familiarisation_attempts"
    "total_experiment_time"
    "effective_modelling_time"
    "total_inter_attempt_interval"
    "first_practice_score"
    "final_practice_score"
    "best_practice_score"
    "practice_score_gain"
    "practice_gain_ratio"
    "valid_modelling_attempts"
    "engineering_test_score"
    "test_score_gain"
    "test_gain_ratio"
    "instructional_design_condition"
    "reported_model"
    "reported_R2"
    "reported_computation_time"
    "reported_prediction_error"
    "model_revision_rounds"
    "selected_highest_R2_model"
    "mean_practice_time"
    "consecutive_improvement_count"
    "improving_transition_ratio" ];


%% ------------------------------------------------------------------------
% 3. Check whether all required Chinese columns exist
% -------------------------------------------------------------------------

rawVarNames = string(T_raw.Properties.VariableNames);

[foundFlag, loc] = ismember(chNames, rawVarNames);

if any(~foundFlag)
    missingColumns = chNames(~foundFlag);
    error("The following required columns are missing from the Excel file:\n%s", ...
        strjoin(missingColumns, newline));
end

% Reorder table according to the predefined column order.
T = T_raw(:, cellstr(chNames));

% Rename variables into English names.
T.Properties.VariableNames = cellstr(engNames);

% Store original Chinese names as variable descriptions.
T.Properties.VariableDescriptions = cellstr(chNames);


%% ------------------------------------------------------------------------
% 4. Convert selected variables to categorical type
% -------------------------------------------------------------------------

categoricalVars = [ ...
    "student_id"
    "student_name"
    "gender"
    "class_id"
    "student_tag"
    "instructional_design_condition"
    "reported_model"
    "selected_highest_R2_model" ];

for i = 1:numel(categoricalVars)
    v = categoricalVars(i);

    if v == "student_id"
        % Student ID should be converted carefully to avoid scientific notation
        % or decimal formatting when it was imported as double.
        T.(v) = categorical(toIDString(T.(v)));
    else
        % Other categorical variables are converted through string first.
        T.(v) = categorical(string(T.(v)));
    end
end
%% Recode student_tag into professional English categories

tag = string(T.student_tag);

% Replace undefined or empty tags
tag(isundefined(T.student_tag) | tag == "<undefined>" | tag == "") = "General";

% Replace Chinese tags
tag(tag == "民族生") = "Ethnic minority student";

tag(tag == "民族生，双少生" | tag == "民族生,双少生") = ...
    "ethnic minorities for both parents";

% Convert back to categorical
T.student_tag = categorical(tag);

%% ------------------------------------------------------------------------
% 5. Convert all remaining variables to double
% -------------------------------------------------------------------------

allVars = string(T.Properties.VariableNames);
numericVars = setdiff(allVars, categoricalVars, "stable");

for i = 1:numel(numericVars)
    v = numericVars(i);
    T.(v) = toDoubleColumn(T.(v));
end


%% ------------------------------------------------------------------------
% 6. Basic checking
% -------------------------------------------------------------------------

fprintf("Cleaned table created: %d rows, %d columns.\n", height(T), width(T));

disp("Variable classes after cleaning:");
varClass = strings(width(T),1);

for j = 1:width(T)
    varClass(j) = string(class(T.(j)));
end

disp(table(string(T.Properties.VariableNames(:)), varClass, ...
    'VariableNames', {'VariableName','Class'}));

disp("Summary of cleaned table:");
summary(T);
%% ------------------------------------------------------------------------
% 7. Optional: save cleaned data
% -------------------------------------------------------------------------

save("dmto_student_learning_data_cleaned_0621.mat", "T");

writetable(T, "dmto_student_learning_data_cleaned_0621.xlsx");

fprintf("Cleaned data saved as:\n");
fprintf("  dmto_student_learning_data_cleaned.mat\n");
fprintf("  dmto_student_learning_data_cleaned.xlsx\n");
%% ========================================================================
% Local helper functions
% ========================================================================

function idStr = toIDString(x)
    % Convert student IDs into stable strings.
    % This avoids displaying numeric IDs as scientific notation.
    %
    % If IDs were imported as double, they are formatted with no decimals.
    % If IDs were imported as string/cell/categorical, they are converted directly.

    if isnumeric(x)
        idStr = string(compose('%.0f', x));
    elseif iscell(x)
        idStr = string(x);
    elseif isstring(x)
        idStr = x;
    elseif iscategorical(x)
        idStr = string(x);
    else
        idStr = string(x);
    end

    idStr = strtrim(idStr);
    idStr(idStr == "" | lower(idStr) == "nan" | lower(idStr) == "<missing>") = missing;
end


function y = toDoubleColumn(x)
    % Convert a table column into double.
    %
    % This function handles numeric, string, cell, and categorical columns.
    % It also removes common non-numeric symbols such as commas and percent signs.
    %
    % Note:
    % If a value is stored as "85%", this function converts it to 85, not 0.85.
    % Check ratio variables after import if your Excel file stores percentages as text.

    if isnumeric(x)
        y = double(x);
        return;
    end

    if iscell(x)
        s = string(x);
    elseif isstring(x)
        s = x;
    elseif iscategorical(x)
        s = string(x);
    else
        s = string(x);
    end

    s = strtrim(s);

    % Treat common missing-value strings as missing.
    missingFlag = s == "" | lower(s) == "nan" | lower(s) == "na" | ...
                  lower(s) == "n/a" | s == "-" | s == "—" | ...
                  lower(s) == "<missing>";

    % Remove commas and percent signs before conversion.
    s = erase(s, ",");
    s = erase(s, "%");

    y = str2double(s);
    y(missingFlag) = NaN;
end

%% Class-wise statistics and raincloud-like plots for DMTO learning data
%
% Input:
%   T: cleaned MATLAB table
%
% Requirement:
%   T should contain:
%       - class_id
%       - numeric/double variables
%
% Output:
%   1. StatsByClass_DMTO.xlsx
%   2. Figures_Boxplot/*.png
%   3. Figures_Raincloud/*.png

clearvars -except T; clc;

%% ------------------------------------------------------------------------
% 1. Recode class labels: 1班, 2班, 3班, 4班 -> C1, C2, C3, C4
% -------------------------------------------------------------------------

classStr = string(T.class_id);
classStr = strtrim(classStr);

classGroup = strings(height(T),1);

classGroup(contains(classStr, "1班") | classStr == "1" | upper(classStr) == "C1") = "C1";
classGroup(contains(classStr, "2班") | classStr == "2" | upper(classStr) == "C2") = "C2";
classGroup(contains(classStr, "3班") | classStr == "3" | upper(classStr) == "C3") = "C3";
classGroup(contains(classStr, "4班") | classStr == "4" | upper(classStr) == "C4") = "C4";

% Check unrecognized class labels
unknownClass = classGroup == "";

if any(unknownClass)
    warning("Some class labels were not recognized. Please check:");
    disp(unique(classStr(unknownClass)));
end

T.class_group = categorical(classGroup, ["C1","C2","C3","C4"]);

disp("Class counts:");
disp(groupcounts(T.class_group));


%% ------------------------------------------------------------------------
% 2. Detect double variables automatically
% -------------------------------------------------------------------------

varNames = string(T.Properties.VariableNames);

isDoubleVar = false(size(varNames));

for i = 1:numel(varNames)
    isDoubleVar(i) = isa(T.(varNames(i)), "double");
end

doubleVars = varNames(isDoubleVar);

% Remove class_group if somehow detected as numeric, although it should not be.
doubleVars = setdiff(doubleVars, "class_group", "stable");

fprintf("Detected %d double variables.\n", numel(doubleVars));
disp(doubleVars(:));


%% ------------------------------------------------------------------------
% 3. Compute class-wise statistics for all double variables
% -------------------------------------------------------------------------

classes = categorical(["C1","C2","C3","C4"], ["C1","C2","C3","C4"]);

resultCell = {};
rowID = 0;

for iVar = 1:numel(doubleVars)

    v = doubleVars(iVar);

    for iClass = 1:numel(classes)

        c = classes(iClass);

        idx = T.class_group == c;
        xAll = T.(v)(idx);
        x = xAll(~isnan(xAll));

        rowID = rowID + 1;

        resultCell{rowID,1} = char(v);
        resultCell{rowID,2} = char(string(c));
        resultCell{rowID,3} = numel(xAll);          % total records in this class
        resultCell{rowID,4} = sum(isnan(xAll));     % missing records
        resultCell{rowID,5} = numel(x);             % valid records

        if isempty(x)
            resultCell{rowID,6}  = NaN;             % mean
            resultCell{rowID,7}  = NaN;             % median
            resultCell{rowID,8}  = NaN;             % min
            resultCell{rowID,9}  = NaN;             % max
            resultCell{rowID,10} = NaN;             % std
        else
            resultCell{rowID,6}  = mean(x, "omitnan");
            resultCell{rowID,7}  = median(x, "omitnan");
            resultCell{rowID,8}  = min(x, [], "omitnan");
            resultCell{rowID,9}  = max(x, [], "omitnan");
            resultCell{rowID,10} = std(x, "omitnan");
        end
    end
end

StatsByClass = cell2table(resultCell, ...
    "VariableNames", {'Variable', 'Class', 'N_total', 'N_missing', 'N_valid', ...
                      'Mean', 'Median', 'Min', 'Max', 'Std'});

disp(StatsByClass);

writetable(StatsByClass, "StatsByClass_DMTO.xlsx");

fprintf("Class-wise statistics saved to StatsByClass_DMTO.xlsx\n");


%% ------------------------------------------------------------------------
% 4. Create output folders for figures
% -------------------------------------------------------------------------

boxplotDir = "Figures_Boxplot";
raincloudDir = "Figures_Raincloud";

if ~exist(boxplotDir, "dir")
    mkdir(boxplotDir);
end

if ~exist(raincloudDir, "dir")
    mkdir(raincloudDir);
end


%% ------------------------------------------------------------------------
% 5. Generate boxplots for all double variables
% -------------------------------------------------------------------------

for iVar = 1:numel(doubleVars)

    v = doubleVars(iVar);

    figure("Color", "w", "Position", [100 100 700 480]);

    boxchart(T.class_group, T.(v));
    xlabel("Class");
    ylabel(strrep(v, "_", " "));
    title("Boxplot of " + strrep(v, "_", " ") + " by Class", ...
        "Interpreter", "none");

    grid on;

    fileOut = fullfile(boxplotDir, makeSafeFileName("Boxplot_" + v + ".png"));
    exportgraphics(gcf, fileOut, "Resolution", 300);

    close(gcf);
end

fprintf("Boxplots saved to %s\n", boxplotDir);


%% ------------------------------------------------------------------------
% 6. Generate raincloud-like plots for all double variables
% -------------------------------------------------------------------------
% A raincloud plot usually combines:
%   - kernel density plot
%   - boxplot
%   - individual data points
%
% MATLAB does not provide a native raincloud plot.
% The function below creates a simple raincloud-like version.

for iVar = 1:numel(doubleVars)

    v = doubleVars(iVar);

    figure("Color", "w", "Position", [100 100 760 520]);
    hold on;

    plotRaincloudByClass(T, v, "class_group");

    xlabel("Class");
    ylabel(strrep(v, "_", " "));
    title("Raincloud-like Plot of " + strrep(v, "_", " ") + " by Class", ...
        "Interpreter", "none");

    grid on;
    box on;

    fileOut = fullfile(raincloudDir, makeSafeFileName("Raincloud_" + v + ".png"));
    exportgraphics(gcf, fileOut, "Resolution", 300);

    close(gcf);
end

fprintf("Raincloud-like plots saved to %s\n", raincloudDir);


%% ------------------------------------------------------------------------
% 7. Optional: save the updated table with class_group
% -------------------------------------------------------------------------

save("DMTO_table_with_class_group.mat", "T", "StatsByClass");

fprintf("Updated table and statistics saved to DMTO_table_with_class_group.mat\n");


%% ========================================================================
% Local helper functions
% ========================================================================

function plotRaincloudByClass(T, varName, classVar)
    % Create a simple raincloud-like plot for one variable grouped by class.
    %
    % Components:
    %   1. Half-density plot on the left side of each class position
    %   2. Boxchart at each class position
    %   3. Jittered individual data points

    classCats = categories(T.(classVar));
    nClass = numel(classCats);

    maxDensityWidth = 0.35;

    for k = 1:nClass

        c = classCats{k};

        idx = T.(classVar) == c;
        xData = T.(varName)(idx);
        xData = xData(~isnan(xData));

        if isempty(xData)
            continue;
        end

        xCenter = k;

        %% Kernel density
        if numel(unique(xData)) >= 3 && numel(xData) >= 5
            try
                [f, yGrid] = ksdensity(xData);

                % Normalize density width
                f = f ./ max(f) .* maxDensityWidth;

                % Draw half-density cloud to the left
                patch(xCenter - f, yGrid, [0.6 0.6 0.6], ...
                    "FaceAlpha", 0.25, ...
                    "EdgeColor", "none");
            catch
                % If ksdensity fails, skip density for this class.
            end
        end

        %% Jittered raw data points
        jitter = (rand(size(xData)) - 0.5) * 0.16;
        scatter(xCenter + 0.12 + jitter, xData, 18, ...
            "filled", ...
            "MarkerFaceAlpha", 0.45, ...
            "MarkerEdgeAlpha", 0.45);

        %% Boxplot component
        boxchart(repmat(xCenter + 0.28, size(xData)), xData, ...
            "BoxWidth", 0.18, ...
            "MarkerStyle", "none");
    end

    xlim([0.4, nClass + 0.8]);
    xticks(1:nClass);
    xticklabels(classCats);
end


function safeName = makeSafeFileName(fileName)
    % Make a safe file name by replacing problematic characters.

    safeName = string(fileName);
    safeName = replace(safeName, " ", "_");
    safeName = replace(safeName, "/", "_");
    safeName = replace(safeName, "\", "_");
    safeName = replace(safeName, ":", "_");
    safeName = replace(safeName, "*", "_");
    safeName = replace(safeName, "?", "_");
    safeName = replace(safeName, """", "_");
    safeName = replace(safeName, "<", "_");
    safeName = replace(safeName, ">", "_");
    safeName = replace(safeName, "|", "_");

    safeName = char(safeName);
end
%%
%% Radar plots for five rubric dimensions across four classes
%
% Required table:
%   T
%
% Required variables in T:
%   class_id or class_group
%   process_understanding
%   variable_selection
%   modelling_workflow
%   model_evaluation
%   engineering_recommendation
%
% Output:
%   Radar_Rubric_Classes_Overlay.png
%   Radar_Rubric_Classes_Subplots.png

clearvars -except T; clc;


%% ------------------------------------------------------------------------
% 1. Recode class labels into C1, C2, C3, C4 if class_group does not exist
% -------------------------------------------------------------------------

if ~ismember("class_group", string(T.Properties.VariableNames))

    classStr = string(T.class_id);
    classStr = strtrim(classStr);

    classGroup = strings(height(T),1);

    classGroup(contains(classStr, "1班") | classStr == "1" | upper(classStr) == "C1") = "C1";
    classGroup(contains(classStr, "2班") | classStr == "2" | upper(classStr) == "C2") = "C2";
    classGroup(contains(classStr, "3班") | classStr == "3" | upper(classStr) == "C3") = "C3";
    classGroup(contains(classStr, "4班") | classStr == "4" | upper(classStr) == "C4") = "C4";

    if any(classGroup == "")
        warning("Some class labels were not recognised. Please check:");
        disp(unique(classStr(classGroup == "")));
    end

    T.class_group = categorical(classGroup, ["C1","C2","C3","C4"]);
end

disp("Class counts:");
disp(groupcounts(T.class_group));


%% ------------------------------------------------------------------------
% 2. Define rubric variables and labels
% -------------------------------------------------------------------------

rubricVars = [ ...
    "process_understanding"
    "variable_selection"
    "modelling_workflow"
    "model_evaluation"
    "engineering_recommendation" ];

% Short labels are better for radar figures.
rubricLabels = [ ...
    "Process"
    "Variables"
    "Workflow"
    "Evaluation"
    "Recommendation" ];

classLabels = ["C1","C2","C3","C4"];

rMax = 20;   % each rubric dimension is scored out of 20


%% ------------------------------------------------------------------------
% 3. Calculate class-wise mean values
% -------------------------------------------------------------------------

M = nan(numel(classLabels), numel(rubricVars));

for i = 1:numel(classLabels)

    idx = T.class_group == classLabels(i);

    for j = 1:numel(rubricVars)
        M(i,j) = mean(T.(rubricVars(j))(idx), "omitnan");
    end
end

RadarMeanTable = array2table(M, ...
    "VariableNames", cellstr(rubricVars), ...
    "RowNames", cellstr(classLabels));

disp("Class-wise mean rubric scores:");
disp(RadarMeanTable);

writetable(RadarMeanTable, "Radar_Rubric_Class_Means.xlsx", ...
    "WriteRowNames", true);


%% ------------------------------------------------------------------------
% 4. Combined radar plot: C1-C4 in one figure
% -------------------------------------------------------------------------

figure("Color", "w", "Position", [100 100 820 720]);

ax = axes;
drawRadar(ax, M, rubricLabels, classLabels, ...
    "Rubric Profiles by Class", rMax);

exportgraphics(gcf, "Radar_Rubric_Classes_Overlay.png", "Resolution", 300);


%% ------------------------------------------------------------------------
% 5. Four sub-radar plots: one class per subplot
% -------------------------------------------------------------------------

figure("Color", "w", "Position", [100 100 1000 820]);

tiledlayout(2,2, "Padding", "compact", "TileSpacing", "compact");

for i = 1:numel(classLabels)

    ax = nexttile;

    drawRadar(ax, M(i,:), rubricLabels, classLabels(i), ...
        "Class " + classLabels(i), rMax);
end

sgtitle("Rubric Profiles of Four Classes", ...
    "FontWeight", "bold", "FontSize", 16);

exportgraphics(gcf, "Radar_Rubric_Classes_Subplots.png", "Resolution", 300);


%% ------------------------------------------------------------------------
% 6. Optional: median radar plot
% -------------------------------------------------------------------------
% Mean is sensitive to outliers. Median can be useful as a robustness check.
% Uncomment this block if needed.

% M_median = nan(numel(classLabels), numel(rubricVars));
%
% for i = 1:numel(classLabels)
%     idx = T.class_group == classLabels(i);
%
%     for j = 1:numel(rubricVars)
%         M_median(i,j) = median(T.(rubricVars(j))(idx), "omitnan");
%     end
% end
%
% figure("Color", "w", "Position", [100 100 820 720]);
% ax = axes;
% drawRadar(ax, M_median, rubricLabels, classLabels, ...
%     "Median Rubric Profiles by Class", rMax);
%
% exportgraphics(gcf, "Radar_Rubric_Classes_Overlay_Median.png", "Resolution", 300);


%% ========================================================================
% Local helper function: drawRadar
% ========================================================================

function drawRadar(ax, values, axisLabels, groupLabels, plotTitle, rMax)
    % Draw radar chart using normal Cartesian axes.
    %
    % values:
    %   nGroup x nDimension matrix
    %
    % axisLabels:
    %   names of radar axes
    %
    % groupLabels:
    %   names of groups, e.g. C1-C4
    %
    % rMax:
    %   maximum radial value, e.g. 20

    axes(ax);
    cla(ax);
    hold(ax, "on");

    values = double(values);

    if isrow(values)
        values = reshape(values, 1, []);
    end

    [nGroup, nDim] = size(values);

    % Angles: start from top, move clockwise
    theta = pi/2 - (0:nDim-1) * 2*pi/nDim;
    thetaClosed = [theta, theta(1)];

    % Normalize values to [0,1]
    valuesNorm = values ./ rMax;

    % Limit values to [0,1] for plotting
    valuesNorm(valuesNorm < 0) = 0;
    valuesNorm(valuesNorm > 1) = 1;

    %% Draw polygon grid
    gridTicks = 0:5:rMax;

    for g = gridTicks
        r = g / rMax;
        [xGrid, yGrid] = pol2cart(thetaClosed, r * ones(1, nDim+1));

        if g == rMax
            plot(ax, xGrid, yGrid, "k-", "LineWidth", 1.0);
        else
            plot(ax, xGrid, yGrid, "--", ...
                "Color", [0.75 0.75 0.75], ...
                "LineWidth", 0.8);
        end

        % radial tick label
        if g > 0
            text(ax, 0.03, r, string(g), ...
                "FontSize", 9, ...
                "Color", [0.35 0.35 0.35]);
        end
    end

    %% Draw radial axes
    for d = 1:nDim
        [xAxis, yAxis] = pol2cart([theta(d), theta(d)], [0, 1]);
        plot(ax, xAxis, yAxis, "-", ...
            "Color", [0.70 0.70 0.70], ...
            "LineWidth", 0.8);
    end

    %% Axis labels
    labelRadius = 1.18;

    for d = 1:nDim
        [xLabel, yLabel] = pol2cart(theta(d), labelRadius);

        text(ax, xLabel, yLabel, axisLabels(d), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", ...
            "FontSize", 11, ...
            "FontWeight", "bold");
    end

    %% Plot data polygons
    colors = lines(nGroup);

    h = gobjects(nGroup,1);

    for i = 1:nGroup

        r = valuesNorm(i,:);
        rClosed = [r, r(1)];

        [x, y] = pol2cart(thetaClosed, rClosed);

        % Filled polygon
        patch(ax, x, y, colors(i,:), ...
            "FaceAlpha", 0.13, ...
            "EdgeColor", "none");

        % Boundary line
        h(i) = plot(ax, x, y, "-o", ...
            "Color", colors(i,:), ...
            "LineWidth", 2.0, ...
            "MarkerSize", 5, ...
            "MarkerFaceColor", colors(i,:));
    end

    %% Figure settings
    axis(ax, "equal");
    axis(ax, [-1.35 1.35 -1.25 1.30]);
    axis(ax, "off");

    title(ax, plotTitle, ...
        "FontSize", 14, ...
        "FontWeight", "bold");

    if nGroup > 1
        legend(ax, h, groupLabels, ...
            "Location", "eastoutside", ...
            "Box", "off");
    end
end

%% Raincloud plots for pretest, standard exam, and engineering test scores
%
% Required table:
%   T
%
% Required variables:
%   pretest_score
%   standard_exam_score
%   engineering_test_score
%
% Purpose:
%   Show score distributions under:
%   1. unprepared / pre-class condition
%   2. sufficiently prepared standard examination
%   3. engineering-decision-required test
%
% Output:
%   Score_Raincloud_TwoPanel.png
%   Score_Raincloud_TwoPanel.pdf
%   Optional: Score_Raincloud_ThreeScores_OneAxis.png

clearvars -except T; clc;


%% ------------------------------------------------------------------------
% 1. Extract score data
% -------------------------------------------------------------------------

pretest = T.pretest_score;
standardExam = T.standard_exam_score;
engineeringTest = T.engineering_test_score;

% Remove missing values
pretest = pretest(~isnan(pretest));
standardExam = standardExam(~isnan(standardExam));
engineeringTest = engineeringTest(~isnan(engineeringTest));


%% ------------------------------------------------------------------------
% 2. Define a restrained Nature-style colour palette
% -------------------------------------------------------------------------
% The palette uses muted, publication-friendly colours.
% Avoid overly saturated or decorative colours.

color_pretest     = [0.42, 0.53, 0.70];   % muted blue-grey
color_standard    = [0.20, 0.55, 0.52];   % muted teal
color_engineering = [0.76, 0.32, 0.25];   % muted vermillion

colors_two = [color_standard; color_engineering];


%% ------------------------------------------------------------------------
% 3. Main figure: pretest separately, standard and engineering test together
% -------------------------------------------------------------------------

% Important:
% Use clf or create a new figure before tiledlayout.
% This avoids the "layout does not have sufficient space" error when rerunning code.

figure("Color", "w", "Position", [100 100 1000 460]);
clf;

tl = tiledlayout(1,2, ...
    "Padding", "compact", ...
    "TileSpacing", "compact");


%% Panel A: Pretest score distribution
ax1 = nexttile(tl, 1);
hold(ax1, "on");

plotRaincloud(ax1, ...
    {pretest}, ...
    ["Pre-class test"], ...
    color_pretest, ...
    [0 20], ...
    "A. Pre-class test", ...
    [0 20]);

ylabel(ax1, "Score");
ylim(ax1, [0 20]);                       % changed here
yticks(ax1, 0:5:20);                     % changed here
setNatureStyle(ax1);

%% Panel B: Standard exam vs engineering decision test
ax2 = nexttile(tl, 2);
hold(ax2, "on");

% Smoothed empirical probability with a short soft tail beyond 100.
% The tail is only for visual smoothing of the raincloud shape.
% It does not imply that scores can exceed 100.

scoreBinEdges = 0:5:100;
interpMethod = "pchip";

upperTailEnd = 103;      % density visually decays to zero around 110
tailRatio = 0.015;        % probability just above 100 relative to density at 100
tailMidPoint = 101.5;      % controls how quickly the density decreases after 100

plotRaincloudBinnedSoftTail(ax2, ...
    {standardExam, engineeringTest}, ...
    ["Standard exam", "Engineering test"], ...
    colors_two, ...
    [50 110], ...
    "B. Standard exam and engineering decision test", ...
    scoreBinEdges, ...
    interpMethod, ...
    upperTailEnd, ...
    tailMidPoint, ...
    tailRatio);

ylabel(ax2, "Score");
ylim(ax2, [50 105]);
yticks(ax2, 50:5:105);
setNatureStyle(ax2);

%% Add ceiling-ratio annotation to Panel B
ceilTol = 1e-9;

std_ceiling_ratio = mean(standardExam(~isnan(standardExam)) >= 100 - ceilTol);
eng_ceiling_ratio = mean(engineeringTest(~isnan(engineeringTest)) >= 100 - ceilTol);

ceilingText = sprintf("Ceiling at 100\nStandard exam: %.1f%%\nEngineering test: %.1f%%", ...
    100 * std_ceiling_ratio, ...
    100 * eng_ceiling_ratio);

text(ax2, 1.30, 63, ceilingText, ...
    "HorizontalAlignment", "right", ...
    "VerticalAlignment", "top", ...
    "FontSize", 9.5, ...
    "FontName", "Arial", ...
    "Color", [0.15 0.15 0.15], ...
    "BackgroundColor", "w", ...
    "EdgeColor", [0.75 0.75 0.75], ...
    "Margin", 5);

%% Overall title
sgtitle(tl, "Score distributions across assessment stages", ...
    "FontSize", 16, ...
    "FontWeight", "bold");


%% Export
exportgraphics(gcf, "Score_Raincloud_TwoPanel_low.png", "Resolution", 600);
exportgraphics(gcf, "Score_Raincloud_TwoPanel_low.pdf", "ContentType", "vector");

%% ========================================================================
% Local helper function: plotRaincloud
% ========================================================================

function plotRaincloud(ax, dataCell, labels, colors, yLimits, titleText, densitySupport)
    % Draw vertical raincloud-like plots.
    %
    % Components:
    %   - left half-density cloud
    %   - jittered raw data points
    %   - compact boxplot
    %
    % Inputs:
    %   ax       : axes handle
    %   dataCell : cell array, each cell contains one numeric vector
    %   labels   : string array of group labels
    %   colors   : nGroup x 3 RGB colour matrix
    %   yLimits  : [] or [ymin ymax]
    %   titleText: plot title

    % densitySupport:
    %   []        -> ordinary KDE
    %   [0 100]   -> bounded KDE for score variables

    if nargin < 7
        densitySupport = [];
    end

    axes(ax);
    hold(ax, "on");

    nGroup = numel(dataCell);
    densityWidth = 0.32;

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

                % Normalize density width for visual display only
                f = f ./ max(f) .* densityWidth;

                % Draw half violin on the left side
                patch(ax, ...
                    xCenter - f, yGrid, colors(i,:), ...
                    "FaceAlpha", 0.28, ...
                    "EdgeColor", "none");
            catch
                % If ksdensity fails, skip density.
            end
        end

        %% Jittered raw points
        rng(10 + i);  % reproducible jitter
        jitter = (rand(size(y)) - 0.5) * 0.14;

        scatter(ax, ...
            xCenter + 0.08 + jitter, y, ...
            20, ...
            "MarkerFaceColor", colors(i,:), ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceAlpha", 0.45);

        %% Boxchart component
        boxchart(ax, ...
            repmat(xCenter + 0.25, size(y)), y, ...
            "BoxWidth", 0.16, ...
            "MarkerStyle", "none", ...
            "BoxFaceColor", colors(i,:), ...
            "BoxFaceAlpha", 0.35, ...
            "LineWidth", 1.0);

        %% Mean marker
        mu = mean(y, "omitnan");
        plot(ax, xCenter + 0.25, mu, ...
            "d", ...
            "MarkerSize", 6, ...
            "MarkerFaceColor", "w", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 1.0);
    end

    xlim(ax, [0.45, nGroup + 0.65]);
    xticks(ax, 1:nGroup);
    xticklabels(ax, labels);

    if ~isempty(yLimits)
        ylim(ax, yLimits);
    end

    title(ax, titleText, ...
        "FontSize", 13, ...
        "FontWeight", "bold");
end


%% ========================================================================
% Local helper function: setNatureStyle
% ========================================================================

function setNatureStyle(ax)
    % Apply a restrained publication-style format.

    ax.FontName = "Arial";
    ax.FontSize = 11;
    ax.LineWidth = 1.0;
    ax.TickDir = "out";
    ax.Box = "off";

    grid(ax, "on");
    ax.GridAlpha = 0.15;
    ax.XGrid = "off";
    ax.YGrid = "on";

    ax.Color = "w";
end

function plotRaincloudBinnedSoftTail(ax, dataCell, labels, colors, yLimits, titleText, binEdges, interpMethod, upperTailEnd, tailMidPoint, tailRatio)
    % Smooth empirical raincloud plot with a short soft tail beyond the
    % maximum score.
    %
    % Purpose:
    %   This function is designed for bounded score variables with ceiling
    %   effects. It preserves the empirical probability near 100, but avoids
    %   an artificial truncated shape by adding a short visual smoothing tail
    %   beyond 100.
    %
    % Important:
    %   The tail beyond 100 is only for visualization. It should not be
    %   interpreted as real probability of scores above 100.
    %
    % Inputs:
    %   ax            : axes handle
    %   dataCell      : cell array of score vectors
    %   labels        : group labels
    %   colors        : nGroup x 3 RGB matrix
    %   yLimits       : display y-axis limits, e.g. [40 120]
    %   titleText     : panel title
    %   binEdges      : empirical score bins, e.g. 0:5:100
    %   interpMethod  : "pchip" or "makima"
    %   upperTailEnd  : where the soft tail reaches zero, e.g. 110
    %   tailMidPoint  : intermediate point after 100, e.g. 104
    %   tailRatio     : tail density at tailMidPoint relative to density at 100

    if nargin < 8 || isempty(interpMethod)
        interpMethod = "pchip";
    end

    if nargin < 9 || isempty(upperTailEnd)
        upperTailEnd = 110;
    end

    if nargin < 10 || isempty(tailMidPoint)
        tailMidPoint = 104;
    end

    if nargin < 11 || isempty(tailRatio)
        tailRatio = 0.06;
    end

    axes(ax);
    hold(ax, "on");

    nGroup = numel(dataCell);
    densityWidth = 0.32;

    lowerEdge = binEdges(1);
    upperScore = binEdges(end);      % usually 100

    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;

    % Fine grid extends beyond 100 for visual smoothing.
    yFine = linspace(lowerEdge, upperTailEnd, 650);

    for i = 1:nGroup

        y = dataCell{i};
        y = y(:);
        y = y(~isnan(y));

        if isempty(y)
            continue;
        end

        xCenter = i;

        %% --------------------------------------------------------------
        % 1. Empirical probability in score bins
        % ---------------------------------------------------------------

        prob = histcounts(y, binEdges, "Normalization", "probability");

        %% --------------------------------------------------------------
        % 2. Mild smoothing of empirical bin probabilities
        % ---------------------------------------------------------------

        probSmooth = prob;

        if numel(probSmooth) >= 4
            probSmooth = smoothdata(probSmooth, "movmean", 3);
        end

        %% --------------------------------------------------------------
        % 3. Preserve the observed ceiling mass at score = 100
        % ---------------------------------------------------------------
        % This ensures that when many students obtain exactly 100,
        % the smoothed cloud remains high at 100.

        ceilTol = 1e-9;
        ceilingMass = mean(y >= upperScore - ceilTol);

        % Last-bin probability contains scores in the last interval, such as 95-100.
        lastBinMass = prob(end);

        % Density anchor at 100 should reflect both last-bin mass and exact ceiling mass.
        % This keeps the standard-exam cloud high at 100.
        pAtUpperScore = max([probSmooth(end), lastBinMass, ceilingMass]);

        %% --------------------------------------------------------------
        % 4. Add a short soft tail above 100
        % ---------------------------------------------------------------
        % The tail is not a real score distribution. It is a visual device
        % to avoid a flat truncation at 100.
        %
        % Anchor logic:
        %   - empirical distribution up to bin centers
        %   - high density at 100 if many students reach the ceiling
        %   - small density at tailMidPoint
        %   - zero density at upperTailEnd

        yAnchor = [lowerEdge, binCenters, upperScore, tailMidPoint, upperTailEnd];
        pAnchor = [0, probSmooth, pAtUpperScore, tailRatio * pAtUpperScore, 0];

        % Remove duplicate or non-increasing anchor positions
        [yAnchor, uniqueIdx] = unique(yAnchor, "stable");
        pAnchor = pAnchor(uniqueIdx);

        % Shape-preserving interpolation
        pFine = interp1(yAnchor, pAnchor, yFine, interpMethod);

        % Remove numerical artefacts
        pFine(pFine < 0) = 0;

        %% --------------------------------------------------------------
        % 5. Normalize visual width
        % ---------------------------------------------------------------

        if max(pFine) > 0
            widthFine = pFine ./ max(pFine) .* densityWidth;
        else
            widthFine = pFine;
        end

        %% --------------------------------------------------------------
        % 6. Draw smooth half-cloud
        % ---------------------------------------------------------------

        xLeft = xCenter - widthFine;
        xRight = xCenter * ones(size(widthFine));

        xPoly = [xLeft, fliplr(xRight)];
        yPoly = [yFine, fliplr(yFine)];

        patch(ax, xPoly, yPoly, colors(i,:), ...
            "FaceAlpha", 0.28, ...
            "EdgeColor", "none");

        %% --------------------------------------------------------------
        % 7. Raw data points
        % ---------------------------------------------------------------

        rng(20 + i);
        jitter = (rand(size(y)) - 0.5) * 0.14;

        scatter(ax, ...
            xCenter + 0.08 + jitter, y, ...
            20, ...
            "MarkerFaceColor", colors(i,:), ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceAlpha", 0.45);

        %% --------------------------------------------------------------
        % 8. Boxchart
        % ---------------------------------------------------------------

        boxchart(ax, ...
            repmat(xCenter + 0.25, size(y)), y, ...
            "BoxWidth", 0.16, ...
            "MarkerStyle", "none", ...
            "BoxFaceColor", colors(i,:), ...
            "BoxFaceAlpha", 0.35, ...
            "LineWidth", 1.0);

        %% --------------------------------------------------------------
        % 9. Mean marker
        % ---------------------------------------------------------------

        mu = mean(y, "omitnan");

        plot(ax, xCenter + 0.25, mu, ...
            "d", ...
            "MarkerSize", 6, ...
            "MarkerFaceColor", "w", ...
            "MarkerEdgeColor", [0.15 0.15 0.15], ...
            "LineWidth", 1.0);
    end

    xlim(ax, [0.45, nGroup + 0.65]);
    xticks(ax, 1:nGroup);
    xticklabels(ax, labels);

    if ~isempty(yLimits)
        ylim(ax, yLimits);
    end

    title(ax, titleText, ...
        "FontSize", 13, ...
        "FontWeight", "bold");
end