function diffGitHub_pullrequest(branchname)
    proj = openProject(pwd);

    gitCommand = sprintf('git --no-pager diff --name-only origin/main..origin/%s ***.slx', branchname);
    [status, modifiedFiles] = system(gitCommand);
    if status ~= 0
        warning("git diff failed")
        warning(modifiedFiles)
        return;
    end
    modifiedFiles = split(modifiedFiles);
    modifiedFiles(end) = [];

    if isempty(modifiedFiles)
        disp('No modified models to compare.')
        return
    end

    tempdir = fullfile(proj.RootFolder, "modelscopy");
    mkdir(tempdir)

    for i = 1:numel(modifiedFiles)
        diffToAncestor(tempdir, string(modifiedFiles(i)));
    end

    rmdir(tempdir, 's');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function report = diffToAncestor(tempdir, fileName)
    ancestor = getAncestor(tempdir, fileName);
    if isempty(ancestor)
        report = [];
        return
    end

    [~, name, ~] = fileparts(fileName);

    % ------------------------------------------------------------------
    % HEADLESS: Use slxmlcomp.compare instead of visdiff
    % No GUI / display / Comparison Tool needed
    % ------------------------------------------------------------------
    try
        % Compare the two SLX files at the XML level
        diffResult = slxmlcomp.compare(ancestor, fileName);

        % Write results to an HTML report in the workspace root
        % (workflow uploads *.html from workspace root)
        reportFile = fullfile(fileparts(fileparts(tempdir)), ...
                              sprintf('%s_diff_report.html', name));

        fid = fopen(reportFile, 'w');
        fprintf(fid, '<!DOCTYPE html>\n<html>\n<head>\n');
        fprintf(fid, '<title>Diff Report: %s</title>\n', name);
        fprintf(fid, '<style>\n');
        fprintf(fid, '  body { font-family: Arial, sans-serif; margin: 20px; }\n');
        fprintf(fid, '  h1 { color: #333; }\n');
        fprintf(fid, '  table { border-collapse: collapse; width: 100%%; }\n');
        fprintf(fid, '  th { background-color: #4CAF50; color: white; padding: 8px; text-align: left; }\n');
        fprintf(fid, '  td { border: 1px solid #ddd; padding: 8px; }\n');
        fprintf(fid, '  tr:nth-child(even) { background-color: #f2f2f2; }\n');
        fprintf(fid, '  .added    { color: green; font-weight: bold; }\n');
        fprintf(fid, '  .removed  { color: red;   font-weight: bold; }\n');
        fprintf(fid, '  .modified { color: orange; font-weight: bold; }\n');
        fprintf(fid, '</style>\n</head>\n<body>\n');
        fprintf(fid, '<h1>Model Diff Report: %s</h1>\n', name);
        fprintf(fid, '<p><b>Ancestor (main):</b> %s</p>\n', ancestor);
        fprintf(fid, '<p><b>Modified:</b> %s</p>\n', fileName);
        fprintf(fid, '<p><b>Total differences:</b> %d</p>\n', diffResult.Count);

        if diffResult.Count == 0
            fprintf(fid, '<p style="color:green;">No differences found.</p>\n');
        else
            fprintf(fid, '<table>\n');
            fprintf(fid, '<tr><th>#</th><th>Type</th><th>Path</th></tr>\n');
            for k = 1:diffResult.Count
                item = diffResult.Item(k);
                dtype = item.DifferenceType;

                % Pick CSS class based on difference type
                if strcmpi(dtype, 'added')
                    css = 'added';
                elseif strcmpi(dtype, 'removed')
                    css = 'removed';
                else
                    css = 'modified';
                end

                fprintf(fid, '<tr><td>%d</td><td class="%s">%s</td><td>%s</td></tr>\n', ...
                        k, css, dtype, item.Path);
            end
            fprintf(fid, '</table>\n');
        end

        fprintf(fid, '</body>\n</html>\n');
        fclose(fid);

        fprintf('Report written: %s\n', reportFile);
        report = reportFile;

    catch ME
        warning('Comparison failed for %s: %s', fileName, ME.message);
        report = [];
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ancestor = getAncestor(tempdir, fileName)
    [~, name, ext] = fileparts(fileName);
    ancestor = fullfile(tempdir, name);

    fileName = strrep(fileName, '\', '/');
    ancestor = strrep(sprintf('%s%s%s', ancestor, "_ancestor", ext), '\', '/');

    gitCommand = sprintf('git --no-pager show origin/main:%s > %s', fileName, ancestor);
    [status, ~] = system(gitCommand);
    if status ~= 0
        ancestor = [];
    end
end

%   Copyright 2024-2026 The MathWorks, Inc.
