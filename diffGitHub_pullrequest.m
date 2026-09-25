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

    fprintf('Found %d modified model(s):\n', numel(modifiedFiles));
    for i = 1:numel(modifiedFiles)
        fprintf('  %s\n', modifiedFiles(i));
    end

    % ---------------------------------------------------------------
    % R2023a KEY SETTING: Disable screenshots so visdiff + publish
    % works on headless Linux CI runners without any display
    % This is the official MathWorks fix for Linux CI/CD pipelines
    % See: https://www.mathworks.com/matlabcentral/answers/1955194
    % ---------------------------------------------------------------
    s = settings().comparisons.slx.DisplayReportScreenshots;
    s.TemporaryValue = false;

    tempdir   = fullfile(proj.RootFolder, "modelscopy");
    reportdir = proj.RootFolder;   % HTML reports land in workspace root
    mkdir(tempdir)

    for i = 1:numel(modifiedFiles)
        diffToAncestor(tempdir, reportdir, string(modifiedFiles(i)));
    end

    rmdir(tempdir, 's');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function report = diffToAncestor(tempdir, reportdir, fileName)
    ancestor = getAncestor(tempdir, fileName);
    if isempty(ancestor)
        fprintf('Skipping %s — new model, no ancestor on main.\n', fileName);
        report = [];
        return
    end

    fprintf('Comparing : %s\n', fileName);
    fprintf('Ancestor  : %s\n', ancestor);

    try
        % visdiff generates the official MathWorks File Comparison Report
        % with file metadata, environment info, filters, and diff results
        comp = visdiff(ancestor, fileName);

        % 'unfiltered' shows ALL differences including hidden blocks
        filter(comp, 'unfiltered');

        % publish writes the HTML in the exact MathWorks report format
        % shown in the reference screenshot (File Comparison Report)
        report = publish(comp, 'html', 'OutputFolder', reportdir);
        fprintf('Report written: %s\n', report);

    catch ME
        fprintf('[ERROR] Comparison failed for %s: %s\n', fileName, ME.message);
        fprintf('Message: %s\n', ME.message);
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