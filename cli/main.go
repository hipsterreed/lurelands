package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Styles
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00CED1")).
			Bold(true).
			MarginLeft(2)

	itemStyle = lipgloss.NewStyle().
			PaddingLeft(4)

	selectedItemStyle = lipgloss.NewStyle().
				PaddingLeft(2).
				Foreground(lipgloss.Color("#00CED1"))

	categoryStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#666666")).
			Italic(true).
			PaddingLeft(4)

	statusStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00CED1")).
			MarginLeft(2)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FF6B6B")).
			MarginLeft(2)

	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#98FB98")).
			MarginLeft(2)

	headerStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("#00CED1")).
			BorderBottom(true).
			Padding(0, 1).
			MarginBottom(1)

	spinnerStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#00CED1"))
)

// Message types for spinner
type commandFinishedMsg struct {
	err    error
	output string
}

// Spinner model for loading state
type spinnerModel struct {
	spinner  spinner.Model
	title    string
	quitting bool
	done     bool
	err      error
	output   string
}

func newSpinnerModel(title string) spinnerModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = spinnerStyle
	return spinnerModel{
		spinner: s,
		title:   title,
	}
}

func (m spinnerModel) Init() tea.Cmd {
	return m.spinner.Tick
}

func (m spinnerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		}

	case commandFinishedMsg:
		m.done = true
		m.err = msg.err
		m.output = msg.output
		return m, tea.Quit

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}

	return m, nil
}

func (m spinnerModel) View() string {
	if m.quitting {
		return ""
	}

	if m.done {
		return ""
	}

	return fmt.Sprintf("\n  %s %s\n", m.spinner.View(), m.title)
}

// Run command with spinner
func runCommandWithSpinner(title, cmd string, args []string, workDir string) error {
	// Create spinner model
	sm := newSpinnerModel(title)

	// Create the command
	c := exec.Command(cmd, args...)
	c.Dir = workDir

	// Capture output
	var stdout, stderr bytes.Buffer
	c.Stdout = &stdout
	c.Stderr = &stderr

	// Start command
	if err := c.Start(); err != nil {
		return err
	}

	// Run spinner in a goroutine with command execution
	p := tea.NewProgram(sm)

	go func() {
		err := c.Wait()
		output := stdout.String()
		if stderr.Len() > 0 {
			output += stderr.String()
		}
		p.Send(commandFinishedMsg{err: err, output: output})
	}()

	finalModel, err := p.Run()
	if err != nil {
		return err
	}

	fm := finalModel.(spinnerModel)

	// Print captured output
	if fm.output != "" {
		fmt.Print(fm.output)
	}

	if fm.quitting {
		// User cancelled
		c.Process.Kill()
		return fmt.Errorf("cancelled by user")
	}

	return fm.err
}

// Command item for the list
type item struct {
	title       string
	description string
	category    string
	command     string
	args        []string
	workDir     string
}

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.description }
func (i item) FilterValue() string { return i.title }

type itemDelegate struct{}

func (d itemDelegate) Height() int                             { return 1 }
func (d itemDelegate) Spacing() int                            { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }
func (d itemDelegate) Render(w io.Writer, m list.Model, index int, listItem list.Item) {
	i, ok := listItem.(item)
	if !ok {
		return
	}

	str := fmt.Sprintf("%s", i.title)

	fn := itemStyle.Render
	if index == m.Index() {
		fn = func(s ...string) string {
			return selectedItemStyle.Render("▸ " + strings.Join(s, " "))
		}
	}

	fmt.Fprint(w, fn(str))
}

// Model for the application
type model struct {
	list       list.Model
	choice     string
	quitting   bool
	executing  bool
	err        error
	rootDir    string
	categories []string
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.list.SetWidth(msg.Width)
		return m, nil

	case tea.KeyMsg:
		switch keypress := msg.String(); keypress {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit

		case "enter":
			i, ok := m.list.SelectedItem().(item)
			if ok && i.command != "" {
				m.choice = i.title
				m.executing = true
				return m, tea.Quit
			}
		}
	}

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

func (m model) View() string {
	if m.quitting {
		return ""
	}

	if m.executing {
		return statusStyle.Render(fmt.Sprintf("🎣 Running: %s...\n", m.choice))
	}

	header := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00CED1")).
		Bold(true).
		Render(`
  ╦  ╦ ╦╦═╗╔═╗╦  ╔═╗╔╗╔╔╦╗╔═╗
  ║  ║ ║╠╦╝║╣ ║  ╠═╣║║║ ║║╚═╗
  ╩═╝╚═╝╩╚═╚═╝╩═╝╩ ╩╝╚╝═╩╝╚═╝`)

	subtitle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginLeft(2).
		Render("  🎣 Multiplayer Fishing Game CLI\n")

	return header + "\n" + subtitle + "\n" + m.list.View()
}

