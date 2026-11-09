function build_pfile()
%BUILD_PFILE  Rebuild the student copy of the self-tests as a protected p-file.
%
%   build_pfile()
%
%   INPUT:  none
%   OUTPUT: none returned. Writes ../run_self_tests.p (the file students get).
%
%   The readable source, instructor/run_self_tests.m, contains the expected
%   answers, so students receive only the p-file. Run this after every
%   change to run_self_tests.m. A p-file cannot be password protected; its
%   contents are obfuscated, which is what keeps the answers out of sight.

    here = fileparts(mfilename('fullpath'));
    pcode(fullfile(here, 'run_self_tests.m'), '-inplace');
    movefile(fullfile(here, 'run_self_tests.p'), fullfile(here, '..', 'run_self_tests.p'), 'f');
    fprintf('wrote %s\n', fullfile(fileparts(here), 'run_self_tests.p'));
end
