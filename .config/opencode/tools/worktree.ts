import { tool } from "@opencode-ai/plugin"
import { execSync } from "child_process"
import path from "path"

/**
 * Run a shell command synchronously and return trimmed stdout.
 * Throws on non-zero exit with stderr included in the message.
 */
function run(cmd: string, cwd: string): string {
  try {
    return execSync(cmd, { cwd, encoding: "utf8" }).trim()
  } catch (err: unknown) {
    const e = err as { stderr?: Buffer; stdout?: Buffer; message?: string }
    const detail = (e.stderr?.toString() ?? e.stdout?.toString() ?? e.message ?? "unknown error").trim()
    throw new Error(`Command failed: ${cmd}\n${detail}`)
  }
}

/**
 * worktree_create
 *
 * Creates a new git worktree + branch for isolated parallel work.
 * The worktree is placed at <git-root>/../worktrees/<name> so it
 * never pollutes the main working tree.
 */
export const worktree_create = tool({
  description:
    "Create an isolated git worktree + branch for parallel work. " +
    "Use this when your task touches shared files or another agent is working in the same repo. " +
    "Returns the absolute path of the new worktree directory.",
  args: {
    name: tool.schema
      .string()
      .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, "Use lowercase-kebab-case, e.g. feature-login-screen")
      .describe(
        "Short kebab-case name for the worktree and branch (e.g. 'feature-login-screen'). " +
          "A branch called feature/<name> will be created.",
      ),
  },
  async execute(args, context) {
    const { name } = args
    const worktreeRoot = context.worktree
    const branch = `feature/${name}`
    const worktreePath = path.resolve(worktreeRoot, "..", "worktrees", name)

    // Ensure parent directory exists
    run(`mkdir -p ${path.dirname(worktreePath)}`, worktreeRoot)

    // Check if branch already exists
    const branchExists = run(`git branch --list ${branch}`, worktreeRoot)

    let result: string
    if (branchExists) {
      result = run(`git worktree add "${worktreePath}" ${branch}`, worktreeRoot)
    } else {
      result = run(`git worktree add -b ${branch} "${worktreePath}"`, worktreeRoot)
    }

    return [
      `Worktree created successfully.`,
      `  Branch   : ${branch}`,
      `  Directory: ${worktreePath}`,
      `  Git output: ${result || "ok"}`,
      ``,
      `Next steps:`,
      `  1. Work exclusively inside: ${worktreePath}`,
      `  2. Run tests inside that directory before merging.`,
      `  3. When done, call worktree_cleanup with name="${name}" — but ONLY after merge confirmation from the user or coordinator.`,
    ].join("\n")
  },
})

/**
 * worktree_cleanup
 *
 * Removes a merged git worktree + branch safely.
 * Enforces a confirmation gate — the agent MUST pass confirmed=true,
 * which should only happen after the human or coordinator has explicitly
 * approved the cleanup. This prevents accidental deletion of unmerged work.
 */
export const worktree_cleanup = tool({
  description:
    "Remove a git worktree and its branch AFTER it has been merged. " +
    "Requires confirmed=true — only pass this after the human or coordinator " +
    "has explicitly approved the cleanup. Never call this proactively.",
  args: {
    name: tool.schema
      .string()
      .describe("The same name used in worktree_create (e.g. 'feature-login-screen')."),
    confirmed: tool.schema
      .boolean()
      .describe(
        "Set to true ONLY when the user or coordinator has explicitly confirmed the branch is merged " +
          "and cleanup is approved. If unsure, do NOT call this tool — ask for permission first.",
      ),
  },
  async execute(args, context) {
    const { name, confirmed } = args

    if (!confirmed) {
      return [
        "Cleanup BLOCKED — confirmation not given.",
        "",
        `Before calling worktree_cleanup again:`,
        `  1. Confirm branch feature/${name} has been merged into main.`,
        `  2. Get explicit approval from the user or coordinator.`,
        `  3. Then call worktree_cleanup({ name: "${name}", confirmed: true }).`,
      ].join("\n")
    }

    const worktreeRoot = context.worktree
    const branch = `feature/${name}`
    const worktreePath = path.resolve(worktreeRoot, "..", "worktrees", name)

    // Verify the branch is fully merged into main before proceeding
    const mergeCheck = run(`git branch --merged main --list ${branch}`, worktreeRoot)

    if (!mergeCheck) {
      return [
        `Cleanup ABORTED — branch '${branch}' does not appear to be merged into main.`,
        "",
        `Please merge the branch first:`,
        `  git switch main && git merge ${branch}`,
        "",
        `Then request cleanup again with confirmed=true.`,
      ].join("\n")
    }

    // Remove worktree directory
    const removeResult = run(`git worktree remove --force "${worktreePath}"`, worktreeRoot)

    // Delete the branch
    const branchResult = run(`git branch -d ${branch}`, worktreeRoot)

    return [
      `Worktree cleaned up successfully.`,
      `  Removed directory: ${worktreePath}`,
      `  Deleted branch   : ${branch}`,
      `  worktree remove  : ${removeResult || "ok"}`,
      `  branch delete    : ${branchResult || "ok"}`,
    ].join("\n")
  },
})
