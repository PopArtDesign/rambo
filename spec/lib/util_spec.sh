#shellcheck shell=bash

app_name=rambo
app_libs_path=./lib

Include ./common.bash
Include ./lib/util.bash

Describe 'app::util::realpath'
    It 'accepts multiple options'
        dir="${SHELLSPEC_TMPBASE}/realpath-test"

        mkdir -p "${dir}"

        When call app::util::realpath -q -m "${dir}"

        The status should be success
        The output should equal "${dir}"
    End
End
