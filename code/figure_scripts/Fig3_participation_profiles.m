%% Figure 3: participation-profile signatures and composition
repoRoot=fileparts(fileparts(fileparts(mfilename("fullpath"))));
T=readtable(fullfile(repoRoot,"data","anonymised_student_level_dataset.csv"),"TextType","string");
A=readtable(fullfile(repoRoot,"outputs","participation_profile_assignment.csv"),"TextType","string");
assert(height(T)==height(A) && isequal(A.StudentRow,(1:height(T))'), ...
    "Profile assignments are not aligned with source rows.");
profileNames=["Low-start deliberate improvers";"High-start plateau learners"; ...
    "Intensive model optimizers";"Minimal-time completers"];
profile=categorical(A.ParticipationProfile,profileNames,"Ordinal",true);
featureNames=["improving_transition_ratio","mean_practice_time", ...
    "model_revision_rounds","first_practice_score","practice_gain_ratio"];
featureLabels=["Improving transitions","Practice time","Model revisions", ...
    "First practice score","Practice gain"];
X=double(T{:,featureNames}); X(:,2)=log1p(X(:,2)); X(:,3)=log1p(X(:,3));
Xz=(X-mean(X,1,"omitnan"))./std(X,0,1,"omitnan");
profileMeans=nan(4,5); profileN=zeros(4,1);
for g=1:4
    mask=profile==profileNames(g); profileN(g)=nnz(mask);
    profileMeans(g,:)=mean(Xz(mask,:),1,"omitnan");
end
x=double(T.standard_exam_score);
stratumCode=ones(height(T),1); stratumCode(x>=95 & x<100)=2; stratumCode(x==100)=3;
counts=zeros(3,4);
for g=1:3
    for k=1:4, counts(g,k)=nnz(stratumCode==g & profile==profileNames(k)); end
end
percent=100*counts./sum(counts,2);

fig=figure("Color","w","Position",[80 80 1180 630]);
tl=tiledlayout(fig,1,2,"Padding","compact","TileSpacing","compact");
ax=nexttile(tl,1); imagesc(ax,profileMeans); colorbar(ax); colormap(ax,parula(256));
xticks(ax,1:5); xticklabels(ax,featureLabels);
yticks(ax,1:4); yticklabels(ax,profileNames+" (n="+string(profileN)+")");
xtickangle(ax,25); xlabel(ax,"Trace feature"); title(ax,"A  Standardised trace signatures");
for r=1:4
    for c=1:5
        text(ax,c,r,sprintf("%.2f",profileMeans(r,c)), ...
            "HorizontalAlignment","center","Color","k","FontSize",9);
    end
end
box(ax,"off");
ax=nexttile(tl,2); bar(ax,percent,"stacked");
xticks(ax,1:3); xticklabels(ax,["<95","95-99","100"]);
ylabel(ax,"Students within score stratum (%)"); xlabel(ax,"Familiar-task score stratum");
title(ax,"B  Participation-profile composition"); ylim(ax,[0 100]);
legend(ax,profileNames,"Location","eastoutside"); grid(ax,"on"); box(ax,"off");
title(tl,"Participation profiles summarise different platform-trace patterns");
outDir=fullfile(repoRoot,"figures","final_png_or_pdf_exports");
if ~isfolder(outDir), mkdir(outDir); end
exportgraphics(fig,fullfile(outDir,"Fig3_participation_profiles.png"),"Resolution",600);
exportgraphics(fig,fullfile(outDir,"Fig3_participation_profiles.pdf"),"ContentType","vector");
close(fig);

