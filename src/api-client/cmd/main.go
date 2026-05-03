package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"

	penpot "github.com/agherasim/penpot-desktop/api-client"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		printError(err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		printUsage()
		return nil
	}

	// Global --token flag before the subcommand
	token := os.Getenv("PENPOT_AUTH_TOKEN")
	baseURL := os.Getenv("PENPOT_API_URL")

	global := flag.NewFlagSet("penpot", flag.ContinueOnError)
	global.StringVar(&token, "token", token, "API access token (default: $PENPOT_AUTH_TOKEN)")
	global.StringVar(&baseURL, "base-url", baseURL, "Penpot API base URL (default: $PENPOT_API_URL)")
	global.Usage = printUsage

	// Find the first non-flag arg to use as the group, pass the rest
	splitAt := len(args)
	for i, a := range args {
		if !strings.HasPrefix(a, "-") {
			splitAt = i
			break
		}
	}
	if err := global.Parse(args[:splitAt]); err != nil {
		return err
	}
	rest := append(global.Args(), args[splitAt:]...)

	if len(rest) == 0 {
		printUsage()
		return nil
	}

	opts := []penpot.Option{penpot.WithToken(token)}
	if baseURL != "" {
		opts = append(opts, penpot.WithBaseURL(baseURL))
	}
	client := penpot.New(opts...)

	group := rest[0]
	switch group {
	case "config":
		return runConfig(token, baseURL)
	case "auth":
		return runAuth(client, rest[1:])
	case "files":
		return runFiles(client, rest[1:])
	default:
		return fmt.Errorf("unknown command group %q — use config, auth or files", group)
	}
}

// --- config ---

func runConfig(token, baseURL string) error {
	tokenPreview := ""
	if len(token) >= 4 {
		tokenPreview = token[:4] + "..."
	} else if token != "" {
		tokenPreview = token + "..."
	}

	cfg := map[string]string{
		"apiURL": baseURL,
		"token":  tokenPreview,
	}
	return printJSON(cfg)
}

// --- auth ---

func runAuth(c *penpot.Client, args []string) error {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: penpot auth <command>")
		fmt.Fprintln(os.Stderr, "  verify-token  --token TOKEN")
		return nil
	}
	switch args[0] {
	case "verify-token":
		fs := flag.NewFlagSet("verify-token", flag.ExitOnError)
		tok := fs.String("token", "", "Token to verify (required)")
		fs.Usage = func() {
			fmt.Fprintln(os.Stderr, "usage: penpot auth verify-token --token TOKEN")
			fs.PrintDefaults()
		}
		fs.Parse(args[1:])
		if *tok == "" {
			// Fall back to env token if none provided
			*tok = os.Getenv("PENPOT_AUTH_TOKEN")
		}
		if *tok == "" {
			return fmt.Errorf("--token is required")
		}
		result, err := c.VerifyToken(*tok)
		if err != nil {
			return err
		}
		return printJSON(result)
	default:
		return fmt.Errorf("unknown auth command %q", args[0])
	}
}

// --- files ---

