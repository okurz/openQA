use strict;
use warnings;

# note: Only job module statistics for jobs 99946 and 99963 are set in `t/fixtures/01-jobs.pl`.
#       Statistics for other jobs are *not* consistent in the fixtures database.

[
    JobModules => {
        t_created => time2str('%Y-%m-%d %H:%M:%S', time - 10000, 'UTC'),
        script => 'tests/installation/welcome.pm',
        job_id => 99937,
        category => 'installation',
        name => 'welcome',
        result => 'passed',
    },
    JobModules => {
        script => 'tests/installation/installation_mode.pm',
        job_id => 99937,
        category => 'installation',
        name => 'installation_mode',
        result => 'passed',
    },
    JobModules => {
        script => 'tests/installation/installation_mode.pm',
        job_id => 99939,
        category => 'installation',
        name => 'installation_mode',
        result => 'softfailed'
    },
    JobModules => {
        t_created => time2str('%Y-%m-%d %H:%M:%S', time - 50000),
        script => 'tests/installation/partitioning.pm',
        job_id => 99937,
        category => 'installation',
        name => 'partitioning',
        result => 'passed',
    },
    JobModules => {
        t_created => time2str('%Y-%m-%d %H:%M:%S', time - 100000),
        script => 'tests/installation/installation_finish.pm',
        job_id => 99937,
        category => 'installation',
        name => 'installation_finish',
        result => 'passed',
    },
    JobModules => {
        script => 'tests/x11/xterm.pm',
        job_id => 99937,
        category => 'x11',
        name => 'xterm',
        result => 'failed',
    },
    JobModules => {
        script => 'tests/x11/firefox.pm',
        job_id => 99937,
        category => 'x11',
        name => 'firefox',
        result => 'passed',
    },
    JobModules => {
        script => 'tests/x11/shutdown.pm',
        job_id => 99937,
        category => 'x11',
        name => 'shutdown',
        result => 'failed',
    },
    JobModules => {
        script => 'tests/installation/isosize.pm',
        job_id => 99938,
        category => 'installation',
        name => 'isosize',
        result => 'passed',
    },
    JobModules => {
        script => 'tests/installation/logpackages.pm',
        job_id => 99938,
        category => 'installation',
        name => 'logpackages',
        result => 'failed',
    },
    JobModules => {
        script => 'tests/installation/installer_desktopselection.pm',
        job_id => 99938,
        category => 'installation',
        name => 'installer_desktopselection',
        result => 'none',
    },
    JobModules => {
        script => 'tests/installation/user_settings.pm',
        job_id => 99938,
        category => 'installation',
        name => 'user_settings',
        result => 'none',
    },
    JobModules => {
        script => 'tests/console/yast2_lan.pm',
        job_id => 99764,
        category => 'console',
        name => 'yast2_lan',
        always_rollback => 1,
        important => 1,
        result => 'passed',
    },
    JobModules => {
        script => 'tests/console/yast2_bootloader.pm',
        job_id => 99764,
        category => 'console',
        name => 'yast2_bootloader',
        result => 'passed',
        milestone => 1,
        important => 1,
    },
    JobModules => {
        script => 'tests/console/sshd.pm',
        job_id => 99764,
        category => 'console',
        name => 'sshd',
        result => 'passed',
        fatal => '1',
    },
    JobModules => {
        script => 'tests/console/textinfo.pm',
        job_id => 99764,
        category => 'console',
        name => 'textinfo',
        result => 'passed',
    },
]
