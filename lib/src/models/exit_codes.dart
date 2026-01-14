/// Exit codes used by the GWM CLI tool.
///
/// These codes follow standard CLI conventions and provide specific
/// error information for different failure scenarios.
enum ExitCode {
  /// Operation completed successfully
  success(0),

  /// General unspecified error occurred
  generalError(1),

  /// Command-line arguments were invalid or missing
  invalidArguments(2),

  /// The requested worktree already exists
  worktreeExists(3),

  /// The specified Git branch does not exist
  branchNotFound(4),

  /// A hook command returned a non-zero exit status
  hookFailed(5),

  /// Invalid or malformed configuration file
  configError(6),

  /// A Git command returned a non-zero exit status
  gitFailed(7),

  /// Shell wrapper is missing or not properly configured
  shellWrapperMissing(8);

  const ExitCode(this.value);

  /// The integer value of the exit code
  final int value;
}
