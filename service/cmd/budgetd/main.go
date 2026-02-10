package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"budgetexcel/service/internal/api"
	"budgetexcel/service/internal/db"
	"budgetexcel/service/internal/suggest"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

const version = "0.1.0"

func main() {
	cfg := loadConfig()

	database, err := db.Open(cfg.DBPath)
	if err != nil {
		log.Fatalf("db open failed: %v", err)
	}

	if err := db.RunMigrations(cfg.DBPath, cfg.MigrationsPath); err != nil {
		log.Fatalf("migrations failed: %v", err)
	}

	app := fiber.New()
	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format: "${time} ${status} - ${latency} ${method} ${path}\n",
	}))

	suggestCfg := suggest.LoadConfig()
	suggester, err := suggest.NewOrchestrator(database, suggestCfg)
	if err != nil {
		log.Printf("suggestions disabled: %v", err)
	}

	if suggester != nil {
		go suggester.StartPoller(context.Background())
	}

	api.RegisterRoutes(app, &api.API{
		DB:      database,
		Started: time.Now(),
		Version: version,
		DBPath:  cfg.DBPath,
		Suggestions: suggester,
	})

	log.Printf("budgetd listening on %s", cfg.Addr)
	if err := app.Listen(cfg.Addr); err != nil {
		log.Fatalf("listen failed: %v", err)
	}
}

type config struct {
	Addr           string
	DBPath         string
	MigrationsPath string
}

func loadConfig() config {
	addr := getenv("AUTODISCO_ADDR", "127.0.0.1:8787")
	localAppData := getenv("LOCALAPPDATA", "C:\\Users\\Admin\\AppData\\Local")
	defaultDB := filepath.Join(localAppData, "BudgetApp", "data", "budget.sqlite")
	migrationsPath := getenv("AUTODISCO_MIGRATIONS_PATH", "migrations")

	return config{
		Addr:           addr,
		DBPath:         getenv("AUTODISCO_DB_PATH", defaultDB),
		MigrationsPath: migrationsPath,
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func (c config) String() string {
	return fmt.Sprintf("addr=%s db=%s migrations=%s", c.Addr, c.DBPath, c.MigrationsPath)
}
