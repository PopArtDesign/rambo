#shellcheck shell=bash

app_name=rambo
app_libs_path=./lib

Include ./common.bash
Include ./lib/error.bash

Describe 'app::error::error'
    It 'returns specified exit code'
        When run app::error::error --exit 42 'test error'

        The status should equal 42
        The error should equal 'rambo ERROR: test error'
    End

    It 'fails with message on invalid exit code'
        When run app::error::error --exit 0 'test error'

        The status should be failure
        The error should include 'app::error::error(): invalid exit code: 0'
        The error should not include 'ERROR: test error'
    End
End
