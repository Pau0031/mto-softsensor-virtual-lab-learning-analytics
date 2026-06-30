# Beyond Platform Scores: Scaffolding Engineering Judgement and Learning Analytics in a Data-Driven MTO Virtual Laboratory

This repository contains the anonymised data, MATLAB code, statistical outputs, and figure materials associated with the manuscript:

**Beyond Platform Scores: Scaffolding Engineering Judgement and Learning Analytics in a Data-Driven MTO Virtual Laboratory**

The study examines how learning gain, engineering judgement, and learning behaviours can be evaluated in a no-code virtual laboratory for developing a soft sensor for catalyst coke content in the methanol-to-olefins (MTO) process.

## Repository structure

```text
data/
  anonymised_student_level_dataset.csv
  report_rater_scores_anonymised.csv

code/
  feature_construction.m
  scaffolding_test.m
  learning_mode_clustering.m
  figure_scripts/

outputs/
  Correlation_Association_Table.xlsx
  LearningMode_ExternalValidation_Mean_4.xlsx
  LearningMode_ExternalValidation_Std_4.xlsx
  Scaffold_Model_Comparison_Summary.xlsx
  full_regression_coefficients.txt
  rater_reliability_outputs.docx

figures/
  editable_figure_sources/
  final_png_or_pdf_exports/
```

## Data files

### `data/anonymised_student_level_dataset.csv`

This file contains the anonymised student-level analytical dataset used in the manuscript. It includes assessment outcomes, report-rubric scores, learning-trace variables, model-decision variables, and instructional-condition labels.

Main variable groups include:

- baseline score: pretest score
- assessment outcomes: standard MTO exam score, engineering test score, report score
- rubric dimensions: process understanding, variable selection, modelling workflow, model evaluation, engineering recommendation
- learning traces: practice scores, practice gain, modelling time, model-revision rounds, improving transition ratio
- model-decision variables: reported model, reported R², selected highest-R² model
- instructional design condition: N, A, R, and RA

The scaffold labels are:

```text
N  = no scaffold
A  = process-oriented assessment scaffold
R  = engineering-reasoning scaffold
RA = combined scaffolds
```

### `data/report_rater_scores_anonymised.csv`

This file contains anonymised report scores assigned by three independent raters. It is used to reproduce the inter-rater reliability analysis, including ICC, Cronbach's alpha, pairwise Pearson correlations, and Kendall's W.

## Code files

### `code/feature_construction.m`

Constructs student-level learning-trace and model-decision variables from the cleaned data. This script should be run before the statistical analysis scripts if feature reconstruction is required.

### `code/scaffolding_test.m`

Reproduces the scaffold-related analyses, including:

- class-wise comparisons
- robust regression models
- scaffold models
- trace-adjusted models
- decision-behaviour models
- model-comparison summaries

### `code/learning_mode_clustering.m`

Reproduces the learning-mode analysis using k-means clustering based on five learning-trace variables:

- improving transition ratio
- mean practice time
- model-revision rounds
- first practice score
- practice gain ratio

The script generates the four learning modes reported in the manuscript:

- deliberate improvers
- high-start plateau learners
- invested optimizers
- minimal-time completers

### `code/figure_scripts/`

Contains scripts used to generate manuscript figures. Editable source files and exported figure files are stored separately in the `figures/` folder.

## Outputs

The `outputs/` folder contains key statistical results used in the manuscript and Supplementary Information.

### `Correlation_Association_Table.xlsx`

Long-format correlation and association results, including Spearman correlations, p-values, and adjusted p-values.

### `LearningMode_ExternalValidation_Mean_4.xlsx`

Mean values of clustering variables and external validation indicators for the four learning modes.

### `LearningMode_ExternalValidation_Std_4.xlsx`

Standard deviations of clustering variables and external validation indicators for the four learning modes.

### `Scaffold_Model_Comparison_Summary.xlsx`

Model-comparison results for scaffold-related regression models, including adjusted R², AIC, and BIC.

### `full_regression_coefficients.txt`

Full coefficient-level outputs for robust regression models.

### `rater_reliability_outputs.docx`

English report of inter-rater agreement analysis, including ICC(2,1), ICC(2,3), Cronbach's alpha, pairwise Pearson correlations, Kendall's W, and descriptive statistics for the three raters.

## Figures

The `figures/` folder contains figure materials.

```text
figures/editable_figure_sources/
```

contains editable figure source files.

```text
figures/final_png_or_pdf_exports/
```

contains final exported figures used in the manuscript.

## Recommended reproduction workflow

Run the scripts in the following order:

```text
1. code/feature_construction.m
2. code/scaffolding_test.m
3. code/learning_mode_clustering.m
4. code/figure_scripts/
```

Some output files are already provided in the `outputs/` folder for verification and direct comparison with the manuscript.

## Software requirements

The analyses were conducted in MATLAB. The scripts use standard MATLAB functions for data processing, regression modelling, clustering, and visualisation.

Recommended environment:

```text
MATLAB R2022b or later
Statistics and Machine Learning Toolbox
```

## Data privacy and ethical use

All student-level data in this repository have been anonymised. Student names, student IDs, raw reports, and raw platform logs are not released. The released dataset is intended only for reproducing the analyses reported in the manuscript.

The study was approved by the College of Chemistry and Chemical Engineering under approval number **CCV2601**. All data were anonymised before analysis and used only for educational research.

## Notes on interpretation

The instructional conditions were implemented across intact classes in a sequential design rather than through individual random assignment. Therefore, scaffold-related results should be interpreted as design-based associations rather than fully randomised causal effects.

The standard platform score, engineering-oriented decision test, report rubric, and learning traces represent different layers of evidence. The repository is organised to support reproduction of the manuscript's central argument: data-driven virtual laboratories should be evaluated not only by task completion or model-performance metrics, but also by evidence of engineering judgement and learning-process quality.

## Citation

Please cite the associated manuscript if using this dataset, code, or outputs:

```text
Zhang, X., & Zhang, H. Beyond Platform Scores: Scaffolding Engineering Judgement and Learning Analytics in a Data-Driven MTO Virtual Laboratory. Education for Chemical Engineers.
```

## Contact

For questions about the dataset, code, or manuscript, please contact:

```text
Hao Zhang
School of Chemistry and Chemical Engineering
Southwest University
Email: haozhang@swu.edu.cn
```
