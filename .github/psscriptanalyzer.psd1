@{
    # PSScriptAnalyzer settings for GitHub code scanning.
    # The excluded rules are style-only and intentional in this CLI tool:
    # - Write-Host is the intended console output.
    # - Empty catch blocks are used for best-effort cleanup.
    # - The plural noun and the unused legacy parameter are harmless.
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSAvoidUsingEmptyCatchBlock'
        'PSUseSingularNouns'
        'PSReviewUnusedParameter'
    )
}
