%% Figure 4: modified-scenario outcomes within the perfect-score subgroup
repoRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
T=readtable(fullfile(repoRoot,"data","anonymised_student_level_dataset.csv"),"TextType","string");
A=readtable(fullfile(repoRoot,"outputs","participation_profile_assignment.csv"),"TextType","string");
assert(height(T)==height(A) && isequal(A.StudentRow,(1:height(T))'), ...
    "Profile assignments are not aligned with source rows.");
profileNames=["Low-start deliberate improvers";"High-start plateau learners"; ...
    "Intensive model optimizers";"Minimal-time completers"];
profile=categorical(A.ParticipationProfile,profileNames,"Ordinal",true);
fullMask=double(T.standard_exam_score)==100;
outcome=double(T.engineering_test_score(fullMask));
group=profile(fullMask);

summaryFile=fullfile(repoRoot,"outputs","Tasks10_13_Evidence.xlsx");
testSummary=readtable(summaryFile,"Sheet","T12_EngPatternTest", ...
    "TextType","string","VariableNamingRule","preserve");
permutationP=testSummary.PermutationPValue(1);
epsilon2=testSummary.EpsilonSquared(1);

fig=figure("Color","w","Position",[100 100 920 620]); ax=axes(fig);
boxchart(ax,group,outcome,"MarkerStyle",".","BoxFaceColor",[0.76 0.43 0.24]);
hold(ax,"on"); rng(926,"twister");
for k=1:numel(profileNames)
    inGroup=group==profileNames(k);
    x=k+0.18*(rand(nnz(inGroup),1)-0.5);
    scatter(ax,x,outcome(inGroup),36,[0.20 0.34 0.46],"filled", ...
        "MarkerFaceAlpha",0.65,"HandleVisibility","off");
end
ylabel(ax,"Modified-scenario score"); xlabel(ax,"Participation profile");
xtickangle(ax,20);
title(ax,sprintf("Embedded-score=100 subgroup (n=%d): permutation p=%.4f, \\epsilon^2=%.4f", ...
    nnz(fullMask),permutationP,epsilon2));
grid(ax,"on"); box(ax,"off");
outDir=fullfile(repoRoot,"figures","final_png_or_pdf_exports");
if ~isfolder(outDir), mkdir(outDir); end
exportgraphics(fig,fullfile(outDir,"Fig4_profile_outcomes.png"),"Resolution",600);
exportgraphics(fig,fullfile(outDir,"Fig4_profile_outcomes.pdf"),"ContentType","vector");
close(fig);

