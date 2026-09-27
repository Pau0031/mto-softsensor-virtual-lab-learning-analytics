%% Figure 1: familiar-task score equivalence
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
T = readtable(fullfile(repoRoot,"data","anonymised_student_level_dataset.csv"),"TextType","string");
outDir = fullfile(repoRoot,"figures","final_png_or_pdf_exports");
if ~isfolder(outDir), mkdir(outDir); end
x = double(T.standard_exam_score);
y = double(T.engineering_test_score);
strata = strings(height(T),1);
strata(x<95)="<95"; strata(x>=95 & x<100)="95-99"; strata(x==100)="100";
strata = categorical(strata,["<95","95-99","100"],"Ordinal",true);
[tauB,tauP] = corr(x,y,"Type","Kendall","Rows","complete");
scoreValues = unique(x); scoreN = arrayfun(@(z) nnz(x==z),scoreValues);

fig = figure("Color","w","Position",[80 80 1180 780]);
tl = tiledlayout(fig,2,2,"Padding","compact","TileSpacing","compact");
ax = nexttile(tl,1); bar(ax,scoreValues,scoreN,0.8);
xlabel(ax,"Familiar-task embedded score"); ylabel(ax,"Students");
title(ax,"A  Embedded-score distribution"); grid(ax,"on");
ax = nexttile(tl,2);
rng(926,"twister"); xPlot=x+0.18*(rand(size(x))-0.5);
scatter(ax,xPlot,y,34,double(strata),"filled","MarkerFaceAlpha",0.68);
xlabel(ax,"Familiar-task embedded score"); ylabel(ax,"Modified-scenario score");
title(ax,sprintf("B  Kendall \\tau_b = %.3f, p = %.3f",tauB,tauP));
cb = colorbar(ax);
cb.Ticks = 1:3;
cb.TickLabels = ["<95", "95-99", "100"];
cb.Label.String = "Familiar-task score stratum";
grid(ax,"on");
ax = nexttile(tl,3); boxchart(ax,strata,y,"MarkerStyle",".");
xlabel(ax,"Familiar-task score stratum"); ylabel(ax,"Modified-scenario score");
title(ax,"C  Modified-scenario score by score stratum"); grid(ax,"on");
ax = nexttile(tl,4); y100=y(x==100);
histogram(ax,y100,"BinMethod","integers");
xlabel(ax,"Modified-scenario score"); ylabel(ax,"Students");
title(ax,sprintf("D  Embedded score = 100 (n=%d; median=%.0f; IQR=%.0f)", ...
    numel(y100),median(y100),iqr(y100))); grid(ax,"on");
title(tl,"A ceiling score on the familiar task does not determine modified-task performance");
exportgraphics(fig,fullfile(outDir,"Fig1_score_equivalence.png"),"Resolution",600);
exportgraphics(fig,fullfile(outDir,"Fig1_score_equivalence.pdf"),"ContentType","vector");
close(fig);

