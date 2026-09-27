# Beyond Platform Scores: What Score Equivalence Conceals in a Data-Driven Virtual Laboratory

This repository contains the anonymised analytical dataset, MATLAB source code, and supporting outputs for the revised manuscript. The study examines what a high score on a familiar embedded task does—and does not—show about students' engineering reasoning and participation in an MTO soft-sensor virtual laboratory.

The V2 analysis treats four sources as complementary evidence:

1. scores from the familiar-task embedded assessment;
2. scores from the modified-scenario task;
3. written-report rubric scores as evidence of articulated modelling reasoning; and
4. platform-recorded participation traces summarised as participation profiles.

The earlier scaffold-condition analyses are not part of this manuscript. V1 remains available in the Git history and on the `v1-legacy-scaffold` branch.

## Repository contents

    data/
      anonymised_student_level_dataset.csv
      report_rater_scores_anonymised.xlsx

    code/
      data_pretreatment_feature_construction.m
      participation_profile_clustering.m
      score_equivalence_analysis.m

    make_main_figures_nature.m

    Figures_Main_Final/
      Fig1_ScoreEquivalence.pdf / .png
      Fig2_ReasoningHeterogeneity.pdf / .png
      Fig3_ParticipationProfiles.pdf / .png
      Fig4_ProcessOutcome.pdf / .png

    outputs/
      ScoreEquivalence_Analysis.xlsx
      Tasks10_13_Evidence.xlsx
      Inter_rater_Agreement_Analysis_Report.docx
      participation_profile_assignment.csv
      participation_profile_statistics.csv

The four final main-text figures are generated together by `make_main_figures_nature.m`. It uses manuscript terminology, normalises existing participation-profile labels without reclustering students, and exports PNG and vector PDF files to `Figures_Main_Final/`. The Excel workbooks contain the frozen supplementary analyses used to check the reported values.

## Data

`data/anonymised_student_level_dataset.csv` contains 119 anonymised student-level records. It includes familiar-task embedded scores, modified-scenario scores, five report-rubric dimensions, and platform participation variables. Some source column names retain earlier internal terminology for reproducibility; in the revised manuscript, `standard_exam_score` is the familiar-task embedded score, `engineering_test_score` is the modified-scenario score, and the legacy `learning_mode` concept is described as a participation profile.

`data/report_rater_scores_anonymised.xlsx` contains anonymised ratings from three independent report raters. The associated reliability report is in `outputs/Inter_rater_Agreement_Analysis_Report.docx`.

The analytical dataset is retained without deleting legacy columns. The code uses only the fields documented in its comments. Student names and direct identifiers are not included in the released analytical dataset.

## Reproduction

MATLAB R2022b or later is recommended. The clustering and rank-based analyses require Statistics and Machine Learning Toolbox.

From the repository root, run:

    run(fullfile("code", "participation_profile_clustering.m"))
    run(fullfile("code", "score_equivalence_analysis.m"))
    T = readtable(fullfile("data", "anonymised_student_level_dataset.csv"), "TextType", "string");
    A = readtable(fullfile("outputs", "participation_profile_assignment.csv"), "TextType", "string");
    assert(height(T) == height(A) && isequal(A.StudentRow, (1:height(T))'));
    T.participation_pattern_final = A.ParticipationProfile;
    run("make_main_figures_nature.m")

`participation_profile_clustering.m` uses five platform-trace features, a fixed four-profile solution, robust scaling, and a fixed random seed. It writes row-aligned profile assignments and profile summaries under `outputs/`. `score_equivalence_analysis.m` uses the same anonymised rows, creates the familiar-score strata, and reproduces the core descriptive and rank-based comparisons. Its recomputed workbook is named `ScoreEquivalence_Reproduced.xlsx`; the supplied `ScoreEquivalence_Analysis.xlsx` and `Tasks10_13_Evidence.xlsx` are retained as the frozen analysis records.

The analyses do not use student identifiers to join files. Profile assignments are linked to the anonymised analytical table by row number, and the analysis script checks that the row counts match before proceeding. The main-figure script expects `T` to be loaded and to contain a participation-profile field; the commands above attach the released row-aligned labels. It only harmonises those labels and does not recluster. The permutation test is Monte Carlo; its recomputed p value can vary slightly with the seed. The frozen analysis workbook is the source for manuscript-reported permutation results, while the reproduced workbook records the result from the script's documented fixed seed.

## Main interpretation

The familiar-task score has a ceiling: 62 of 119 students (52.1%) received 100. Within this perfect-score group, modified-scenario scores still varied substantially (median 86; IQR 13; range 61–100). The association between familiar-task and modified-scenario scores was small and not statistically significant in the supplied analysis (Kendall's τb = 0.0703, p = 0.311).

Participation profiles provide a complementary description of trace patterns. They are not causal categories or measures of ability. Profile comparisons and rubric results should be interpreted as evidence about different dimensions of performance, not as proof that any one score fully represents engineering judgement.

## Ethics and data use

The study is associated with institutional approval reference **CCV2601**. The released student-level data are anonymised. Users must follow the institution's approval scope and applicable requirements when reusing or redistributing the data. The approval reference alone should not be interpreted as a statement about individual consent or a waiver.

## Citation

Please cite the associated manuscript when using these materials:

    Zhang, X., & Zhang, H. Beyond Platform Scores: What Score Equivalence Conceals in a Data-Driven Virtual Laboratory.

## Contact

Hao Zhang
School of Chemistry and Chemical Engineering
Southwest University