func getRootDir() string {
	// Get the executable path
	ex, err := os.Executable()
	if err != nil {
		// Fallback to current directory
		dir, _ := os.Getwd()
		return dir
	}

	// Check if we're running from a symlink or the cli directory
	exPath := filepath.Dir(ex)

	// If running via `go run`, use current directory
	if strings.Contains(exPath, "go-build") {
		dir, _ := os.Getwd()
		// Navigate up if we're in the cli directory
		if filepath.Base(dir) == "cli" {
			return filepath.Dir(dir)
		}
		return dir
	}

	// Navigate up from cli directory if needed
	if filepath.Base(exPath) == "cli" {
		return filepath.Dir(exPath)
	}

	return exPath
}

func initialModel() model {
	rootDir := getRootDir()
	flutterDir := filepath.Join(rootDir, "apps", "lurelands")
	spacetimeDir := filepath.Join(rootDir, "services", "spacetime-server")
	bridgeDir := filepath.Join(rootDir, "services", "bridge")

	items := []list.Item{
		item{title: "─── Flutter ───", description: "", category: "header", command: "", args: nil, workDir: ""},
		item{
			title:       "Run (default device)",
			description: "flutter run",
			category:    "flutter",
			command:     "flutter",
			args:        []string{"run"},
			workDir:     flutterDir,
		},
		item{
			title:       "Run on iOS",
			description: "flutter run -d ios",
			category:    "flutter",
			command:     "flutter",
			args:        []string{"run", "-d", "ios"},
			workDir:     flutterDir,
		},
		item{
			title:       "Run on Android",
			description: "flutter run -d android",
			category:    "flutter",
			command:     "flutter",
			args:        []string{"run", "-d", "android"},
			workDir:     flutterDir,
		},
		item{
			title:       "Run on Web",
			description: "flutter run -d chrome",
			category:    "flutter",
			command:     "flutter",
			args:        []string{"run", "-d", "chrome"},
			workDir:     flutterDir,
		},
		item{title: "─── Database ───", description: "", category: "header", command: "", args: nil, workDir: ""},
		item{
			title:       "Deploy to Maincloud",
			description: "spacetime publish --server maincloud",
			category:    "database",
			command:     "spacetime",
			args:        []string{"publish", "--server", "maincloud", "lurelands"},
			workDir:     spacetimeDir,
		},
		item{
			title:       "Deploy Locally",
			description: "spacetime publish lurelands",
			category:    "database",
			command:     "spacetime",
			args:        []string{"publish", "lurelands"},
			workDir:     spacetimeDir,
		},
		item{title: "─── Bridge ───", description: "", category: "header", command: "", args: nil, workDir: ""},
		item{
			title:       "Build",
			description: "bun run build",
			category:    "bridge",
			command:     "bun",
			args:        []string{"run", "build"},
			workDir:     bridgeDir,
		},
		item{
			title:       "Dev Mode",
			description: "bun run dev (hot reload)",
			category:    "bridge",
			command:     "bun",
			args:        []string{"run", "dev"},
			workDir:     bridgeDir,
		},
		item{
			title:       "Start Production",
			description: "bun run start",
			category:    "bridge",
			command:     "bun",
			args:        []string{"run", "start"},
			workDir:     bridgeDir,
		},
		item{
			title:       "Generate Types",
			description: "Generate TypeScript bindings",
			category:    "bridge",
			command:     "bun",
			args:        []string{"run", "generate"},
			workDir:     bridgeDir,
		},
	}

	l := list.New(items, itemDelegate{}, 50, 18)
	l.Title = ""
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)
	l.SetShowHelp(true)
	l.Styles.Title = titleStyle
	l.Styles.HelpStyle = lipgloss.NewStyle().MarginLeft(2).Foreground(lipgloss.Color("#666666"))

	return model{
		list:    l,
		rootDir: rootDir,
	}
}

func runCommand(cmd string, args []string, workDir string) error {
	c := exec.Command(cmd, args...)
	c.Dir = workDir
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	c.Stdin = os.Stdin
	return c.Run()
}

func main() {
	// Check for direct command-line arguments
	if len(os.Args) > 1 {
		handleDirectCommand(os.Args[1:])
		return
	}

	// Run the interactive TUI
	m := initialModel()
	p := tea.NewProgram(m, tea.WithAltScreen())

	finalModel, err := p.Run()
	if err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}

	// Execute the selected command
	if fm, ok := finalModel.(model); ok && fm.executing {
		i, ok := fm.list.SelectedItem().(item)
		if ok && i.command != "" {
			fmt.Printf("\n%s Running: %s %s\n",
				lipgloss.NewStyle().Foreground(lipgloss.Color("#00CED1")).Render("▸"),
				i.command,
				strings.Join(i.args, " "))

			var err error
			// Use spinner for build commands
			if i.title == "Build" || i.title == "Generate Types" || strings.Contains(i.title, "Deploy") {
				err = runCommandWithSpinner(
					fmt.Sprintf("Building %s...", i.category),
					i.command, i.args, i.workDir,
				)
			} else {
				fmt.Println()
				err = runCommand(i.command, i.args, i.workDir)
			}

			if err != nil {
				fmt.Printf("\n%s\n", errorStyle.Render(fmt.Sprintf("✗ Error: %v", err)))
				os.Exit(1)
			}
			fmt.Printf("\n%s\n", successStyle.Render("✓ Done!"))
		}
	}
}

