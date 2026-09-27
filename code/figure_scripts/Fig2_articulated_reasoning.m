%% Figure 2: report-rubric evidence of articulated modelling reasoning
repoRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
T = readtable(fullfile(repoRoot,"data","anonymised_student_level_dataset.csv"),"TextType","string");
outDir = fullfile(repoRoot,"figures","final_png_or_pdf_exports");
rubricNames = ["process_understanding","variable_selection", ...
    "modelling_workflow","model_evaluation","engineering_recommendation"];
rubricLabels = ["Process understanding","Variable selection", ...
    "Modelling workflow","Model evaluation","Engineering recommendation"];
x=double(T.standard_exam_score);
strata=strings(height(T),1);
strata(x<95)="<95"; strata(x>=95 & x<100)="95-99"; strata(x==100)="100";
strata=categorical(strata,["<95","95-99","100"],"Ordinal",true);
means=nan(numel(rubricNames),3);
for j=1:numel(rubricNames)
    values=double(T.(rubricNames(j)));
    for g=1:3, means(j,g)=mean(values(double(strata)==g),"omitnan"); end
end

fig=figure("Color","w","Position",[80 80 1180 620]);
tl=tiledlayout(fig,1,2,"Padding","compact","TileSpacing","compact");
ax=nexttile(tl,1); imagesc(ax,means); colorbar(ax); colormap(ax,parula(256));
xticks(ax,1:3); xticklabels(ax,["<95","95-99","100"]);
yticks(ax,1:numel(rubricLabels)); yticklabels(ax,rubricLabels);
xlabel(ax,"Familiar-task score stratum"); title(ax,"A  Mean rubric scores by stratum");
for r=1:size(means,1)
    for c=1:size(means,2)
        text(ax,c,r,sprintf("%.1f",means(r,c)),"HorizontalAlignment","center","Color","k");
    end
end
box(ax,"off");

fullMask=x==100; allValues=[]; allGroups=[];
for j=1:numel(rubricNames)
    values=double(T.(rubricNames(j)));
    allValues=[allValues;values(fullMask)]; %#ok<AGROW>
    allGroups=[allGroups;repmat(j,nnz(fullMask),1)]; %#ok<AGROW>
end
ax=nexttile(tl,2);
boxchart(ax,categorical(allGroups,1:numel(rubricLabels),rubricLabels), ...
    allValues,"MarkerStyle",".");
ylabel(ax,"Report-rubric score"); xlabel(ax,"Rubric dimension");
xtickangle(ax,25);
title(ax,sprintf("B  Rubric-score spread among embedded-score=100 students (n=%d)",nnz(fullMask)));
grid(ax,"on"); box(ax,"off");
title(tl,"Written reports provide evidence beyond the embedded score");
exportgraphics(fig,fullfile(outDir,"Fig2_articulated_reasoning.png"),"Resolution",600);
exportgraphics(fig,fullfile(outDir,"Fig2_articulated_reasoning.pdf"),"ContentType","vector");
close(fig);