func runFiles(c *penpot.Client, args []string) error {
	if len(args) == 0 {
		printFilesUsage()
		return nil
	}
	switch args[0] {
	case "create":
		fs := flag.NewFlagSet("files create", flag.ExitOnError)
		name := fs.String("name", "", "File name (required)")
		projectID := fs.String("project-id", "", "Project UUID (required)")
		id := fs.String("id", "", "Optional file UUID")
		shared := fs.Bool("shared", false, "Mark as shared library")
		features := fs.String("features", "", "Comma-separated feature flags")
		fs.Parse(args[1:])
		requireFlags(fs, "name", "project-id")
		req := penpot.CreateFileReq{
			Name:      *name,
			ProjectID: *projectID,
			ID:        *id,
			IsShared:  *shared,
		}
		if *features != "" {
			req.Features = strings.Split(*features, ",")
		}
		result, err := c.CreateFile(req)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "get":
		fs := flag.NewFlagSet("files get", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		features := fs.String("features", "", "Comma-separated feature flags")
		fs.Parse(args[1:])
		requireFlags(fs, "id")
		var feats []string
		if *features != "" {
			feats = strings.Split(*features, ",")
		}
		result, err := c.GetFile(*id, feats)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "info":
		fs := flag.NewFlagSet("files info", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "id")
		result, err := c.GetFileInfo(*id)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "summary":
		fs := flag.NewFlagSet("files summary", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "id")
		result, err := c.GetFileSummary(*id)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "delete":
		fs := flag.NewFlagSet("files delete", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "id")
		if err := c.DeleteFile(*id); err != nil {
			return err
		}
		fmt.Println("deleted")
		return nil

	case "rename":
		fs := flag.NewFlagSet("files rename", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		name := fs.String("name", "", "New name (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "id", "name")
		result, err := c.RenameFile(*id, *name)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "update":
		fs := flag.NewFlagSet("files update", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		sessionID := fs.String("session-id", "", "Session UUID (required)")
		revn := fs.Int("revn", 0, "Revision number (required)")
		vern := fs.Int("vern", 0, "Version number (required)")
		skip := fs.Bool("skip-validate", false, "Skip validation")
		fs.Parse(args[1:])
		requireFlags(fs, "id", "session-id")
		result, err := c.UpdateFile(penpot.UpdateFileReq{
			ID:           *id,
			SessionID:    *sessionID,
			Revn:         *revn,
			Vern:         *vern,
			SkipValidate: *skip,
		})
		if err != nil {
			return err
		}
		return printJSON(result)

	case "list":
		fs := flag.NewFlagSet("files list", flag.ExitOnError)
		projectID := fs.String("project-id", "", "Project UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "project-id")
		result, err := c.GetProjectFiles(*projectID)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "set-shared":
		fs := flag.NewFlagSet("files set-shared", flag.ExitOnError)
		id := fs.String("id", "", "File UUID (required)")
		shared := fs.Bool("shared", true, "Share state (default true)")
		fs.Parse(args[1:])
		requireFlags(fs, "id")
		if err := c.SetFileShared(*id, *shared); err != nil {
			return err
		}
		fmt.Printf("isShared set to %v\n", *shared)
		return nil

	case "search":
		fs := flag.NewFlagSet("files search", flag.ExitOnError)
		teamID := fs.String("team-id", "", "Team UUID (required)")
		term := fs.String("term", "", "Search term")
		fs.Parse(args[1:])
		requireFlags(fs, "team-id")
		result, err := c.SearchFiles(*teamID, *term)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "get-page":
		fs := flag.NewFlagSet("files get-page", flag.ExitOnError)
		fileID := fs.String("file-id", "", "File UUID (required)")
		pageID := fs.String("page-id", "", "Page UUID")
		shareID := fs.String("share-id", "", "Share UUID")
		objectID := fs.String("object-id", "", "Object UUID")
		fs.Parse(args[1:])
		requireFlags(fs, "file-id")
		result, err := c.GetPage(penpot.GetPageReq{
			FileID:   *fileID,
			PageID:   *pageID,
			ShareID:  *shareID,
			ObjectID: *objectID,
		})
		if err != nil {
			return err
		}
		return printJSON(result)

	case "libraries":
		fs := flag.NewFlagSet("files libraries", flag.ExitOnError)
		fileID := fs.String("file-id", "", "File UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "file-id")
		result, err := c.GetFileLibraries(*fileID)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "link-library":
		fs := flag.NewFlagSet("files link-library", flag.ExitOnError)
		fileID := fs.String("file-id", "", "File UUID (required)")
		libraryID := fs.String("library-id", "", "Library file UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "file-id", "library-id")
		if err := c.LinkFileToLibrary(*fileID, *libraryID); err != nil {
			return err
		}
		fmt.Println("linked")
		return nil

	case "unlink-library":
		fs := flag.NewFlagSet("files unlink-library", flag.ExitOnError)
		fileID := fs.String("file-id", "", "File UUID (required)")
		libraryID := fs.String("library-id", "", "Library file UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "file-id", "library-id")
		if err := c.UnlinkFileFromLibrary(*fileID, *libraryID); err != nil {
			return err
		}
		fmt.Println("unlinked")
		return nil

	case "has-libraries":
		fs := flag.NewFlagSet("files has-libraries", flag.ExitOnError)
		fileID := fs.String("file-id", "", "File UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "file-id")
		result, err := c.HasFileLibraries(*fileID)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "shared":
		fs := flag.NewFlagSet("files shared", flag.ExitOnError)
		teamID := fs.String("team-id", "", "Team UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "team-id")
		result, err := c.GetTeamSharedFiles(*teamID)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "recent":
		fs := flag.NewFlagSet("files recent", flag.ExitOnError)
		teamID := fs.String("team-id", "", "Team UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "team-id")
		result, err := c.GetTeamRecentFiles(*teamID)
		if err != nil {
			return err
		}
		return printJSON(result)

	case "deleted":
		fs := flag.NewFlagSet("files deleted", flag.ExitOnError)
		teamID := fs.String("team-id", "", "Team UUID (required)")
		fs.Parse(args[1:])
		requireFlags(fs, "team-id")
		result, err := c.GetTeamDeletedFiles(*teamID)
		if err != nil {
			return err
		}
		return printJSON(result)

	default:
		return fmt.Errorf("unknown files command %q", args[0])
	}
}

// --- helpers ---

func printError(err error) {
	var apiErr *penpot.APIError
	if errors.As(err, &apiErr) {
		enc := json.NewEncoder(os.Stderr)
		enc.SetIndent("", "  ")
		enc.Encode(apiErr)
		return
	}
	fmt.Fprintln(os.Stderr, "error:", err)
}

func printJSON(v any) error {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(v)
}

// requireFlags exits with an error if any of the named flags are empty strings.
func requireFlags(fs *flag.FlagSet, names ...string) {
	for _, name := range names {
		f := fs.Lookup(name)
		if f == nil || f.Value.String() == "" {
			fmt.Fprintf(os.Stderr, "error: --%s is required\n\n", name)
			fs.Usage()
			os.Exit(2)
		}
	}
}

func printUsage() {
	fmt.Fprint(os.Stderr, `usage: penpot [--token TOKEN] [--base-url URL] <group> <command> [flags]

Groups:
  config  Show active configuration
  auth    Authentication commands
  files   File management commands

Global flags:
  --token      API access token (default: $PENPOT_AUTH_TOKEN)
  --base-url   Penpot API base URL (default: $PENPOT_API_URL)

Run "penpot auth" or "penpot files" for available commands.
`)
}

func printFilesUsage() {
	fmt.Fprint(os.Stderr, `usage: penpot files <command> [flags]

Commands:
  create          --name NAME --project-id ID [--id ID] [--shared] [--features f1,f2]
  get             --id ID [--features f1,f2]
  info            --id ID
  summary         --id ID
  delete          --id ID
  rename          --id ID --name NAME
  update          --id ID --session-id ID --revn N --vern N [--skip-validate]
  list            --project-id ID
  set-shared      --id ID [--shared=false]
  search          --team-id ID [--term TERM]
  get-page        --file-id ID [--page-id ID] [--share-id ID] [--object-id ID]
  libraries       --file-id ID
  link-library    --file-id ID --library-id ID
  unlink-library  --file-id ID --library-id ID
  has-libraries   --file-id ID
  shared          --team-id ID
  recent          --team-id ID
  deleted         --team-id ID
`)
}