func handleDirectCommand(args []string) {
	rootDir := getRootDir()
	flutterDir := filepath.Join(rootDir, "apps", "lurelands")
	spacetimeDir := filepath.Join(rootDir, "services", "spacetime-server")
	bridgeDir := filepath.Join(rootDir, "services", "bridge")

	commands := map[string]struct {
		cmd     string
		args    []string
		workDir string
		desc    string
	}{
		"run":             {"flutter", []string{"run"}, flutterDir, "Run Flutter app"},
		"run:ios":         {"flutter", []string{"run", "-d", "ios"}, flutterDir, "Run on iOS"},
		"run:android":     {"flutter", []string{"run", "-d", "android"}, flutterDir, "Run on Android"},
		"run:web":         {"flutter", []string{"run", "-d", "chrome"}, flutterDir, "Run on web"},
		"deploy":          {"spacetime", []string{"publish", "--server", "maincloud", "lurelands"}, spacetimeDir, "Deploy to maincloud"},
		"deploy:local":    {"spacetime", []string{"publish", "lurelands"}, spacetimeDir, "Deploy locally"},
		"bridge:build":    {"bun", []string{"run", "build"}, bridgeDir, "Build bridge"},
		"bridge:dev":      {"bun", []string{"run", "dev"}, bridgeDir, "Bridge dev mode"},
		"bridge:start":    {"bun", []string{"run", "start"}, bridgeDir, "Bridge production"},
		"bridge:generate": {"bun", []string{"run", "generate"}, bridgeDir, "Generate types"},
	}

	if args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		printHelp(commands)
		return
	}

	cmd, exists := commands[args[0]]
	if !exists {
		fmt.Printf("%s Unknown command: %s\n\n", errorStyle.Render("✗"), args[0])
		printHelp(commands)
		os.Exit(1)
	}

	fmt.Printf("\n%s %s\n",
		lipgloss.NewStyle().Foreground(lipgloss.Color("#00CED1")).Render("▸"),
		cmd.desc)

	var err error
	// Use spinner for build/deploy commands
	cmdName := args[0]
	if cmdName == "bridge:build" || cmdName == "bridge:generate" || strings.HasPrefix(cmdName, "deploy") {
		err = runCommandWithSpinner(
			fmt.Sprintf("Running %s...", cmd.desc),
			cmd.cmd, cmd.args, cmd.workDir,
		)
	} else {
		fmt.Println()
		err = runCommand(cmd.cmd, cmd.args, cmd.workDir)
	}

	if err != nil {
		fmt.Printf("\n%s\n", errorStyle.Render(fmt.Sprintf("✗ Error: %v", err)))
		os.Exit(1)
	}
	fmt.Printf("\n%s\n", successStyle.Render("✓ Done!"))
}

func printHelp(commands map[string]struct {
	cmd     string
	args    []string
	workDir string
	desc    string
}) {
	header := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00CED1")).
		Bold(true).
		Render(`
  ╦  ╦ ╦╦═╗╔═╗╦  ╔═╗╔╗╔╔╦╗╔═╗
  ║  ║ ║╠╦╝║╣ ║  ╠═╣║║║ ║║╚═╗
  ╩═╝╚═╝╩╚═╚═╝╩═╝╩ ╩╝╚╝═╩╝╚═╝`)

	fmt.Println(header)
	fmt.Println(lipgloss.NewStyle().Foreground(lipgloss.Color("#666666")).MarginLeft(2).Render("  🎣 Multiplayer Fishing Game CLI\n"))

	fmt.Println(lipgloss.NewStyle().Bold(true).Render("Usage:") + " lurelands [command]")
	fmt.Println()
	fmt.Println(lipgloss.NewStyle().Bold(true).Render("Commands:"))

	cmdStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#00CED1")).Width(20)
	descStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#AAAAAA"))

	orderedCmds := []string{
		"run", "run:ios", "run:android", "run:web",
		"deploy", "deploy:local",
		"bridge:build", "bridge:dev", "bridge:start", "bridge:generate",
	}

	categories := map[string]string{
		"run":            "Flutter",
		"deploy":         "Database",
		"bridge:build":   "Bridge",
	}

	for _, name := range orderedCmds {
		if cat, hasCategory := categories[name]; hasCategory {
			fmt.Printf("\n  %s\n", lipgloss.NewStyle().Foreground(lipgloss.Color("#666666")).Italic(true).Render("─── "+cat+" ───"))
		}
		cmd := commands[name]
		fmt.Printf("  %s %s\n", cmdStyle.Render(name), descStyle.Render(cmd.desc))
	}

	fmt.Println()
	fmt.Println(lipgloss.NewStyle().Foreground(lipgloss.Color("#666666")).Render("  Run without arguments for interactive mode"))
	fmt.Println()
}

